# Exercise Data Contract

This document defines the meaning of every biomechanics-sensitive field in the
bundled exercise catalog. `Scripts/curate.py` is the classification/defaults
authoring source; `specs/exercise-anatomy-review.csv` is the reviewed muscle-role
source; and `specs/exercise-definitions.csv` is the tracked exact-name definition
source. The generator validates source/catalog name-set parity and has no
dependency on the untracked `.wger-data` directory. `vivobody/Resources/catalog.json`
is generated output.

## Identity and movement definition

- `catalogID` is a stable, unique, lowercase identifier for one canonical
  movement. It does not change when display copy changes and is independent of
  SwiftData's installation-local model UUID.
- Bundled exercise history uses `catalogID`. Custom catalog items use their
  persistent item UUID plus the complete normalized performance signature:
  semantic kind, modality, tracking mode, load mode, and bodyweight fraction
  quantized to basis points. Changing any of those fields starts a separate
  history/record series instead of comparing unlike performances. Copy-only
  edits such as name or movement-definition changes do not create a new series.
- A measured 1RM belongs to the performance signature under which it was
  entered. Editing a custom exercise's modality, tracking mode, load mode, or
  bodyweight fraction clears that measured value rather than reinterpreting it
  under a different load equation. Bundled performance semantics are locked.
- One record describes one movement. Alternatives, supersets, or slash-joined
  movements must be split or deleted.
- `movementDefinition` states the setup and joint action precisely enough to
  distinguish the record from similarly named variants.
- Aliases are search synonyms only. Canonical names and aliases are unique after
  case-folding and whitespace normalization.

## Muscle roles

Each listed muscle has one categorical role:

- `primary`: intended target or principal force-producing region.
- `secondary`: meaningfully loaded synergist that may receive partial training
  stimulus.
- `stabilizer`: contributes to position or joint control but receives no
  hard-set-volume credit.

Roles serve two separate consumers:

| Role | Exercise Anatomy intensity | Training Development hard-set credit |
|---|---:|---:|
| Primary | 1.0 | 1.0 |
| Secondary | 0.5 | 0.5 |
| Stabilizer | 0.2 | 0.0 |

These values are deliberate product heuristics, not measurements of EMG,
hypertrophy, force, or energy expenditure. Strength and power exercises must
have at least one primary muscle. Conditioning and mobility movements may use
an explicit no-primary exception.

The hard-set column applies only after a valid dynamic-strength repetition set
or isometric-strength duration set passes the modality/tracking gate. Power
movements retain anatomy roles for the temporary Exercise Anatomy map, but
those roles never enter Today's chronic Training Development map or earn
hypertrophy hard-set credit.

The two 3D modes are intentionally distinct:

- **Training Development (Today):** chronic, decayed hard-set estimate;
  primary 1.0, secondary 0.5, stabilizer 0.0.
- **Exercise Anatomy (Exercise Detail):** temporary movement-role overlay;
  primary 1.0, secondary 0.5, stabilizer 0.2, for every modality.

Gluteus maximus and gluteus medius are independent regions. Hip extension does
not imply glute-med credit; hip abduction does not imply glute-max credit.
Unilateral lower-body work may train both when pelvic control is a meaningful
loaded demand.

The rotator-cuff taxonomy is also explicit:

- `externalRotators`: infraspinatus and teres minor.
- `teresMajor`: shoulder extension/adduction/internal-rotation contributor.
- `subscapularis`: internal-rotation target; analytics-visible but not painted
  until the body asset contains an appropriate mesh.

There are no legacy combined `glutes` or `teres` catalog values.

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
modes. It is zero for `external` and `nonComparable`. Band resistance is always
`nonComparable` in the current contract: a color, nominal stack value, or band
label does not define its changing force through the range of motion. A future
model would need an explicit calibrated force curve before that can change.

The session snapshots the latest measured body weight at start. A persisted
`bodyweightAtStart` value of `0` means unknown; it is a sentinel, not a
physiological value. There is no assumed-average or fabricated fallback.
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
- `pattern` describes the dominant compound pattern. Locomotion has its own
  value; isolation records have no pattern.
- `direction` exists only for push and pull patterns.
- `plane` follows the catalog heuristic in `ExerciseCatalog.swift`: pure
  horizontal ad/abduction and rotation are transverse; lateral travel and
  ab/adduction are frontal; dominant forward/backward or vertical travel is
  sagittal.
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

- Generator `--check` produces a zero diff.
- Every required raw enum decodes without fallback.
- Stable IDs, canonical names, and normalized aliases are unique.
- Every muscle and role is recognized; combined legacy regions are absent.
- Every strength and power exercise has a primary muscle.
- Push/pull direction, isolation/pattern, modality/tracking, and load-mode
  invariants hold.
- Every band exercise is explicitly `nonComparable`.
- Explicit regression fixtures cover corrected high-risk records and the
  independent glute-max/glute-med mappings.
