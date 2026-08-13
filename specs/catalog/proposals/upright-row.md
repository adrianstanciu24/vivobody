# Upright-row contract discovery

Status: deferred. No validator-loaded family or exercise is activated by this
document.

## Decision

Keep the upright row as its own candidate family, but do not activate it from
the presently reviewed evidence.

The movement is not a lateral-raise variant merely because both elevate the
upper arm. A strict raise holds the elbow angle and remains an isolation
exercise; an upright row materially flexes the elbow while the upper arm
elevates and is therefore compound. It also does not belong to either active
row family: those families require shoulder extension or horizontal abduction
plus scapular retraction, whereas an upright row begins with the arm by the
side and elevates it. A vertical press reverses the elbow action by requiring
extension.

The available upright-row study establishes grip-dependent muscle excitation,
but not the dynamic three-dimensional path needed to fix the family contract.
Activating a frontal-plane shoulder-abduction signature, scapular elevation,
or a terminal upper-arm angle from the exercise name would be a guess.

## Evidence reviewed

The candidate exercise-specific source is:

- **McAllister et al. (2013), “Effect of grip width on
  electromyographic activity during the upright row,”** DOI
  `10.1519/JSC.0b013e31824f23ad`, PMID `22362088`. Sixteen
  resistance-trained men performed two repetitions at one common absolute
  load under grips of 50%, 100%, and 200% of biacromial breadth. Increasing
  grip width increased concentric lateral- and posterior-deltoid excitation;
  several eccentric deltoid, trapezius, and biceps comparisons also changed,
  with less biceps involvement at the widest grip. This is direct evidence
  that grip width is load-bearing variant metadata. It does not establish
  joint actions, scapular angular change, humeral axial rotation, pull target,
  or one muscle-role hierarchy for every width.

The evidence registry should use the future ID
`mcallister-2013-upright-row-grip-width` only if an upright-row family or
exercise actually cites it. This proposal deliberately does not register an
otherwise unused source.

The already registered anatomy sources
`ackland-2008-shoulder-moment-arms`, `holzbaur-2005-upper-extremity`, and
`seth-2019-shoulder-work` can challenge a proposed muscle/action assignment.
They are not upright-row experiments. Likewise,
`ludewig-2009-multiplanar-humeral-elevation` directly documents coordinated
shoulder-complex motion during unloaded flexion and abduction, but it cannot
by itself substitute for loaded upright-row kinematics.

Surface EMG is not used as a joint-action detector. In particular, posterior
deltoid excitation does not permit assigning it as a dynamic shoulder-
abduction secondary under the current anatomy profile, and upper-trapezius
excitation does not distinguish scapular elevation from upward rotation or
stabilization.

## Candidate classification, not an activated contract

The following fields are likely but remain conditional on the geometry gate:

```json
{
  "id": "upright-row",
  "name": "Upright Row",
  "fixed": {
    "mechanic": "compound",
    "pattern": "pull",
    "direction": "vertical",
    "planes": ["frontal"]
  },
  "groupPolicy": {
    "default": "shoulders",
    "allowed": ["shoulders"]
  },
  "allowed": {
    "equipment": ["barbell"],
    "modalities": ["dynamicStrength"],
    "trackingModes": ["reps"],
    "loadModes": ["external"],
    "lateralities": ["bilateral"]
  }
}
```

`vertical` describes the principal implement travel, not an anatomical plane.
`frontal` would be valid only if the reviewed protocol establishes shoulder
abduction as the shoulder basis action without a meaningful sagittal flexion
component. If grip width changes the upper arm into a scapular or mixed
corridor, the family may need multiple shoulder basis actions, narrower grip-
specific ownership, or a split. The catalog must not call that corridor an
“oblique plane”; the only planes remain sagittal, frontal, and transverse.

## Action gate

Two concentric actions are mechanically characteristic but still require the
full protocol to pin their range:

1. `shoulder.abduction`; and
2. `elbow.flexion`.

The scapular signature is unresolved:

- normal arm elevation uses coordinated upward rotation and posterior tilt,
  but unloaded elevation cannot prove the same family-wide loaded upright-row
  action set;
- upper-trapezius EMG cannot decide whether `scapula.elevation`,
  `scapula.upwardRotation`, both, or primarily stabilization should be
  authored; and
- neither a high elbow position nor the word “row” proves
  `scapula.retraction`.

No family JSON should be written until the review chooses the scapular prime
actions. Omitting a known coupled action merely to pass validation would be as
misleading as inventing one.

Once the positive signature is settled, the first boundary review should
consider forbidding these as deliberate concentric prime actions:

- `shoulder.extension` and `shoulder.horizontalAbduction`, which belong to
  the active row families;
- `shoulder.flexion`, if the measured path really is pure frontal abduction;
- `scapula.retraction`, unless direct kinematics establish it;
- `elbow.extension`, which belongs to pressing; and
- spinal, hip, knee, and ankle propulsion, which would turn the record into a
  high-pull or cheating variant.

Humeral internal or external rotation must not be forbidden until it is
measured. A pronated hand on a bar is forearm orientation, not proof of
glenohumeral internal rotation.

## Candidate muscle policy

These assignments are supportable if shoulder abduction and elbow flexion are
confirmed:

| Candidate role | Muscle | Reason and limit |
|---|---|---|
| Primary | `deltoidLateral` | Principal shoulder-abduction training emphasis; anatomical moment arms and grip-width EMG support involvement without supplying a numeric contribution. |
| Secondary | `bicepsBrachii`, `brachialis`, `brachioradialis` | The three separately represented elbow flexors produce the required action. Grip width may change excitation, but does not remove the action. |
| Secondary | `supraspinatus` | Anatomically capable shoulder abductor; exact angle-dependent contribution remains categorical. |
| Optional secondary | `deltoidAnterior` | Anatomically capable of abduction, with contribution dependent on the measured elevation corridor. |
| Stabilizer | `deltoidPosterior` | McAllister records excitation, but the current profile does not make it a shoulder abductor; do not promote EMG into a false action. |
| Stabilizers | `externalRotators`, `subscapularis` | Glenohumeral control, not evidence of a deliberate rotation prime action. |
| Stabilizers | `fingerFlexors`, `extensorCarpiRadialis` | Static implement hold plus wrist control, without recreating a generic forearm region or dynamic grip action. |
| Stabilizers | `abs`, `obliques`, `lumbarExtensors` | Available only with declared spinal or pelvic stability demands. |

The roles of `trapeziusUpper`, `trapeziusLower`, and `serratus` remain blocked
on the scapular-action decision. If upward rotation is required, capable
upward rotators become dynamic contributors. If elevation is also required,
that changes the upper-trapezius contract. They must not be assigned from EMG
rank while leaving the action that explains the role undeclared.

## Required geometry vocabulary

An eventual contract should reuse the raise vocabulary where the meaning is
identical:

- `kineticChain`: `open`;
- `bodyPosition`: initially `standing`;
- `torsoSupport`: `none`;
- `scapularTranslation`: `free`;
- `elevationPath`: only the measured torso-relative upper-arm corridor;
- `humerothoracicStartElevationDegrees`: expected arm-at-side zero, but pin it
  from the reviewed protocol;
- `humerothoracicEndElevationDegrees`: unresolved and not inferable from bar
  height or an exercise illustration;
- `elbowMotion`: `flexes`;
- `humeralRotation`: an independently measured value, never inferred from
  `gripOrientation`;
- `gripOrientation`: expected `pronated` for the first straight-bar roster;
- `relativeGripWidth`: `narrow|shoulderWidth|wide`, with the reviewed fixtures
  explicitly mapped to 50%, 100%, and 200% of biacromial breadth;
- `pullTarget`: unresolved until the protocol identifies the terminal bar/body
  relationship;
- `lowerBodyContribution`: `none`;
- `contralateralSupport`: `none`; and
- `interRepSupport`: `none` unless the reviewed setup says otherwise.

Do not add `fixedPath` or machine vocabulary to a barbell-only first contract.
Cable, dumbbell, kettlebell, EZ-bar, Smith, and purpose-built machine upright
rows require their own apparatus/path review rather than name-based cloning.

## Narrow future roster

If the full McAllister protocol resolves the geometry gates, the maximum
initial roster should be its three straight-bar conditions:

1. `narrow-grip-barbell-upright-row` — 50% biacromial breadth;
2. `shoulder-width-barbell-upright-row` — 100% biacromial breadth; and
3. `wide-grip-barbell-upright-row` — 200% biacromial breadth.

These percentages anchor experimental fixtures; they are not biological
thresholds for every future implement. Muscle roles should remain categorical
unless the action contract itself changes. Grip-width EMG differences do not
create continuous involvement weights.

Any conditional rules must have both matching and contrasting exercises in
this roster. Likely rules include bilateral grip-width presence and the
straight-bar pronated setup, but constants are better expressed as single-
value axes when every record shares them; an always-true exercise rule would
fail the established contrast requirement.

## Cross-family boundaries

| Neighbor | Upright-row distinction |
|---|---|
| `shoulder-abduction-raise` | Both may abduct the shoulder; the raise holds the elbow angle, while the upright row materially flexes it. |
| `vertical-press` | The upright row flexes the elbow and pulls the implement upward; the press extends the elbow and pushes. |
| `shoulder-horizontal-abduction-row` | The active row begins from an already elevated upper arm and horizontally abducts with retraction; the candidate upright row elevates from the side. An endpoint near shoulder height does not make the actions equivalent. |
| `shoulder-extension-row` | The active row extends the shoulder toward the torso and retracts the scapula; the upright row elevates the upper arm. |
| Future shrug | A shrug can elevate the scapula without required shoulder abduction and elbow flexion. |
| Future high pull | A high pull adds deliberate hip, knee, or ankle propulsion; the strict upright row forbids lower-body drive. |
| Future face pull | A face pull uses horizontal abduction, external rotation, and retraction rather than arm-at-side abduction. |

## Activation gates

1. Obtain the full primary protocol, figures, or author-supplied methods for
   the exact McAllister straight-bar setup. Record start angle, terminal upper-
   arm elevation, pull target, upper-arm elevation corridor, and whether
   humeral axial rotation was measured or controlled.
2. Find direct loaded dynamic kinematics that can decide upward rotation,
   posterior tilt, scapular elevation, and retraction. If no such evidence is
   available, keep the family deferred rather than substituting upper-trapezius
   EMG or unloaded elevation.
3. Decide whether all three grip widths share one shoulder plane/action
   signature. Split or narrow the roster if they do not.
4. Register `mcallister-2013-upright-row-grip-width` only when the activated
   family or exercises cite it, with a scope that states EMG and protocol
   limits.
5. Add the family contract, one mutation test per rule assertion, admitted-axis
   coverage, and matching/contrasting fixtures for every conditional rule.
6. Add boundary mutations proving that elbow-angle-held raises, elbow-extension
   presses, retraction rows, shrugs, and lower-body-driven high pulls cannot
   enter through `additionalPrimeActions` or permissive axes.

Until those gates are met, the correct catalog result is no upright-row
exercise rather than a precise-looking record built from unmeasured geometry.
