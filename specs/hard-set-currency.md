# Spec: Hard-set-equivalent work currency (load / reps / RIR awareness)

Status: implemented (2026-07-11)
Date: 2026-07-11
Scope: new `Models/Insights/SetStimulus.swift`, `MuscleVolume` (currency +
session ordering), `MuscleDevelopment` (currency, header), consumers unchanged
(`SessionAnalytics`, `TrainingSignature`, `AntagonistBalance`, Today attention
tiles, Insights sections, 3D body). Tests: new `SetStimulusTests`, additions to
`MuscleCalibrationTests`; existing `MuscleVolumeTests` / `MuscleDevelopmentTests`
/ `BodyModelSceneTests` must pass unchanged. No data-model migration.

## Why

The 3D body's colour is driven by `MuscleDevelopment`, whose work currency is
`Exercise.effectiveSetsByMuscle`: completed-set **count** × graded involvement
weight. This is limitation #2 in `specs/muscle-model-fixes.md`, accepted at the
time and documented in the `MuscleDevelopment` header:

> Load/progression blindness. A 5 lb set counts like a 50 lb set (reps and RIR
> likewise).

Concretely, today the model cannot distinguish:

- a 5 lb curl from a 50 lb working curl (load),
- a heavy single from a full working set (reps),
- a set stopped 5 reps shy of failure from a set taken to failure (RIR),
- warm-up ramps from working volume (they count whole).

Everything needed to fix this is already logged per `SetRecord`: `weight`
(canonical lb), `reps`, `duration`, `repsInReserve` + `rirLogged` (the flag that
already solves the default-RIR-2 masquerade). Epley e1RM math already exists
(`ExerciseProgressPoint.estimated1RM`).

Decision (2026-07-11): upgrade the **shared** currency, not just the body
model. `MuscleVolume` (weekly bars, neglect list, antagonist balance) and
`MuscleDevelopment` (3D body, signature) keep agreeing by construction — the
invariant both file headers promise. This is also semantically correct: the
volume-landmark literature the bars are calibrated against counts **hard
sets** (sets near failure at meaningful load), which is exactly what the new
currency measures.

## What stays (deliberately)

- The integrator: leaky weekly-volume estimate, τ ≈ 65 d, `s · 7/τ` stimulus
  injection, exact exponential decay. Untouched.
- Landmark normalisation and γ = 0.5 development map. Untouched.
- `VolumeLandmark` values. Unchanged — the anchor below is chosen so a
  genuinely hard working set is still worth exactly 1.0 sets.
- Graded involvement weights. Still the outermost multiplier.
- `MuscleColor` / `BodyModelScene` / `Channels` / `State` API shapes. Untouched.
- The completion gate — only `isCompleted` sets count.

This is a currency upgrade, not a model rework. The one-sentence read becomes:
**colour = your estimated recent weekly hard sets, versus your productive
target.**

## The new currency: hard-set equivalents

One completed set credits each involved muscle:

```
credit = involvement × effort(RIR) × repFactor(reps | duration) × loadFactor(e1RM ratio)
```

Each factor is ≤ 1 (multipliers only subtract; junk fades, nothing inflates),
and each is **anchored at 1.0 for a normal hard working set**, so users who
train and log properly see the same colours and bars as today, and the
existing landmark calibration holds.

### 1. effort(RIR) — proximity to failure

Only meaningful when `rirLogged == true` (`.reps` sets only; the flag is never
true for `.duration` holds). Unlogged → **neutral 1.0**: never punish a user
for not rating.

```
effort = effortDecayPerRIR ^ max(0, rir − 2)      // effortDecayPerRIR = 0.8
```

| RIR | 0–2 | 3 | 4 | 5 |
|---|---|---|---|---|
| effort | 1.00 | 0.80 | 0.64 | 0.51 |

RIR 0–2 all count as full hard sets — that matches the "within ~3–4 reps of
failure is stimulating" consensus the landmarks assume, and it means the
typical logged rating (2) stays at full credit (no landmark recalibration, no
colour shift for existing users).

### 2. repFactor — set duration of tension

Very low-rep sets (heavy singles/doubles) deliver less hypertrophy stimulus
per set than 5+-rep sets; beyond ~5 reps, a hard set is a hard set (20-rep
sets near failure count the same as 8-rep sets near failure — deliberately no
tonnage term, see "Rejected alternatives").

```
.reps:      repFactor = reps ≥ fullCreditReps ? 1 : repFloor + (1 − repFloor) × (reps − 1) / (fullCreditReps − 1)
.duration:  repFactor = min(1, duration / fullCreditSeconds), floored at repFloor
```

Defaults: `fullCreditReps = 5`, `fullCreditSeconds = 20`, `repFloor = 0.5`
(a heavy single is genuinely half a hard set, not noise).

| reps | 1 | 2 | 3 | 4 | 5+ |
|---|---|---|---|---|---|
| repFactor | 0.50 | 0.625 | 0.75 | 0.875 | 1.00 |

### 3. loadFactor — load relative to YOUR history on this lift

The term that kills the 5 lb curl problem and demotes warm-up ramps even when
RIR isn't logged. No absolute thresholds — everything is relative to the
lifter's own demonstrated strength on that exercise.

Per `.reps` set with `weight > 0`:

```
r          = e1RM(set) / reference          // e1RM = weight × (1 + reps/30), Epley — same formula as ExerciseProgress
loadFactor = loadFloor + (1 − loadFloor) × clamp((r − rampLow) / (rampHigh − rampLow), 0, 1)
```

Defaults: `rampLow = 0.4`, `rampHigh = 0.7`, `loadFloor = 0.3`.

| r (set e1RM / reference) | ≤ 0.4 | 0.5 | 0.6 | ≥ 0.7 |
|---|---|---|---|---|
| loadFactor | 0.30 | 0.53 | 0.77 | 1.00 |

Anything at ≥ 70 % of your demonstrated e1RM is a full-credit load — that
covers every sane working-set scheme (5×5 at 85 %, 3×8 at 75 %, 3×12 at 70 %).
A 135 lb warm-up before a 315 bench (r ≈ 0.43) earns ~0.37; a 5 lb curl for
someone who curls 50 (r ≈ 0.1) earns the 0.3 floor before the rep/effort terms.

Neutral (1.0) cases, all deliberate:

- `weight == 0` — bodyweight movements (pull-ups, dips, push-ups) and
  unloaded holds carry no load signal; involvement + effort + reps carry them.
- `.duration` sets — e1RM is a rep construct; weighted holds get no load term.
- No reference yet — the first-ever instance of a lift full-credits and seeds
  the reference. New exercises are never punished for having no history.

**The reference** is a per-exercise **decaying max** of set e1RM, keyed by
`ExerciseIdentity.key(catalogItemID:name:)` (stable-ID with name fallback, the
same identity every other per-exercise surface uses):

```
on each completed set:   reference = max(e1RM(set), reference × exp(−Δt / referenceTau))
```

`referenceTau = 130` days (a ~90-day half-life). A decaying max instead of an
all-time max so that a lifter returning from a long layoff isn't demoted for
honest working sets that sit below a year-old PR; the reference relaxes toward
what they currently lift. Updates are **causal**: a set is judged against the
reference *before* it raises it, so the PR set itself gets full credit and the
warm-ups before it are judged against real history.

### Total floor

`credit` per set is floored at `stimulusFloor = 0.1` × involvement before
crediting, so any completed set still registers (a muscle that did *something*
never reads identical to one that did nothing, and `VolumeZone.untrained`
still means literally untrained).

### Worked example — one bench session, 315 lb e1RM reference

| set | weight × reps | RIR (logged) | effort | rep | load | credit (chest, inv 1.0) |
|---|---|---|---|---|---|---|
| warm-up | 135 × 10 | — | 1.00 | 1.00 | 0.37 | 0.37 |
| warm-up | 225 × 5 | — | 1.00 | 1.00 | 0.95 | 0.95 |
| work | 275 × 6 | 2 | 1.00 | 1.00 | 1.00 | 1.00 |
| work | 275 × 6 | 1 | 1.00 | 1.00 | 1.00 | 1.00 |
| back-off | 185 × 12 | 4 | 0.64 | 1.00 | 0.85 | 0.54 |

Old currency: 5.0 chest sets. New: 3.86 hard-set equivalents — the number a
coach would actually write down. (The 225×5 warm-up reading 0.95 is correct
behaviour: at 78 % e1RM for 5 it *is* nearly a working set; the RIR term is
what would demote it further, if rated.)

## Architecture

### New file: `Models/Insights/SetStimulus.swift`

`Exercise.effectiveSetsByMuscle` can no longer be a pure property of one
exercise — the load factor needs history. It is replaced by a small stateful
calculator that carries the trailing reference table across a chronological
replay:

```swift
nonisolated enum SetStimulus {
    struct Parameters {                 // all knobs above; static let `default`
        var effortDecayPerRIR = 0.8
        var fullCreditReps = 5
        var fullCreditSeconds: TimeInterval = 20
        var repFloor = 0.5
        var rampLow = 0.4, rampHigh = 0.7, loadFloor = 0.3
        var referenceTau = 130.0        // days
        var stimulusFloor = 0.1
    }

    /// Carried across a chronological session replay. Value type —
    /// pure, testable on a virtual clock like every other model.
    struct Calculator {
        init(parameters: Parameters = .default)
        /// Hard-set-equivalent credit per muscle for one exercise's
        /// completed sets, judged against (then updating) the trailing
        /// per-exercise e1RM reference. `date` is the session's clock.
        mutating func credit(for exercise: Exercise, at date: Date) -> [Muscle: Double]
    }
}
```

Internals: `[String: (e1RM: Double, at: Date)]` keyed by exercise identity;
per-set factor functions exposed (internal) for direct unit testing.

### `MuscleVolume` changes

- `Exercise.effectiveSetsByMuscle` is deleted (only two call sites exist);
  `muscleVolume(window:now:)` builds a `SetStimulus.Calculator` and replays
  sessions **sorted ascending by completion date** — required for causal
  references; today's loop is order-blind so sorting changes nothing else.
- Recency (`daysSinceLastTrained`) keeps gating on "any completed work", not
  on credit magnitude.
- Header comment: "effective sets" → "hard-set equivalents"; document the
  factors in one paragraph.

### `MuscleDevelopment` changes

- `sessionStimulus(_:parameters:)` becomes calculator-driven: `simulate` owns
  one `SetStimulus.Calculator` across its (already sorted) replay and feeds
  `credit(for:at:)` into the unchanged `applyStimulus`.
- `Parameters` gains `var stimulus: SetStimulus.Parameters = .default` so
  calibration sweeps can reach the new knobs.
- Header: delete the "Load/progression blindness" known-limitation bullet,
  update the one-sentence read; note the shared calculator.

### Consumers

No API or shape changes. `SessionAnalytics` (fingerprint cache),
`TrainingSignature`, `AntagonistBalance` (4-week window), Today attention
tiles, Insights volume bars, and the widget snapshot pipeline all inherit the
new numbers through the same types. Snapshot payload shape is unchanged — no
version bump.

### Cost

One extra dictionary and O(completed sets) float math per full replay, which
already walks every set. `SessionAnalytics` still computes each surface once
per data-change; no new per-render work.

## Rejected alternatives

- **Tonnage (weight × reps)** — rewards high-rep light junk, double-counts
  load and reps, and was already removed once (`specs/simplify-muscle-model.md`
  deleted the tonnage currency deliberately).
- **%1RM / TRIMP-style impulse models** — the ~30-tunable Banister stack this
  codebase already replaced with the explainable integrator. Not going back.
- **Absolute load thresholds** — meaningless across users and exercises; the
  per-exercise decaying-max reference is self-calibrating.
- **Punishing unlogged RIR** (e.g., defaulting effort to 0.85) — would shift
  every existing user's colours the day they update, for data they never
  entered. Neutral-when-absent is the only defensible default.

## Calibration and tests

Invariant: existing suites pass **unchanged**. Their fixtures (reps 8,
constant weight, unlogged RIR, first-instance references) are exactly the
neutral anchor — verified against `MuscleVolumeTests`, `MuscleDevelopmentTests`,
`MuscleCalibrationTests` fixtures before writing this spec.

New `SetStimulusTests` (virtual clock, in-memory models, per
`TrainingLoadTests` template):

- **Anchors**: hard working set (≥5 reps, r ≥ 0.7, RIR ≤ 2 or unlogged) = 1.0
  exactly; unlogged RIR neutral; `weight == 0` neutral; first instance neutral
  and seeds the reference; `.duration` sets skip effort + load.
- **Factor curves**: table-driven checks of the three ramps and their floors;
  total floor at 0.1.
- **Causality**: within one exercise, a PR set gets full credit and raises the
  reference for the *next* set, not itself; warm-ups before a PR judged
  against prior history.
- **Reference decay**: after a 6-month layoff, working sets at ~70 % of the
  old peak read ≥ ~0.9 loadFactor (the decayed reference has relaxed).
- **Currency agreement**: `muscleVolume` and `sessionStimulus` produce
  identical per-muscle credit for the same history (extends the existing
  `MuscleDevelopmentTests` agreement test).

New `MuscleCalibrationTests` bands (same visually-distinct-bands doctrine):

- **Warm-up honesty**: 12 weeks of 3 working sets + 3 warm-up sets must land
  visibly below 12 weeks of 6 working sets (old model: identical).
- **Token-weight honesty**: a program at ~10 % of reference e1RM must read
  clearly below the same program at working weight.
- **RIR honesty**: a program logged at RIR 5 must read visibly below the same
  program at RIR 1.

## Rollout

1. `SetStimulus.swift` + `SetStimulusTests` (pure, no call sites yet).
2. Switch `MuscleVolume` + `MuscleDevelopment` to the calculator in one
   commit; delete `Exercise.effectiveSetsByMuscle`; update both headers and
   this spec's status.
3. Calibration additions; full test run; `Scripts/verify.sh` (Today body +
   `TAB=insights`) with `--seed-history` and `--seed-showcase`.
4. Update `specs/muscle-model-fixes.md` issue #2 status to "fixed (this spec)".
