# Spec: Simplify the muscle development model

Status: implemented (2026-06-12), with exercise semantics updated by
`exercise-data-contract.md` (2026-07-19). Notes:
`MuscleForecastBoard.fadeThreshold` recalibrated 0.92 → 0.95 for the
γ-softened decay curve. `ExerciseLoad` now owns comparable resistance
semantics and is no longer orphaned.
Date: 2026-06-11
Scope: `MuscleDevelopment`, `Muscle`, `BodyReadiness`, `MuscleTightness`,
`MuscleMomentum`, `MuscleForecast`, `TodayScreen`, `InsightsScreen`, tests.

## Why

The current `MuscleDevelopment` model (Banister impulse-response +
Rescorla–Wagner habituation + Verhulst ceiling + Weber–Fechner log stimulus)
produces exactly four user-visible behaviours:

1. development builds over weeks of training,
2. it plateaus,
3. it holds for ~a week of neglect, then fades,
4. heavier/larger doses develop more than trivial ones.

It does this with ~30 interacting tunables across four stacked nonlinearities,
which makes the final colour unexplainable ("why is my chest 0.62?") and
calibration fragile. It also runs as a full-history replay five times per
screen pass (Today body, readiness, tightness, momentum, forecast), and it
maintains a second, disjoint "how much work" currency (tonnage) alongside the
effective-set currency `MuscleVolume` already defines and calibrates.

This spec replaces the growth machinery with a leaky integrator over the
**same effective-set currency as `MuscleVolume`**, normalised by the volume
landmarks we already maintain, trims the tightness model to its observable
core, and computes the model state once per screen pass.

## What stays (deliberately)

These parts earn their complexity and are untouched:

- **Categorical involvement roles** (`Muscle.Involvement`) — primary and
  secondary muscles project to fractional volume credit; stabilizers remain
  visual but earn no hard-set credit.
- **Grace-gated closed-form decay** (`decayFactor` / softplus) — exact,
  order-independent, already tested. It is the "holds for a week, then fades"
  behaviour, and the forecast board marches it into the future.
- **Momentum via fast/slow trackers** — `adaptationSlow`, `slowFollowRate`,
  `momentumReference` and the slow decay knobs stay as-is; the Insights
  momentum board reads them.
- **Fatigue channel shape** — saturating bump + half-life decay (re-based to
  set units, see below).
- **`MuscleColor` and `BodyModelScene`** — the renderer consumes a generic
  muscle-map channel. Continuous trained colours interpolate in perceptual
  OKLab space; a neutral no-history baseline remains distinct from faded
  trained tissue.
- **Public API shapes** — `Channels`, `State`, `simulate`, `nodeChannels`,
  and the four downstream boards keep their types; only internals and
  parameters change.

## The new development model

### Currency: effective sets

One completed set credits each involved muscle `1 × involvement weight`
effective sets — identical to `MuscleVolume`. Both tracking modes count the
same (a logged hold is one set). Tonnage, bodyweight fractions, and the RIR
discount leave the model entirely.

```
sessionSets[muscle] = Σ over strength exercises:
    completedSetCount × involvement.volumeCredits[muscle]
```

### Level: leaky integrator with the existing grace-gated decay

Per muscle, a single accumulator `V` (unit: effective sets):

- On a session: `V += sessionSets[muscle]`, `lastStimulated = date`.
- Over time: `V *= decayFactor(ageStart, ageEnd, rate, graceDays, width)` —
  the existing closed-form grace-gated decay, same knobs
  (`decayRate = ln2/45`, `graceDays = 7`, `graceWidth = 3`).

### Development: normalised against the volume landmark

```
V_ref(muscle) = landmark(muscle).optimalHigh / (1 − weeklyDecayFactor)
adaptation    = min(1, (V / V_ref) ^ developmentGamma)      // gamma ≈ 0.5
```

- `weeklyDecayFactor` is `decayFactor(0, 7, …)` — derived from the decay
  knobs, not a new constant. `V_ref` is therefore the steady state `V`
  reaches when you train the muscle at the top of its productive band every
  week. Train at `optimalHigh` consistently → development converges to 1.0.
  Train at `mev` → it converges to ≈ `(mev/optimalHigh)^γ`.
- `developmentGamma` (≈ 0.5) is the one perceptual knob: concave so early
  sessions are visibly rewarded (newbie gains) while vivid orange still takes
  months of consistency.

The one-sentence explanation, which is the point: **"colour = how
consistently you've kept this muscle near its productive weekly set range."**
The body, the volume bars, and the neglect list now agree by construction
because they share one currency and one landmark table.

### Momentum: unchanged mechanism, new substrate

`adaptationSlow` tracks `adaptation` exactly as today (per-session pull by
`slowFollowRate`, slower grace-gated decay). `momentum = clamp((A − A_slow) /
momentumReference)`. Thresholds in `MuscleMomentumBoard` get re-checked in
the calibration tests (see below) since the adaptation curve changes shape.

### Fatigue: re-based to sets

```
fiber.fatigue = min(1, fatigue + (1 − exp(−sessionSets / fatigueSetScale)))
```

`fatigueSetScale ≈ 6` (a hard ~6-effective-set session reads near-fully
fresh). Half-life decay unchanged (`fatigueHalfLifeDays = 2`).
`BodyReadiness.freshFatigueThreshold` re-verified in tests.

### What we knowingly lose

- **Load-progression sensitivity.** A 5 lb curl set counts like a 50 lb curl
  set; "same weights forever → growth stalls" is no longer derived. Plateau
  now comes from volume saturation, not habituation. Accepted: the body
  reads training consistency and balance; per-lift load progression already
  has its own surfaces (`ExerciseProgress`, strength trajectory).
- **Load-scaled ceiling.** Replaced by the landmark normalisation.

## The simplified tightness model

Keep the observable core: *contraction-biased volume tightens, lengthening
work relieves, rest slowly eases.*

- **Tighten:** `T = min(1, T + tightenGain × romSets × susceptibility)` where
  `romSets = Σ sets × involvement × tighteningBias(exercise)`. The
  `tighteningBias` heuristic (isometric 1.0 / isolation 0.9 / compound 0.6 /
  lengthened-pattern 0.3) stays. `tightenGain ≈ 0.04`, calibrated so 1–2 hard
  contraction-biased sessions on a susceptible muscle cross the 0.25 flag
  threshold.
- **Relieve:** unchanged — `T *= exp(−mobilityRelief × dose)` from mobility
  work and the small full-ROM credit (`movementDose`, `mobilityRepSeconds`,
  `fullRomReliefFraction` all stay).
- **Rest:** grace-gated decay to **zero** — the `tightnessRestFloor` is
  deleted. Same decay knobs (`tightnessDecayRate`, grace 3 d, width 3 d).

**Deleted:** `posturalAmplifier`, `Parameters.posturalCouplingGain`, and
`Muscle.tightnessAntagonist` (the crossed-syndrome coupling).
`Muscle.tightnessSusceptibility` stays — it is one table, observable in
output, and cheap.

## Compute once: shared state

Today `MuscleDevelopment.simulate` (full-history replay) runs independently
inside `nodeChannels` (Today body), `bodyReadiness`, `muscleTightness`,
`muscleMomentum`, and `muscleForecast`.

- Refactor the four boards to derive from an existing state:
  `BodyReadiness(state:now:)`, `MuscleTightnessBoard(state:)`,
  `MuscleMomentumBoard(state:now:)`, `muscleForecast(state:now:horizonDays:)`
  (forecast copies the state before marching it forward).
- Keep thin `[WorkoutSession]` convenience extensions that call `simulate`
  then delegate, so existing tests and call sites still read naturally.
- `TodayScreen` and `InsightsScreen` each compute **one**
  `MuscleDevelopment.State` per data change and feed all their consumers.
- Drop the `bodyweight:` parameter from `simulate`, `nodeChannels`,
  `nodeIntensities`, and all four boards — the model no longer needs
  `ExerciseLoad` or the latest body weight. (`ExerciseLoad` itself stays for
  its other consumers.) `TodayScreen` stops passing `bodyWeights.latest` to
  the model.

Incremental state snapshots (persisting `State` and only advancing with new
sessions) remain a possible follow-up; with the 5× replay collapsed to 1×
they are not needed yet.

## Parameter inventory (before → after)

| Group | Before | After |
|---|---|---|
| Growth | cap, growthGain, initialOverload, habituationRate, ceilingFloor, ceilingStimulusLow, ceilingStimulusHigh (7) | developmentGamma (1) + the shared landmark table |
| Decay | decayRate, graceDays, graceWidth (3) | same (3) |
| Momentum | 5 | same (5) |
| Fatigue | fatigueHalfLifeDays, fatigueScale (2) | fatigueHalfLifeDays, fatigueSetScale (2) |
| Tightness | tightenGain, mobilityRelief, fullRomReliefFraction, decay ×3, restFloor, mobilityRepSeconds, posturalCouplingGain (9) | drop restFloor + coupling (7) |
| Effort | secondsPerRepEquivalent, effortPerReserveStep (2) | secondsPerRepEquivalent for mobility dose only (1) |
| **Total** | **~28** | **~19, with the 7-knob growth stack reduced to 1** |

## File-by-file changes

- `Models/MuscleDevelopment.swift` — replace `applyStimulus` growth math with
  the integrator + landmark normalisation; re-base `sessionStimulus` /
  `Impulse` to effective sets (rename `loadStimulus` → `effectiveSets`);
  delete `ceiling`, `smoothstep`, habituation, `completedEffort`,
  `effortFactor`, `posturalAmplifier`; re-base fatigue; remove
  `bodyweight` parameters; update the header comment to the new model.
- `Models/Muscle.swift` — delete `tightnessAntagonist`.
- `Models/MuscleVolume.swift` — extract the per-session effective-set
  crediting into a shared helper both `muscleVolume` and `MuscleDevelopment`
  call, so the currency cannot drift.
- `Models/BodyReadiness.swift`, `MuscleTightness.swift`,
  `MuscleMomentum.swift`, `MuscleForecast.swift` — accept a prebuilt `State`;
  keep `[WorkoutSession]` wrappers; drop `bodyweight:`.
- `Screens/Today/TodayScreen.swift`, `Screens/Insights/InsightsScreen.swift`
  — compute one `State`, pass it down; stop threading body weight into the
  model.
- `Components/Displays/BodyModelScene.swift`, `Models/MuscleColor.swift` —
  no changes.

## Test plan

- **Rewrite `MuscleDevelopmentTests`** for the new behaviour: builds over
  sessions; asymptotes at the landmark steady state; order-independence
  (still guaranteed by the decay semigroup + commutative session adds);
  ~1-week colour hold then fade; momentum sign during growth vs layoff;
  fatigue bump/decay in set units.
- **Update `MuscleTightnessTests`**: delete antagonist-coupling and
  rest-floor tests; keep accrual / relief / threshold tests, re-calibrated.
- **New calibration sweep test** (the lesson from the salmon-collapse bug):
  run four synthetic 12-week programs — beginner full-body, push/pull/legs,
  bench-only bro split, and 12 weeks of nothing after a base — and assert
  the resulting adaptations land in visually distinct bands and that the
  neglected program fades on schedule.
- **Boards**: re-verify `MuscleMomentumBoard` thresholds,
  `BodyReadiness.freshFatigueThreshold`, and `MuscleForecast` fade days
  against the new curves; tune constants in the boards, not the UI.

## Verification

1. `xcodebuild -scheme vivobody -destination 'generic/platform=iOS Simulator' build` — zero warnings.
2. `xcodebuild … test` — full suite.
3. `Scripts/verify.sh` — Today body renders with development colours and a
   single pulsing muscle from seeded data; compare against a pre-change
   screenshot for plausibility (bands distinguishable, no all-salmon body).

## Rollout order

1. Extract the shared effective-set crediting helper from `MuscleVolume`.
2. Rewrite `MuscleDevelopment` internals (growth, fatigue, tightness) behind
   the unchanged `Channels`/`State` API; update tests + calibration sweep.
3. Delete `tightnessAntagonist` and dead parameters.
4. Shared-state refactor of the four boards + two screens; drop `bodyweight`.
5. Build, test, `Scripts/verify.sh`, screenshot review.
