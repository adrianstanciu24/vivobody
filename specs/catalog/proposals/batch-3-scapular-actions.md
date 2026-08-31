# Batch 3 scapular-action decision

Status: **resolved**. Three narrow contracts are active, upward rotation is
owned as a coupled action inside elevation/raise/press families, and downward
rotation has a permanent no-standalone-family ownership decision.

## Outcome

| Candidate | Decision | Product fixture or resolution |
|---|---|---|
| `scapular-protraction` | Active | Supine dumbbell scapular punch |
| `scapular-elevation` | Active and expanded | Single-arm dumbbell shrug plus exact bilateral 30-degree stabilization shrug |
| `scapular-depression` | Active | McCabe unilateral overhead-band depression |
| `scapular-upward-rotation` | Resolved without standalone family | Coupled prime action in `scapular-elevation` and the reviewed raise/press owners |
| `scapular-downward-rotation` | Resolved: no standalone family | Coupled candidates remain with protraction, dip/depression, or shoulder-motion owners |

The result is deliberately not five symmetric one-action files. Scapular
motions are coupled in the reviewed exercises, and family symmetry is not a
reason to erase those couplings.

## Shared classification rule

For scapular isolation families, the cardinal plane comes from the
distinguishing scapular action rather than a held humeral posture. The supine
punch and standing band retraction are transverse; elevation and depression
are frontal. A held arm angle is an authored variant value, not a dynamic
shoulder action.

`planeBasisActions` lists one representative action per cardinal plane. The
elevation family therefore uses `scapula.elevation` as its sole plane basis
while retaining `scapula.upwardRotation` as a second prime action in the same
plane.

## Active contract: scapular protraction

The starter record remains the directly reviewed supine dumbbell scapular
punch. It holds the humerus at 90 degrees of forward elevation and the elbow
extended while one scapula moves anterolaterally around the thorax. Dynamic
shoulder flexion, horizontal adduction, elbow extension, and every other
scapular action remain forbidden.

Serratus is the sole primary and pectoralis minor is secondary. Castelein et
al. measured both during the punch, with significantly greater serratus
activity. Intelangelo et al. measured the loaded punch phases and supports the
exact posture and categorical control roles. Neither paper supplies a general
license for push-up-plus, cable punch, dynamic hug, wall slide, or unsupported
standing variants.

The contract continues to disclose that its action comes from the prescribed
loaded protraction range rather than from EMG. The source did not measure full
three-dimensional scapular coupling.

## Active contract: scapular elevation

### Shared signature

Both active records declare:

- `scapula.elevation` as the distinguishing basis action; and
- `scapula.elevation|scapula.upwardRotation` as the complete prime signature.

This preserves the measured coupling rather than treating a shrug as pure
vertical translation.

### Single-arm dumbbell shrug

The original record remains a standing unilateral dumbbell shrug with the arm
at the side, elbow extended, neck still, and lower body inactive. Levator
scapulae and upper trapezius are primary; serratus is secondary. Its hand,
wrist, shoulder, elbow, spine, and pelvis assignments remain exact to the
loaded unilateral setup.

### Bilateral 30-degree stabilization shrug

Lee et al. directly compared three shrug strategies in 17 participants with
scapular downward-rotation syndrome. The exact admitted variant is:

- standing with feet shoulder-width apart;
- bilateral shoulders held at 30 degrees of frontal-plane abduction;
- a digital inclinometer used to retain the arm angle;
- light contact between the radial wrist borders and plastic frontal guides;
- bilateral target bars set to each participant's maximum shrug height; and
- investigator stabilization at the chin and the most prominent thoracic
  spinous process.
- two trials, each held at the maximum-height target for five seconds before a
  slow return.

EMG was collected during the five-second isometric phase, and scapular
upward-rotation angle was measured immediately after each exercise condition,
not continuously through the repetition. The stabilization condition produced
greater post-condition upward rotation than the preferred and frontal shrugs.
It is still an elevation repetition, so it belongs inside
`scapular-elevation`; it does not create a duplicate upward-rotation family or
claim a dynamic angle trace.

The fixture carries no training implement and receives no wrist/hand stability
demand or grip-muscle assignment. Its `other` equipment classification names
the laboratory guides and partner stabilization, while `armSegmentGravity`
and `nonComparable` preserve the absence of external load. Upper trapezius and
levator scapulae remain elevation primaries; serratus and lower trapezius are
secondary upward rotators. Lateral deltoid and supraspinatus are stabilizers
for the isometrically held 30-degree shoulder-abduction posture; they receive
no dynamic shoulder-abduction credit. The remaining shoulder, elbow, spine,
and pelvis assignments are likewise stabilizers only.

The equipment rules lock the two topologies in both directions: dumbbell means
unilateral arms-at-side external loading without laboratory stabilization;
`other` means the bilateral 30-degree non-comparable laboratory task with all
guides and stabilization present.

## Active contract: scapular depression

### Why the earlier hold is now cleared

McCabe et al. prescribed five isotonic repetitions of unilateral scapular
depression against Theraband. The subject stood with the working arm beside
the torso and elbow extended, held a band anchored overhead, began with the
band just taut, and used a subject-adjusted resistance described as moderate
effort for five correct repetitions. Each repetition used two seconds
concentric and two seconds eccentric, with five seconds between repetitions.

This is an unambiguous dynamic loaded depression range. The contract uses the
same evidence standard already accepted for the supine punch: prescribed
motion establishes the action, while EMG establishes categorical role support.
Because the paper did not measure three-dimensional scapular coupling, every
setup value is pinned and other geometries remain excluded.

### Role policy

During the exact depression task McCabe et al. measured upper trapezius at
20% MVIC, middle trapezius at 19%, lower trapezius at 21%, and serratus at 41%.
Lower trapezius is the sole primary because it is the only measured region in
the study that can produce depression. Serratus is a stabilizer: its larger EMG
signal does not give it a depression capability. Pectoralis minor was not
measured and receives no inferred volume credit.

External rotators, triceps, extensor carpi radialis, finger flexors, and trunk
regions are mechanics-derived stabilizers for the fixed shoulder/elbow/grip
and standing posture.

The active family admits only `Standing Band Scapular Depression`. Dips,
seated press-ups, weight-relief raises, scapular pull-ups, straight-arm
pulldowns, and passive hangs remain outside it.

Later follow-up: `scapular-pull-up` is now a separate active family under
[`default-candidate-follow-up-2026-08.md`](default-candidate-follow-up-2026-08.md)
because its reviewed depression-plus-retraction cycle cannot enter this
depression-only owner.

## Resolved ownership: scapular upward rotation

There is no standalone `scapular-upward-rotation` family.

Every reviewed dynamic fixture couples upward rotation to another defining
motion:

- Seth et al.'s loaded shrug and Lee et al.'s stabilization shrug both elevate
  and upwardly rotate the scapula, so `scapular-elevation` owns them;
- flexion and abduction raises couple rotation to humeral elevation; and
- vertical presses couple it to shoulder and elbow actions.

The Lee record closes the old evidence hold by adding the exact directly
measured 30-degree fixture to its honest owner. Creating another family with
the same elevation-plus-upward-rotation signature would duplicate ownership,
not add a new mechanic.

## Permanent ownership decision: scapular downward rotation

There is no standalone `scapular-downward-rotation` family under the current
action vocabulary and evidence.

The primary kinematic candidates all belong elsewhere:

- Lunden et al.'s bone-pin wall push-up-plus moved into downward rotation and
  internal rotation while the scapula protracted and the humerus moved. It is
  a protraction/press topology and does not establish a downward-rotator role
  roster.
- Nawoczenski et al.'s wheelchair weight-relief raise combined decreased
  upward rotation with depression, anterior tipping, and internal rotation. It
  is a closed-chain body-raising task in the dip/depression boundary.
- Lee et al. (2025) used biplanar videoradiography during a weighted cable
  pull-down and found *more* upward rotation during concentric shoulder
  adduction. A pulldown must not be inferred into downward rotation from its
  name or textbook intuition.
- Loaded arm lowering can show downward rotation, but the action is coupled to
  humeral lowering and eccentric control. It is not a reproducible concentric
  downward-rotation isolation with a measured role hierarchy.

Pectoralis minor, levator scapulae, and rhomboids retain downward-rotation
capabilities in the anatomy foundation for honest compound mechanics. Those
capabilities do not create a volume-bearing exercise without an exact fixture.

This is a resolved no-family outcome, not an open evidence count. It should be
revisited only if a future primary source supplies a dynamically loaded fixture
with downward rotation directly measured, all coupled actions authored, and a
defensible downward-rotator role roster.

## Explicit ownership map

| Exercise or setup | Owner |
|---|---|
| Supine dumbbell scapular punch | `scapular-protraction` |
| Single-arm dumbbell shrug | `scapular-elevation` |
| Bilateral 30-degree stabilization shrug | `scapular-elevation` |
| Standing overhead-band depression | `scapular-depression` |
| Unsupported cable press or push-up with protraction | `horizontal-press` |
| Dynamic hug | Protraction/horizontal-adduction boundary |
| Wall slide, scaption, front raise, lateral raise | Active raise owner |
| Seated press-up, dip-shrug, weight-relief raise | Dip/depression boundary |
| Scapular pull-up | Vertical-pull/depression boundary |
| Straight-arm cable pulldown or pullover | `shoulder-extension-isolation` |
| Wall push-up-plus downward rotation | Protraction/press boundary |
| Weighted pulldown | Vertical pull; no downward-rotation inference |

## Evidence payloads introduced by this resolution

- `mccabe-2007-below-90-scapular-exercises` — McCabe RA, Orishimo KF,
  McHugh MP, Nicholas SJ, *Surface Electromyographic Analysis of the Lower
  Trapezius Muscle During Exercises Performed Below Ninety Degrees of Shoulder
  Elevation in Healthy Subjects*, 2007; PMID `21522201`; PMCID `PMC2953285`;
  no DOI; canonical PMC URL.
- `lee-2016-stabilization-shrug-upward-rotation` — Lee JH, Cynn HS,
  Choi WJ, Jeong HJ, Yoon TL, *Various shrug exercises can change scapular
  kinematics and scapular rotator muscle activities in subjects with scapular
  downward rotation syndrome*, *Human Movement Science* 45:119-129, 2016;
  DOI `10.1016/j.humov.2015.11.016`; PMID `26625348`.
- Boundary evidence: Lunden et al., DOI `10.1016/j.jse.2009.06.003`, PMID
  `19733487`, PMCID `PMC2841059`; Nawoczenski et al., DOI
  `10.1016/S0003-9993(03)00260-0`, PMID `13680564`; Lee ECS et al., DOI
  `10.1016/j.jbiomech.2025.112932`, PMID `40886433`.

The shared evidence registry is maintained by the integration lane. The family
files intentionally use the exact IDs above.

## Required integration tests

The integration suite should add:

1. exact family, signature, role-policy, axis, rule, and roster assertions for
   depression and the expanded elevation owner;
2. mutations proving lower trapezius remains depression's sole primary,
   serratus cannot be promoted to a depression mover, and pectoralis minor
   cannot be inferred into the one reviewed record;
3. exact depression anchor, tension, effort, cadence, rest, and load semantics;
4. mutations for shoulder/elbow motion and every forbidden coupled scapular
   action;
5. exact Lee fixture rules, including bilateral laterality, 30-degree frontal
   abduction, inclinometer, target bars, wrist guides, manual stabilization,
   no implement, no grip roles, and non-comparable zero load;
6. a pin that no standalone upward-rotation or downward-rotation family is
   active;
7. negative wall-plus, weight-relief, pulldown, passive-hang, and unsupported
   shrug fixtures; and
8. runtime projection of both new records and the expanded family metadata.
