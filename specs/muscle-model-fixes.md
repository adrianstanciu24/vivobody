# Spec: Fix the muscle-development model issues

Status: implemented (Tier 0 `c8eb164`, Tier 1 `970bfa6`, Tier 2 `64cfa08`, Tier 3 — this update)
Date: 2026-06-24
Scope: `MuscleDevelopment`, `BodyModelScene`, `RotatableBodyModel`/`TodayScreen`,
`MuscleColor` (read-only), tests (`MuscleDevelopmentTests`, `BodyModelSceneTests`,
`MuscleMappingTests`). No data-model migration.

## Why

A review of the 3D body-model pipeline (`WorkoutSession[]` → effective sets →
`MuscleDevelopment` leaky integrator → `MuscleColor` ramp → `BodyModelScene`
materials → `RotatableBodyModel`) surfaced ten issues. All ten were verified
true against the code, the math, git history, and the `BodyModel.scn` archive.
They split into four tiers by risk and independence; this spec fixes them in
that order so the safe wins land first and the model rework stays isolated
behind the unchanged `Channels`/`State` API.

Verified findings (issue numbers referenced throughout):

1. **Frequency bias** in `V_ref` normalisation — the decay is grace-gated from
   `lastStimulated` and resets every session, so the same weekly volume split
   across more sessions reaches a higher steady state. `V_ref` is calibrated
   only for once-weekly dosing. Confirmed numerically: pectorals `V_ref ≈ 731`;
   1×/week (20 sets) → adaptation ≈ 0.87 after a year, 2×/week (10 sets, same
   weekly volume) → ≈ 0.98 (`V_ss` 1.67× higher). **Fix (this spec).**
2. **Load/progression blindness** — currency is completed-set *count* ×
   involvement weight, no load/reps/RIR term. Deliberate, documented.
   **Defer; document as a known limitation.** — Fixed 2026-07-11 by the
   hard-set-equivalent currency (`SetStimulus`), see
   `specs/hard-set-currency.md`.
3. **Very slow convergence** — weekly optimal training reaches only ≈ 0.874 at
   one year; 0.99 needs ≈ 2.7 years; 1×/week never reaches exactly 1.0.
   **Fix (folded into the rework).**
4. **Stale comment** — `TodayScreen` still says the figure pulses "where you've
   tightened up"; `Channels` now holds only `adaptation`. **Fix (one-line).**
5. **No `.scn` node-name validation test** — ~240 quirk-spelled node names
   (`Adductor_Mangus`, `Biceps_femoris`) are never checked against the archive;
   the existing `everyMuscleExpandsToLeftRightNodes` is a pure `_L`/`_R` string
   check. A re-export with corrected spelling would silently stop lighting
   muscles. **Fix (new test).**
6. **Render test doesn't verify colour** — `developmentLivesInTheDiffuseNotAShader`
   asserts diffuse-non-nil + no shader, never the expected orange. **Fix
   (strengthen test).**
7. **`applyMaterials` assumes a flat scene** — it walks only `pivot.childNodes`
   and `setMaterial` recursively stamps descendants, so an intermediate group
   node would flood untrained material over nested muscles. The archive is flat
   today (238 direct geometry children, depth 1), so this is latent fragility.
   **Fix (harden + the #5 test guards it).**
8. **Uncached full-history replay** — `MuscleDevelopment.simulate(from:)` is an
   un-memoised `let` inside the `ScrollView` body closure, O(sessions × muscles)
   on every body invalidation. **Fix (memoise).**
9. **No left/right asymmetry** — one value fans out to both `_L`/`_R`; the data
   model can't even record side. Deliberate. **Defer; document as a known
   limitation.**
10. **Saturation hides overtraining** — `min(1, …)` clamps, so 2× optimal looks
    identical to 1× optimal; volume bars flag `.high` separately. Intrinsic to a
    0–1 ramp. **Leave as-is; document.**

## Tier 0 — Safe correctness + test lockdown (no behaviour change)

### 4. Stale comment
`Screens/Today/TodayScreen.swift`, the `bodyModelHero` doc comment. Replace
"Lit by the muscles you've trained (development, with a pulse where you've
tightened up), so it reads as your body, not a mannequin." with a
development-only description (the figure no longer pulses). The accessibility
label already reads correctly and is untouched.

### 7. Harden `applyMaterials` against scene nesting
`Components/Displays/BodyModelScene.swift`. Today:

```swift
for child in pivot.childNodes {            // direct children only
    guard let name = child.name else { continue }
    child.opacity = 1
    setMaterial(materialFor(name: name, …), on: child)   // setMaterial recurses
}
```

`setMaterial` propagates the chosen material to the node *and every descendant*,
so a direct-child group node (name matches nothing → untrained base) would erase
nested muscle colours. Make material assignment **structure-agnostic and
per-mesh** by enumerating geometry nodes and keying off each mesh's own name:

```swift
pivot.enumerateChildNodes { node, _ in
    guard node.geometry != nil, let name = node.name else { return }
    node.opacity = 1
    node.geometry?.materials = [
        materialFor(name: name, channels: channels, theme: theme, bone: bone, tissue: tissue)
    ]
}
```

Group nodes (no geometry) are skipped; each mesh gets the material for its own
name; nothing propagates across the hierarchy. `setMaterial`'s
propagate-to-descendants helper is no longer needed and is removed. The
catch-all untrained behaviour for display-only meshes (face/hands) is preserved
because `materialFor` still returns the untrained base for unrecognised names.

### 5. Validate every node name exists in the archive
New test in `BodyModelSceneTests` (or `MuscleMappingTests`). Load the real
scene, collect every node name under `bodyPivot` recursively into a `Set`, and
assert each expected name is present:

```swift
@Test func everyMappedNodeExistsInArchive() throws {
    let scene = try #require(BodyModelScene.make(theme: .dark))
    let pivot = try #require(scene.rootNode.childNode(withName: "bodyPivot", recursively: true))
    var names = Set<String>()
    pivot.enumerateChildNodes { n, _ in if let name = n.name { names.insert(name) } }

    for muscle in Muscle.allCases {
        for node in muscle.nodeNames {
            #expect(names.contains(node), "BodyModel.scn missing node '\(node)' for \(muscle)")
        }
    }
    #expect(names.contains("Skeleton"))
}
```

This catches spelling drift on any future archive re-export — the exact failure
mode #5 describes — and is the regression guard for the #7 hardening.

### 6. Assert the render boundary applies the *correct* colour
Strengthen `developmentLivesInTheDiffuseNotAShader` (or add a sibling test):
compare the developed muscle's `diffuse.contents` (a `UIColor`) to the expected
`MuscleColor.rgb(for:theme:)` for its channels, within a small tolerance, per
theme. This ensures a wrong material *assignment* (e.g. from a future scene
change) is caught, not just a missing/shader-based tint.

```swift
let expected = MuscleColor.rgb(for: .init(adaptation: 0.9), theme: theme)
var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
(developed.diffuse.contents as! UIColor).getRed(&r, green: &g, blue: &b, alpha: &a)
#expect(abs(Double(r) - expected.red)   < 0.02)
#expect(abs(Double(g) - expected.green) < 0.02)
#expect(abs(Double(b) - expected.blue)  < 0.02)
```

## Tier 1 — Performance

### 8. Memoise the model replay
`Screens/Today/TodayScreen.swift`. `MuscleDevelopment.simulate(from:)` runs in
the `ScrollView` content closure with no caching, re-replaying the full history
on every body invalidation. Compute the state once per data change and cache it:

- Hold `@State private var modelState = MuscleDevelopment.State()` and a cheap
  signature `@State private var modelSignature = ""`.
- Recompute only when the signature changes, where
  `signature = "\(completedSessions.count)-\(completedSessions.first?.completedAt?.timeIntervalSince1970 ?? 0)"`
  (count + latest completion is sufficient — sessions are archived append-only
  and the `@Query` sorts by `completedAt` descending).
- Drive it from `.onChange(of: signature) { … }` plus an initial compute in
  `.onAppear`/`.task`, and read `modelState` in the body instead of calling
  `simulate` inline.

No behaviour change; the body stops doing O(sessions × muscles) work on
unrelated invalidations (unit toggle, sheet presentation, height latching).
The existing `.scrollTransition` depth effect is unaffected.

## Tier 2 — Model rework: frequency-invariant development (#1, #3)

The build replaces the grace-gated, reset-on-session accumulator `V` with a
**frequency-invariant estimate of recent weekly effective sets**, normalised
directly against the volume landmark. Same `Channels`/`State` public API; the
shared effective-set currency (`Exercise.effectiveSetsByMuscle`) is untouched.

### The root cause, precisely

Frequency bias is caused by `advance` measuring decay age from `lastStimulated`,
which `applyStimulus` resets every session. During active training the inter-
session gap sits inside the grace window, so almost no decay accrues between
doses and `V` piles up far above what weekly volume warrants — while `V_ref` is
the once-weekly steady state. Grace-from-last-session is therefore intrinsically
frequency-coupled.

### The new level: a weekly-volume estimate (constant-rate leaky integrator)

Per muscle, track `weeklyVolume` W (unit: effective sets per 7 days) and
`lastUpdate`. Both decay and stimulus are expressed so the steady state depends
only on the *average weekly rate*, not how it is chunked:

```
advance to t:   W *= exp(-(t - lastUpdate) / tau)           // constant-rate relaxation
stimulus s:     W += s * (7 / tau)                          // rate increment
```

`tau` is the relaxation time-constant in days (recommended `tau ≈ 65`, i.e. the
old ~45-day half-life: `tau = halfLife / ln 2`). Under a weekly volume `Q`
delivered in `n` equal doses spaced `T = 7/n` apart, the post-dose steady state
is

```
W_peak = (Q/n)(7/tau) / (1 - exp(-7 / (n·tau)))   ->  Q   as n grows
```

With `tau = 65`: 1×/week → `1.055·Q`, 2×/week → `1.027·Q`, continuous → `Q`. The
residual frequency spread is **~3%** (down from the current ~67%), and the
time-average of W is exactly `Q` regardless of cadence. Decay remains an exact
semigroup (`exp(-(a+b)/tau) = exp(-a/tau)·exp(-b/tau)`), so order-independence
and "advance once vs many times agree" are preserved.

### Development: normalise directly against the landmark

Because W already estimates weekly volume, the reference is simply the landmark
band top — no separate `V_ref` derivation:

```
adaptation = min(1, (W / landmark.optimalHigh) ^ developmentGamma)   // gamma ≈ 0.5
```

The one-sentence contract is now literally true: **colour = your estimated
recent weekly effective sets versus your productive target.** Train at
`optimalHigh` → W ≈ `optimalHigh` → adaptation → ~1.0 regardless of split. Train
at `mev` → plateaus near `(mev/optimalHigh)^gamma`. Same weekly volume, same
colour speed (#1 fixed).

### Convergence recalibration (#3)

Build is governed by `tau`: `W(t) ≈ W_ss·(1 - exp(-t/tau))`. At `optimalHigh`
weekly with `tau = 65`, `gamma = 0.5`:

| Elapsed | W / optimalHigh | adaptation |
|---|---|---|
| 6 weeks  | ~0.50 | ~0.71 |
| 3 months | ~0.79 | ~0.89 |
| 6 months | ~0.98 | ~0.99 |
| 1 year   | clamp | 1.0 |

vs the old ~0.87 at a full year. `tau` and `gamma` are the two calibration
knobs; the calibration-sweep test pins the bands. Full vivid is now reachable in
~6–12 months of consistent optimal training instead of "multiple years / never".

### Grace ("holds ~a week, then fades")

A constant-rate `tau ≈ 65` already holds most colour through the first week:
at 5 days, `W` retains `exp(-5/65) = 0.926`, and after the `gamma = 0.5` square
root the colour retains `~0.96` — consistent with the existing detraining
assertion that 5-day colour stays above ~0.95 of fresh. We therefore **drop the
grace-gated sigmoid + softplus** (it was the source of the frequency coupling)
and rely on `tau` for the hold-then-fade, recalibrating the detraining test to
the new curve. If a sharper flat-then-knee is later desired, it can return as a
*read-time* hold keyed on days-since-last-session (unambiguous during a layoff,
so frequency-invariant) rather than as accumulator decay — explicitly out of
scope here.

### Code changes (`Models/MuscleDevelopment.swift`)

- Rename `Fiber.volume` → `weeklyVolume`; keep `lastStimulated` (used for
  `daysSinceLastTrained`-style recency and the rate update's `lastUpdate`).
- `advance`: replace the grace-gated `decayFactor` call with
  `weeklyVolume *= exp(-dtDays / tau)`.
- `applyStimulus`: `fiber.weeklyVolume += sets * (7 / tau)`.
- `State.development`: `min(1, pow(W / landmark.optimalHigh, developmentGamma))`;
  delete `referenceVolume` and the `weeklyDecayFactor` derivation.
- `Parameters`: replace `decayRate`/`graceDays`/`graceWidth` with a single
  `tau` (≈ 65); keep `developmentGamma`. Delete `decayFactor`/`softplus` (or
  keep `softplus` only if reused; expected: deleted).
- Update the file header to describe the weekly-volume estimator and the new
  one-sentence contract.

## Tier 3 — Documented limitations (no code behaviour change)

Add a short "Known limitations (accepted)" note to the `MuscleDevelopment`
header and reference it here:

- **#2 Load/progression blindness** — colour reads volume consistency, not load,
  reps, or RIR; a light and a heavy set count the same. Per-lift progression
  lives on `ExerciseProgress` / strength trajectory. (Already stated in the
  header; keep and cross-reference.)
- **#9 No left/right asymmetry** — development is per bilateral `Muscle`; both
  `_L`/`_R` meshes share a value and the log cannot record side. Unilateral
  imbalance is out of scope until the data model records side.
- **#10 Saturation** — `adaptation` clamps at 1.0, so the body cannot depict
  over-target volume; the weekly volume bars' `.high` zone remains the surface
  for excess.

## Test plan

- **Rewrite `MuscleDevelopmentTests`** for the new model:
  - **Frequency invariance (new, the headline test):** the same weekly volume
    (e.g. 20 sets) delivered 1×, 2×, and 3× per week converges to adaptations
    within a small tolerance of each other (assert spread < ~0.05).
  - Build monotonic; never maxes in one session; scales with weekly volume.
  - Convergence bands match the recalibration table above (≈0.71 @ 6 wk,
    ≈0.89 @ 3 mo, ≈0.99 @ 6 mo).
  - `mev`-level training plateaus near `(mev/optimalHigh)^gamma`, distinctly
    below an `optimalHigh` program.
  - Detraining: holds most colour through ~1 week, then fades, deeper over time.
  - Order-independence (constant-rate semigroup) and determinism retained.
  - Currency still equals `MuscleVolume` effective sets, scaled by involvement.
- **Calibration sweep** (keep the salmon-collapse guard): four synthetic 12-week
  programs (beginner full-body, push/pull/legs, bench-only, and a base then
  12 weeks off) land in visually distinct bands and the neglected program fades.
- **`BodyModelSceneTests`:** new `everyMappedNodeExistsInArchive` (#5);
  strengthened colour assertion in `developmentLivesInTheDiffuseNotAShader` (#6).
- **`MuscleMappingTests`:** unchanged (`everyMuscleExpandsToLeftRightNodes`
  stays as the cheap string check; the new archive test complements it).

## Verification

1. `xcodebuild -scheme vivobody -destination 'generic/platform=iOS Simulator' build` — zero warnings.
2. `xcodebuild … test` — full suite green.
3. `Scripts/verify.sh` — Today body renders development colours from seeded
   data; bands distinguishable, no all-salmon body; compare against a
   pre-change screenshot for plausibility.

## Rollout order

1. [done — `c8eb164`] Tier 0: stale comment (#4), harden `applyMaterials` (#7),
   add archive node test (#5), strengthen render colour test (#6).
2. [done — `970bfa6`] Tier 1: memoise the replay (#8).
3. [done — `64cfa08`] Tier 2: rework `MuscleDevelopment` to the weekly-volume
   estimator behind the unchanged `Channels`/`State` API (#1); recalibrate
   `tau`/`gamma`, add the frequency-invariance + convergence tests, recalibrate
   the calibration bands (#3).
4. [done] Tier 3: header "Known limitations" note (#2, #9, #10).
5. [done] Build (zero warnings), full suite (113 tests green), `Scripts/verify.sh`
   (Today body renders development colours).

## Implementation notes (as-built deviations from the plan)

- **`Fiber.lastStimulated` was dropped, not kept.** With constant-rate decay the
  elapsed interval is the state-level `lastUpdate` (same for every fiber), so the
  per-fiber timestamp the grace gate needed is gone. `Fiber` now holds only
  `weeklyVolume`. `MuscleVolume` computes its own `daysSinceLastTrained`
  independently, so nothing else depended on it.
- **`Channels` is marked `nonisolated`** to keep the pure value-type model (and
  its `Equatable` conformance) usable off the main actor, matching the
  `nonisolated struct VolumeLandmark` convention in `MuscleVolume.swift`.
- **Calibration sweep kept its existing bench-cadence programs** (dedicated vs
  casual, prime-vs-assistor, neglect schedule) rather than introducing four new
  synthetic programs; the bands were recalibrated to the new curve (dedicated
  2×6/12wk ≈ 0.67, casual 1×3/12wk ≈ 0.34, one-week-off ≈ 0.95 of fresh).
- **Existing `MuscleDevelopmentTests` mostly survived unchanged** — the new model
  reproduces build/diminishing-returns/detraining/convergence behaviour — so the
  edits were a `.volume`→`.weeklyVolume` rename plus two added tests
  (frequency invariance, convergence bands) rather than a full rewrite.
- **Measured results:** frequency spread for identical weekly volume split
  1×/2×/3× = 0.013 (was ~67% bias, #1); convergence ≈ 0.71 @ 6 wk, 0.89 @ 3 mo,
  0.995 @ 6 mo (#3).
```
