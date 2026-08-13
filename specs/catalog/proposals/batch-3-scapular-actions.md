# Batch 3 scapular-action decision

Status: **two narrow contracts activated; three standalone candidates deferred**.
This document records the evidence review and boundary decisions for
`scapular-protraction`, `scapular-elevation`, `scapular-depression`,
`scapular-upward-rotation`, and `scapular-downward-rotation`.

## Outcome

| Candidate | Decision | Product fixture or gate |
|---|---|---|
| `scapular-protraction` | Activate | One directly reviewed supine dumbbell scapular punch |
| `scapular-elevation` | Activate | One directly measured single-arm dumbbell shrug, with coupled upward rotation authored honestly |
| `scapular-depression` | Defer | Obtain loaded scapular kinematics and a muscle-role anchor that includes the pectoralis minor or otherwise supports the role policy |
| `scapular-upward-rotation` | Defer as standalone | Reviewed upward-rotation shrugs also elevate; keep rotation coupled inside the elevation/raise/press owner |
| `scapular-downward-rotation` | Defer as standalone | Reviewed candidates also add protraction/internal rotation/anterior tilt or closed-chain depression |

The result is deliberately not five symmetric one-action files. Scapular
motions are coupled in the reviewed exercises, and family symmetry is not a
reason to erase those couplings.

No taxonomy, joint-action, family-schema, or validator extension is required
for the two activated contracts. Three exercise-specific sources must be
registered in `evidence.json` before repository-wide validation can pass; their
exact metadata appears below.

## Shared classification rule

For these isolation families, the cardinal plane comes from the distinguishing
scapular action rather than from the held humeral posture. A supine punch is
therefore transverse because its basis action is `scapula.protraction`, even
though the humerus is held in sagittal-plane forward elevation. A shrug is
frontal because both its basis elevation and its directly observed coupled
upward rotation are frontal scapular actions.

`planeBasisActions` lists only one representative action per cardinal plane.
The elevation family therefore uses `scapula.elevation` as its basis while
retaining `scapula.upwardRotation` as a second prime action in the same plane.
Listing both as plane bases would falsely imply two distinct planes and violate
the existing plane-exactness contract.

## Activated contract: scapular protraction

### Boundary

The starter exercise holds the humerus at 90 degrees of forward elevation and
holds the elbow extended while one scapula moves anterolaterally around the
thorax. Dynamic shoulder flexion, horizontal adduction, elbow extension, and
every other scapular action are forbidden. This separates the family from:

- the active horizontal-press family, whose push-ups and unsupported cable
  presses combine protraction with glenohumeral and elbow actions;
- a dynamic hug, which combines protraction with shoulder horizontal
  adduction;
- wall slides and scaption, which combine protraction or upward rotation with
  humeral elevation; and
- the wall push-up plus measured by Lunden et al., which added scapular
  downward rotation/internal rotation and glenohumeral motion rather than
  behaving as a pure protraction fixture.

The contract uses `scapularTranslation: supportConstrained` because the supine
surface limits posterior translation. That value does not mean the scapula is
motionless. The reviewed exercise deliberately moves it around the thorax
while it remains in contact with the support; the distinction is the same
support-contact vocabulary used by the press families.

The held humeral posture reuses the existing shared
`upperArmPosition: flexed90` spelling from the elbow-extension contract. It is
a posture, not a dynamic `shoulder.flexion` action.

### Muscle-policy judgment

Serratus anterior is the sole primary. Castelein et al. measured surface
serratus anterior and fine-wire pectoralis minor during the serratus punch and
two modified push-up-plus tasks. Both muscles were active, but serratus activity
was significantly greater than pectoralis-minor activity during the punch;
pectoralis minor remained in the reported 15% to 29% MVIC range across the
three protraction tasks.
That supports `serratus: primary` and `pectoralisMinor: secondary`, not two
interchangeable primaries.

Intelangelo et al. divided the supine punch into press-up, concentric punch,
eccentric punch, and return phases. Serratus activity was moderate to high in
the punch phases, upper-trapezius activity was very low, and infraspinatus
activity remained below 10% MVIC. The contract therefore uses the split
external-rotator region as a shoulder stabilizer rather than inventing it as a
dynamic mover. Triceps and the distal loaded-grip stabilizers are
mechanics-derived posture assignments; the exercise sources did not measure
them.

This activation rests on an unambiguously prescribed loaded protraction range,
not on EMG creating an action. Neither exercise paper measured full
three-dimensional scapular kinematics, so variants with different support,
chain, or humeral geometry remain excluded.

### Initial roster

| Exercise | Why it is admitted | Evidence limitation |
|---|---|---|
| Supine Dumbbell Scapular Punch | Directly studied loaded supine punch; shoulder fixed at 90 degrees, elbow extended, full available protraction | Source reports EMG and prescribed motion, not 3-D scapular coupling |

Bodyweight push-up-plus, knee push-up-plus, wall push-up-plus, standing cable
punches, band punches, dynamic hugs, and bilateral variants are not implicit
axis values. Each requires a family-contract edit after its coupled motion is
reviewed.

One record is still a useful active contract here: it makes the strict
protraction-only boundary executable, supplies a reviewed serratus/pectoralis-
minor role fixture, and gives future variants a mutation target. Adding a
second name without a genuinely different reviewed setup would increase count
without increasing mechanical coverage.

## Activated contract: scapular elevation

### Boundary

The starter exercise is a standing single-arm dumbbell shrug with the humerus
held beside the torso, elbow extended, neck still, and lower body inactive.
Seth et al. tracked the thorax, scapula, and humerus during unloaded and 2 kg
loaded shrug trials, then drove a shoulder model with the measured kinematics.
The model reproduced an independently moving scapula and identified levator
scapulae as an elevator while superior trapezius both elevated and upwardly
rotated it. The authors also found trapezius and serratus working together in
upward rotation during shrugging.

The family therefore declares both `scapula.elevation` and
`scapula.upwardRotation` as prime actions. Omitting upward rotation would be the
kind of convenient simplification this catalog is designed to catch. It does
not turn the exercise into a standalone upward-rotation family: elevation is
still the distinguishing action and the named loaded repetition.

The same one-subject trace also changes two smaller model coordinates. The
model's scapular `abduction` coordinate locates the scapula around the thoracic
surface; it is not this catalog's glenohumeral `shoulder.abduction` action.
Its `winging` coordinate is scapular internal/external rotation about the
scapula's longitudinal axis; it is not interchangeable with
protraction/retraction or anterior/posterior tilt. The source does not identify
either smaller coordinate as a positive-work training target, and the current
taxonomy has no honest action ID for winging. They are therefore disclosed as
observed three-dimensional coupling, not authored as additional prime actions.
Forbidding the nearest-but-incorrect catalog actions prevents a future record
from silently relabeling those coordinates; it is not a zero-motion claim.

Rolling the shoulder, flexing or abducting the humerus, bending the elbow,
moving the cervical spine, leaning the trunk, or using leg drive crosses the
contract. A carry remains locomotion or an isometric support task rather than
a shrug merely because the upper trapezius is loaded.

The foundation has no cervical region or neck joint actions. The required
single-value `neckContribution: none` axis therefore records the technique
boundary and prevents an author from admitting a neck-driven variant without a
contract edit, but it is not a claim that the current capability validator can
model cervical muscle work. `contralateralSupport: none` reuses the raise-family
meaning and prevents the unilateral fixture from silently becoming a braced
shrug.

### Muscle-policy judgment

Levator scapulae and upper trapezius are both primary. Seth et al. supply the
motion-and-model anchor. Castelein et al. add a 26-participant surface/fine-wire
comparison of an arms-at-side shrug, overhead shrug, and overhead retraction.
Upper-trapezius activity was high across tasks, while levator-scapulae and
rhomboid-major activity was greater in the arms-at-side shrug than in the
overhead shrug. That establishes task-dependent rhomboid activity, but not
dynamic positive work in the exact modeled shrug. Seth et al.'s work analysis
did not retain the rhomboids among contributors exceeding its reporting
threshold. The initial record therefore does not promote rhomboids to a mover
role from EMG magnitude alone; adding them later requires direct role review.

Serratus is secondary because it participates in the measured upward-rotation
component, not because every shrug is assumed to target it equally. The
rotator-cuff, elbow, wrist, hand, spine, and pelvis stabilizers are categorical
control assignments. The only direct loaded-kinematics/model source used one
healthy adult, so the contract does not claim population-level magnitude
rankings or authorize every commercial shrug variant.

### Initial roster

| Exercise | Why it is admitted | Evidence limitation |
|---|---|---|
| Single-Arm Dumbbell Shrug | Direct unloaded/2 kg shrug kinematics and model; fine-wire/surface corroboration for medial scapular muscles | Kinematic/model experiment used one healthy adult; its 2 kg laboratory load establishes the reviewed motion, not a product starting weight |

The exercise uses a conservative product seed of 20 lb / 10 kg. The seed sits
above the catalog's 10 lb / 5 kg single-arm raise tier because a shrug keeps
the load beside the torso instead of carrying it through a long arm lever, but
below the 35 lb / 15 kg one-arm row tier because this is the first narrowly
reviewed unilateral shrug fixture. As elsewhere in the catalog, these are
independent clean scrubber detents rather than a converted laboratory load or
a strength prescription.

Barbell, trap-bar, bilateral dumbbell, behind-the-back, cable, Smith, lever
machine, chest-supported, incline, overhead, and jumping shrugs remain outside
the initial vocabulary. They are plausible future variants, not evidence-free
aliases of the measured task.

The one-record elevation contract is likewise intentional. It activates the
only setup for which this review can join observed scapular kinematics to a
defensible muscle policy, while preventing the common barbell/trap-bar/machine
roster from being admitted by name alone. A future setup must prove why it
belongs instead of inheriting membership from the word “shrug.”

## Deferred contract: scapular depression

Scapular depression is anatomically distinct, but the reviewed exercise record
does not yet support a truthful loaded family and role policy.

McCabe et al. prescribed five isotonic repetitions of unilateral elastic
scapular depression and also studied a seated press-up. The depression task
produced only moderate lower-trapezius activity (21% MVIC) while serratus
activity averaged 41% MVIC; pectoralis minor was not measured. The press-up
produced greater lower-trapezius activity, but the authors interpreted that
muscle as resisting superior displacement under bodyweight rather than proving
that it alone created a clean scapular-depression repetition. The paper reports
EMG rather than scapular kinematics and has no DOI, which the current evidence
registry requires.

Smith et al. studied protraction, retraction, elevation, depression, and clock
motions inside a shoulder immobilizer. Depression again produced its largest
reported response in serratus anterior (47% MVC), while pectoralis minor was
not measured. The immobilized, unquantified-resistance task is useful
rehabilitation evidence but not enough to author a normal loaded product
fixture.

The obvious closed-chain alternatives are also not clean. Nawoczenski et al.
measured a wheelchair weight-relief raise and found increased scapular
anterior tipping/internal rotation plus decreased upward rotation. A seated
press-up or dip-shrug must therefore not be reduced to depression without
measuring or authoring those coupled rotations. A scapular pull-up also changes
the body relative to fixed hands and may couple retraction/downward rotation;
no reviewed source measured a strict loaded version closely enough for this
batch.

Activation requires all of the following:

1. a named loaded exercise with dynamic scapular depression directly measured
   or unambiguously prescribed through a reproducible range;
2. measured coupled rotation/tilt/translation, or evidence that those motions
   do not define the repetition;
3. an exercise-specific muscle study that measures the plausible prime movers,
   especially pectoralis minor and lower trapezius, instead of assigning roles
   from anatomy alone;
4. a clear open- versus closed-chain choice and resistance/load semantics; and
5. negative fixtures excluding dips, shoulder-extension pulls, straight-arm
   pulldowns, weight-relief raises, and passive hanging.

The current evidence-registry rule is a secondary tooling blocker for the
McCabe paper: it has PMID `21522201` and PMCID `PMC2953285` but no DOI. If that
source later becomes load-bearing, the registry must either permit a canonical
PubMed/PMC identifier when no DOI exists or explicitly document why this
otherwise useful primary source cannot be registered.

## Deferred contract: scapular upward rotation

Do not activate a standalone `scapular-upward-rotation` family.

The best reviewed exercises intentionally couple rotation to another defining
motion:

- Seth et al.'s shrug elevates and upwardly rotates the scapula, so the active
  elevation family owns that coupled task.
- Lee et al. compared three shrug strategies at 30 degrees of shoulder
  abduction and found greater upward rotation in the stabilization shrug. The
  task is still a shrug, not rotation without elevation.
- Pizzari et al.'s “upward rotation shrug” likewise begins from 30 degrees of
  abduction and was an EMG comparison, not proof of a rotation-only repetition.
- The active flexion-raise, abduction-raise, and vertical-press families already
  author upward rotation alongside humeral elevation where motion evidence
  supports it.

A future standalone contract must produce dynamic upward rotation while
holding scapular elevation/depression and humeral elevation materially fixed,
then demonstrate that loaded range directly. No reviewed product exercise
clears that gate. “Upward-rotation exercise” in a rehabilitation paper is not
by itself a family boundary.

## Deferred contract: scapular downward rotation

Do not activate a standalone `scapular-downward-rotation` family.

Lunden et al. used bone pins and electromagnetic tracking during the wall
push-up plus. From the starting position to the plus position the scapula
downwardly and internally rotated, while the humerus elevated and moved
anterior to the scapular plane. That is strong evidence *against* treating the
task as a one-action downward-rotation exercise.

Nawoczenski et al. directly measured a wheelchair weight-relief raise and found
decreased upward rotation together with anterior tipping/internal rotation.
It is a closed-chain body-raising task and belongs in the depression/dip
boundary review, not in a rotation-only contract. Levator scapulae, rhomboids,
and pectoralis minor remain anatomically capable downward rotators, but anatomy
does not create a catalog exercise.

Activation requires a loaded task whose downward rotation is directly measured
and whose elevation/depression, protraction/retraction, tilt, humeral motion,
and elbow motion are either fixed or modeled honestly. No reviewed exercise
meets that standard.

## Explicit ownership map

| Exercise or setup | Owner |
|---|---|
| Supine dumbbell scapular punch | Active `scapular-protraction` |
| Standard single-arm dumbbell shrug | Active `scapular-elevation` |
| Unsupported cable press or push-up with deliberate protraction | Active `horizontal-press` |
| Dynamic hug | Future protraction/horizontal-adduction boundary; not the strict protraction contract |
| Wall slide, scaption, front raise, lateral raise | Active raise family or future coupled elevation contract |
| Upward-rotation shrug at 30 degrees abduction | Future `scapular-elevation` variant after exact setup review |
| Seated press-up, dip-shrug, weight-relief raise | Deferred depression/dip boundary |
| Scapular pull-up | Deferred depression/vertical-pull boundary |
| Straight-arm cable pulldown or pullover | Active `shoulder-extension-isolation`, not scapular depression |
| Loaded dip | `dip` Batch-3 review; not scapular-only depression |
| Carry or static shrug hold | Future locomotion/isometric owner |

## Evidence to register for activation

These three JSON-ready entries are required by the two active family files.
They are intentionally not added from this proposal lane because
`evidence.json` is a shared integration file.

```json
{
  "id": "castelein-2016-serratus-pectoralis-minor-protraction",
  "sourceType": "experimentalEMGStudy",
  "title": "Serratus anterior or pectoralis minor: Which muscle has the upper hand during protraction exercises?",
  "authors": [
    "Birgit Castelein",
    "Barbara Cagnie",
    "Thierry Parlevliet",
    "Ann Cools"
  ],
  "year": 2016,
  "doi": "10.1016/j.math.2015.12.002",
  "pmid": "26749459",
  "url": "https://doi.org/10.1016/j.math.2015.12.002",
  "scope": "Surface serratus-anterior and fine-wire pectoralis-minor EMG in 26 healthy participants during the serratus punch and wall/floor modified push-up-plus tasks. The serratus punch produced significantly greater serratus than pectoralis-minor activity; it supports categorical roles, while the study did not measure scapular kinematics."
}
```

```json
{
  "id": "intelangelo-2022-supine-scapular-punch",
  "sourceType": "experimentalEMGStudy",
  "title": "Supine scapular punch: An exercise for early phases of shoulder rehabilitation?",
  "authors": [
    "Leonardo Intelangelo",
    "Lassaga Ignacio",
    "Cristian Mendoza",
    "Diego Bordachar",
    "Daniel Jerez-Mayorga",
    "Alexandre Carvalho Barbosa"
  ],
  "year": 2022,
  "doi": "10.1016/j.clinbiomech.2022.105583",
  "pmid": "35124534",
  "url": "https://doi.org/10.1016/j.clinbiomech.2022.105583",
  "scope": "Loaded and unloaded supine scapular-punch phases in 34 healthy participants and 20 participants with unilateral shoulder pain. Serratus activity was moderate to high during concentric/eccentric punch phases, upper-trapezius activity was very low, and infraspinatus activity remained below 10%; the prescribed movement, not EMG alone, supplies the protraction action."
}
```

```json
{
  "id": "castelein-2016-scapular-muscles-shrug",
  "sourceType": "experimentalEMGStudy",
  "title": "Modifying the shoulder joint position during shrugging and retraction exercises alters the activation of the medial scapular muscles",
  "authors": [
    "Birgit Castelein",
    "Ann Cools",
    "Thierry Parlevliet",
    "Barbara Cagnie"
  ],
  "year": 2016,
  "doi": "10.1016/j.math.2015.09.005",
  "pmid": "26409441",
  "url": "https://doi.org/10.1016/j.math.2015.09.005",
  "scope": "Surface upper/middle/lower-trapezius and fine-wire levator-scapulae/rhomboid-major EMG in 26 healthy participants during an arms-at-side loaded shrug, an overhead shrug, and overhead retraction. It supports medial-scapular role differences by shoulder position but does not measure scapular kinematics."
}
```

## Reviewed but not registered while deferred

- Proposed ID `mccabe-2007-scapular-depression-press-up` — McCabe RA,
  Orishimo KF, McHugh MP, Nicholas SJ, *Surface electromygraphic analysis of
  the lower trapezius muscle during exercises performed below ninety degrees
  of shoulder elevation in healthy subjects*, PMID `21522201`, PMCID
  `PMC2953285`; no DOI. It directly prescribes elastic unilateral depression
  and seated press-up tasks but reports no scapular kinematics and does not
  measure pectoralis minor.
- Proposed ID `smith-2006-immobilized-scapulothoracic-exercises` — Smith J,
  Dahm DL, Kaufman KR, Boon AJ, Laskowski ER, Kotajarvi BR, Jacofsky DJ,
  *Electromyographic activity in the immobilized shoulder girdle musculature
  during scapulothoracic exercises*, DOI `10.1016/j.apmr.2006.03.013`, PMID
  `16813779`. Depression/protraction in an immobilizer inform the deferral but
  do not supply a normal externally loaded catalog fixture.
- Proposed ID `nawoczenski-2003-weight-relief-raise-kinematics` — Nawoczenski
  DA et al., *Three-dimensional shoulder kinematics during a pressure relief
  technique and wheelchair transfer*, DOI
  `10.1016/S0003-9993(03)00260-0`, PMID `13680564`. Directly measured coupled
  anterior tipping/internal rotation and decreased upward rotation in a
  weight-relief raise.
- Proposed ID `lee-2016-shrug-kinematics` — Lee JH, Cynn HS, Choi WJ, Jeong HJ,
  Yoon TL, *Various shrug exercises can change scapular kinematics and scapular
  rotator muscle activities in subjects with scapular downward rotation
  syndrome*, DOI `10.1016/j.humov.2015.11.016`, PMID `26625348`. It supports a
  future elevation-family variant, not standalone upward rotation.
- Proposed ID `pizzari-2014-upward-rotation-shrug` — Pizzari T, Wickham J,
  Balster S, Ganderton C, Watson L, *Modifying a shrug exercise can facilitate
  the upward rotator muscles of the scapula*, DOI
  `10.1016/j.clinbiomech.2013.11.011`, PMID `24342452`. EMG comparison of a
  standard shrug at 0 degrees and upward-rotation shrug at 30 degrees of
  abduction; no direct rotation measurement.
- Proposed ID `lunden-2010-wall-push-up-plus-kinematics` — Lunden JB, Braman JP,
  LaPrade RF, Ludewig PM, *Shoulder kinematics during the wall push-up plus
  exercise*, DOI `10.1016/j.jse.2009.06.003`, PMID `19733487`. Bone-pin
  kinematics demonstrate the coupled downward rotation/internal rotation and
  glenohumeral motion that keep the wall task out of strict protraction and
  downward-rotation families.

Do not register these deferred-only sources until an active anatomy profile,
family, or exercise cites them; unused evidence is intentionally rejected.

## Activation tests required

The integration suite should add:

1. exact family IDs, names, fixed classification, group policy, signatures,
   role policies, axis IDs, and one-record rosters;
2. exact assertions that protraction uses only
   `scapula.protraction`, while elevation uses
   `scapula.elevation|scapula.upwardRotation` with elevation as the sole plane
   basis;
3. negative action mutations adding shoulder flexion, elbow extension,
   downward rotation, or anterior tilt to the punch and adding shoulder
   elevation, elbow flexion, non-`none` neck contribution, or downward rotation
   to the shrug;
4. role mutations proving serratus remains the punch primary and pectoralis
   minor cannot replace it, plus mutations proving levator scapulae and upper
   trapezius both remain shrug primaries and serratus remains at least
   secondary;
5. exact assertions that the shrug disclosure preserves the model-specific
   abduction/winging distinction without relabeling either as a catalog action;
6. exact coverage of every admitted enum and boolean value, including the
   support-constrained-but-moving scapula on the punch;
7. global catalog-ID, canonical-name, and alias uniqueness; and
8. negative fixtures for a dynamic hug, wall push-up plus, upright row,
   rolling shrug, overhead shrug, seated press-up, and scapular pull-up.

Until the depression and rotation gates are met, the correct Batch-3 outcome
is two active scapular family files and no standalone contracts for the other
three candidate actions.
