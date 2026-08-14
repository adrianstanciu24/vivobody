# Upright-row activation

Status: activated as the bounded `upright-row` family with one directly
reviewed low-cable exercise.

## Decision

Activate a narrow bilateral cable upright-row contract. The family is a
compound vertical pull whose defining dynamic actions are elbow flexion and a
catalog-authored mixture of shoulder flexion and abduction. Scapular upward
rotation and posterior tilt remain coupled elevation actions. The first roster
contains only Lorenzetti et al.'s standing low-cable, straight-bar topology.

This is deliberately not a lateral-raise, row, shrug, press, or high-pull
variant:

- unlike an angle-held raise, the elbow flexes materially;
- unlike the active horizontal-abduction and shoulder-extension rows, the
  upper arm elevates from the side and scapular retraction is forbidden as a
  deliberate prime action;
- unlike a shrug, shoulder elevation and elbow flexion are required while
  scapular elevation is not authored as a prime action;
- unlike a press, the elbow flexes rather than extends; and
- unlike a high pull, deliberate lower-body propulsion is forbidden.

The family is a bounded catalog adaptation, not a claim that one experiment
measured every authored coordinate. Lorenzetti supplies the exact exercise
topology and observed multiplanar shoulder motion. General arm-elevation
kinematics supply the unavoidable scapular coupling, with the transfer and its
limits stated explicitly in the family definition.

## Primary evidence and scope

### Lorenzetti et al. 2017

`lorenzetti-2017-pulling-exercise-kinematics` is the exercise-defining source:

- 15 healthy adults performed standing upright rows at 10% and 25% of body
  weight on an adjustable low-cable station;
- the reviewed setup used a straight bar, feet approximately shoulder-width
  apart, slightly flexed knees, an upright/core-engaged torso, and a vertical
  pull with elbows slightly above the hands;
- the pull ended when the elbows reached shoulder height and returned slowly;
  and
- three-dimensional motion capture reported substantial shoulder excursion in
  both sagittal and frontal coordinates and directly documented nontrivial
  spinal behavior.

The source does not justify numeric humerothoracic start or end angles. Its
shoulder coordinates use the Rab-style XYZ/Cardan decomposition. Near 90
degrees of abduction that sequence approaches gimbal lock, so sagittal and
axial components cease to have a unique anatomical interpretation. The
contract therefore records a qualitative mixed flexion-abduction corridor,
uses the directly prescribed elbow-height endpoint, marks humeral rotation
`nonstandardized`, and assigns no axial-rotation prime action. The reported
spinal behavior likewise requires `spineMotion: nonstandardized`; an upright
or core-engaged instruction is not evidence that the spine remained fixed.

### Coupled scapular motion

`ludewig-2009-multiplanar-humeral-elevation` directly observed scapular upward
rotation and posterior tilt during sagittal flexion and coronal abduction.
Those two coupled actions are therefore retained across the family's mixed
elevation corridor without assigning a fixed scapulohumeral ratio.

`eldridge-2024-loaded-scapular-elevation` directly studied externally loaded
arm elevation. It supports preserving upward rotation when resistance is
added, but its load-related changes were small and mostly near the measurement
error. It did not measure this upright-row fixture and does not directly
measure posterior tilt. Posterior tilt remains the disclosed transfer from
Ludewig rather than a loaded upright-row result.

`seth-2019-shoulder-work` supplies a complementary loaded modeling boundary:
the scapulothoracic model was checked against kinematics and surface EMG during
unloaded and 2 kg flexion and abduction, and supports categorical dynamic
deltoid, upper-trapezius, and serratus contributions. Its single participant
does not establish population magnitudes or a role ranking for an upright
row.

### McAllister et al. 2013

`mcallister-2013-upright-row-grip-width` directly measured surface EMG during
straight-bar barbell upright rows in 16 resistance-trained men at 50%, 100%,
and 200% of biacromial breadth. It establishes upright-row recruitment of the
anterior, lateral, and posterior deltoids, upper and middle trapezius, and
biceps, and shows that grip width can change within-muscle excitation.

It does **not**:

- measure the activated cable exercise;
- establish joint or scapular actions;
- compare one muscle's normalized contribution with another;
- justify a different role hierarchy for an unquantified cable grip; or
- permit posterior-deltoid excitation to become a shoulder-extension prime or
  middle-trapezius excitation to become a scapular-retraction prime.

The cable record therefore preserves its source-shown but unquantified grip
instead of importing McAllister's three barbell thresholds.

## Activated contract

The fixed classification is:

```json
{
  "id": "upright-row",
  "fixed": {
    "mechanic": "compound",
    "pattern": "pull",
    "direction": "vertical",
    "planes": ["sagittal", "frontal"]
  },
  "groupPolicy": {
    "default": "shoulders",
    "allowed": ["shoulders"]
  },
  "allowed": {
    "equipment": ["cable"],
    "modalities": ["dynamicStrength"],
    "trackingModes": ["reps"],
    "loadModes": ["external"],
    "lateralities": ["bilateral"]
  }
}
```

`vertical` describes the principal bar travel and does not collapse the two
anatomical shoulder planes into an invented oblique plane.

The movement signature is:

```json
{
  "planeBasisActions": [
    "shoulder.flexion",
    "shoulder.abduction"
  ],
  "primeActions": [
    "shoulder.flexion",
    "shoulder.abduction",
    "scapula.upwardRotation",
    "scapula.posteriorTilt",
    "elbow.flexion"
  ],
  "stabilityDemands": [
    "shoulder",
    "scapula",
    "elbow",
    "forearm",
    "wrist",
    "hand",
    "spine",
    "pelvis"
  ]
}
```

The full forbidden-action complement makes all other actions unavailable as
deliberate primes. Of particular importance:

- `shoulder.internalRotation` and `shoulder.externalRotation` are forbidden
  because the Euler decomposition cannot resolve a deliberate axial action;
- `scapula.retraction` is forbidden because neither a row name nor middle-
  trapezius EMG establishes retraction;
- `scapula.elevation` is forbidden because neither upper-trapezius EMG nor the
  small load-related elevation change in a different arm-elevation task makes
  it training-defining here; and
- every spinal and lower-body action is forbidden so nonstandardized posture
  cannot broaden into a high pull.

Forbidding a prime action does not assert that its coordinate was identically
zero. It states that the action is not a deliberate, volume-bearing definition
of this family.

## Muscle-role policy

The exact hierarchy is:

| Role | Regions |
|---|---|
| Primary | `deltoidLateral` |
| Secondary | `deltoidAnterior`, `supraspinatus`, `bicepsBrachii`, `brachialis`, `brachioradialis`, `serratus`, `trapeziusUpper`, `trapeziusLower` |
| Stabilizer | `deltoidPosterior`, `trapeziusMiddle`, `externalRotators`, `subscapularis`, `fingerFlexors`, `extensorCarpiRadialis`, `abs`, `obliques`, `lumbarExtensors` |

Lateral deltoid owns the secure shoulder-abduction emphasis. Anterior deltoid
serves the bounded flexion component, and supraspinatus serves abduction. The
three represented elbow flexors serve the required elbow-flexion action.
Serratus plus upper and lower trapezius serve the two coupled scapular actions.

Posterior deltoid and middle trapezius retain McAllister's recruitment signal
without converting surface EMG into false extension or retraction actions.
The two rotator-cuff regions stabilize the elevated humerus. Finger flexors
retain the bar while extensor carpi radialis controls the wrist against the
flexors' wrist moment. Abs, obliques, and lumbar extensors serve the declared
spine and pelvis demands. The lumbar-extensor role remains textually visible
without painting a substitute body-model surface.

## Reviewed exercise and geometry

The initial roster contains only
`standing-low-cable-upright-row`. Its required geometry is:

- `kineticChain: open`;
- `bodyPosition: standing` and `torsoSupport: none`;
- `scapularTranslation: free`;
- `elevationPath: mixedFlexionAbductionCatalogAdaptation`;
- `endpointCriterion: elbowsAtShoulderHeight`;
- `elbowMotion: flexes` and
  `elbowHandRelationship: elbowsSlightlyAboveHands`;
- `humeralRotation: nonstandardized`;
- `gripOrientation: pronated` and
  `gripWidth: sourceShownNotQuantified`;
- `handleType: straightBar` and `handTask: staticImplementHold`;
- `resistanceGeometry: lowCableVerticalPull` and `fixedPath: false`;
- `spineMotion: nonstandardized`;
- `kneeSetup: slightlyFlexed`; and
- `lowerBodyContribution: none`.

No numeric shoulder-angle, pull-to-body landmark, fixed humeral rotation, or
scapular-retraction/elevation field is inferred. Cable direction alone does
not make the implement path mechanically fixed.

## Boundaries and deferred variants

This activation does not admit McAllister's three barbell conditions. Barbell,
dumbbell, kettlebell, EZ-bar, Smith-machine, selectorized-machine, unilateral,
and intentionally leg-driven variants require direct topology review before
entry. A future grip-width expansion must preserve separate apparatus evidence
and cannot treat 50%, 100%, and 200% of biacromial breadth as universal
biological thresholds.

Neighbor boundaries remain exact:

| Neighbor | Required distinction |
|---|---|
| `shoulder-abduction-raise` | Holds the elbow angle instead of flexing it. |
| `shoulder-flexion-raise` | Holds the elbow angle and uses a pure sagittal basis. |
| `shoulder-horizontal-abduction-row` | Begins elevated, horizontally abducts, and retracts. |
| `shoulder-extension-row` | Extends the shoulder toward the torso and retracts. |
| `scapular-elevation` | Elevates the scapula without required shoulder elevation and elbow flexion. |
| `vertical-press` | Extends the elbow while moving the load away. |
| Future high pull | Adds deliberate lower-body propulsion. |

## Validation plan

The activation batch must add mutation coverage that:

1. pins the exact family and one-record roster;
2. asserts that the five prime actions plus the forbidden complement partition
   all canonical actions exactly;
3. removes or mutates each prime action and verifies direct rejection;
4. attempts to add shoulder axial rotation, scapular retraction/elevation,
   elbow extension, spinal motion, or lower-body propulsion as a prime action;
5. mutates the mixed two-plane basis and fixed plane list;
6. mutates every required role, stability demand, and one-record axis;
7. proves the free cable path retains `fixedPath: false`;
8. rejects angle-held raises, retraction rows, presses, shrugs, and high pulls
   through both action and geometry mutations; and
9. pins the runtime projection's family identity, two planes, classification,
   complete role map, and absence of a substitute mesh for
   `lumbarExtensors`.

No new taxonomy region, joint action, condition, schema feature, or validator
rule is required by this family.
