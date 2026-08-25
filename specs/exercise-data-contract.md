# Exercise Data Contract

This document defines the meaning of every biomechanics-sensitive field in the
bundled exercise catalog. The reviewed contracts in `specs/catalog/families/`
are the canonical exercise source. `Scripts/catalog.py` validates those
contracts against the taxonomy, joint-action, evidence, and family-schema
foundations, then deterministically projects them into
`vivobody/Resources/catalog.json`. The runtime catalog contains exactly the 57
active families and their 136 reviewed exercises; the synthetic fixture and
supplemental `--family` inputs are never emitted.

## Identity and movement instructions

- `catalogID` is a stable, unique, lowercase identifier for one canonical
  movement. It does not change when display copy changes and is independent of
  SwiftData's installation-local model UUID.
- Bundled exercise history uses `catalogID`. Custom catalog items use their
  persistent item UUID plus the complete normalized performance signature:
  semantic kind, modality, tracking mode, load mode, and bodyweight fraction
  quantized to basis points. Changing any of those fields starts a separate
  history/record series instead of comparing unlike performances. Copy-only
  edits such as name or movement-instruction changes do not create a new series.
- A measured 1RM belongs to the performance signature under which it was
  entered. Editing a custom exercise's modality, tracking mode, load mode, or
  bodyweight fraction clears that measured value rather than reinterpreting it
  under a different load equation. Bundled performance semantics are locked.
- One record describes one movement. Alternatives, supersets, or slash-joined
  movements must be split or deleted.
- `execution` is one directly authored object whose labeled fields separate
  sequential phases from concurrent constraints: `startingPosition`,
  `movement`, `endpoint`, `controlledJoints`, `supportAndPosture`, and a
  non-empty `disqualifyingCompensations` array are always required;
  `returnPhase` is required exactly for rep-tracked exercises;
  `sideOrDirection` is required exactly for unilateral exercises and
  carry-pattern families. The labeled fields distinguish the record from
  similarly named variants without runtime sentence parsing.
- Aliases are search synonyms only. Canonical names and aliases are unique after
  case-folding and whitespace normalization.

## Muscle roles

Each listed muscle has one categorical role:

- `primary`: intended target or principal force-producing region.
- `secondary`: meaningfully loaded synergist that may receive partial training
  stimulus.
- `stabilizer`: contributes to position or joint control but receives no
  hard-set-volume credit.

Roles are encoded in the SwiftData snapshot shape, projected onto Exercise
Anatomy, and projected into training credit separately:

| Role | Snapshot value | Exercise Anatomy intensity | Training Development hard-set credit |
|---|---:|---:|---:|
| Primary | 1.0 | 1.0 | 1.0 |
| Secondary | 0.5 | 0.5 | 0.5 |
| Stabilizer | 0.2 | 0.2 | 0.0 |

The snapshot values distinguish categorical roles in the existing
`[String: Double]` persistence schema. Stabilizer `0.2` also gives it faint
temporary emphasis on Exercise Detail, but is not a claim of 20% development.
The values are product heuristics, not measurements of EMG, hypertrophy, force,
or energy expenditure.
Strength and power exercises must have at least one primary muscle.
Conditioning and mobility movements may use an explicit no-primary exception.

The hard-set column applies only after a valid dynamic-strength repetition set
or isometric-strength duration set passes the modality/tracking gate. Power
movements retain anatomy roles as text context, but those roles never enter
Today's chronic Training Development map or earn hypertrophy hard-set credit.

The two 3D modes are intentionally distinct:

- **Training Development (Today):** chronic, decayed hard-set estimate;
  primary 1.0, secondary 0.5, stabilizer 0.0.
- **Exercise Anatomy (Exercise Detail):** temporary movement-role overlay;
  primary 1.0, secondary 0.5, stabilizer 0.2, for every modality. It describes
  involvement only and never feeds Training Development calculations.

Gluteus maximus and gluteus medius are independent regions. Hip extension does
not imply glute-med credit; hip abduction does not imply glute-max credit.
Unilateral lower-body work may train both when pelvic control is a meaningful
loaded demand.

Tensor fasciae latae (`tensorFasciaeLatae`) is also independent from gluteus
medius and the exact hip-flexor regions. Exercises author its role explicitly;
the reviewed side-lying cuff-weight hip-abduction record treats Glute Med as
primary and TFL as a secondary synergist, so their development values can
diverge. Incidental bracing is omitted rather than implying meaningful core
training.

The rotator-cuff taxonomy is also explicit:

- `externalRotators`: infraspinatus and teres minor.
- `teresMajor`: shoulder extension/adduction/internal-rotation contributor.
- `subscapularis`: internal-rotation target; analytics-visible but not painted
  until the body asset contains an appropriate mesh.

There are no combined `glutes` or `teres` catalog values. The complete
set of 58 exact runtime regions, including split upper-body, lower-body, and
lumbar contributors, and its 60 trainable mesh bases are defined only by
`specs/catalog/taxonomy.json`.

Hip rotation adds explicitly unvisualized `gluteMin`, `piriformis`,
`obturatorInternusGemelli`, `obturatorExternus`, and `quadratusFemoris`
regions. Obturator internus and the gemelli share one exact region because the
reviewed exercise evidence and torque model report their conjoined tendon
together; the other short rotators remain separate. Their exercise roles stay
textually visible and feed analytics without painting a substitute 3D mesh.

## Modality and tracking

- `dynamicStrength`: repeated loaded movement; eligible for hard-set volume
  and, when effective load is comparable, load/repetition records, tonnage, and
  estimated 1RM.
- `isometricStrength`: loaded hold; eligible for duration progress and
  hard-set volume, but not tonnage or estimated 1RM. Comparable loaded holds
  rank effective load first and duration second; non-comparable holds rank
  duration alone.
- `power`: explosive jumps, throws, catches, and Olympic-lift derivatives.
  Rep-tracked power with an `external` load may earn direct load/repetition
  records and load-times-repetitions tonnage. Power never earns hypertrophy
  hard sets or estimated 1RM. Jumps, throws, bands, and other non-comparable
  power work remain unranked because the log lacks output dimensions such as
  height, velocity, or distance.
- `conditioning`: locomotion or work-capacity movement; excluded from strength
  PR, estimated-1RM, and hypertrophy-volume analytics.
- `mobility`: mobility, rehabilitation, or passive movement; excluded from
  strength and hypertrophy analytics.

Custom-exercise authoring exposes every modality through
`ExerciseModality.customExerciseChoices`; `customExerciseTrackingModes` owns
their permitted measures. Dynamic strength and power are fixed to reps,
isometric strength is fixed to duration, and conditioning and mobility let the
user choose reps or duration. Conditioning and mobility remain visible in
workouts and history while staying excluded from strength PRs, comparable
tonnage, hypertrophy hard sets, and the 3D development model.

`trackingMode` describes the entered measurement (`reps` or `duration`); it does
not substitute for modality.

RIR is valid only for an explicitly rated (`rirLogged`) completed
`.dynamicStrength + .reps` set. Rollups of performed repetition work also
require positive repetitions. The stored default RIR value is not a reading,
and isometric, power, conditioning, mobility, and mismatched modality/tracking
records never enter RIR averages, hard-set counts, or progression guidance.

Each workout and per-set template row also stores an explicit set intent:
`working` or `warmUp`. Warm-ups remain visible in history and completion
counts, but are excluded from records, comparable tonnage, RIR analytics,
hard-set credit, and Training Development. Untagged/defaulted rows are
working sets; exercise names never infer set intent.

## Load semantics

- `external`: logged weight is the comparable resistance.
- `bodyweightAdded`: effective resistance is
  `loggedWeight + bodyweightFraction * bodyWeight`.
- `assistanceSubtracted`: effective resistance is
  `max(0, bodyweightFraction * bodyWeight - loggedWeight)`.
- `nonComparable`: no honest single effective-load value exists; exclude the
  movement from load-based record and tonnage comparisons. A duration-tracked
  isometric may still compare duration within its own duration-only series.

`bodyweightFraction` is a coefficient used only by the two bodyweight load
modes. It is zero for `external` and `nonComparable`. Reviewed band exercises
may be bundled, but their resistance is always `nonComparable`: a color,
nominal stack value, or band label does not define its changing force through
the range of motion. A future model would need an explicit calibrated force
curve before that can change.

The session snapshots the latest measured body weight at start. A persisted
`bodyweightAtStart` value of `0` means unknown; it is a sentinel, not a
physiological value. There is no assumed-average or fabricated fallback.
Saving or correcting a body-weight entry refreshes snapshots for workouts
started on that same calendar day. This treats the daily measurement as the
source of truth while preserving snapshots from other days as immutable
history; a later genuine weight change never rewrites an older workout.
`bodyweightAdded` and `assistanceSubtracted` therefore return no effective load
until a positive measured body weight exists, so their load-based records and
tonnage are omitted for that session. `external` load remains usable without a
body-weight measurement.

Comparable-tonnage rollups carry both a known subtotal and an availability
state. `complete` means every eligible completed set had an effective load;
`partial` means the displayed known subtotal excludes some eligible work; and
`unavailable` means none of the eligible tonnage can be established. Timed and
`nonComparable` work is outside the tonnage pool and does not make it partial.
Density, contribution shares, trend deltas, and charts must not treat a partial
or unavailable subtotal as a complete total.

## Performance records

- Dynamic-strength and eligible external-load power performances compare
  effective load first, then repetitions at equal load.
- Comparable loaded isometrics compare effective load first, then duration at
  equal load. Non-comparable isometrics compare duration only. Loaded and
  duration-only isometric series never compare with one another.
- The first valid performance in a record-eligible semantic series establishes
  a record. Later performances must beat the standing value under that same
  comparison contract.
- Estimated 1RM remains a dynamic-strength-only metric; a direct power record
  never opts power work into estimated 1RM or hard-set analytics.
- A measured 1RM is valid only for comparable `.dynamicStrength + .reps`
  semantics and is cleared when a custom item's performance signature changes.

## Classification

- `group` is the best browsing bucket, not a claim that no other region works.
- `mechanic` describes single- versus multi-joint movement mechanics.
- `trainingRole` describes conventional programming placement as
  `push|pull|legs|core|other`. It applies to compound and isolation work, powers
  cross-mechanic discovery filters, and is authored explicitly rather than
  inferred from a joint action. For example, a lateral raise is `push` by PPL
  placement even though shoulder abduction is not a literal pressing action.
- `pattern` describes the dominant compound pattern. Locomotion has its own
  value; isolation records have no pattern.
- `direction` exists only for push and pull patterns and uses
  `horizontal|vertical|diagonal`. Direction describes the resistance/travel
  direction, not an anatomical plane.
- `planes` contains one or more of the three cardinal anatomical planes in the
  canonical order `sagittal|frontal|transverse`. A reviewed family may be
  multiplanar; the compiler never collapses it to one inferred plane.
- `laterality` describes how the movement is performed. Alternating or
  one-side-at-a-time movements are unilateral even when both sides comprise one
  logged set.

## Defaults and evidence

Default load, repetitions, and duration are starting UI values, not
biomechanical truths. Machine-stack values are not portable between machines.

An anatomy review may use anatomical action, kinematics, force measurements,
and exercise-specific activation studies to establish roles. Evidence does not
justify pretending the catalog's categorical roles are exact physiological
fractions. Ambiguous movement names must be clarified, split, or deleted rather
than inferred silently.

## Required validation

The bundled catalog must satisfy all of the following before shipping:

- `python3 Scripts/catalog.py --check` validates every canonical source and
  proves the bundled runtime catalog is byte-for-byte compiler output.
- The projection contains exactly 57 family IDs and 136 exercise records; it is
  stable under family file discovery order and excludes the synthetic fixture
  and supplemental `--family` validation inputs.
- The evidence registry contains exactly 154 source identities, each referenced
  by an active foundation, family, or exercise claim.
- Every required raw enum decodes without fallback.
- Stable IDs, canonical names, and normalized aliases are unique.
- Every muscle and role is recognized; obsolete aggregate regions are absent.
- Every strength and power exercise has a primary muscle.
- Training-role vocabulary, compound push/pull role agreement, push/pull
  direction, isolation/pattern, modality/tracking, and load-mode invariants
  hold.
- Every bundled band exercise uses `nonComparable` load semantics.
- Explicit regression fixtures cover corrected high-risk records and the
  independent glute-max/glute-med mappings.
