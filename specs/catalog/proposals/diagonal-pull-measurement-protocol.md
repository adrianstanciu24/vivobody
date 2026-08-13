# Diagonal-pull activation measurement protocol

Status: required evidence protocol; not validator input.

This protocol is the concrete unlock for the deferred `diagonal-pull`
candidate. It exists because public product photographs, exploded parts
drawings, and a historical patent do not provide calibrated human-relative
endpoints or joint kinematics. Do not activate the family or populate numeric
axes from those materials.

## Questions the capture must answer

1. Does the candidate have a reproducible torso-relative path distinct from
   both vertical pulls and horizontal rows?
2. Is the path's sagittal component anterior, posterior, or effectively
   neutral during the concentric?
3. Does the humerus perform meaningful adduction plus extension from a flexed
   start, rather than primarily extension or horizontal abduction?
4. Which `upperArmPath` corridor is actually present?
5. Is scapular retraction a consistent dynamic action or only an assumed
   stabilization strategy?
6. Do bilateral and supported unilateral executions remain biomechanically
   equivalent enough for one family?

Geometry answers family ownership. It does **not** by itself assign muscle
roles.

## Accepted evidence routes

Use either:

- calibrated 3D human-motion capture on an identified physical machine; or
- manufacturer-supplied dimensioned CAD/kinematic endpoints explicitly tied to
  the measured revision, followed by separate human thorax, humerus, and
  scapula tracking for the joint-action questions.

An articulated marketing mesh without an accuracy declaration is not
dimensioned CAD. A 2D product photograph, a product's overall envelope, a
room-space lever angle, or a patent drawing assumed to scale is not accepted.

## Fixture identity

Record all of the following before capture:

- manufacturer, product name, SKU, model label, serial number, and capture
  date;
- movement-arm assembly identifiers or visible part numbers;
- seat and thigh-pad setting indices;
- chest-pad configuration and the participant's contact with it;
- handle, grip, lever-arm, and contralateral-support configuration;
- resistance source, external load, and whether counterbalance is installed;
- photographs of the model/serial label and the complete setup; and
- any manufacturer geometry or setup instruction used as a proxy.

The initial candidate is the Hammer Strength Plate Loaded Iso-Lateral High
Row, SKU `IL-HR`. Data from another product do not silently inherit that
identity.

## Coordinate and event convention

Use a documented, validated anatomical thorax coordinate system and retain its
landmark definitions in the artifact. Do not derive a torso frame from image
edges or from the machine frame.

For each repetition:

1. identify the canonical loaded eccentric start and concentric finish with a
   predeclared event rule;
2. express each working-hand center relative to the moving thorax at both
   events;
3. for bilateral execution, also compute the midpoint of the hands;
4. subtract the start-relative coordinate from the finish-relative coordinate;
5. project that chord into the thorax sagittal plane;
6. report `pullInclinationDegrees` as the magnitude between the projected chord
   and the thorax anterior-posterior axis; and
7. report `sagittalPathDirection` separately from the signed
   anterior-posterior component.

Zero degrees is anterior-posterior; 90 degrees is superior-inferior. Keep the
raw signed coordinates so the calculation is reproducible. Report torso
translation and rotation independently; do not let a moving torso manufacture
an implement-path classification.

The capture must also retain thorax-relative humerus orientation through the
repetition and a validated scapular measurement. Handle travel cannot be used
as a substitute for glenohumeral or scapulothoracic motion.

## Conditions

Capture the candidate on the same identified machine as:

- strict bilateral execution; and
- strict unilateral execution using the documented contralateral support
  handle.

Capture neighboring boundary fixtures with the same coordinate/event
convention:

- a canonical strict pull-up;
- a front pulldown;
- a tucked shoulder-extension row; and
- a flared shoulder-height horizontal-abduction row.

Predeclare the participant/body-size coverage, the canonical seat-alignment
rule, adjacent realistic seat settings used for sensitivity analysis, loading
rule, range-of-motion instruction, and repetition count. Include repeated
trials sufficient to estimate measurement and within-person variability.
Because the path is anatomy-relative, one photographed athlete cannot define a
population-wide exact value.

## Required outputs

The tracked measurement artifact must contain:

- immutable raw calibrated data or a stable reviewed archive reference;
- fixture and participant/surrogate metadata without personal identifiers;
- the processing script and its version;
- start/end event annotations;
- per-trial hand, thorax, humerus, and scapula results;
- bilateral/unilateral and seat-setting sensitivity summaries;
- measurement uncertainty and repeatability results;
- derived canonical exercise values or an explicit reason no honest proxy can
  be authored; and
- a provenance manifest tying every derived value to its source artifact.

Do not copy a mean into JSON without retaining its distribution, uncertainty,
and derivation.

## Activation decision

Activate `diagonal-pull` only when all of these are true:

- the candidate's reviewed path is separated from the neighboring fixture
  distributions by more than the measurement uncertainty;
- the separation survives realistic body-size and seat-setting variation;
- the measured shoulder actions support adduction plus conditioned extension;
- the reviewed `upperArmPath` and scapular policy are encoded without visual
  inference; and
- bilateral and unilateral records either agree within the declared tolerance
  or carry truthful distinct canonical values inside the same non-overlapping
  family band.

If the candidate overlaps vertical pull or an existing row family, route it to
that family or keep it deferred. Do not create a degree cutoff merely to
preserve the proposed family.

Muscle-role activation is a separate gate. Condition-matched force/EMG evidence
must resolve the disputed lats, rhomboid, middle-trapezius, teres-major, and
sternocostal-pectoralis hierarchy. Surface-EMG magnitude alone must not be used
as a cross-muscle primary/secondary ranking, and scapular retraction must not be
inferred from retractor excitation.

## Catalog work after the evidence passes

Only after acceptance of the measurement artifact:

1. add the candidate family and its reviewed records;
2. add defensible `pullInclinationDegrees` and `sagittalPathDirection` values or
   reviewed proxies to every affected pull/row record;
3. migrate shared pull path vocabulary atomically;
4. assert the complete family-to-direction-band map and non-overlap;
5. add out-of-band, signed-direction, joint-action, role, and cross-family
   boundary mutations; and
6. register only the sources actually referenced by the active contracts or
   exercises.
