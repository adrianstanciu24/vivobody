# Shoulder-extension row contract discovery

Status: approved and activated. The enforceable source is
`families/shoulder-extension-row.json`; this non-validator document preserves
the research, evidence limitations, and boundary decisions that produced it.
The app-facing display name remains “Horizontal Row”; the explicit ID records
the humeral action that distinguishes this contract from other horizontal
pulls.

## Activated family boundary

Use `shoulder-extension-row` for strict, shoulder-extension-dominant rows
performed with the upper arm tucked or travelling in a modest scapular
corridor. The canonical concentric signature is:

1. the humerus extends from a flexed position toward the torso;
2. the scapula retracts;
3. the elbow flexes; and
4. the torso and lower body resist the load without deliberately propelling it.

Do **not** use one universal row contract. A deliberately flared row to the
upper chest is not merely a grip variant: its defining humeral action shifts
toward shoulder horizontal abduction and its muscular emphasis shifts toward
the trapezius and deltoid. It belongs to the active
`shoulder-horizontal-abduction-row`. Lorenzetti's measured seated 45-degree
cable pulldown now belongs to `diagonal-pull`; a commercial lever machine
marketed as a “high row” does not inherit that ownership and may still belong
to a horizontal row after model-specific geometry review. Exercise names
cannot decide between those signatures. Face pulls cross another boundary by adding deliberate shoulder
external rotation.

This split is supported by two direct comparisons. Suspension low rows produced
a different excitation profile from high and horizontal-abduction rows, and a
recent narrow-versus-wide seated-row study found greater latissimus-dorsi
excitation in the narrow row but greater upper-, middle-, and lower-trapezius
and lateral-deltoid excitation in the wide row. The split is a contract
boundary, not a claim that any muscle switches completely on or off at a
particular elbow angle.

## Activated classification

```json
{
  "id": "shoulder-extension-row",
  "fixed": {
    "mechanic": "compound",
    "pattern": "pull",
    "direction": "horizontal",
    "planes": ["sagittal"]
  },
  "groupPolicy": {
    "default": "back",
    "allowed": ["back"]
  },
  "allowed": {
    "equipment": [
      "barbell",
      "dumbbell",
      "cable",
      "machine",
      "bodyweight"
    ],
    "modalities": ["dynamicStrength"],
    "trackingModes": ["reps"],
    "loadModes": ["external", "bodyweightAdded"],
    "lateralities": ["bilateral", "unilateral"]
  },
  "movementSignature": {
    "planeBasisActions": [
      "shoulder.extension"
    ],
    "primeActions": [
      {
        "action": "shoulder.extension",
        "condition": "fromFlexedPosition"
      },
      "scapula.retraction",
      "elbow.flexion"
    ],
    "forbiddenPrimeActions": [
      "shoulder.flexion",
      "shoulder.abduction",
      "shoulder.horizontalAdduction",
      "shoulder.horizontalAbduction",
      "shoulder.externalRotation",
      "scapula.protraction",
      "elbow.extension",
      "spine.flexion",
      "spine.extension",
      "spine.lateralFlexion",
      "spine.rotation",
      "hip.extension",
      "knee.extension",
      "ankle.plantarflexion"
    ],
    "stabilityDemands": [
      "shoulder",
      "scapula",
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

`horizontal` describes the principal resistance/body-travel direction relative
to the torso. It does not mean that every implement travels horizontally in the
room: a barbell travels mostly vertically in world coordinates while a
hip-hinged torso makes it a horizontal pull relative to the body.

The family plane is `sagittal` because the humeral basis action is shoulder
extension. `scapula.retraction` is a transverse action at a different joint and
does not add `transverse` to the family plane set. Adding it would falsely claim
a transverse shoulder action and would fail the existing basis-plane exactness
rule. This is the row equivalent of the documented vertical-pull plane
subtlety.

The conditioned extension is deliberate. A canonical row begins with the
humerus flexed in front of the torso and extends it toward the torso. The
existing `fromFlexedPosition` condition records that context without turning
position-dependent muscle capabilities into unconditional anatomy claims.

`shoulder.horizontalAbduction` is explicitly forbidden as a **prime** action.
This does not claim that every admitted row has zero transverse excursion; it
prevents a flared, horizontal-abduction-dominant row from entering through an
alias or an `additionalPrimeActions` edit. Small three-dimensional components
do not become catalog prime actions merely because living joints do not move in
perfect mathematical planes.

## Scapular action and support decision

The activated canonical technique allows the scapulae to protract during the
eccentric phase and retract during the concentric phase. Therefore
`scapula.retraction` is a fixed prime action and the activated
`scapularTranslation` axis is initially limited to `free`.

The action signature describes the concentric phase. Its
`scapula.protraction` prohibition prevents protraction from being authored as
a concentric prime action; it does not deny the controlled protraction that is
the eccentric reversal of the declared retraction.

This is a technique boundary, not a verdict that a fixed-scapula seated row is
invalid. Padovan et al. directly compared deliberately fixed and free scapular
positions and found broadly comparable excitation with selected spatial and
phase-specific differences. The fixed condition is a coaching constraint; it
is not created automatically by a chest pad.

A bench or machine pad supports the anterior torso. The scapulae remain on the
posterior thorax and can translate during a chest-supported row. Therefore:

- `torsoSupport: bench|machinePad` does not imply constrained scapulae;
- every initially admitted row uses `scapularTranslation: free`; and
- adding a deliberately fixed-scapula technique later requires a visible
  contract review rather than reusing the press-family
  `supportConstrained` rule.

## Activated muscle policy

| Role | Activated muscles | Contract meaning |
|---|---|---|
| Primary | `lats` | Sole dominant training emphasis for the admitted narrow/tucked shoulder-extension row. |
| Required secondary | `teresMajor`, `deltoidPosterior`, `bicepsBrachii`, `brachialis`, `brachioradialis`, `trapeziusMiddle`, `rhomboids` | Shoulder extension, the three separately represented elbow flexors, and dynamic scapular retraction. |
| Optional secondary | `trapeziusLower`, `pectoralisMajorSternocostal` | Exercise-specific retraction contribution and position-dependent extension assistance. |
| Required stabilizer | `subscapularis`, `fingerFlexors`, `extensorCarpiRadialis` | Direction-specific glenohumeral control plus explicit hand/wrist control. |
| Conditional hip-hinged stabilizers | `lumbarExtensors` and `gluteMax` | Every unsupported hip-hinged record resists spinal and hip motion. |
| Conditional suspended stabilizers | `abs`, `lumbarExtensors`, and `gluteMax` | The inverted-row branch maintains a straight body against gravity. |
| Conditional unilateral stabilizer | `obliques` | Every unilateral record resists asymmetric pelvic and trunk motion. |
| Conditional trunk stabilizer | At least one of `abs`, `obliques`, or `lumbarExtensors` when `torsoSupport: none` | Unsupported torso control without falsely forcing the same demand onto a chest-pad row. |
| Other allowed stabilizers | `externalRotators`, `supraspinatus`, `trapeziusUpper`, `serratus`, `pectoralisMinor`, `abs`, `obliques`, `lumbarExtensors`, `gluteMax`, `gluteMed`, `medialHamstrings`, `bicepsFemoris` | Exercise-specific shoulder, scapular, spinal, pelvic, hip, and knee control; the conditional rows above still make some assignments mandatory in matching setups. The two hamstring regions replace the retired aggregate without granting the unsplit biceps-femoris mesh hip-extension capability. |

The activated `allowedByRole` lists do not duplicate a muscle across roles.
Middle trapezius and rhomboids are secondaries rather than stabilizers because
the family declares the action they produce—scapular retraction—as part of the
movement. Lower trapezius is allowed in the same dynamic role but is not forced
onto every setup.

`pectoralisMajorSternocostal` is optional secondary because the conditioned
extension begins from a flexed humeral position and matches its anatomy
profile. It is not required: the reviewed row studies do not justify forcing a
visible pectoral role onto every setup, and capability alone does not establish
meaningful exercise emphasis.

`deltoidPosterior` is required here rather than optional as it is in vertical
pull. Shoulder extension from a flexed start is this family's sole humeral
basis action, and the posterior deltoid contributes directly to that row path.
Vertical pull is principally shoulder adduction with a variable sagittal
extension component, so the same role is not forced across every pull-up and
pulldown. The row requirement is supported by the action map and the reviewed
row and inverted-row evidence, while the limitations section still discloses
that no study tested every admitted setup.

Requiring both middle trapezius and rhomboids is partly anatomy-driven. Lehman
et al. recorded them with a combined surface-electrode site, so that study
cannot apportion their individual excitation. The independent action map says
both produce retraction, and fine-wire work confirms coactivation in a rowing
position—although that study used 90-degree shoulder abduction outside this
family's admitted path. This is stronger than allowing either muscle to
disappear, but it should remain an explicit review decision rather than being
presented as condition-matched exercise EMG.

`subscapularis` is the activated required cuff stabilizer. A direct row study
found subscapularis excitation greater than infraspinatus during the row while
concluding that the cuff acted as a direction-specific dynamic stabilizer.
`externalRotators` and `supraspinatus` remain allowed stabilizers; copying an
external-rotator requirement from presses would ignore the row-specific data.

Aggregate `triceps` should remain excluded. Its long head can contribute to
shoulder extension, but the catalog does not split it from the elbow-extending
heads, so presenting the whole triceps as a normal rowing secondary would be
misleading.

## Activated variant axes

- `kineticChain`: required `open|closed`. External-load rows are open;
  fixed-bar inverted rows are closed.
- `bodyPosition`: required
  `hipHinged|seated|prone|supineSuspended`. The values describe the torso/setup
  relationship rather than its world-space resistance path.
- `lowerBodySupport`: required `none|feet`, retaining the shared definition:
  the lower-body contact that materially changes effective bodyweight loading.
  Only the initial inverted-row branch uses `feet`.
- `torsoSupport`: required `none|bench|machinePad`. A contralateral hand and
  knee support the body without becoming direct torso support.
- `scapularTranslation`: required and initially limited to `free`.
- `gripOrientation`: required `pronated|neutral|supinated`.
- `relativeGripWidth`: optional `narrow|shoulderWidth`; required for bilateral
  exercises and absent for unilateral exercises. The global ordered vocabulary
  is `narrow|shoulderWidth|medium|wide`; this family admits only its first two
  values. Vertical pull now uses `narrow` for its close-grip neutral pulldown,
  so `shoulderWidth` is never a family-local synonym for close grip. Do not
  introduce `close` or `closeGrip` synonyms.
- `upperArmPath`: required `tucked|scapular`. `tucked` keeps the upper arm near
  the torso; `scapular` allows a modest abducted corridor while shoulder
  extension remains the principal humeral action. `flared` is deliberately
  absent.
- `fixedPath`: required boolean with the existing shared meaning: whether rails
  or a lever constrain the external load path. A fixed-bar inverted row still
  uses `false` because the axis does not describe distal fixation; that remains
  `kineticChain`.
- `machineType`: optional `leverRow|smith`, present only for machine equipment.
  The names describe mechanisms without embedding exercise angle or family
  name.
- `leverArmConfiguration`: optional `linked|independent`, required for
  `leverRow` and absent for Smith rails or non-machine equipment. It uses the
  same vocabulary as the shoulder-height-row sibling; a linked lever cannot be
  authored unilaterally.
- `lowerBodyContribution`: required and initially limited to `none`.
- `interRepSupport`: required `none|floor`. `floor` represents a strict
  floor-reset row such as a Pendlay row; it does not permit hip or spinal drive.
- `contralateralSupport`: required `none|handAndKneeOnBench`. The latter is the
  canonical supported one-arm dumbbell-row setup, not torso support.
- `bodyweightApparatus`: optional and initially limited to `fixedBar`; required
  for bodyweight equipment and absent otherwise. Suspension handles and rings
  remain visible future decisions.
- `bodyLeverage`: optional and initially limited to `parallelFeetFloor`;
  required for bodyweight equipment and absent otherwise. This pins the setup
  used by the activated bodyweight-load estimate rather than pretending all
  inverted-row inclinations are equivalent.

`relativeGripWidth` and `upperArmPath` are both necessary. Hand spacing is
observable but does not uniquely determine humeral path; independent handles
can be held narrowly while the elbows flare, and a bar grip does not guarantee
one exact elbow angle. The contract should test both rather than infer either
from the exercise name.

## Activated cross-field rules

The following names are the intended JSON rule IDs. Each bullet has one
predicate so the activated test suite can prove both a matching and a
contrasting roster branch.

1. `bodyweight-uses-closed-chain-load-semantics`: bodyweight equipment requires
   closed chain, `supineSuspended`, `lowerBodySupport: feet`, no torso support,
   `fixedPath: false`, `interRepSupport: none`,
   `contralateralSupport: none`, `loadMode: bodyweightAdded`, and presence of
   `bodyweightApparatus` and `bodyLeverage`. It does not dictate grip, upper-arm
   path, apparatus value, or laterality.
2. `parallel-feet-floor-pins-bodyweight-load`:
   `bodyLeverage: parallelFeetFloor` requires bodyweight equipment,
   `supineSuspended`, feet support, and the reviewed `0.73` bodyweight fraction.
   Leverage controls geometry and loading, not grip or apparatus.
3. `fixed-bar-apparatus-requires-bodyweight`:
   `bodyweightApparatus: fixedBar` requires bodyweight equipment and limits
   grip to `pronated|supinated`. Future rings, suspension handles, or parallel
   handles need explicit apparatus values and their own review rather than
   changing the meaning of leverage or admitting a neutral grip on a straight
   bar.
4. `non-bodyweight-uses-open-chain-external-load`: every non-bodyweight record
   requires open chain, external load, zero `bodyweightFraction`,
   `lowerBodySupport: none`, and absence of both bodyweight-only axes.
5. `machine-requires-fixed-path-and-type`: machine equipment requires
   `fixedPath: true` plus `machineType`.
6. `non-machine-requires-free-path`: every non-machine record requires
   `fixedPath: false` and omits both machine-only axes.
7. `lever-row-is-supported-seated`: `machineType: leverRow` requires `seated`,
   `machinePad`, `neutral|pronated` grip, no contralateral support, and a
   declared `leverArmConfiguration`.
8. `smith-row-is-hip-hinged`: `machineType: smith` requires `hipHinged`, no
   torso support, bilateral laterality, pronated grip, and no contralateral
   support, and omits `leverArmConfiguration` because Smith rails are not lever
   arms.
9. `linked-lever-arms-are-bilateral`: a linked left/right lever requires
   `machineType: leverRow` and bilateral laterality.
10. `barbell-is-unsupported-hip-hinged`: barbell equipment requires
   `hipHinged`, no torso support, and `fixedPath: false`; supinated and pronated
   grips are admitted while neutral is not.
11. `dumbbell-is-neutral-free-path`: dumbbell equipment is limited to
    `hipHinged|prone`, neutral grip, and a non-fixed path.
12. `prone-row-is-supported-bilateral-dumbbell`: `bodyPosition: prone`
    requires bilateral dumbbell equipment and `torsoSupport: bench`.
13. `cable-is-unsupported-seated-free-path`: cable equipment requires
    `seated`, no torso support, `neutral|pronated` grip, a free external path,
    and `interRepSupport: none`.
14. `bench-support-requires-prone-dumbbell`: `torsoSupport: bench` requires
    bilateral dumbbell equipment and `prone`.
15. `machine-pad-requires-lever-row`: `torsoSupport: machinePad` requires
    `machineType: leverRow` and `seated`.
16. `hand-and-knee-support-is-unilateral-dumbbell`:
    `contralateralSupport: handAndKneeOnBench` requires unilateral dumbbell
    equipment, `hipHinged`, and no torso support.
17. `bilateral-has-no-contralateral-support`: bilateral records require
    `contralateralSupport: none`.
18. `bilateral-requires-grip-width`: bilateral records require
    `relativeGripWidth`.
19. `unilateral-requires-asymmetric-control`: unilateral records are limited to
    dumbbell, cable, or machine equipment, omit `relativeGripWidth`, add a
    `pelvis` stability demand, and assign `obliques` as a stabilizer. The rule
    language cannot express “lever-row machine” with its single predicate.
    Rule `machine-requires-fixed-path-and-type` requires a machine type, while
    `smith-row-is-hip-hinged` requires bilateral laterality, so those rules
    jointly leave `leverRow` as the only unilateral machine branch.
    `lever-row-is-supported-seated` then requires a configuration, and
    `linked-lever-arms-are-bilateral` forces the unilateral branch to
    `independent`. The unilateral-Smith mutation must assert the
    `smith-row-is-hip-hinged` failure message so that dependency cannot be
    loosened silently. One-arm inverted rows remain out.
20. `hip-hinged-requires-posterior-chain-stability`:
    `bodyPosition: hipHinged` adds `spine`, `pelvis`, and `hip` stability
    demands and assigns both `lumbarExtensors` and `gluteMax` as stabilizers.
21. `suspended-requires-straight-body-stability`:
    `bodyPosition: supineSuspended` adds `spine`, `pelvis`, and `hip` stability
    demands and assigns `abs`, `lumbarExtensors`, and `gluteMax` as stabilizers.
22. `unsupported-requires-trunk-stability`: `torsoSupport: none` adds a `spine`
    stability demand and assigns at least one of `abs`, `obliques`, or
    `lumbarExtensors` as a stabilizer.
23. `floor-reset-is-strict-pronated-barbell`: `interRepSupport: floor` requires
    bilateral pronated barbell equipment, `hipHinged`, no torso support, and no
    lower-body contribution.
24. `narrow-grip-requires-tucked-path`: `relativeGripWidth: narrow` requires
    `upperArmPath: tucked`.
25. `supinated-grip-requires-tucked-path`: a supinated grip requires
    `upperArmPath: tucked` in the initial contract.

`scapularTranslation` and `lowerBodyContribution` are required single-value
axes (`free` and `none`). They are axis constraints, not always-true exercise
rules; every exercise rule requires a real predicate and a contrasting roster
branch.

Rule `unsupported-requires-trunk-stability` uses the activated conditional
muscle assertion. `requireInvolvement` still requires one exact assignment;
`requireMuscleRequirements` reuses the family-level requirement shape when any
member of a reviewed set is truthful:

```json
{
  "requireMuscleRequirements": [
    {
      "anyOf": ["abs", "obliques", "lumbarExtensors"],
      "minimumRole": "stabilizer"
    }
  ]
}
```

Without that assertion, `lats` could satisfy an added `spine` stability demand
through its anatomy profile while an unsupported row omitted every explicitly
authored trunk stabilizer. That would be schema-valid but biomechanically too
permissive.

Within the activated roster, the conditional any-of clause is load-bearing for
exactly the bilateral Seated Cable Row. Hip-hinged and suspended records already
receive `lumbarExtensors` through rules 19 and 20, while every unilateral record
receives `obliques` through rule 18. The mutation test for rule 21 must therefore
remove the trunk assignment from Seated Cable Row rather than depending on
exercise-array order.

## Activated scope and exclusions

| Candidate | Decision | Reason |
|---|---|---|
| Strict pronated or underhand barbell bent-over row | Own | Extension-dominant signature with grip and path explicit. |
| Pendlay row | Own | Same signature with `interRepSupport: floor`; hip or spinal drive remains forbidden. |
| Bilateral or one-arm dumbbell row | Own | Same signature; support and laterality alter trunk demands. |
| Chest-supported dumbbell row | Own | Same upper-body signature with anterior torso support and free scapular translation. |
| Seated cable row, bilateral or unilateral | Own | Open-chain free-handle version of the same narrow/tucked signature. |
| Shoulder-width pronated straight-bar seated cable row | Own | Common pronated cable implementation inside the same extension-dominant boundary; admitted without forcing a separate initial coverage record. |
| Chest-supported lever row machine | Own | Same signature with a guided external path. |
| Pronated lever-row handles | Own | Grip orientation does not change family ownership when the upper-arm path remains tucked or scapular. |
| Smith machine bent-over row | Own | Same strict hip-hinged signature with a rail-guided path; evidence is mechanics-derived. |
| Fixed-bar inverted row | Own only with canonical leverage pinned | Closed-chain version; variable inclinations must not silently reuse one bodyweight fraction. |
| Supinated fixed-bar inverted row | Admit vocabulary; defer record | A straight fixed bar supports an underhand grip within the same mechanics; add a catalog item only if it is a useful searchable variant. |
| Neutral-grip inverted row | Defer | Requires a reviewed `parallelHandles` apparatus value; neutral grip is not representable by the initial straight `fixedBar`. |
| Wide-grip or deliberately flared high row to the upper chest | Exclude | Horizontal-abduction/trapezius-emphasis boundary; active `shoulder-horizontal-abduction-row`. |
| Seated 45-degree cable pulldown | Exclude; owned by `diagonal-pull` | Its source-exact start and chest-contact path define a diagonal rather than horizontal record. |
| Overhead-start lever high-row machine | Defer outside current owners | Product naming does not prove equivalence to the active measured cable fixture. |
| Face pull | Exclude | Adds deliberate shoulder external rotation and a higher pull target. |
| Rear-delt fly | Exclude | Omits elbow flexion and belongs to a shoulder-horizontal-abduction isolation family. |
| Upright row | Exclude | Shoulder elevation/abduction signature rather than horizontal shoulder extension. |
| Renegade row | Defer | Adds a loaded plank, contralateral arm support, and anti-rotation demand that deserve an explicit hybrid contract. |
| T-bar, landmine, or Meadows row | Defer | Pivot-guided path, stance, and equipment semantics are not represented by the initial axes. |
| Seal or chest-supported barbell row | Defer | Valid mechanics, but unnecessary for initial axis coverage once the dumbbell supported branch exists; add only as a useful searchable movement. |
| Suspension-handle or ring row | Defer | Independent moving handles and instability require an apparatus axis expansion and their own load anchor. |
| Feet-elevated or inclined inverted row | Defer | Body inclination materially changes effective bodyweight load. |
| One-arm inverted row | Defer | Advanced unilateral closed-chain mechanics are not licensed by the cable/dumbbell branch. |
| Kroc, cheat, or momentum row | Exclude | Hip, spine, or lower-body propulsion is part of the repetition. |
| Gorilla row | Defer | Alternating kettlebell support and stance need explicit equipment and support semantics. |

The exclusion of a wide row is not a safety judgment. It is a family-ownership
decision grounded in a different humeral action and emphasis profile.
“High row” remains too ambiguous to route by name: the humeral action and
resistance path decide between the active horizontal-abduction contract and a
future diagonal contract.

Pronated cable bars and pronated machine handles are admitted vocabulary, not
silent deferrals. The initial coverage matrix does not add duplicate records
solely to exercise those grip/equipment permutations; a distinct catalog item
should be added when it is a useful searchable movement.

## Activated coverage roster

These 12 records form a coverage matrix, not a Cartesian product:

| Exercise | Coverage purpose |
|---|---|
| Barbell Bent-Over Row | Bilateral pronated hip-hinged non-fixed-path baseline. |
| Underhand Barbell Row | Supinated, tucked-path branch. |
| Pendlay Row | Floor-reset branch without lower-body propulsion. |
| Dumbbell Bent-Over Row | Bilateral neutral-grip free-weight branch. |
| One-Arm Dumbbell Row | Unilateral hand-and-knee-supported branch and asymmetric trunk rule. |
| Chest-Supported Dumbbell Row | Prone bench support while scapular translation remains free. |
| Seated Cable Row | Bilateral narrow neutral cable baseline. |
| Single-Arm Seated Cable Row | Unilateral unsupported seated cable branch. |
| Chest-Supported Machine Row | Bilateral linked-lever, machine-pad branch. |
| Single-Arm Chest-Supported Machine Row | Unilateral independent-lever interaction with the pad branch. |
| Smith Machine Bent-Over Row | Rail-guided machine plus hip-hinged stability branch. |
| Inverted Row | Closed-chain, shoulder-width pronated, scapular-path fixed-bar bodyweight branch with pinned leverage. |

Together they cover all admitted equipment, lateralities, grip orientations,
relative grip widths, upper-arm paths, body positions, torso supports, chain
values, fixed-path values, machine types, lever-arm configurations,
inter-repetition support values, and
contralateral-support values. They do not generate every grip/equipment
permutation.

### Bodyweight-load gate

The inverted-row record requires special care. Vural et al. measured applied
strap force and bodyweight distribution under specific feet-on-ground and
feet-suspended setups; loading changed with setup and contraction phase. Their
approximately horizontal feet-on-ground isotonic condition provides a
reviewable authoring anchor near `0.73`, not a universal fraction for every
exercise called “inverted row.”

Recommended initial choice: author one fixed-bar, straight-body,
feet-on-floor, approximately parallel inverted row with
`bodyweightFraction: 0.73`, and pin that setup with
`bodyLeverage: parallelFeetFloor`. This transfers the measured suspension
geometry to a fixed-bar setup because the load split is principally geometric;
the transfer is still an inference and must be disclosed. If that inference is
not accepted, defer the inverted-row record rather than publishing a false
universal fraction.

## Evidence limitations and mechanics-derived fixtures

The evidence supports the family boundary and role envelope, but it does not
directly test every admitted record:

- Surface and high-density EMG describe excitation under tested conditions;
  they do not by themselves prove hypertrophy, establish continuous muscle
  weights, or turn an observed ranking into a universal categorical role.
- The reviewed work directly covers seated, bent-over, cable, machine,
  unilateral, bilateral, and inverted-row conditions, but no reviewed study
  isolates the activated Smith row or a strict Pendlay row. Those are
  mechanics-derived coverage fixtures.
- The one-arm dumbbell support configuration is mechanics-derived. The
  unilateral trunk rule is supported across unilateral cable, machine, and
  free-weight rows, but that does not make every setup condition-matched.
- The activated chest-supported dumbbell record extrapolates the support effect
  from free-versus-machine and standing-versus-bench comparisons. The latter
  bent-over-row study was explicitly preliminary and had only three
  participants. Activation cites it on the chest-supported dumbbell-row record
  only for posture/support context; it is not load-bearing evidence for a
  muscle-role change.
- The recent fixed-versus-free scapular study tested a deliberate technique
  constraint. It must not be misread as evidence that an anterior chest pad
  physically pins scapular translation.
- Rhomboid participation is supported by the action map, combined
  middle-trapezius/rhomboid surface EMG, and fine-wire rowing-position work.
  The fine-wire condition used 90-degree shoulder abduction, and the current
  exercise evidence does not isolate rhomboids across all 12 activated variants.
- The existing evidence ID
  `wattanaprakornkul-2011-rotator-cuff-bench-press-and-row` now unambiguously
  names and scopes both tested directions. The horizontal-press reference was
  updated atomically rather than registering a duplicate source.

## Registered evidence IDs

Activation registered these stable IDs:

- `lehman-2004-seated-row-activation`
- `fenwick-2009-row-trunk-loading`
- `saeterbakken-2015-unilateral-row-core`
- `youdas-2016-inverted-row`
- `youdas-2021-suspension-row`
- `fennell-2016-shoulder-retractor-row`
- `vural-2023-suspension-row-loading`
- `padovan-2025-seated-row-grip-width`
- `padovan-2026-seated-row-scapular-position`
- `garcia-jaen-2021-bent-over-row-posture`

Ackland and the renamed Wattanaprakornkul source already exist. The Padovan
scapular-position paper was published online on 2025-12-24 but belongs to the
2026 JFMK volume and is therefore deliberately keyed to the bibliographic issue
year. García-Jaén must be referenced by the chest-supported dumbbell-row record
with its preliminary three-participant limitation in the registry scope;
otherwise it must not be registered because unused evidence fails validation.

## Evidence reviewed

- [Ackland et al. (2008), *Moment arms of the muscles crossing the anatomical
  shoulder*](https://doi.org/10.1111/j.1469-7580.2008.00965.x): anatomical
  capability evidence for latissimus dorsi, teres major, posterior deltoid,
  and cuff actions. It does not rank row variants.
- [Lehman et al. (2004), *Variations in muscle activation levels during
  traditional latissimus dorsi weight training exercises: An experimental
  study*](https://doi.org/10.1186/1476-5918-3-4): twelve trained men; seated
  rows recruited latissimus dorsi, biceps, and a combined middle-trapezius/
  rhomboid site. Its isometric analysis and combined retractor electrode limit
  role separation.
- [Fenwick et al. (2009), *Comparison of different rowing exercises: trunk
  muscle activation and lumbar spine motion, load, and stiffness*](https://doi.org/10.1519/JSC.0b013e3181942019): seven men; inverted, bent-over,
  and one-arm cable rows produced meaningfully different spinal load and trunk
  demands, supporting explicit position and laterality rules.
- [Wattanaprakornkul et al. (2011), *Direction-specific recruitment of rotator
  cuff muscles during bench press and row*](https://doi.org/10.1016/j.jelekin.2011.09.002): fifteen volunteers across 20%, 50%, and 70% maximal load;
  row-specific cuff recruitment supports required subscapularis stabilization
  instead of copying a press rule.
- [Saeterbakken et al. (2015), *The Effect of Performing Bi- and Unilateral Row
  Exercises on Core Muscle Activation*](https://doi.org/10.1055/s-0034-1398646): fifteen trained men; free-weight, seated cable, and machine rows
  performed bilaterally and unilaterally support posture-, equipment-, and
  asymmetry-specific trunk rules.
- [Youdas et al. (2016), *Activation of Spinal Stabilizers and Shoulder Complex
  Muscles During an Inverted Row Using a Portable Pull-up Device and Body
  Weight Resistance*](https://doi.org/10.1519/JSC.0000000000001210): 26
  participants; latissimus dorsi, posterior deltoid, biceps, trapezius, and
  trunk excitation support the inverted-row role envelope, not one universal
  bodyweight fraction.
- [Youdas et al. (2021), *Recruitment of Shoulder Complex and Torso Stabilizer
  Muscles With Rowing Exercises Using a Suspension Strap Training
  System*](https://doi.org/10.1177/1941738120945986): 28 participants; low,
  high, and horizontal-abduction rows produced distinct excitation profiles,
  directly supporting the activated family split.
- [Fennell et al. (2016), *Shoulder Retractor Strengthening Exercise to
  Minimize Rhomboid Muscle Activity and Subacromial
  Impingement*](https://doi.org/10.3138/ptc.2014-83): the study recruited
  twelve participants but reports analyzable fine-wire EMG from eight. It
  confirmed middle-trapezius/rhomboid coactivation in a 90-degree-abducted,
  elbow-flexed rowing position. That posture directly supports the active
  shoulder-height sibling while remaining mismatched to this narrow/tucked
  extension-row family.
- [Vural et al. (2023), *Can different variations of suspension exercises
  provide adequate loads and muscle activations for upper body
  training?*](https://doi.org/10.1371/journal.pone.0291608): twelve male
  athletes; setup- and phase-dependent strap forces support a pinned
  bodyweight-load anchor and warn against treating every inverted-row angle as
  equivalent.
- [Padovan et al. (2025), *High-Density Surface Electromyography Excitation of
  Prime Movers in the Narrow vs. Wide Grip Seated Row
  Exercise*](https://doi.org/10.5114/jhk/209550): fourteen trained men;
  narrow and wide rows produced different latissimus, trapezius, and deltoid
  excitation profiles, supporting the narrow/tucked ownership boundary.
- [Padovan et al. (2026), *High-Density Surface Electromyography Excitation of
  Prime Movers Across Scapular Positions in the Seated
  Row*](https://doi.org/10.3390/jfmk11010006): fourteen trained men; deliberately
  fixed and free scapular techniques produced broadly comparable excitation
  with selected phase/spatial differences. This supports a visible technique
  decision but does not make chest support equivalent to scapular fixation.
- [García-Jaén et al. (2021), *Electromyographical responses of the lumbar,
  dorsal and shoulder musculature during the bent-over row exercise: a
  comparison between standing and bench postures (a preliminary
  study)*](https://doi.org/10.7752/jpes.2021.04236): useful directional support
  for posture and upper-arm-path axes, but only three participants; it is
  explicitly non-load-bearing.

## Review status

All 12 discovery decisions were reviewed and accepted. The family contract,
its 12-exercise coverage roster, and its evidence records are now active
validator input:

1. The explicit `shoulder-extension-row` boundary is active; flared rows now
   route to the active shoulder-horizontal-abduction sibling, while
   overhead-start high-row machines remain a named geometry-review deferral —
   done.
2. Direction is torso-relative, the shoulder basis plane is sagittal, and
   transverse scapular retraction does not create a false shoulder plane —
   done.
3. Dynamic scapular retraction is canonical; deliberately fixed-scapula rows
   remain outside this initial contract — done.
4. `lats` is the sole primary, the required dynamic contributors and
   row-specific cuff policy are enforced, and the rhomboid evidence limitation
   is disclosed — done.
5. The shared grip-width scale, this family's `narrow|shoulderWidth` subset,
   and `tucked|scapular` paths are active; wide/flared rows remain outside —
   done.
6. Bench and machine-pad support reduce trunk demand while leaving
   `scapularTranslation: free` — done.
7. Five equipment classes plus `leverRow|smith` machine mechanisms are active;
   lever rows declare shared `linked|independent` arm configuration while Smith
   rails omit it. T-bar/landmine, kettlebell, band, and suspension-handle rows
   remain out — done.
8. `lowerBodyContribution: none` is enforced; momentum and renegade rows do
   not enter as ordinary variants — done.
9. The fixed-bar inverted row is pinned to `parallelFeetFloor` and a disclosed
   `0.73` authoring anchor — done.
10. Conditional `requireMuscleRequirements` enforces visible unsupported-row
    trunk involvement without forcing one universal trunk muscle — done.
11. The 12-record roster covers every admitted axis value without expanding to
    a Cartesian product — done.
12. All 24 JSON rules have real matching and contrasting exercises. Tests
    independently reject mutations of all 89 enforced consequences, including
    every `then` assertion, presence/absence constraint, exact involvement,
    conditional muscle requirement, and additional stability demand — done.
