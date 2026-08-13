# Vertical pull contract discovery

Status: approved and activated. The enforceable source is
`families/vertical-pull.json`; this non-validator document preserves the
research, evidence limitations, and boundary decisions that produced it.

## Activated family boundary

Use one `vertical-pull` family for strict pull-ups, assisted pull-ups, cable
pulldowns, and purpose-built lever pulldowns. Open- and closed-chain versions
move different segments, but share the catalog-defining concentric signature:
the humerus moves down from an overhead position, the elbow flexes, and the
scapula retracts without deliberate trunk or lower-body propulsion.

The family should cover front/scapular-path variants using pronated, neutral,
or supinated grips. It should not absorb every exercise that begins with the
hands overhead. Straight-arm pulldowns, scapular pull-ups, flared
horizontal-abduction high rows, diagonal high-row machines, behind-neck
pulldowns, kipping or butterfly pull-ups, muscle-ups, and band-assisted
pull-ups cross a joint-action, path, propulsion, transition, or load-semantics
boundary. Flared high rows hand off to the active
`shoulder-horizontal-abduction-row`. The overhead-start lever-high-row
candidate is reviewed in `proposals/diagonal-pull.md`; it remains unactivated
until torso-relative path geometry can distinguish it from this family without
relying on its product name.

`vertical` remains the app-facing principal resistance/body-travel direction;
it is not an anatomical plane. The accepted front/scapular corridor combines
frontal shoulder adduction and a sagittal shoulder-extension component. The
relative size of those components changes with grip and path.

## Activated classification

```json
{
  "id": "vertical-pull",
  "fixed": {
    "mechanic": "compound",
    "pattern": "pull",
    "direction": "vertical",
    "planes": ["sagittal", "frontal"]
  },
  "groupPolicy": {
    "default": "back",
    "allowed": ["back"]
  },
  "allowed": {
    "equipment": ["bodyweight", "cable", "machine"],
    "modalities": ["dynamicStrength"],
    "trackingModes": ["reps"],
    "loadModes": [
      "external",
      "bodyweightAdded",
      "assistanceSubtracted"
    ],
    "lateralities": ["bilateral", "unilateral"]
  },
  "movementSignature": {
    "planeBasisActions": [
      "shoulder.extension",
      "shoulder.adduction"
    ],
    "primeActions": [
      {
        "action": "shoulder.extension",
        "condition": "fromFlexedPosition"
      },
      "shoulder.adduction",
      "scapula.retraction",
      "elbow.flexion"
    ],
    "forbiddenPrimeActions": [
      "shoulder.flexion",
      "shoulder.abduction",
      "shoulder.horizontalAdduction",
      "shoulder.horizontalAbduction",
      "elbow.extension",
      "spine.flexion",
      "spine.extension",
      "spine.lateralFlexion",
      "spine.rotation",
      "hip.flexion",
      "hip.extension",
      "knee.flexion",
      "knee.extension",
      "ankle.plantarflexion"
    ],
    "stabilityDemands": [
      "shoulder",
      "scapula",
      "spine",
      "wrist",
      "hand"
    ]
  },
  "recommended": {
    "defaultReps": {
      "minimum": 5,
      "maximum": 15
    }
  }
}
```

The family `planes` set is derived only from the shoulder
`planeBasisActions`. `scapula.retraction` remains a transverse action at the
scapula and does not add `transverse` to the family plane set; doing so would
falsely claim a transverse shoulder component and fail the basis-plane
exactness rule.

The conditioned extension is deliberate. A canonical repetition starts with
the humerus flexed overhead, so the existing `fromFlexedPosition` condition
lets the sternocostal pectoralis-major capability participate without turning
that position-dependent action into an unconditional anatomy claim.

The two shoulder basis actions are a component model of the accepted
front/scapular corridor, not a claim that every grip has equal sagittal and
frontal excursion. Wide, deliberately lateral pulldowns can minimize sagittal
extension, while shoulder-width pull-ups and anterior pulldowns use a more
anterior plane. The current validator requires all family basis actions to be
shared prime actions. If review concludes that a valid wide variant has no
meaningful extension component, the correct response is to improve that model
or split the ownership boundary—not to retain a biomechanically false action
just to satisfy the existing schema.

## Scapular action decision

The active contract declares `scapula.retraction` as its only fixed scapular
prime action.

Pull-up tracking shows grip-dependent protraction/retraction ranges, including
retraction toward the top of the front pull-up. Front pulldown research also
records meaningful middle-trapezius excitation and describes scapular
adduction/retraction during the movement. That is enough to make retraction a
reviewable shared action rather than treating every scapular contributor as a
generic stabilizer.

Do **not** initially declare `scapula.downwardRotation` or
`scapula.depression` as universal prime actions:

- Arm lowering does not prove scapular downward rotation. A 2025 in-vivo study
  found a more upward-rotated scapular orientation during concentrically
  loaded shoulder adduction than during loaded abduction at comparable task
  positions, with substantial individual variability.
- “More upward rotation” describes orientation relative to the comparison
  task; by itself it does not prove that the scapula rotated upward over the
  concentric phase. Orientation and direction of angular change must not be
  conflated in either direction.
- Pull-up scapular medial/lateral rotation and protraction/retraction patterns
  differ by grip. A family-wide downward-rotation assertion would therefore
  be stronger than the reviewed data.
- Scapular depression is mechanically plausible, especially during the start
  of a pull-up, but the reviewed exercise studies do not yet establish it as a
  common full-repetition prime action across pull-ups, cable pulldowns, and
  assisted machines.

The active contract keeps scapular upward/downward rotation and depression out
of both the required and forbidden action sets. A later exercise may add a
scapular action only with phase-specific evidence and a contract review.

## Activated muscle policy

| Role | Active muscles | Contract meaning |
|---|---|---|
| Primary | `lats` | Sole dominant training emphasis across the admitted vertical-pull variants. |
| Required secondary | `teresMajor`, `bicepsBrachii`, `brachialis`, `brachioradialis` | Shared shoulder adduction/extension synergy plus the three separately represented elbow flexors. |
| Required retractor | At least one of `trapeziusMiddle`, `trapeziusLower`, or `rhomboids`, authored as secondary | Produces the declared scapular-retraction action while allowing pull-up and pulldown records to differ. |
| Optional secondary | `pectoralisMajorSternocostal`, `deltoidPosterior`, and the remaining allowed retractors | Position-, grip-, and path-dependent dynamic contribution. |
| Required stabilizer | `externalRotators`, `fingerFlexors`, `extensorCarpiRadialis`, plus at least one of `abs`, `obliques`, or `lowerBack` | Glenohumeral control, explicit hand/wrist control, and strict trunk control. |
| Optional stabilizer | `subscapularis`, `serratus`, `trapeziusUpper`, `pectoralisMinor`, and the remaining trunk stabilizers | Exercise-specific shoulder, scapular, and torso control. |

The active `allowedByRole` lists do not duplicate a muscle across roles.
Middle/lower trapezius and rhomboids are dynamic secondaries here because the
contract declares retraction. Serratus, upper trapezius, and pectoralis minor
remain stabilizers until the family declares a scapular action they produce.

`pectoralisMajorSternocostal` is optional secondary rather than required.
Pull-up and front-pulldown studies record meaningful pectoralis-major
excitation, and the independent anatomy map supports adduction plus extension
from a flexed start. The evidence does not justify forcing the same regional
role onto every grip and machine variant.

The taxonomy says aggregate `triceps` can produce shoulder extension because
its long head crosses the shoulder. Do not admit aggregate `triceps` as a
vertical-pull secondary in this first contract: the app does not split the long
head from the elbow-extending heads, and presenting the whole triceps as a
pulling synergist would be misleading. This is a known aggregation limit, not
an anatomy-map contradiction.

## Activated variant axes

- `kineticChain`: required `open|closed`. Pulldowns are open; pull-ups and
  assisted pull-ups are closed.
- `bodyPosition`: required `seated|suspended`. `suspended` means the torso is
  below fixed hands; an assistance platform may support the knees without
  changing that upper-body relationship.
- `lowerBodySupport`: required `none|thighPad|assistancePlatform`, using the
  shared definition: the lower-body contact or support that materially changes
  effective bodyweight loading; `none` when no such contact participates.
- `torsoSupport`: required and initially limited to `none`. Chest-supported
  diagonal machines need a later ownership review.
- `scapularTranslation`: required and initially limited to `free`. A thigh pad
  or assistance platform does not pin the scapula to a posterior surface.
- `gripOrientation`: required `pronated|neutral|supinated`.
- `relativeGripWidth`: optional `narrow|shoulderWidth|medium|wide`; required for
  a bilateral record and absent for a unilateral record. This is the shared
  cross-family width scale; `narrow` is distinct from shoulder-width rather
  than a family-local synonym for it.
- `pathConstraint`: required
  `free|leverGuided|assistancePlatformGuided`. This family-specific axis
  distinguishes an unconstrained implement/body path, a lever-guided
  resistance path, and the guided platform/body path of an assisted pull-up
  without changing the shared press-family meaning of `fixedPath`.
- `machineType`: optional `leverPulldown|assistedPullUp` and present only for
  machine equipment.
- `lowerBodyContribution`: required and initially limited to `none`.
- `pullPath`: required and initially limited to `frontScapular`; behind-neck
  paths cannot enter through a name or alias.

`relativeGripWidth` is categorical on purpose. The research conditions give
useful authoring anchors—approximately 1.0, 1.5, and 2.0 times biacromial
width—but those values are not biological switches and users do not measure
their bar grip with calipers. The axis makes common variants testable without
pretending to have exercise-level geometric precision.

The width studies do not support changing the primary muscle contract simply
because a grip is wide. Pronated versus supinated orientation and width can
change excitation, strength, range, and shoulder kinematics; they remain
variant axes inside one family rather than automatic reasons to assign a new
primary.

## Activated cross-field rules

1. `equipment: bodyweight` requires closed chain, `suspended`,
   `lowerBodySupport: none`, `pathConstraint: free`, bilateral laterality,
   `loadMode: bodyweightAdded`, and `bodyweightFraction: 1.0`.
2. `equipment: cable` requires open chain, `seated`, `thighPad`,
   `pathConstraint: free`, and `loadMode: external`.
3. `equipment: machine` requires a `machineType`.
4. `equipment != machine` explicitly requires `machineType` to be absent, so
   invalid metadata produces a direct non-machine rule failure rather than a
   transitive conflict with a machine branch.
5. `machineType: leverPulldown` requires open chain, `seated`, `thighPad`,
   `pathConstraint: leverGuided`, and `loadMode: external`.
6. `machineType: assistedPullUp` requires closed chain, `suspended`,
   `lowerBodySupport: assistancePlatform`, bilateral laterality,
   `pathConstraint: assistancePlatformGuided`,
   `loadMode: assistanceSubtracted`, and `bodyweightFraction: 1.0`.
7. A bilateral record requires `relativeGripWidth`; a unilateral record must
   omit it.
8. A unilateral record is limited to cable or `leverPulldown` equipment and
   must add a `pelvis` stability demand. One-arm bodyweight pull-ups and
   unilateral assisted-platform pull-ups remain outside the initial scope.
9. A suspended record must add a `pelvis` stability demand. The base contract
   already requires spinal stability for every record.
10. Every record uses `torsoSupport: none`, `scapularTranslation: free`,
   `lowerBodyContribution: none`, and `pullPath: frontScapular`.

Do not declare `fixedPath` in this family. Its shared definition is specifically
whether rails or a lever constrain an external load path, which does not
truthfully describe an assisted pull-up's subtractive platform. The dedicated
`pathConstraint` enum keeps that distinction visible. Hand fixation remains
separate in `kineticChain`.

## Activated scope and exclusions

| Candidate | Active decision | Reason |
|---|---|---|
| Strict pull-up, chin-up, and neutral-grip pull-up | Own | Same shoulder/elbow signature; grip orientation is explicit. |
| Wide-grip pull-up | Own, with a visible width value | It has distinct kinematics but remains the same family; inclusion is not a safety claim. |
| Added-weight pull-up | Do not create a second catalog item | `bodyweightAdded` already represents added external load on the canonical pull-up record. |
| Assisted pull-up/chin-up machine | Own | Closed-chain signature with explicit subtractive assistance. |
| Seated cable pulldown variants | Own | Open-chain version of the same accepted front/scapular signature. |
| Bilateral or unilateral lever pulldown | Own | Same signature with a guided resistance path. |
| Flared high row to the upper chest | Exclude | Shoulder horizontal abduction dominates; ownership belongs to the active `shoulder-horizontal-abduction-row`. |
| Overhead-start lever high-row machine | Defer | `proposals/diagonal-pull.md` must establish a distinct torso-relative path and humeral actions; the product name does not prove diagonal ownership. |
| Half-kneeling or tall-kneeling cable pulldown | Defer | Adds support, pelvis, and possible unilateral trunk-control combinations not covered by the initial seated rule. |
| Behind-neck pulldown | Defer | Distinct humeral path and mobility demand; front-only is a scope boundary, not a claim that the exercise is universally unsafe. |
| Straight-arm pulldown or machine pullover | Exclude | No elbow-flexion signature; belongs to a shoulder-extension isolation family. |
| Scapular pull-up | Exclude | Deliberately omits the shoulder/elbow signature; belongs to a scapular-action family. |
| Kipping or butterfly pull-up | Exclude | Hip, knee, trunk, and momentum contributions are part of the movement rather than stabilization only. |
| Muscle-up | Exclude | Adds a transition and press phase. |
| Ring, towel, or rotating-handle pull-up | Defer | Grip motion and instability need explicit axes and evidence. |
| Band-assisted pull-up | Defer | The current global band rule uses `nonComparable`; variable elastic assistance cannot truthfully use the fixed `assistanceSubtracted` semantics. |
| One-arm bodyweight pull-up | Defer | Advanced unilateral closed-chain mechanics should not enter merely because cable pulldowns admit unilateral records. |

## Activated coverage roster

These 13 records are active validator input. They form a coverage matrix, not a
Cartesian product.

| Exercise | Coverage purpose |
|---|---|
| Pull-Up | Closed-chain, pronated, shoulder-width bodyweight baseline. |
| Chin-Up | Supinated closed-chain variant and its biceps/pectoral delta. |
| Neutral-Grip Pull-Up | Neutral closed-chain grip branch. |
| Wide-Grip Pull-Up | Wide pronated branch and documented scapular-kinematic difference. |
| Assisted Pull-Up Machine | Guided subtractive-assistance branch. |
| Assisted Chin-Up Machine | Supinated interaction with subtractive assistance. |
| Cable Lat Pulldown | Open-chain, pronated, medium-width cable baseline. |
| Close-Grip Neutral Lat Pulldown | Neutral narrow-width cable branch. |
| Underhand Lat Pulldown | Supinated cable branch. |
| Wide-Grip Lat Pulldown | Wide pronated cable branch without inventing a new primary-muscle policy. |
| Single-Arm Cable Lat Pulldown | Unilateral free-handle branch and pelvic-stability rule. |
| Machine Lat Pulldown | Bilateral lever-guided branch. |
| Single-Arm Machine Lat Pulldown | Unilateral interaction with the lever-guided branch. |

This set covers all allowed equipment, load modes, chain values, grip
orientations, grip widths, laterality values, support modes, and all three
path-constraint values. Extra width/orientation permutations should be added only
when they are useful searchable exercises, not to fill a matrix.

Three active records contain mechanics-derived coverage decisions that are
not directly isolated by the reviewed exercise studies. None of Buonsenso et
al.'s seven pulldown conditions was unilateral, so the single-arm cable and
lever records—and their explicit pelvic-stability demand—derive conservatively
from asymmetric loading mechanics. The assisted chin-up combines supinated-grip
evidence from unassisted chin-ups with assisted-machine evidence; no reviewed
study crosses those two conditions directly. Their prime movers remain the
family baseline. They are identified here as mechanics-derived and are not
presented as condition-matched EMG findings.

## Evidence reviewed

- [Ackland et al. (2008), *Moment arms of the muscles crossing the anatomical
  shoulder*](https://doi.org/10.1111/j.1469-7580.2008.00965.x): anatomical
  capability evidence for latissimus dorsi, teres major, posterior deltoid,
  and pectoral shoulder actions. It does not rank exercise variants.
- [Youdas et al. (2010), *Surface electromyographic activation patterns and
  elbow joint motion during a pull-up, chin-up, or Perfect-Pullup rotational
  exercise*](https://doi.org/10.1519/JSC.0b013e3181f1598c): 25 participants;
  latissimus dorsi, biceps, infraspinatus, lower trapezius, pectoralis major,
  erector spinae, and external-oblique excitation supports the active role
  envelope. Chin-ups increased biceps and pectoralis-major excitation, while
  pull-ups increased lower-trapezius excitation. Surface EMG does not by
  itself establish an anatomical action or continuous muscle weight.
- [Doma et al. (2013), *Kinematic and electromyographic comparisons between
  chin-ups and lat-pull down exercises*](https://doi.org/10.1080/14763141.2012.760204):
  directly compares closed-chain chin-ups and open-chain pulldowns and reports
  meaningful kinematic and trunk-muscle differences. It supports chain and
  body-position axes while retaining common family ownership.
- [Lusk et al. (2010), *Grip width and forearm orientation effects on muscle
  activity during the lat pull-down*](https://doi.org/10.1519/JSC.0b013e3181ddb0ab):
  twelve trained men performed anterior pulldowns at 70% 1RM. Pronated grips
  produced greater latissimus-dorsi excitation than supinated grips, while
  width did not create the assumed latissimus advantage.
- [Andersen et al. (2014), *Effects of grip width on muscle strength and
  activation in the lat pull-down*](https://doi.org/10.1097/JSC.0000000000000232):
  fifteen men used 1.0, 1.5, and 2.0 times biacromial width. The operational
  widths support categorical authoring anchors; small strength/activation
  differences do not justify separate muscle contracts.
- [Prinold and Bull (2016), *Scapula kinematics of pull-up techniques:
  Avoiding impingement risk with training changes*](https://doi.org/10.1016/j.jsams.2015.08.002):
  eleven trained participants showed grip-dependent humerothoracic,
  glenohumeral, and scapulothoracic kinematics. The data support explicit grip
  axes and scapular retraction; the paper's injury-risk interpretation is not
  used as a catalog prohibition.
- [Padovan et al. (2024), *High-Density Electromyography Excitation in Front
  vs. Back Lat Pull-Down Prime Movers*](https://doi.org/10.5114/jhk/185211):
  fourteen trained men showed distinct front/back excitation and spatial
  patterns. The study supports a visible front-path boundary and secondary
  roles for pectoralis major, middle trapezius, biceps, and posterior deltoid;
  it does not establish that behind-neck pulldowns are universally unsafe.
- [Lee et al. (2025), *Scapular kinematics and task specificity: The effect of
  load direction*](https://doi.org/10.1016/j.jbiomech.2025.112932): ten
  healthy adults were measured with biplanar videoradiography during loaded
  adduction and abduction. More upward-rotated scapular orientation and high
  individual variability during adduction directly warn against deriving a
  universal rotation action from arm-travel direction.
- [Buonsenso et al. (2025), *Electromyographic Analysis of Back Muscle
  Activation During Lat Pulldown Exercise: Effects of Grip Variations and
  Forearm Orientation*](https://doi.org/10.3390/jfmk10030345): forty trained
  men performed seven front-pulldown variants. Broad back-muscle excitation
  was largely similar across the tested grip/width conditions, reinforcing
  axes within one family rather than role-contract proliferation.
- [Dinunzio et al. (2019), *Alterations in kinematics and muscle activation
  patterns with the addition of a kipping action during a pull-up
  activity*](https://doi.org/10.1080/14763141.2018.1452971): eleven athletes
  showed substantially greater hip/knee motion and lower-body/core recruitment
  with kipping. This supports a hard propulsion boundary without making an
  injury claim.
- [Hewit et al. (2018), *A Comparison of Muscle Activation during the Pull-up
  and Three Alternative Pulling Exercises*](https://doi.org/10.19080/JPFMTS.2018.05.555669):
  directly compares bodyweight, seated/kneeling pulldown, and assisted-machine
  conditions. It is useful coverage evidence for the assisted branch, but its
  subgrouped surface-EMG design is not used to assign universal numeric roles.

The active family reuses `ackland-2008-shoulder-moment-arms` and registers the
pulldown paper as `padovan-2024-lat-pulldown-front-back`; the existing
`padovan-2024-standing-overhead-press` ID belongs to a different study. Every
other reviewed source has its own distinct evidence ID.

## Review status

All ten discovery decisions were reviewed and accepted. The family contract
and its 13-exercise coverage roster are now active validator input:

1. One family spans open-chain pulldowns and closed-chain pull-ups/assisted
   pull-ups — done.
2. The dual shoulder-component model is active; a future pure-frontal variant
   must expose and improve the validator model rather than hide a false action
   — done.
3. `scapula.retraction` is the only fixed scapular prime action; universal
   depression and upward/downward rotation remain deferred — done.
4. `lats` is the sole primary, the required secondary/stabilizer policy is
   enforced, and aggregate `triceps` is excluded — done.
5. Bilateral plus seated unilateral cable/lever scope is active; kneeling and
   one-arm bodyweight variants remain out — done.
6. Relative grip width is categorical; the research widths remain authoring
   anchors only — done.
7. Only the front/scapular path is active, without making a universal safety
   verdict on behind-neck pulling — done.
8. The dedicated `pathConstraint` enum is active; `fixedPath` retains its
   external-load-only meaning and is absent from this family — done.
9. Band assistance remains deferred until its variable assistance can be
   represented honestly — done.
10. All 13 reviewed coverage exercises, evidence records, and mutation tests
    are active — done.
