# Batch 7 proposal — farmer and suitcase carries

Status: active as the two one-record contracts
`families/farmer-carry.json` and `families/suitcase-carry.json`, with the
resisted-action foundation and all three evidence records landed atomically.

## Decision

Activate two narrow duration-tracked dumbbell families:

1. `farmer-carry` owns `two-dumbbell-farmer-carry` — equal loads held at
   both sides;
2. `suitcase-carry` owns `single-dumbbell-suitcase-carry` — one load held at
   the right side in the reviewed source, authored as a unilateral exercise
   that the product logs per side.

The shared loaded-grip and walking substrate does not justify one family
contract. Family planes are app-level classification, not merely a validator
basis. Farmer carriage is sagittal because its defining resisted basis is
`hand.fingerExtension`; suitcase carriage is frontal because its
distinguishing resisted basis is `spine.lateralFlexion`. Keeping both in a
sagittal family would make the suitcase record's visible classification false.
The split makes both plane labels truthful without adding a non-anatomical
"oblique" plane or pretending every resisted action belongs to one plane.

Do not admit front-rack, overhead, bottoms-up, offset-pair, yoke, trap-bar,
Zercher, sandbag, waiter, marching-in-place, backward, stair, incline, turn,
hold-only, strapped, or conditioning-circuit variants in this activation.

## Classification and resisted-action model

Both contracts fix:

- `mechanic: compound`;
- `pattern: carry`;
- `direction: null`, because forward travel is not a joint-action direction;
- `primeActions: []`;
- `modality: isometricStrength`;
- `trackingMode: duration`;
- `equipment: dumbbell`.

### `farmer-carry`

The bilateral family fixes:

- `planes: [sagittal]`;
- `planeBasisActions: [hand.fingerExtension]`;
- `resistedActions: [hand.fingerExtension]`;
- `laterality: bilateral`;
- `group: arms`.

`hand.fingerExtension` names the external tendency of each freely hanging
implement to open the grasp. The central opposition map therefore requires
`fingerFlexors` as primary through their `hand.fingerFlexion` capability.
This does not claim dynamic finger-closing repetitions.

### `suitcase-carry`

The unilateral family fixes:

- `planes: [frontal]`;
- `planeBasisActions: [spine.lateralFlexion]`;
- `resistedActions: [hand.fingerExtension, spine.lateralFlexion]`;
- `laterality: unilateral`;
- `group: core`.

The side-held load creates a frontal-plane spinal lateral-flexion tendency.
`obliques` is primary and `quadratusLumborum` secondary through the current
direction-aggregated action model; the contract does not claim dynamic side
bending or side-specific muscle credit. The same implement also resists finger
extension, so `fingerFlexors` remains secondary.

The hand action is sagittal while this family plane is frontal. That is
intentional: `planeBasisActions` selects the family-defining spinal action,
and the resisted hand action retains its own anatomical plane at another joint.
The app-level family plane therefore describes the suitcase carry's
distinguishing trunk demand rather than falsely labeling it sagittal.

Neither family admits or authors exercise-level additional resisted actions. No
conditional exercise rule is needed: the one-record families own their complete
resisted signatures directly. The split leaves no active consumer for the
exercise-level resisted-action-delta API, so that schema and validator surface
can be removed rather than retained speculatively.

Walking necessarily contains cyclic lower-limb joint motion, but it is the
locomotor substrate of these duration-tracked loaded tasks. Neither family
promotes ordinary gait phases to training-defining `primeActions`. All 44
dynamic actions are forbidden as per-exercise prime additions; that is a scope
statement, not a claim that the athlete's joints are motionless.

## Roster

| Family | Exercise | Direct anchor | Deliberate limitation |
|---|---|---|---|
| `farmer-carry` | Two-Dumbbell Farmer Carry | Ellestad et al. used two equally weighted dumbbells over 25 m; Stastny et al. used dumbbells over 8 m; McGill et al. directly compared evenly split two-hand carriage with one-hand carriage. | Product duration and seed are catalog defaults, not a claim that 40 seconds or 60 lb reproduced any one protocol. |
| `suitcase-carry` | Single-Dumbbell Suitcase Carry | Ellestad et al. used one right-hand dumbbell over 25 m; McGill et al. used one right-hand bucket and measured bilateral trunk EMG, 3-D kinematics, forces, and modeled spinal load. | Product laterality means train/log both sides. The studies' right-side condition does not justify side-specific muscle highlighting. |

Ellestad matched the total bilateral load to the forearm-supported mass measured
during a plank and split it evenly between dumbbells; the unilateral load was
half that total. This supports the paired-versus-single topology, not a fixed
percentage prescription. McGill tested 5–30 kg per bucket under several one-
and two-hand comparisons. Stastny used 75 percent of each participant's
six-repetition-maximum carry. None of those protocols establishes the catalog's
starter scrubber values as evidence-based prescriptions.

The active records use clean-slate identities rather than importing the
shipped catalog IDs, names, or alias lists. Their identities and conservative
clean detents are:

- `two-dumbbell-farmer-carry`, **Two-Dumbbell Farmer Carry**, aliases
  **Bilateral Dumbbell Farmer Carry** and **Two-Dumbbell Farmer Walk**:
  60 lb / 27.5 kg **per dumbbell**, 40 seconds;
- `single-dumbbell-suitcase-carry`, **Single-Dumbbell Suitcase Carry**,
  aliases **Unilateral Dumbbell Suitcase Carry** and **Single-Dumbbell
  Suitcase Walk**: 50 lb / 22.5 kg for the single dumbbell, 40 seconds.

`loadAccounting: perImplement` makes the product semantics explicit: farmer
carry logs either equal dumbbell rather than the combined pair, while suitcase
carry logs its single side-held dumbbell. This preserves the per-implement
scrubber convention and prevents a two-times load ambiguity in farmer-carry
history and PR analytics.

## Muscle policy

### Shared loaded-grip and whole-body control

Both families require `fingerFlexors` at least secondary because they supply
the action opposing resisted finger extension. They are primary in
`farmer-carry`, preserving that record's grip-emphasis product placement, and
secondary in `suitcase-carry`, where the frontal trunk resistance defines the
primary emphasis.

The following assignments are stabilizers:

- `extensorCarpiRadialis`: neutral-wrist counter-control under the loaded grip;
- `trapeziusUpper`: scapular control under the downward hand load;
- `externalRotators`: glenohumeral control with the arm held beside the torso;
- `triceps`: held-elbow control;
- `abs`: trunk control;
- `gluteMed`: pelvis/hip control;
- `vasti`: knee-region control;
- `soleus`: anatomy/mechanics-derived ankle-and-foot control during loaded
  walking, not a plantarflexion training prime.

The scapula, shoulder, elbow, wrist, hand, spine, pelvis, hip, knee, ankle, and
foot are materially load-bearing or control-defining. `forearm` is not
declared as a stability region: the neutral forearm orientation is a held
posture, and the reviewed sources do not justify selecting one
pronator/supinator region as a categorical stabilizer.

### Farmer carry

`fingerFlexors` is the sole primary. `abs`, `obliques`, and `lumbarExtensors`
remain stabilizers because this family declares no directional spinal resisted
action. Ellestad directly measured rectus abdominis, external oblique,
longissimus, and multifidus. The posterior stabilizer assignment is therefore
made to the explicitly unvisualized erector-spinae/multifidus region, not to
visible quadratus lumborum or posterior serratus.

### Suitcase carry

`obliques` is primary and `quadratusLumborum` secondary for resisted
`spine.lateralFlexion`; `fingerFlexors` is secondary and `lumbarExtensors` is
a stabilizer. McGill measured both
internal and external obliques plus lumbar/thoracic erector spinae and found
greater torso activation and modeled spinal loading under asymmetric carriage.
Ellestad found a distinct unilateral trunk-activation pattern but did not prove
a universal loaded-side/contralateral hierarchy. Side-specific credit is
therefore forbidden.

The whole visible `obliques` region combines internal and external obliques.
Visible QL credit follows the resisted lateral-flexion action; the separate
unvisualized lumbar-extensor stabilizer is anchored by the measured posterior
panel. Those independent rationales must not be recast as side-specific
evidence or combined into duplicate group volume.

## Variant axes

Both contracts require the same posture and product axes:

| Axis | Farmer value | Suitcase value | Meaning |
|---|---|---|---|
| `kineticChain` | `closed` | `closed` | Ground-supported locomotion. |
| `bodyPosition` | `standing` | `standing` | Upright loaded walking. |
| `upperArmPosition` | `atSide` | `atSide` | Side-held humerus; rack, front-loaded, and overhead topologies are excluded. |
| `humeralRotation` | `neutral` | `neutral` | Neutral humeral posture independent from forearm vocabulary. |
| `carryPath` | `continuousForwardWalk` | `continuousForwardWalk` | Forward level walking; no backward, turning, incline, stair, or march-only branch. |
| `loadSymmetry` | `balancedBilateral` | `unilateral` | Equal paired implements versus one side-held implement. |
| `gripAssistance` | `none` | `none` | No lifting straps or hook assistance. |
| `elbowMotion` | `angleHeld` | `angleHeld` | No deliberate elbow repetition. |
| `elbowPosture` | `extended` | `extended` | The load remains beside the torso rather than in a rack. |
| `forearmMotion` | `angleHeld` | `angleHeld` | No deliberate pronation or supination repetition. |
| `forearmOrientation` | `neutral` | `neutral` | Neutral forearm orientation independent from grip naming. |
| `handTask` | `staticImplementHold` | `staticImplementHold` | Static handle task with resisted finger opening. |
| `loadAccounting` | `perImplement` | `perImplement` | Farmer logs either equal dumbbell rather than the pair total; suitcase logs its single dumbbell. |
| `spineMotion` | `nonstandardized` | `nonstandardized` | Upright control is instructed without falsely claiming zero gait-related motion. |
| `lowerBodyContribution` | `walkingPropulsion` | `walkingPropulsion` | Ordinary gait propulsion is not a family prime action. |
| `fixedPath` | `false`, fixed | `false`, fixed | Neither body nor external load is rail- or lever-guided. |

The family-level laterality and the single-value `loadSymmetry` axes pin each
reviewed topology directly. Unequal paired carries remain excluded rather than
being admitted through a conditional cross-record rule.

## Exercise rules

Neither family has exercise rules. Every invariant is family-level or encoded by
a required single-value axis, and each one-record muscle policy directly pins
the reviewed role hierarchy. This avoids an always-true rule with no contrasting
fixture and removes the old cross-record dependency.

## Boundaries

| Candidate | Decision | Reason |
|---|---|---|
| Farmer hold / suitcase hold | Defer | Removes locomotion and has a different activation profile in Ellestad. |
| Suitcase march | Defer | Marching-in-place is not the reviewed continuous forward path. |
| Backward farmer carry | Defer | Walking direction changes the task and is not in the active evidence. |
| Trap-bar farmer carry | Defer | Different implement geometry and hand position. |
| Strapped farmer carry | Defer | Removes the universal unassisted loaded-grip contract. |
| Offset bilateral carry | Defer | Needs its own asymmetric-load and frontal-resistance contract. |
| Rack / waiter / overhead carry | Defer | Changes shoulder, elbow, scapular, spinal, and plane demands. |
| Zercher / bear-hug / front carry | Defer | Changes load placement and sagittal trunk moment. |
| Yoke carry | Defer | Axial shoulder-borne load and no loaded hand grip. |
| Walking lunge with dumbbells | Exclude | The lunge repetition, not the carry, defines the exercise. |
| Ordinary walking with a backpack | Exclude | No hand-held grip and a different load-placement family. |

Later follow-up: the conventional closed-frame high-handle trap-bar fixture is
now active under
[`default-candidate-follow-up-2026-08.md`](default-candidate-follow-up-2026-08.md).
Other trap-bar geometries and low-handle carry histories remain outside that
source-bounded branch.

## Evidence registration payload

Register these sources only in the same change that activates the family.

### `ellestad-2024-loaded-carry-muscle-activation`

```json
{
  "id": "ellestad-2024-loaded-carry-muscle-activation",
  "sourceType": "experimentalEMGStudy",
  "title": "The Quantification of Muscle Activation During the Loaded Carry Movement Pattern",
  "authors": [
    "Samuel H. Ellestad",
    "Thomas P. Holcomb",
    "Alexis M. Swiergol",
    "Michael E. Holmstrup",
    "Jeremy R. Dicus"
  ],
  "year": 2024,
  "doi": "10.70252/NWUE9985",
  "pmid": "38665162",
  "url": "https://doi.org/10.70252/NWUE9985",
  "scope": "Healthy college-aged participants completed randomized, time- and intensity-matched plank, farmer-carry, suitcase-carry, farmer-hold, and suitcase-hold conditions. The carries covered 25 meters with two equally weighted dumbbells bilaterally or one right-hand dumbbell unilaterally; rectus abdominis, external oblique, longissimus, and multifidus surface EMG was measured bilaterally. It directly supports the carry-versus-hold boundary, paired-versus-single dumbbell topology, and categorical trunk-control envelope, but not side-specific product highlighting, lower-limb roles, a universal external-load percentage, or the catalog duration and weight seeds."
}
```

### `mcgill-2013-one-two-hand-carry`

```json
{
  "id": "mcgill-2013-one-two-hand-carry",
  "sourceType": "experimentalKinematicsEMGModelStudy",
  "title": "Low back loads while walking and carrying: comparing the load carried in one hand or in both hands",
  "authors": [
    "Stuart M. McGill",
    "Leigh Marshall",
    "Jordan Andersen"
  ],
  "year": 2013,
  "doi": "10.1080/00140139.2012.752528",
  "pmid": "23384188",
  "url": "https://doi.org/10.1080/00140139.2012.752528",
  "scope": "Six healthy men with complete data walked while carrying 5-to-30-kilogram buckets either in the right hand or evenly across both hands. Bilateral rectus-abdominis, internal- and external-oblique, latissimus, thoracic-erector, and lumbar-erector EMG, full-body three-dimensional kinematics, force plates, and an anatomically detailed lumbar model directly establish the one-versus-two-hand loading distinction and greater asymmetric trunk demand. The source does not support dumbbell-specific upper-limb roles, side-specific catalog highlighting, duration seeds, or a claim that gait-related spinal motion is absent."
}
```

### `stastny-2015-farmers-walk-lower-limb`

```json
{
  "id": "stastny-2015-farmers-walk-lower-limb",
  "sourceType": "experimentalKinematicsEMGStudy",
  "title": "The Gluteus Medius Vs. Thigh Muscles Strength Ratio and Their Relation to Electromyography Amplitude During a Farmer's Walk Exercise",
  "authors": [
    "Petr Stastny",
    "Michal Lehnert",
    "Amr Zaatar",
    "Zdenek Svoboda",
    "Zuzana Xaverova",
    "Przemysław Pietraszewski"
  ],
  "year": 2015,
  "doi": "10.1515/hukin-2015-0016",
  "pmid": "25964819",
  "url": "https://doi.org/10.1515/hukin-2015-0016",
  "scope": "Sixteen resistance-trained men completed 8-meter dumbbell farmer-walk trials; the analyzed condition used 75 percent of each participant's six-repetition-maximum load, upright-trunk and retracted-shoulder instructions, and natural lower-limb technique. Bilateral gluteus-medius, vastus-medialis, vastus-lateralis, and biceps-femoris surface EMG plus hip-and-knee three-dimensional kinematics support the bilateral dumbbell fixture and categorical gluteus-medius and knee-control envelope. The study measured only four muscles, stratified activation by strength ratios, and does not establish suitcase roles, fixed gait technique, or catalog load and duration seeds."
}
```

## Activation tests

Activation requires:

1. exact `farmer-carry` and `suitcase-carry` IDs, classifications, evidence,
   one-record rosters, names, aliases, definitions, seeds, and durations;
2. exact empty prime-action lists and exact family-owned resisted signatures;
3. sagittal farmer plane/basis exactness and frontal suitcase plane/basis
   exactness, including the suitcase hand action remaining a non-basis
   cross-joint resisted action;
4. rejection of an empty prime-plus-resisted contract, overlap between prime and
   resisted actions, an unknown resisted action, and an incapable primary or
   secondary anti-mover;
5. exact action-opposition coverage and direction-aggregated singleton policy;
6. exact 44-action forbidden-prime complement plus one direct mutation per
   forbidden action in each family;
7. exact variant axes, single-value topology constraints, fixed boolean
   semantics, side-held upper-limb posture, per-implement load accounting, and
   roster coverage;
8. empty exercise-rule arrays and absence of exercise-level resisted-action
   deltas;
9. every muscle requirement removed and every meaningful role weakened;
10. exact stability-provider mapping for every declared region;
11. evidence limitation phrases, exact registration payloads, and complete
    evidence usage;
12. duration tracking and positive imperial/metric seed invariants;
13. no hold, marching, backward, strapped, overhead, rack, yoke, unequal-pair,
    or cross-family alias leakage.
