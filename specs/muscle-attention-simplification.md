# Spec: Muscle map as training attention (simplification pass)

Status: historical implementation record; persistence details superseded by
the current family-first model (2026-08)
Date: 2026-08
Scope: `SetStimulus` (rewritten stateless), `AnalyticsAccumulator`,
`MuscleDevelopment` (linear map, one landmark), `MuscleVolume` (one landmark),
`Muscle` (`resolvedInvolvement` deleted), a temporary snapshot repair,
`Workout`/`WorkoutTemplate`/`ExerciseCatalog` accessors, `TrainingLoad` copy,
and tests. The current pre-production model removed the repair and reset
development data; these paragraphs describe the superseded coarse-taxonomy
implementation.
Supersedes: the pricing machinery of `hard-set-currency.md` and the γ/landmark
table of `simplify-muscle-model.md`. Catalog data fixes (over-generous
secondaries, unsupported micro-regions) are deliberately deferred — see
"Deferred" below.

## Why

First-principles audit of the catalog → stats → 3D body pipeline. The ground
truth the app actually has is (a) a diary of named exercises with completed
sets and (b) an authored belief table (catalog roles). No muscle measurement is
ever logged. Everything the body model shows is therefore an estimate of
**where training attention has gone lately** — not of physiological
development. The pipeline, however, had accreted precision far beyond that
input's accuracy:

- **Calibration inversion.** Simulating a typical PPL week through the old
  math (per-set load/rep factors → per-muscle 3-bucket landmarks → γ=0.5
  concave map) rendered never-directly-trained lower back at ~0.65 while
  directly-benched pectorals sat at ~0.39. Spillover credit from big compound
  lifts (deadlifts/rows credit up to 16 muscles), small landmarks for "low
  responders", and γ's inflation of small values compounded each other.
- **Stateful pricing.** `SetStimulus.Calculator` maintained per-exercise
  decaying e1RM references so warm-ups and token weights could be demoted.
  It forced every consumer through a chronological replay and modelled
  "how impressive a set was" — a claim the diary cannot back.
- **Hot-path legacy repair.** Every `muscleInvolvement` read re-ran a
  legacy-snapshot recovery (including two exact Hip Abduction snapshot
  upgrades), coupling a one-time data problem to every analytics pass.

## Decision

The body model claims one thing: **colour = estimated recent weekly hard
sets, versus one shared productive target.** Every factor that estimated
set *quality* beyond the user's own effort rating was removed.

### Removed

- `SetStimulus.Calculator` and both decaying load-reference tables
  (dynamic e1RM refs, isometric hold refs), `loadFactor`, `repFactor`,
  `holdFactor`, and the stimulus floor. Pricing is now a pure per-set
  function: `1.0 × effortFactor(RIR)`.
- Warm-up demotion. The stored warm-up set kind was removed, and the load
  heuristic was the only remaining demotion. Decision (user): count every
  completed set (Option A). Honest logging is the contract.
- The per-muscle `VolumeLandmark` table (3 buckets: 20/16/12). One shared
  `VolumeLandmark.default` (mev 8, optimalHigh 18) for every muscle. The
  literature's per-muscle ranges are wide, contested, and were the main
  source of the inversion.
- `developmentGamma` (0.5). Intensity is now linear:
  `min(1, W / optimalHigh)` — 0.5 means literally "half the weekly target".
- `Muscle.resolvedInvolvement(...)` hot-path recovery. A temporary launch
  repair replaced it during development, then was deleted when development
  data reset. Current `muscleInvolvement` accessors are pure
  `Involvement(snapshot:)` decodes.

### Kept (earns its keep)

- Catalog roles + 1.0/0.5/0 role credit (primary/secondary/stabilizer);
  stabilizers stay visual-only.
- The RIR discount: RIR 0–2 = full set, ×0.8 per rep further in reserve,
  neutral when unlogged (non-raters are never punished).
- Modality gates: only dynamic-strength reps and isometric-strength holds
  earn credit.
- The leaky integrator (`W += s·7/τ` per session, `exp(−Δt/τ)` decay,
  τ = 65 d): frequency-invariant, order-independent, one time constant.
- The colour pipeline unchanged: OKLab ramp, coarse bands, per-theme stages.

## Calibration (post-change reference values)

Bench-style primary work, evaluated at the last session:

| Program | Development |
|---|---|
| 1 session, 3 sets | ~0.02 |
| 12 wk casual (1×/wk, 3 sets) | ~0.13 |
| 12 wk dedicated (2×/wk, 6 sets) | ~0.50 |
| 18 sets/wk (target) for 6 / 13 / 26 wk | ~0.50 / ~0.79 / ~0.99 |
| Layoff | ×0.90 per week (τ = 65 d), never inverted against direct work |

Secondaries read at exactly half their primary. `MuscleVolume`,
`MuscleDevelopment`, and `TrainingLoad` all consume the same
`SetStimulus.price(for:parameters:)`, so every surface agrees on what "a set
of work" is worth by construction.

## Test impact

- `SetStimulusTests` rewritten for the stateless contract (anchors, role
  credit, modality gates, RIR curve, cross-surface agreement).
- `MuscleCalibrationTests`: warm-up-padding and token-weight tests deleted
  (concepts removed); bands recalibrated; fixtures now name the real catalog
  record ("Barbell Bench Press" — the roster curation had renamed it, so the
  old fixtures silently resolved to empty involvement).
- `MuscleDevelopmentTests` were recalibrated for the linear map. Temporary
  repair tests were deleted with the repair.
- `MuscleMappingTests` now guard the exact 53-region taxonomy and SceneKit
  ownership rather than a compatibility rewrite.

## Deferred (data fixes, separate pass)

- ~~Trim over-generous catalog secondaries so spillover stops out-shining
  direct work at the data source.~~ Done (2026-08, follow-up pass): 879
  secondary roles demoted to stabilizer (1,566 → 687, −56%; abs 143 → 4,
  calves 96 → 9, forearms 126 → 31, lower back 85 → 18), all 533 primaries
  unchanged, every exercise then ≤ 3 secondaries, with all 24 coarse `Muscle`
  cases represented. This roster was later superseded by the 52-region
  family-first catalog.
- Micro-regions the catalog cannot support (TFL still 0 primary / 1
  secondary, subscapularis 2 primaries with no mesh, teresMajor never
  primary, serratus 2 primaries): merge or give them real coverage.
