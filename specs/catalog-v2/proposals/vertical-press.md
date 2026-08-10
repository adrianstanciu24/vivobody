# Vertical press contract discovery

Status: approved and activated. The enforceable source is
`families/vertical-press.json`; this non-validator document preserves the
research and boundary decisions that produced it.

## Implemented recommendation

The active `vertical-press` family covers strict, open-chain presses performed
with an upright torso and the implement travelling in front of the head or in
the scapular path. The family can cover standing and seated front presses
with free weights or a purpose-built shoulder-press machine.

The family should not absorb every exercise whose name contains “shoulder
press.” Landmine presses, high-incline presses, rotating Arnold presses,
behind-neck presses, and leg-driven push presses have different movement
signatures or unresolved boundaries and should remain outside this contract.

## Activated classification

The active contract implements this classification:

```json
{
  "id": "vertical-press",
  "fixed": {
    "mechanic": "compound",
    "pattern": "push",
    "direction": "vertical",
    "planes": ["sagittal", "frontal"]
  },
  "groupPolicy": {
    "default": "shoulders",
    "allowed": ["shoulders"]
  },
  "allowed": {
    "equipment": ["barbell", "dumbbell", "kettlebell", "machine"],
    "modalities": ["dynamicStrength"],
    "trackingModes": ["reps"],
    "loadModes": ["external"],
    "lateralities": ["bilateral", "unilateral"]
  },
  "movementSignature": {
    "planeBasisActions": [
      "shoulder.flexion",
      "shoulder.abduction"
    ],
    "primeActions": [
      "shoulder.flexion",
      "shoulder.abduction",
      "scapula.upwardRotation",
      "scapula.posteriorTilt",
      "elbow.extension"
    ],
    "forbiddenPrimeActions": [
      "shoulder.extension",
      "shoulder.horizontalAdduction",
      "shoulder.horizontalAbduction",
      "hip.extension",
      "knee.extension",
      "ankle.plantarflexion"
    ],
    "stabilityDemands": ["shoulder", "scapula"]
  }
}
```

`vertical` is the app's resistance-path direction. It is not an anatomical
plane. A normal front/scapular-path press combines sagittal shoulder flexion
and frontal shoulder abduction. The scapular plane lies between those cardinal
planes; it is represented here by both components, never by inventing an
`oblique` plane.

Scapular upward rotation and posterior tilt are declared prime actions because
they are observed movement during a military press, not merely static support.
Consequently, the muscles producing those actions must be authored as dynamic
contributors. The common `scapularTranslation` axis records only whether
external posterior support limits translation along the thorax. A supported
press may therefore use `supportConstrained` while still requiring upward
rotation and posterior tilt; the axis does not claim that the scapula is pinned
or that all scapular motion is absent. The chest families' rule requiring
serratus and middle trapezius as stabilizers under `supportConstrained` is not
transferred: vertical press declares scapular actions that make its capable
contributors dynamic secondaries instead.

## Incline boundary

The existing incline-press contract ends at 45 degrees. There is no biological
switch at 45, 60, or 75 degrees; shoulder and pectoral contributions change
continuously with the path. Any angle cutoff is therefore a catalog ownership
rule, not an anatomical claim.

Activated initial boundary:

- supported `vertical-press`: `pressInclinationDegrees` from 75 through 90;
- standing or unsupported seated `vertical-press`:
  `pressInclinationDegrees: 90`;
- 46 through 74 degrees: intentionally unowned until a high-incline/diagonal
  shoulder-press contract is researched.

This avoids calling a visibly diagonal 60-degree press `vertical`. The 75-degree
lower bound is deliberately conservative and should be treated as a product
decision. The available exercise studies provide useful 80- and 85-degree
reference conditions, but do not prove a universal threshold.

## Activated muscle policy

For the deliberately narrow front/scapular-path family:

| Role | Contract muscles | Contract meaning |
|---|---|---|
| Primary | `deltoidAnterior` | Dominant training emphasis for the accepted front press path. |
| Required secondary | `deltoidLateral`, `supraspinatus`, `triceps`, `serratus`, `trapeziusUpper`, `trapeziusLower` | Humeral elevation, elbow extension, and dynamic scapular rotation/tilt. |
| Optional secondary | `pectoralisMajorClavicular` | Capable shoulder flexor with meaningful but angle-dependent contribution. |
| Stabilizer candidates | `externalRotators`, `subscapularis`, `trapeziusMiddle`, `deltoidPosterior`, `abs`, `obliques`, `lowerBack` | Shoulder, scapular, and variant-specific trunk control. |

The anterior-primary/lateral-secondary split is a catalog emphasis decision,
not a claim that lateral deltoid is unimportant. Moment-arm and exercise EMG
data both show meaningful anterior and lateral deltoid participation. A single
strict role policy is preferable to allowing either muscle to drift between
primary and secondary exercise by exercise without a declared biomechanical
reason.

`serratus`, `trapeziusUpper`, and `trapeziusLower` should be secondary rather
than stabilizer in this family because the contract declares actions they
produce as part of the movement. Torso support changes trunk demands; it does
not erase those scapular actions.

`supraspinatus` is likewise a required secondary rather than a stabilizer-only
entry. Shoulder abduction is a declared prime action, and the muscle produces
that action while also contributing glenohumeral stability. The categorical
role records its dynamic contribution; it does not deny the simultaneous
stability function.

## Resolved foundation changes

### 1. Anterior-deltoid action correction

The capability profile now gives `deltoidAnterior` both shoulder flexion and
shoulder abduction. Ackland et al. measured the anterior and middle deltoid as
the most effective abductors in their tested configurations.

This is a correction to the independent anatomy map, not a special exception
for one family.

### 2. Supraspinatus is muscle 32

The taxonomy separately represents infraspinatus and teres minor as
`externalRotators`, separately represents `subscapularis`, and now represents
`supraspinatus` directly rather than folding it into either category. Muscle 32
produces `shoulder.abduction` and stabilizes `shoulder`, backed by Ackland and
Blache respectively.

It intentionally has `meshBaseNames: []` plus an `unvisualizedReason`, so the
SceneKit mesh count remains 61. The whole-muscle profile deliberately omits
shoulder flexion: Ackland's flexion result distinguishes anterior and posterior
supraspinatus subregions, but this taxonomy does not. The active vertical-press
contract resolves its role as required secondary. The later atomic app cutover
must add the matching Swift/domain case and preserve its no-mesh behavior.

## Initial scope and exclusions

| Candidate | Decision | Reason |
|---|---|---|
| Strict standing/seated barbell front press | Own; standing and supported seated representatives authored | Matches the open-chain upper-body signature. |
| Dumbbell press, bilateral or unilateral | Own; standing bilateral/unilateral, supported bilateral/unilateral seated, and unsupported seated representatives authored | Same signature; laterality and support alter stability demands. |
| Standard kettlebell overhead press | Own; single-arm standing representative authored | Same gross signature; `kettlebellOrientation: standard` keeps bottom-up variants out. |
| Smith or converging shoulder-press machine | Own; one supported seated representative of each mechanism authored | Same signature with a fixed external path. |
| 46–74 degree high-incline press | Defer | Diagonal path and chest/shoulder boundary remain unresolved. |
| Landmine press | Exclude | Diagonal path; needs a separate contract. |
| Arnold press | Defer | Adds meaningful transverse-plane rotation during the repetition. |
| Behind-neck press | Defer or omit | Different humeral path/rotation and distinct deltoid profile; it must not enter through an alias. |
| Push press or jerk | Exclude | Hip, knee, and ankle extension make lower-body power part of the prime movement. |
| Pike or handstand push-up | Defer | Closed-chain bodyweight mechanics need a dedicated review. |
| Cable shoulder press | Defer | Cable line-of-force and setup axes are not yet specified. |

## Activated variant axes

- `kineticChain`: required and limited to `open`; closed-chain pike and
  handstand presses cannot enter without a contract change.
- `bodyPosition`: `standing` or `seated`.
- `torsoSupport`: `none`, `bench`, or `machinePad`.
- `scapularTranslation`: required `free` or `supportConstrained`. `none`
  requires `free`; `bench` and `machinePad` require `supportConstrained`.
  Neither value changes the required scapular rotation and tilt actions.
- `pressInclinationDegrees`: required, 75–90, using the shared signed press
  convention. Standing and unsupported seated variants require exactly 90.
- `gripOrientation`: `pronated` or `neutral`; rotating grips are deferred.
- `fixedPath`: required boolean with the same definition used by all three
  existing press families.
- `machineType`: optional `smith` or `convergingShoulderPress` when equipment
  is machine.
- `kettlebellOrientation`: optional and limited to `standard`. Kettlebell
  equipment requires the axis and a neutral grip; every other equipment type
  must omit the orientation axis.
  Admitting `bottomUp` requires a future contract and stability review.
- `lowerBodyContribution`: required and limited to `none`; leg-driven presses
  need another family.
- `pressPath`: required and limited to `frontScapular`; admitting a
  behind-neck path must require a visible family-contract change rather than an
  alias or naming judgment.

The machine rules should reuse the established vocabulary: machine equipment
requires a fixed path and mechanism; non-machine equipment requires
`fixedPath: false` and omits `machineType`. A converging shoulder-press machine
requires `seated` plus `machinePad`. Smith presses may be standing or seated,
so torso support cannot be inferred from `equipment: machine` alone.

`standing` requires `torsoSupport: none` and 90 degrees. A seated press may use
`none`, `bench`, or `machinePad`; an unsupported seated press also requires 90
degrees. Any non-`none` torso support requires `bodyPosition: seated`. These
rules keep support and inclination independent while leaving no undefined
seated-unsupported case.

Every unsupported-torso variant declares an additional `spine` stability
demand, including an unsupported seated press. Standing and unilateral
variants declare both `spine` and `pelvis`. Exercise rules use
`requireAdditionalStabilityDemands` to require those regions in
`additionalStabilityDemands` when a matching variant condition applies. The
validator separately requires an assigned muscle capable of stabilizing each
region; mutation tests cover missing demands, incapable rosters, unknown
regions, and duplicate regions.

The active contract also forbids spinal motion as a prime action and forbids
scapular downward rotation or anterior tilt. Without those boundaries, a
layback press or an exercise with mechanics opposite to the declared scapular
signature could pass under a strict-press name.

## Initial coverage roster

The first complete roster is a coverage matrix, not a Cartesian product. Each
record must either cover a previously unrepresented contract value or test a
meaningful interaction between values:

| Exercise | Coverage purpose |
|---|---|
| Standing Barbell Overhead Press | Bilateral standing straight-bar baseline. |
| Standing Dumbbell Overhead Press | Bilateral independent free-weight baseline. |
| Single-Arm Standing Dumbbell Overhead Press | Unilateral delta against the standing dumbbell baseline. |
| Seated Dumbbell Overhead Press | Supported 85-degree bilateral dumbbell press. |
| Seated Barbell Overhead Press | Supported straight-bar interaction at the researched 80-degree setup. |
| Unsupported Seated Dumbbell Overhead Press | Explicit seated-plus-no-support branch and its spinal demand. |
| Single-Arm Seated Dumbbell Overhead Press | Supported unilateral interaction, neutral free-weight grip, and the 75-degree lower boundary. |
| Single-Arm Standing Kettlebell Overhead Press | Standard bell-down orientation and the kettlebell equipment branch. |
| Seated Smith Machine Overhead Press | Fixed rail path with bench rather than machine-pad support. |
| Machine Shoulder Press | Purpose-built converging mechanism, neutral handles, and machine-pad support. |

This set covers every currently admitted enum value, both fixed-path values,
and both endpoints of the numerical inclination range. Every declarative
exercise rule has at least one matching and one contrasting real record. Tests
lock both properties. A dual-kettlebell press, standing Smith press, and extra
neutral-grip dumbbell permutations remain valid future candidates but add no
new contract branch, so they are deliberately absent from this first roster.

The unsupported seated dumbbell record is the one mechanics-derived coverage
fixture in the roster. The reviewed seated trials used posterior support and do
not directly isolate a no-backrest condition. Its prime movers therefore remain
the family baseline, while its explicit spinal demand and trunk stabilizers are
a conservative consequence of removing posterior support—not a claimed EMG
ranking. It should be revisited if condition-matched primary evidence changes
that interpretation.

The coverage audit also closed three invalid cross-field combinations. A
standard barbell press and the admitted Smith press must be bilateral, and
`torsoSupport: machinePad` now requires the purpose-built converging machine.
Free-weight and Smith setups use `bench` when externally supported.

## Evidence reviewed

- [Ackland et al. (2008), *Moment arms of the muscles crossing the anatomical
  shoulder*](https://doi.org/10.1111/j.1469-7580.2008.00965.x): cadaveric
  moment-arm measurements support anterior deltoid flexion and abduction,
  lateral deltoid abduction, and clavicular pectoralis major flexion. This is
  anatomical capability evidence, not an exercise-level activation ranking.
- [Ichihashi et al. (2014), *Kinematic characteristics of the scapula and
  clavicle during military press exercise and shoulder
  flexion*](https://doi.org/10.1016/j.jse.2013.11.014): sixteen healthy men
  pressing 2 kg showed military-press scapular upward rotation and posterior
  tilt. The light load limits direct generalization to heavy training, but the
  observed actions are directly relevant to the movement signature.
- [Saeterbakken and Fimland (2013), *Effects of body position and loading
  modality on muscle activity and strength in shoulder
  presses*](https://doi.org/10.1519/JSC.0b013e318276b873): fifteen healthy men
  performed seated/standing barbell/dumbbell presses at 80% 1RM; implement and
  support changed deltoid and triceps excitation. This supports explicit
  equipment and body-position axes, not numeric muscle weights.
- [Saeterbakken and Fimland (2012), *Muscle activity of the core during
  bilateral, unilateral, seated and standing resistance
  exercise*](https://doi.org/10.1007/s00421-011-2141-7): fifteen healthy men
  performed bilateral and unilateral neutral-grip dumbbell shoulder presses at
  80% 1RM. The seated conditions used a 75-degree backrest supporting the upper
  torso and glutes, so they directly support the supported unilateral record—not
  the unsupported seated fixture. The recorded rectus-abdominis,
  external-oblique, and erector-spinae activity supports explicit standing and
  unilateral trunk-stability demands without turning categorical roles into
  numeric activation weights.
- [Padovan et al. (2024), *Surface electromyography excitation in barbell vs.
  kettlebell overhead press prime movers and stabilizer
  muscles*](https://doi.org/10.1007/s11332-024-01301-w): ten experienced male
  instructors performed standing barbell and single-arm standard kettlebell
  presses with 8-RM loads while deltoid, triceps, upper-trapezius, abdominal,
  oblique, and erector-spinae excitation was recorded. It directly supports
  both standing equipment representatives while remaining a small surface-EMG
  study.
- [Luczak et al. (2013), *Shoulder Muscle Activation of Novice and Resistance
  Trained Women during Variations of Dumbbell Press
  Exercises*](https://doi.org/10.1155/2013/612650): compared 0-, 45-, and
  85-degree dumbbell presses in 24 women. The 85-degree condition directly
  supports the canonical supported seated variant and its anterior-deltoid and
  upper-trapezius involvement. Its fixed 4.5 kg load makes it useful for
  variant classification, not universal role magnitudes or an anatomical
  angle cutoff.
- [Coratella et al. (2022), *Front vs Back and Barbell vs Machine Overhead
  Press*](https://doi.org/10.3389/fphys.2022.825880): eight competitive male
  bodybuilders performed front/back barbell and machine presses at 80% 1RM.
  The distinct front/back deltoid and pectoral profiles support excluding the
  behind-neck path from this first contract; the small sample and surface EMG
  do not establish universal muscle-role magnitudes.
- [Balsalobre-Fernández et al. (2018), *Load-velocity profiling in the
  military press exercise: Effects of gender and
  training*](https://doi.org/10.1177/1747954117738243): 39 participants
  completed an incremental seated Smith-machine military press and 24 men
  repeated testing after six weeks of training. Its described pronated-grip,
  upper-chest-to-full-extension setup directly supports the seated Smith
  representative and fixed rail path; it does not provide muscle-role
  rankings.
- [Blache et al. (2017), *Muscle function in glenohumeral joint stability
  during lifting task*](https://doi.org/10.1371/journal.pone.0189406): a
  stability-constrained musculoskeletal simulation identified a substantial
  supraspinatus contribution to compressive shoulder stability during lifting.
  It supports representing supraspinatus, while remaining model evidence rather
  than a direct overhead-press muscle-role measurement.

## Review status

All eight discovery decisions were reviewed and accepted. The family contract
and its ten-exercise coverage roster are now active validator input. Further
exercises are additions only when they are independently useful catalog entries
or introduce a newly reviewed contract branch; they are not generated merely
to fill permutations:

1. One front/scapular-path `vertical-press` family; behind-neck remains out — done.
2. Initial supported angle scope of 75–90 degrees, with 46–74 deliberately
   deferred rather than mislabeled vertical.
3. `deltoidAnterior` primary and `deltoidLateral` required secondary.
4. Dynamic secondary roles for serratus and upper/lower trapezius.
5. Correct anterior-deltoid capability by adding `shoulder.abduction` — done.
6. Add supraspinatus as muscle 32 with explicit no-mesh behavior — done.
7. Make standing/unilateral stability demands mechanically enforceable — done.
8. Admit standard kettlebell presses only with
   `kettlebellOrientation: standard`; `bottomUp` remains mechanically
   unrepresentable until a later stability review — enforced with a single-arm
   standing kettlebell representative.
