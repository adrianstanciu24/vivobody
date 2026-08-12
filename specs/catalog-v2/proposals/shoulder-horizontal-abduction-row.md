# Shoulder-horizontal-abduction row activation record

Status: approved and activated. The enforceable source is
`families/shoulder-horizontal-abduction-row.json`; this document preserves the
evidence limits, ownership reasoning, and reviewed activation decisions.

## Recommended family boundary

Use `shoulder-horizontal-abduction-row` for a strict compound row performed at
shoulder height whose concentric phase combines:

1. glenohumeral horizontal abduction;
2. scapular retraction;
3. elbow flexion; and
4. torso and lower-body resistance without deliberate propulsion.

The family is intentionally narrower than the everyday phrase “high row.” An
overhead-start commercial lever machine may be a diagonal-pull candidate, but
its torso-relative path and humeral actions must be measured; neither an
elevated pivot nor the product name proves shoulder adduction and extension.
`proposals/diagonal-pull.md` records that unresolved candidate, which may still
route to a horizontal row family. Conversely, the exercise that Youdas et al.
call a “horizontal abduction row” keeps the elbow extended. Despite that
paper-specific name, it is mechanically a reverse fly and cannot satisfy this
compound family’s fixed `elbow.flexion` action.

The app-facing family name is **Shoulder-Height Row**. It avoids both
ambiguous alternatives:

- “High Row” is widely used for diagonal, lat-emphasis machines; and
- “Horizontal-Abduction Row” names the straight-arm isolation condition in a
  directly reviewed study.

Exercise names may still use the familiar “rear-delt row” wording. Names and
aliases never decide membership; the authored action signature and variant
geometry do.

## Activated classification

```json
{
  "id": "shoulder-horizontal-abduction-row",
  "name": "Shoulder-Height Row",
  "fixed": {
    "mechanic": "compound",
    "pattern": "pull",
    "direction": "horizontal",
    "planes": ["transverse"]
  },
  "groupPolicy": {
    "default": "shoulders",
    "allowed": ["shoulders"]
  },
  "allowed": {
    "equipment": ["barbell", "dumbbell", "cable", "machine"],
    "modalities": ["dynamicStrength"],
    "trackingModes": ["reps"],
    "loadModes": ["external"],
    "lateralities": ["bilateral", "unilateral"]
  },
  "movementSignature": {
    "planeBasisActions": [
      "shoulder.horizontalAbduction"
    ],
    "primeActions": [
      "shoulder.horizontalAbduction",
      "scapula.retraction",
      "elbow.flexion"
    ],
    "forbiddenPrimeActions": [
      "shoulder.flexion",
      "shoulder.extension",
      "shoulder.abduction",
      "shoulder.adduction",
      "shoulder.horizontalAdduction",
      "shoulder.internalRotation",
      "shoulder.externalRotation",
      "scapula.protraction",
      "scapula.depression",
      "scapula.elevation",
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

`horizontal` is torso-relative resistance direction, as it is in the active
shoulder-extension-row contract. A hip-hinged barbell may travel mostly
vertically in the room while the pull remains horizontal relative to the
torso.

The plane is `transverse` because the sole shoulder basis action is horizontal
abduction. Scapular retraction also happens to be transverse, but it is an
action at a different joint and is not used to manufacture the family plane.
Elbow flexion does not add the elbow’s sagittal plane either.

`shoulder.abduction` is forbidden as a **prime action**, even though the upper
arm is held abducted from the torso. The arm’s shoulder-height position is not
proof that it dynamically abducts during the repetition. That distinction is
why the positional axis is called `upperArmElevationDegrees`: it records
geometry without implying a dynamic shoulder-abduction action.

`shoulder.extension` is forbidden to keep this contract disjoint from
`shoulder-extension-row`. Deliberate `shoulder.externalRotation` is forbidden
to keep a face pull from entering as a name variant. Small three-dimensional
excursions do not become catalog prime actions merely because living joints do
not follow perfect mathematical planes.

Scapular protraction may occur during the eccentric return. Its prohibition
means only that it cannot be authored as a concentric prime action. Scapular
depression is also forbidden as a prime action: Youdas defines the neighboring
low-row endpoint with both retraction and depression, whereas its compound high
row ends with retraction without depression. Without the prohibition, required
secondary `trapeziusLower` could satisfy an exercise-authored depression action
and reopen the low-row boundary. Scapular rotation and tilt remain neither
required nor forbidden because the reviewed EMG data do not establish one
universal angular change across all admitted setups.

## The 60-degree issue: do not hide a mixed plane

Vasconcelos et al. tested pronated-, supinated-, and neutral-grip rows described
as closer to zero degrees, plus separately named 30-, 60-, and 90-degree
upper-arm-abduction conditions. Posterior-deltoid and upper/middle-trapezius
excitation rose toward 60 and 90 degrees, while latissimus excitation and
measured force were greater in the near-zero grip conditions. This is strong
evidence for a continuum, not a biological switch at one catalog boundary.

The current validator gives every exercise in a family the same shoulder
`planeBasisActions`. A 90-degree shoulder-height row can be represented
cleanly as transverse horizontal abduction. A 60-degree row is ambiguous under
that family-wide model and may contain both horizontal-abduction and extension
components, but the reviewed studies did not perform the three-dimensional
joint-action decomposition needed to assign those components precisely.
Vivobody has only the three anatomical planes—there is correctly no `oblique`
plane—so the 60-degree record cannot honestly be placed in either pure family
from the present evidence.

Recommended initial decision:

- keep the activated family at the reviewed 90-degree shoulder-height anchor;
- leave 60-degree rows explicitly deferred as mixed-path rows;
- keep the active extension-row family’s tucked/modest-scapular corridor;
- do not pretend 31, 45, 59, or 60 degrees are established biological cutoffs;
  and
- revisit mixed paths only after the family model can express a per-exercise
  component without falsely applying it to every member.

The required numeric axis therefore uses an exact range:

```json
{
  "id": "upperArmElevationDegrees",
  "valueType": "number",
  "required": true,
  "description": "Upper-arm elevation away from the torso near the concentric endpoint; a position descriptor, not a shoulder-abduction prime action.",
  "minimum": 90,
  "maximum": 90
}
```

The exact 90-degree value is an authoring convention for the canonical setup,
not a claim that a user maintains laboratory precision through every
repetition. It makes the first boundary auditable and prevents a future author
from silently inserting a 60-degree exercise into a pure-transverse contract.

The shoulder-extension-row documentation and shared README record this
handoff. The active sibling’s qualitative `upperArmPath` values were not
retrofitted with invented exact degrees when its exercise studies did not
measure them.

## Activated scapular and support policy

The canonical concentric technique permits the scapulae to retract over the
thorax. Therefore `scapula.retraction` is fixed, and
`scapularTranslation` is initially limited to `free`.

This follows the active row-family support decision:

- a bench or machine pad supports the anterior torso;
- the scapulae remain on the posterior thorax and can translate; and
- `torsoSupport: bench|machinePad` does not imply constrained scapulae.

A deliberately fixed-scapula rehabilitation technique would require a future
contract expansion. Support type alone cannot select that technique or change
a dynamic retractor into a stabilizer.

## Activated muscle policy

| Role | Activated muscles | Contract meaning |
|---|---|---|
| Required primary | `deltoidPosterior` and `trapeziusMiddle` | The family principally emphasizes both defining components: humeral horizontal abduction and scapular retraction. |
| Required secondary | `trapeziusLower`, `rhomboids`, `bicepsBrachii`, `brachialis`, and `brachioradialis` | Meaningful dynamic retraction/force-couple and explicit elbow-flexion contributors without making all prime-action producers primary. |
| Required stabilizer | `trapeziusUpper`, `fingerFlexors`, and `extensorCarpiRadialis` | Scapular control at shoulder height plus explicit hand and wrist control. |
| Optional shoulder stabilizers | `externalRotators`, `supraspinatus`, `subscapularis`, `deltoidLateral` | Direction-, load-, and setup-dependent glenohumeral control; current row evidence does not justify forcing one cuff assignment onto every record. |
| Optional scapular stabilizers | `serratus`, `pectoralisMinor` | Exercise-specific scapular control without declaring protraction, rotation, or tilt as a universal prime action. |
| Conditional trunk/hip stabilizers | `abs`, `obliques`, `lowerBack`, `gluteMax`, `gluteMed`, `medialHamstrings`, `bicepsFemoris` | Required selectively by unsupported, unilateral, and hip-hinged rules. The split hamstring regions preserve hip-versus-knee capability boundaries rather than recreating the retired aggregate. |

Activated required policy shape:

```json
{
  "requirements": [
    {
      "anyOf": ["deltoidPosterior"],
      "minimumRole": "primary"
    },
    {
      "anyOf": ["trapeziusMiddle"],
      "minimumRole": "primary"
    },
    {
      "anyOf": ["trapeziusLower"],
      "minimumRole": "secondary"
    },
    {
      "anyOf": ["rhomboids"],
      "minimumRole": "secondary"
    },
    {
      "anyOf": ["bicepsBrachii"],
      "minimumRole": "secondary"
    },
    {
      "anyOf": ["brachialis"],
      "minimumRole": "secondary"
    },
    {
      "anyOf": ["brachioradialis"],
      "minimumRole": "secondary"
    },
    {
      "anyOf": ["trapeziusUpper"],
      "minimumRole": "stabilizer"
    },
    {
      "anyOf": ["fingerFlexors"],
      "minimumRole": "stabilizer"
    },
    {
      "anyOf": ["extensorCarpiRadialis"],
      "minimumRole": "stabilizer"
    }
  ],
  "allowedByRole": {
    "primary": [
      "deltoidPosterior",
      "trapeziusMiddle"
    ],
    "secondary": [
      "trapeziusLower",
      "rhomboids",
      "bicepsBrachii",
      "brachialis",
      "brachioradialis"
    ],
    "stabilizer": [
      "trapeziusUpper",
      "fingerFlexors",
      "extensorCarpiRadialis",
      "externalRotators",
      "supraspinatus",
      "subscapularis",
      "deltoidLateral",
      "serratus",
      "pectoralisMinor",
      "abs",
      "obliques",
      "lowerBack",
      "gluteMax",
      "gluteMed",
      "medialHamstrings",
      "bicepsFemoris"
    ]
  }
}
```

### Why two primaries

This is the first reviewed family that requires two primary muscles. It is
deliberate, not a side effect of comparing EMG percentages across muscles.
The posterior deltoid produces the defining humeral action, while middle
trapezius produces the defining scapular action; both are principal training
emphases of a strict shoulder-height compound row. The dual-primary choice
expresses training emphasis only; compound status is independently established
by the fixed mechanic and multi-joint action signature.

The family still defaults to the `shoulders` app group because the humeral
horizontal-abduction component distinguishes it from the existing back-group
row. Every record carries posterior deltoid as a primary, so the normal
group/primary invariant remains true. Middle trapezius remains primary-only;
it is not duplicated under secondary to make authoring permissive.

This has a visible product consequence: every activated shoulder-height row
will appear under **Shoulders**, not **Back**, in the exercise library even
though its name contains “row” and middle trapezius is also primary. That is
the activated classification, not an incidental validator outcome. Supporting
discovery under both groups would require an explicit product/taxonomy change;
per-exercise group overrides should not quietly split one family.

Lower trapezius is not promoted solely because Youdas reported similarly high
normalized excitation. Cross-muscle surface-EMG percentages do not provide a
universal force or hypertrophy ranking. It remains a required dynamic
secondary because it can produce the declared retraction and participates in
the shoulder-height scapular force couple.

### Cuff decision

The anatomy map allows `externalRotators` to produce horizontal abduction, and
Sakaki et al. found direction-sensitive infraspinatus activity during
controlled horizontal abduction. That experiment was not a loaded compound
row. Youdas lists all 13 measured muscles; the panel contains no rotator-cuff
muscle. Wattanaprakornkul directly measured cuff recruitment, but its row was
explicitly extension-like rather than this shoulder-height path.

Therefore `externalRotators` is an **optional stabilizer**, not a
required secondary and not a copied mandatory cuff rule. The same conservative
logic keeps supraspinatus and subscapularis optional. Activation can tighten
this only if a condition-matched loaded-row source is found.

### Lats, teres major, and upper trapezius

`lats` and `teresMajor` are deliberately excluded from **all three authored
roles** in this first contract. Their independent action profiles emphasize
extension and adduction rather than horizontal abduction, latissimus excitation
fell markedly in the shoulder-height/high-row conditions, and the reviewed
sources do not identify either muscle as a principal stabilizer of this exact
setup. The exclusion keeps the contract tight; it is not a claim of literally
zero activation or anatomical incapability.

Upper trapezius is a stabilizer despite its high excitation. The full Youdas
article explicitly interprets its high-row role as scapular stabilization and
resistance to posterior-deltoid-driven downward rotation; it similarly says
middle trapezius both stabilized and retracted the scapula. High EMG alone does
not redefine the movement’s prime actions.

## Activated variant axes

- `kineticChain`: required and initially limited to `open`.
- `bodyPosition`: required `hipHinged|seated|prone`.
- `lowerBodySupport`: required and initially limited to `none`, retaining the
  shared definition of lower-body contact that materially changes effective
  bodyweight loading.
- `torsoSupport`: required `none|bench|machinePad`.
- `scapularTranslation`: required and initially limited to `free`.
- `gripOrientation`: required `pronated|neutral`.
- `relativeGripWidth`: optional `wide`; present for bilateral records and
  absent for unilateral records. It measures working-hand spacing at the
  canonical concentric endpoint, so the independent dumbbells stay beneath
  the flared elbows instead of converging merely to cover another enum value.
- `upperArmPath`: required and initially limited to `flared`.
- `upperArmElevationDegrees`: required numeric value pinned to `90` as defined
  above.
- `fixedPath`: required boolean using the existing external-load definition.
- `machineType`: optional and initially limited to `leverRow`.
- `leverArmConfiguration`: optional `linked|independent`, required on machine
  records and absent elsewhere. A linked machine cannot be authored
  unilaterally.
- `lowerBodyContribution`: required and initially limited to `none`.
- `interRepSupport`: required and initially limited to `none`.
- `contralateralSupport`: required and initially limited to `none`.

The single-value axes are contract constraints, not always-true exercise rules.
Every JSON exercise rule needs a real predicate plus both a matching and a
contrasting roster record.

`upperArmPath: flared` and `upperArmElevationDegrees: 90` are related but not
interchangeable. `flared` is a deliberate **new** value that extends the row
vocabulary beyond the sibling’s `tucked|scapular` subset; it is not already
shared vocabulary. The numeric axis makes this initial family’s exact
plane-model boundary machine-checkable. Grip width does neither job.

## Activated cross-field rules

The following rule IDs are active. Each has a real branch in the roster.

1. `machine-requires-fixed-path-and-type`: machine equipment requires
   `fixedPath: true`, `machineType`, and `leverArmConfiguration`.
2. `non-machine-requires-free-path`: every non-machine record requires
   `fixedPath: false` and omits both machine-only axes.
3. `lever-row-is-supported-seated`: `machineType: leverRow` requires machine
   equipment, `seated`, `machinePad`, and no contralateral support.
4. `barbell-is-bilateral-unsupported-hip-hinged`: barbell equipment requires
   bilateral laterality, `hipHinged`, no torso support, pronated grip, wide
   grip, and a free path.
5. `dumbbell-is-bilateral-prone-bench-supported`: dumbbell equipment requires
   bilateral laterality, `prone`, bench support, neutral grip, concentric
   `wide` hand spacing, and a free path.
6. `cable-is-unsupported-seated-free-path`: cable equipment requires `seated`,
   no torso support, `pronated|neutral`, and a free path.
7. `prone-is-supported-bilateral-dumbbell`: `bodyPosition: prone` requires
   bilateral dumbbell equipment and bench support.
8. `bench-support-requires-prone-dumbbell`: `torsoSupport: bench` requires
   bilateral dumbbell equipment and `prone`.
9. `machine-pad-requires-lever-row`: `torsoSupport: machinePad` requires
   machine equipment, `machineType: leverRow`, and `seated`.
10. `bilateral-requires-grip-width`: bilateral records require
    `relativeGripWidth`.
11. `unilateral-requires-asymmetric-control`: unilateral records are limited
    to cable or machine equipment, omit `relativeGripWidth`, add a `pelvis`
    stability demand, and assign `obliques` as a stabilizer. The machine branch
    remains `leverRow` through rules 1 and 3 and must use an independent lever
    arm because rule 14 rejects linked unilateral machinery.
12. `hip-hinged-requires-posterior-chain-stability`:
    `bodyPosition: hipHinged` adds `spine`, `pelvis`, and `hip` stability
    demands and assigns `lowerBack` and `gluteMax` as stabilizers.
13. `unsupported-requires-trunk-stability`: `torsoSupport: none` adds a `spine`
    demand and assigns at least one of `abs`, `obliques`, or `lowerBack` as a
    stabilizer through `requireMuscleRequirements`.
14. `linked-lever-arms-are-bilateral`: a linked left/right machine lever
    requires machine equipment and bilateral laterality.

Rule 13 is independently load-bearing on the bilateral seated cable record;
the hip-hinged record already receives lower-back stabilization from rule 12,
and unilateral cable receives obliques from rule 11. Its mutation test targets
the bilateral cable record explicitly rather than relying on exercise-array
order.

## Activated roster

The initial roster includes the useful bilateral and unilateral variants in one
reviewed activation rather than growing one fixture at a time:

| Catalog exercise | Equipment / laterality | Position and support | Grip / width | Path | Evidence status |
|---|---|---|---|---|---|
| Wide-Grip Barbell Rear-Delt Row | Barbell / bilateral | Hip-hinged / none | Pronated / wide | Free, 90° | Mechanics-derived from the action boundary. |
| Chest-Supported Dumbbell Rear-Delt Row | Dumbbell / bilateral | Prone / bench | Neutral / wide at endpoint | Free, 90° | Mechanics-derived; Fennell supports the posture/action but not a dynamic dumbbell set. |
| Wide-Grip Seated Cable Rear-Delt Row | Cable / bilateral | Seated / none | Pronated / wide | Free, 90° | Direct 90° cable-path anchor; the categorical `wide` value and exact catalog grip implementation are mechanics-derived. |
| Single-Arm Seated Cable Rear-Delt Row | Cable / unilateral | Seated / none | Neutral / width absent | Free, 90° | Mechanics-derived unilateral branch. |
| Chest-Supported Machine Rear-Delt Row | Machine / bilateral | Seated / machine pad | Pronated / wide | Fixed linked lever, 90° | Mechanics-derived mechanism branch. |
| Single-Arm Chest-Supported Machine Rear-Delt Row | Machine / unilateral | Seated / machine pad | Neutral / width absent | Fixed independent lever, 90° | Mechanics-derived unilateral/fixed-path interaction. |

These six records cover every admitted equipment class, laterality, body
position, torso-support value, grip orientation, fixed-path value, machine-type
presence state, and linked/independent lever configurations. They are a useful
catalog roster, not a Cartesian product.

The two unilateral records are intentionally included because they are
distinct searchable movements and exercise the asymmetric-control contract.
No reviewed study directly tested them. Activation accepts that disclosed
mechanics inference; both remain candidates for removal together if future
evidence contradicts the modeled asymmetric-control branch.

### Global name and alias uniqueness

The active shoulder-extension row already owns generic aliases including
`Cable Row`, `Single-Arm Cable Row`, `Machine Row`, `Seated Machine Row`, and
their one-arm equivalents. This family must not reuse them. The activation
uses these collision-resistant aliases and validates the entire family set
together:

| Canonical exercise | Activated aliases |
|---|---|
| Wide-Grip Barbell Rear-Delt Row | `Barbell Rear-Delt Row`, `Wide-Grip Barbell High Row` |
| Chest-Supported Dumbbell Rear-Delt Row | `Dumbbell Rear-Delt Row`, `Chest-Supported Dumbbell High Row` |
| Wide-Grip Seated Cable Rear-Delt Row | `Cable Rear-Delt Row`, `Wide-Grip Cable High Row` |
| Single-Arm Seated Cable Rear-Delt Row | `Single-Arm Cable Rear-Delt Row`, `One-Arm Cable Rear-Delt Row` |
| Chest-Supported Machine Rear-Delt Row | `Machine Rear-Delt Row`, `Chest-Supported Machine High Row` |
| Single-Arm Chest-Supported Machine Rear-Delt Row | `Single-Arm Machine Rear-Delt Row`, `One-Arm Machine Rear-Delt Row` |

This activated set has no normalized collision with any active family name or
alias. Whole-family-set validation keeps that invariant mandatory as the
catalog grows.

Do not add bare `High Row`, `Cable Row`, or `Machine Row`. Besides colliding or
being overly broad, they erase the family boundary. Activation tests assert
both global normalized-name uniqueness and the exact reviewed alias sets so a
later convenience alias cannot silently collide with another family.

## Activated ownership and exclusions

| Candidate | Decision | Reason |
|---|---|---|
| Strict shoulder-height wide cable row with dynamic elbow flexion | Own | Directly matches the 90-degree transverse compound signature. |
| Shoulder-height barbell rear-delt row | Own | Same signature; free-weight implementation is mechanics-derived. |
| Chest-supported dumbbell rear-delt row | Own | Same signature with anterior torso support and free scapular translation. |
| Horizontal-path lever rear-delt row | Own | Same signature with a guided external path. |
| Single-arm cable or lever rear-delt row | Own with disclosure | Same upper-body signature plus asymmetric trunk/pelvic control; no condition-matched study. |
| Suspension high row with elbow flexion | Defer | Mechanically belongs, but the reviewed setup does not establish a transferable effective-bodyweight fraction. |
| Suspension “horizontal abduction row” with straight elbows | Exclude | No dynamic elbow flexion; future reverse-fly/isolation family. |
| Dumbbell reverse fly or reverse pec deck | Exclude | Elbow angle remains essentially fixed; future shoulder-horizontal-abduction isolation family. |
| Rope face pull with deliberate external rotation | Exclude | Adds a forbidden shoulder external-rotation prime action. A face-height row without deliberate rotation is routed by its actual path, not its name. |
| 60-degree flared cable row | Defer | Directly studied but mechanically mixed under the current family-wide exact-plane model. |
| Overhead-start plate-loaded “high row” | Defer; candidate pending geometry review | `proposals/diagonal-pull.md` must first establish a distinct torso-relative path and humeral actions; ownership is not settled. |
| Upright row | Exclude | Vertical/frontal shoulder-abduction and scapular-elevation signature. |
| T-bar, landmine, or pivoting high row | Defer | A room-space pivot arc does not establish diagonal torso-relative travel or shoulder adduction; route only after direct path review. |
| One-arm dumbbell rear-delt row | Defer | Valid candidate, but requires a reviewed free-weight support branch beyond the compact initial roster. |
| Bilateral bent-over dumbbell rear-delt row | Defer | The active dumbbell branch is deliberately prone and bench-supported; unsupported bilateral dumbbells need separate trunk and path review. |
| Standing cable rear-delt row | Defer | The active cable branch is seated; standing changes trunk and lower-body control without a reviewed fixture. |
| Chest-supported barbell rear-delt row | Defer | The active barbell branch is unsupported and hip-hinged; a bench-supported bar path needs its own setup review. |
| Kipping, cheat, or momentum high row | Exclude | Hip, spine, or lower-body propulsion is part of the repetition. |

The suspension high row must not inherit the active inverted row’s `0.73`
bodyweight fraction. That anchor belongs to a different geometry and distal
setup. A missing load estimate is a reason to defer the record, not to guess.

## Evidence limitations and taxonomy gaps

- EMG describes excitation under tested conditions. It does not directly
  measure muscle force, hypertrophy, or a universal primary/secondary ranking.
- Vasconcelos provides the strongest direct angle comparison, but grip/path
  conditions and loading choices limit causal isolation. It directly anchors
  the 90-degree cable path, not an independently manipulated `wide` catalog
  value. Its continuum must not be rewritten as a biological 90-degree
  threshold.
- Youdas directly matches the activated signature: its high-row endpoint uses
  90-degree horizontal abduction, 90-degree elbow flexion, and scapular
  retraction, while its separately named horizontal-abduction row keeps the
  elbow extended. It remains one 45-degree-body-angle suspension setup, and its
  published 13-muscle panel includes neither rhomboids nor any rotator-cuff
  muscle.
- Youdas found substantial upper-thoracic erector excitation. Vivobody’s
  `lowerBack` is the lumbar-extensor region, so that result must not be relabeled
  as `lowerBack`. The current 41-muscle taxonomy still cannot represent thoracic
  erectors separately. This is disclosed rather than hidden by a false mapping.
- Fennell recruited twelve people but reports complete, usable data from only
  eight. Its fine-wire row position supports rhomboid/middle-trapezius
  coactivation at 90 degrees, not dynamic loading across the activated roster.
- Kara supports angle-sensitive **upper- and middle-trapezius** excitation
  during scapular retraction, but not a 90-degree lower-trapezius increase: LT
  changed only modestly from 21.4% MVIC at 0 degrees to 25.2% at 90 degrees,
  was lower than UT and MT at 90 degrees, and only the 0-versus-120 comparison
  reached significance. Its elastic-band rehabilitation conditions are not
  equivalent to heavy rows, and its 120-degree “high row” condition is
  diagonal/overhead rather than evidence for this family. Required
  `trapeziusLower` therefore rests on Youdas plus the independent action map,
  not Kara.
- Sakaki supports admitting cuff involvement during horizontal abduction, but
  the controlled shoulder motion was not a loaded compound row; it cannot make
  one cuff role mandatory.
- Padovan supports a wide-versus-narrow shift toward trapezius and lateral-delt
  excitation and away from lat emphasis. Posterior-delt amplitude did not
  meaningfully differ, so the paper must not be cited as proof that grip width
  alone switches posterior deltoid on.
- Barbell, dumbbell, lever-machine, and both unilateral records are
  mechanics-derived fixtures. The proposal says so instead of laundering the
  cable and suspension evidence across equipment.
- A chest pad reduces trunk demand but does not pin scapular translation.

## Registered evidence IDs

Reuse the existing IDs:

- `ackland-2008-shoulder-moment-arms`
- `fennell-2016-shoulder-retractor-row`
- `padovan-2025-seated-row-grip-width`
- `wattanaprakornkul-2011-rotator-cuff-bench-press-and-row`
- `youdas-2021-suspension-row`

The activation registered these new IDs:

- `vasconcelos-2023-seated-row-abduction-angle`
- `kara-2021-scapular-retraction-abduction-angle`
- `sakaki-2013-shoulder-movement-direction-emg`

Unused registered evidence fails coverage validation, so discovery must not add
these records to `evidence.json` early.

## Evidence reviewed

- [Vasconcelos et al. (2023), *Effect Of Different Grip Position And
  Shoulder-Abduction Angle On Muscle Strength And Activation During The Seated
  Cable Row*](https://doi.org/10.47206/ijsc.v3i1.190): eleven men and ten women
  performed cable-row conditions including 30, 60, and 90 degrees of upper-arm
  abduction. Excitation shifted toward upper/middle trapezius and posterior
  deltoid as the angle increased, while latissimus excitation and force were
  greater nearer zero.
- [Youdas et al. (2021), *Recruitment of Shoulder Complex and Torso Stabilizer
  Muscles With Rowing Exercises Using a Suspension Strap Training
  System*](https://doi.org/10.1177/1941738120945986): 28 participants performed
  low, high, and straight-arm horizontal-abduction rows. Its high-row endpoint
  exactly combines 90-degree horizontal abduction, 90-degree elbow flexion, and
  scapular retraction; its separately named horizontal-abduction row uses the
  same shoulder/scapular endpoint with the elbow extended. The 13-muscle panel
  did not include rhomboids or a rotator-cuff muscle.
- [Padovan et al. (2025), *High-Density Surface Electromyography Excitation of
  Prime Movers in the Narrow vs. Wide Grip Seated Row
  Exercise*](https://doi.org/10.5114/jhk/209550): 14 trained men performed 8RM
  narrow and wide cable rows. The wide setup increased upper/middle/lower
  trapezius and lateral-delt excitation, while the narrow setup increased
  latissimus excitation; grip, pull target, and humeral path covaried.
- [Fennell et al. (2016), *Shoulder Retractor Strengthening Exercise to
  Minimize Rhomboid Muscle Activity and Subacromial
  Impingement*](https://doi.org/10.3138/ptc.2014-83): twelve recruited and eight
  analyzed participants; fine-wire EMG confirms middle-trapezius and rhomboid
  coactivation in a 90-degree-abducted, elbow-flexed rowing position.
- [Kara et al. (2021), *Shoulder-Abduction Angle and Trapezius Muscle Activity
  During Scapular-Retraction Exercise*](https://doi.org/10.4085/1062-6050-0053.21):
  35 asymptomatic participants performed resisted retraction at 0, 45, 90, and
  120 degrees. Upper- and middle-trapezius activity peaked at 90 degrees, while
  lower trapezius did not differ significantly between 0 and 90 degrees and
  was lower than both at 90 degrees. The study neither establishes the required
  LT role nor licenses a 120-degree transverse row.
- [Wattanaprakornkul et al. (2011), *Direction-specific recruitment of rotator
  cuff muscles during bench press and row*](https://doi.org/10.1016/j.jelekin.2011.09.002):
  15 volunteers performed flexion-like bench press and extension-like row tasks
  at 20%, 50%, and 70% of maximal load. It directly supports direction-specific
  cuff stabilization but is not condition-matched evidence for this
  shoulder-height horizontal-abduction row.
- [Sakaki et al. (2013), *Effects of different movement directions on
  electromyography recorded from the shoulder muscles while passing the target
  positions*](https://doi.org/10.1016/j.jelekin.2013.08.010): fine-wire
  supraspinatus plus surface infraspinatus/deltoid EMG in 15 healthy men
  supports direction-dependent cuff involvement during horizontal abduction,
  not a mandatory role in loaded rows.
- [Ackland et al. (2008), *Moment arms of the muscles crossing the anatomical
  shoulder*](https://doi.org/10.1111/j.1469-7580.2008.00965.x): independent
  anatomical capability evidence for posterior deltoid and cuff actions. It
  does not rank row variants or exercise roles.

## Review status

All activation gates are closed:

1. The stable ID, display name, strict three-action signature, transverse
   basis, exact 90-degree authoring convention, dual-primary emphasis, and
   **Shoulders** product grouping are active.
2. Six exercises cover the reviewed equipment, support, grip, laterality, and
   path surface. The five non-direct anchors—four non-cable records plus the
   unilateral cable row—remain explicitly disclosed as mechanics-derived
   rather than condition-matched.
3. Activation review tightened bilateral grip width to endpoint `wide`, renamed
   the positional angle to `upperArmElevationDegrees`, and added
   `leverArmConfiguration` to both row families so a linked machine cannot
   validate as unilateral while Smith rails remain explicitly outside that
   lever-only axis.
4. The three new evidence records are registered; Fennell and Padovan scopes
   now describe the sibling-family boundary without laundering evidence across
   setups.
5. The shared READMEs and shoulder-extension-row proposal record the active
   handoff. Suspension, 60-degree mixed paths, diagonal high rows, reverse
   flies, face pulls, and the additional unsupported/support variants remain
   named deferrals or exclusions.
6. Exact roster, axis coverage, global alias uniqueness, every rule branch,
   every rule consequence, and the important biomechanical boundary mutations
   are enforced in `Scripts/tests/test_catalog_v2.py`.
