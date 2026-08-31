# Batch 5 unilateral compound activation record

Status: **three narrow contracts activated with registered evidence and
contract/mutation tests**.

This document records the decisions behind:

- `families/split-stance-squat.json`;
- `families/step-up.json`; and
- `families/dynamic-lunge.json`.

None of the contracts is a generic synonym bucket. The first owns one
stationary, fixed-foot split squat. The second owns one exact raised-platform
forward stepping sequence. The third owns Comfort et al.'s exact bodyweight
forward and reverse step-and-return lunges. Walking or alternating lunges
remain outside the active boundary because continuous locomotion and
between-repetition support changes were not reviewed as small deltas from the
two discrete lunge fixtures. Likewise, a generic gym step-up cannot be inferred
from one exact height and one exact foot-transition sequence.

## Activation outcome

| Family | Active roster | Reviewed geometry |
|---|---|---|
| `split-stance-squat` | `barbell-split-squat` | Stationary 10-RM barbell split squat, 100% leg-length stance, erect torso, lead thigh parallel |
| `step-up` | `bodyweight-forward-step-up-21cm` | Bodyweight forward step onto 21-cm platform, brief bilateral top, trail foot then lead foot return to lower floor |
| `dynamic-lunge` | `bodyweight-forward-lunge`; `bodyweight-reverse-lunge` | Upright, arms-crossed, bodyweight forward or reverse step-and-return lunge at full self-selected depth with 3-second descent and 2-second ascent |

The roadmap candidate was called `split-stance-lunge`. The active ID is
deliberately `split-stance-squat`: the reviewed exercise has fixed foot
contacts and no landing phase, and the family ID should not imply that dynamic
lunges have already passed the same contract. Its fixed `pattern: "lunge"`
still follows the existing Swift enum's broader product classification, whose
comment groups split squats, step-ups, and walking lunges. The family ID names
the distinguishing stationary geometry; the pattern remains the app's coarse
asymmetric split-stance lower-body category.

## Boundary between the three families

All three families use lead-side hip extension, knee extension, and ankle
plantarflexion during the concentric task. They remain separate because their
support topology differs materially:

| Question | `split-stance-squat` | `step-up` | `dynamic-lunge` |
|---|---|---|---|
| Lead-foot surface | Lower floor | Raised platform | Lower floor or second level force plate |
| Trail-foot support | Forefoot remains on lower floor | Moves from lower floor to platform and back | Remains at start in forward lunge; steps rearward in reverse lunge |
| Loaded repetition start | Fixed split standing | Lead foot already raised, trail foot on lower floor | Bilateral upright standing before a forward or rearward step |
| Upper endpoint | Same fixed split stance | Brief bilateral standing on platform | Bilateral upright start position |
| End of studied sequence | Same fixed split stance | Both feet on lower floor | Both feet returned to the bilateral start |
| Inter-repetition transition | None | Same lead foot is replaced on platform | The stepping foot returns before the next repetition |
| Landing/deceleration branch | Absent | Controlled platform return; no dynamic lunge landing | Present and topology-pinned for the forward and reverse fixtures |

The step-up contract does not hide the final lead-foot step-down. Wang et al.'s
full instruction sequence returns the non-dominant foot to the lower floor and
then steps the dominant foot down beside it. Therefore the active axes encode:

- `leadFootTransition: platformToFloorAfterTrailDescent`;
- `trailFootTransition: floorToPlatformToFloor`;
- `footContact: leadLoadsPlatformThenBothReturnFloor`; and
- `interRepFootTransition: leadFloorToPlatformReset`.

This differs from Simenz et al.'s loaded strength-training protocol, in which
the lead foot remains on a 45.72-cm box and only the trail foot returns between
repetitions. That topology is useful evidence context, but it is not silently
substituted for the active Wang fixture.

## Shared classification and axis vocabulary

All three contracts stamp:

```json
{
  "mechanic": "compound",
  "pattern": "lunge",
  "direction": null,
  "planes": ["sagittal"]
}
```

Hip extension is the one plane-basis action. Knee extension and ankle
plantarflexion remain family prime actions at other joints. `direction` stays
`null`: the press/pull direction vocabulary is not a generic label for all
vertical displacement.

The contracts share established or Batch-5 vocabulary where the meaning is
actually the same:

- `kineticChain`;
- `bodyPosition`;
- `torsoSupport`;
- `stanceConfiguration`;
- `loadPlacement`;
- `rangeOfMotion`;
- `spineMotion`;
- `hipMotion`, `kneeMotion`, `ankleMotion`, and `footMotion`;
- `footContact`;
- `interRepSupport`; and
- `lowerBodyContribution: compoundHipKneeAnkleExtension`.

`stanceConfiguration`, `rangeOfMotion`, and `footContact` are family-scoped
axes. Their values differ because a fixed split stance and a raised-platform
stepping sequence are not interchangeable setups.

The stationary and step-up contracts do not declare `pelvisMotion`. The pelvis
translates as the body
lowers, rises, and steps, but that translation does not independently create
the repetition in the way a thrust or bridge deliberately moves the pelvis as
the load-bearing segment. Pelvis control remains a stability demand.

The dynamic-lunge contract records `pelvisMotion: nonstandardized` alongside
`spineMotion: nonstandardized`. Comfort et al. prescribed upright posture but
did not establish zero pelvis or spine excursion. Its source-specific axes also
separate step direction, which foot lands, whether the selected lead foot
steps or remains planted, the contralateral-foot transition, full
self-selected depth, and return to bilateral standing. Exercise rules bind the
forward and reverse values so a record cannot exchange their support topology
while retaining the other fixture's name.

The step-up deliberately omits `fixedPath`. The shared definition asks whether
rails or a lever constrain an external load path. This bodyweight-only fixture
has no external load path, and no machine or rail guides the body. Adding
`fixedPath: false` would answer a question that the fixture does not pose.

## Stationary split-squat evidence decisions

### Exact fixture

Song et al. tested 20 physically active male university students performing
three consecutive barbell split-squat repetitions with their individual 10-RM
load at 50%, 70%, 100%, and 120% of leg length. Leg length was measured from
the greater trochanter to the lateral malleolus. The dominant limb was placed
in front, the torso was kept erect, and the lower endpoint was the lead thigh
parallel to the floor. Three-dimensional lead-limb kinematics, force-platform
kinetics, and surface EMG from gluteus maximus, vastus lateralis, vastus
medialis, rectus femoris, biceps femoris, semitendinosus, and both
gastrocnemius heads were collected.

The active record pins the study's 100%-leg-length condition rather than
admitting the whole experimental range. The paper recommends at least 100%
for a more stable choice and reports little practical improvement beyond 100%,
while 120% could cause forward slipping. Because the paper does not report the
tape landmark, the contract encodes the categorical
`stanceLength: approximatelyLegLength` rather than a false numeric ratio.
That keeps short- and substantially longer-stance variants outside the
reviewed anatomy contract without claiming unavailable measurement precision.

The paper collected the anterior/dominant limb and explicitly identifies the
absence of posterior-limb data as a limitation. That measurement boundary
stays in evidence prose rather than becoming a variant axis: what a study
instrumented is not an observable exercise property. `laterality: unilateral`
means the lead side is logged; it does not claim that the rear leg contributes
zero load, that the lead leg is load-dominant, or that a percentage split is
known. The paper also does not define a heel-to-heel landmark for its taped
stance positions, so the movement definition retains the study's
100%-leg-length condition without inventing one.

The instructed and video-checked erect torso is encoded separately as
`trunkOrientation: erect`. It does not prove zero segmental lumbar excursion,
which the study did not measure. The contract therefore uses
`spineMotion: nonstandardized`, retains spinal stability, and forbids dynamic
spinal prime actions rather than converting a gross orientation cue into a
false position-held joint claim.

Stastny et al. directly compared stationary split squats with walking lunges
under ipsilateral and contralateral 5-RM dumbbell loading. The paper identifies
the defining boundary: walking lunges contain a dynamic landing and impact,
whereas split-squat feet remain fixed. It also found exercise- and
load-position-sensitive gluteus-medius and vastus activity. This supports
keeping walking lunges and one-dumbbell loading outside the first contract,
not activating them as aliases or harmless axes.

### Ankle plantarflexion is a dynamic action

The ankle action is not inferred from an extensor moment label alone. Song's
Table 1 defines negative ankle values as dorsiflexion and reports a peak of
`-2.9 +/- 4.6 degrees` for the 100%-leg-length condition. The repetition then
returns from that bottom position to the same split-standing start. Reversing
the bottom-position dorsiflexion toward the standing angle during ascent is
dynamic plantarflexion. The paper also reports a positive ankle extension
moment and directly records both gastrocnemius heads, but those observations
are corroborating rather than the sole basis for the action.

Soleus was not in Song's surface-EMG panel. Its secondary role is derived from
the directly observed plantarflexion action plus the independent Arnold lower-
limb action profile. This inference is disclosed rather than presented as
exercise-specific soleus measurement.

### Muscle roles

`vasti` and `gluteMax` are co-primary because the task deliberately trains both
knee and hip extension, and the condition-matched study reports substantial
extension moments and direct activation at both joints. `rectusFemoris` and
the two visible plantarflexor regions are secondaries.

The hamstring panel requires restraint. Song notes that simultaneous hip and
knee movement makes the phase and function of rectus femoris, biceps femoris,
and semitendinosus difficult to resolve from surface excitation. The visible
`medialHamstrings` and unsplit `bicepsFemoris` regions therefore receive
stabilizer credit, not automatic prime-mover credit from EMG amplitude.
`gluteMed` stabilizes the unilateral pelvis and hip. The barbell-specific grip,
upper-back, shoulder, arm, and trunk stabilizers reflect the unsupported setup
and the independent anatomy profiles; they are not claimed to have been
measured by Song. The text identifies a barbell but does not name a high- or
low-bar site or hand orientation. `upperBackBarbell` and `pronated` are bounded
figure- and mechanics-derived encodings, not textual-method claims; the shared
load-placement spelling deliberately avoids a false upper-trapezius precision.

`laterality: unilateral` means that the lead side is the logged training side.
It does not mean that the rear limb is absent or inactive.

## Forward step-up evidence decisions

### Exact fixture and full repetition

Wang et al. analyzed 21 older adults performing forward and lateral stepping
at a self-selected pace on a 21-cm force-platform step. In the forward task,
the dominant foot began fully on the platform. Participants shifted onto that
limb, extended the lead hip and knee, brought the trail foot to the platform,
paused briefly, returned the trail foot to the lower floor, and finally stepped
the lead foot down beside it. They were instructed not to push or hop from the
trail leg. The full final lead-foot step-down is part of the active movement
definition and axes.

A safety bar was available for balance loss, but participants were instructed
not to use it for movement assistance. Post-hoc force data were below 2% body
weight for all but four participants; those four averaged 4.8% at their maximum
trials. `torsoSupport: none` therefore describes the intended unsupported task,
not a claim that every recorded trial had literally zero incidental contact.

The study measured three-dimensional hip, knee, and ankle kinematics and
kinetics of the dominant limb. The forward step produced greater hip power and
work than the lateral condition, while the lateral condition shifted more
demand to the knee and ankle. The active family admits only forward stepping.

Wang contains no exercise EMG. Individual muscle roles on this exact 21-cm
bodyweight fixture are therefore anatomy- and mechanics-derived wherever not
directly measured. `vasti` and `gluteMax` represent the training-defining knee-
and hip-extension demands. Rectus femoris, gastrocnemius, and soleus are
bounded secondary contributors. The visible medial-hamstring and unsplit
biceps-femoris regions receive stabilizer credit: simultaneous hip and knee
extension prevents a different loaded 45.72-cm EMG fixture from proving net
dynamic hamstring contribution to this bodyweight task. Gluteus medius and the
trunk regions also receive stabilizer credit. These categories are not a
numeric ranking of Wang's unmeasured muscle excitation.

### Adverse muscle-role evidence

MacAskill et al. measured a different bodyweight forward step-up and found
greater gluteus-medius than gluteus-maximus excitation, with mean values of
62.7% and 28.7% MVIC respectively. That source used a lower 15.24-cm step and a
gym-style repetition in which the lead foot remained on the step while the
trail toes returned to the floor; it is not the same height or full foot-
transition sequence as Wang. It is nevertheless adverse to any claim that all
low bodyweight step-ups strongly emphasize gluteus maximus. The contract keeps
`gluteMax` primary because Wang's condition-matched joint work makes hip
extension a defining training demand, not because MacAskill proves high gluteal
excitation. Family roles encode mechanical/training emphasis, not an EMG
leaderboard.

MacAskill has PMID `25540706` and PMCID `PMC4275195` but no DOI. The current
evidence registry requires a DOI and a DOI-derived URL, so it cannot be
registered without the already-tracked evidence-schema decision to permit a
reviewed alternative identifier. Until then, this proposal records it as
discovery/adverse evidence rather than a JSON evidence reference.

### Loaded step-up evidence is context, not fixture provenance

Simenz et al. tested 15 resistance-trained women using 6-RM loads on an exact
45.72-cm box. Its standard forward step-up kept the lead foot on the box while
the trail foot moved up and down. It directly measured biceps femoris, gluteus
maximus, gluteus medius, rectus femoris, semitendinosus, vastus lateralis, and
vastus medialis, and it explicitly describes hip extension, knee extension,
and ankle plantarflexion.

The full methods do not report the external implement or its placement. A 6-RM
number cannot tell the catalog whether the resistance was a barbell, vest,
dumbbells, or another setup, and those choices change equipment, load
placement, grip demands, and stabilizers. Simenz is therefore a family-level
action and muscle-context source only. It is intentionally absent from the
21-cm bodyweight exercise's `evidenceRefs` and cannot activate the loaded
45.72-cm record.

### Step-up ankle action and load analytics

Wang reports sagittal ankle excursion and ankle positive work during the
support phase. The lead ankle begins dorsiflexed under the raised-foot geometry
and moves toward the standing-on-platform angle during ascent. That angular
change, together with the measured ankle work, supports dynamic
plantarflexion; the action is not inferred from calf activity or an extensor
moment alone. Simenz supplies independent action-language corroboration.

No reviewed source supplies a defensible effective bodyweight fraction for the
exact Wang task. The record therefore uses `loadMode: nonComparable` and
`bodyweightFraction: 0`. It will not participate in load-based analytics. A
plausible-looking fraction would be false precision because the trail limb,
moving body segments, platform height, and support phase all affect effective
load.

No generic `Step-Up` alias is owned. Both the name and only alias retain
`21 cm`, because the contract does not admit arbitrary heights or the more
common continuous lead-foot-on-platform gym repetition.

## Dynamic-lunge evidence decisions

### Two records, one exact step-and-return contract

Comfort et al. tested forward and reverse lunges with the same participants,
bodyweight loading, bilateral upright start, crossed-arm posture, cadence, full
self-selected depth, lead-limb measurement model, and return endpoint. They
therefore belong to one family. They are not aliases for one movement: the
forward task makes the selected lead foot step, land with whole-foot contact,
remain planted during the loaded phases, and return; the reverse task keeps the
selected front foot planted while the contralateral foot steps backward,
lands, and returns. Required topology axes plus reciprocal exercise rules make
those differences contractual.

The records prescribe completion on the selected side followed by the other
side, matching the source's per-limb trials without turning the exercise into
an alternating or walking lunge. Both begin and end in bilateral standing;
neither owns a fixed split-stance start.

### Action and muscle-role boundary

Three-dimensional kinematics and force-plate kinetics establish sagittal
lead-limb hip, knee, and ankle demand across the lowering and raising phases.
The ascent is modeled as `hip.extension`, `knee.extension`, and
`ankle.plantarflexion`; dorsiflexion at the bottom is the starting position for
the authored plantarflexion action, not an additional dorsiflexion prime.

Comfort et al. did not record EMG. Vasti and gluteus maximus are conservative
co-primary mechanics-and-anatomy assignments for the defining knee- and
hip-extension demands, not a measured ranking between muscles. Rectus femoris,
gastrocnemius, and soleus receive secondary roles within their compatible
action envelopes. The medial and lateral hamstrings, gluteus medius, abs,
obliques, and lumbar extensors are stabilizers only; they satisfy the explicit
spine, pelvis, hip, knee, ankle, and foot stability demands without receiving
mover volume credit. The family does not infer a universal forward-versus-
reverse role difference from the reported joint kinetics.

### Load and unmeasured motion

The source reports bodyweight movement, not an externally comparable load or
an effective bodyweight fraction. Both records therefore use
`loadMode: nonComparable`, zero entered weight, and zero bodyweight fraction.
Upright posture is prescribed, while exact spine and pelvis motion is not;
those axes remain `nonstandardized`. No fixed stride length or joint-angle
depth is invented from the full self-selected-depth instruction.

## Explicit exclusions and future owners

| Candidate | Initial decision | Reason or future owner |
|---|---|---|
| Bodyweight forward lunge | Activate in `dynamic-lunge` | Comfort directly reviews the selected lead-foot forward step, whole-foot landing, full-depth descent, and return to bilateral start. |
| Bodyweight reverse lunge | Activate in `dynamic-lunge` | Comfort directly reviews the contralateral rearward step while the selected front foot remains planted, followed by return to bilateral start. |
| Walking lunge | Defer | Alternating impact and locomotor transition are directly distinguished by Stastny. |
| Rear-foot-elevated split squat | Defer | Rear support height materially changes support and joint geometry. |
| Front-foot-elevated split squat | Defer | Raised lead foot without stepping is neither active family fixture. |
| Bodyweight or dumbbell split squat | Defer | Load placement and upper-body stabilizers differ; Stastny does not validate the barbell roles for them. |
| Short- or long-stance split squat | Defer | Song shows step-length-sensitive kinematics, kinetics, and EMG. |
| Smith or supported split squat | Defer | Guidance/support changes path and stability demands. |
| Continuous gym step-up | Defer | Lead foot remains on platform; Wang's full sequence steps it to the floor. |
| Loaded 45.72-cm step-up | Defer | Simenz does not identify implement or placement. |
| Other step heights | Defer | Height affects kinematics and muscle demand; 21 cm is exactly pinned. |
| Lateral, crossover, or diagonal step-up | Defer | Different planes and hip actions; Simenz reports variant-sensitive roles. |
| Hovering-trail-foot step-up | Defer | Removes the bilateral top support and changes balance demand. |
| Step-down | Exclude | Downward task with different prime phase and ownership. |
| Continuous stairs or stair machine | Exclude | Locomotor/machine task, not a discrete reviewed repetition. |
| Explosive step-up or jump | Exclude | Power/locomotion modality and flight/landing actions. |
| Loaded, lateral, crossover, or jumping lunge | Exclude from `dynamic-lunge` | Comfort's active fixtures are unloaded sagittal step-and-return repetitions. |
| Stationary lunge or split squat | Exclude from `dynamic-lunge` | Fixed feet and no landing remain owned by `split-stance-squat`. |

Later follow-up: exact paired-dumbbell stationary split-squat and reverse-lunge
fixtures are now active under
[`default-candidate-follow-up-2026-08.md`](default-candidate-follow-up-2026-08.md).
This does not broaden either owner to arbitrary loaded, alternating, or walking
variants.

## Evidence entries required at activation

The following IDs and metadata are pre-declared so activation does not invent
slugs or bibliographic details ad hoc.

### `song-2023-split-squat-step-length`

```json
{
  "id": "song-2023-split-squat-step-length",
  "sourceType": "experimentalKinematicsEMGStudy",
  "title": "Effects of step lengths on biomechanical characteristics of lower extremity during split squat movement",
  "authors": [
    "Qingquan Song",
    "Mujia Ma",
    "Hui Liu",
    "Xiaobin Wei",
    "Xiaoping Chen"
  ],
  "year": 2023,
  "doi": "10.3389/fbioe.2023.1277493",
  "pmid": "38026855",
  "url": "https://doi.org/10.3389/fbioe.2023.1277493"
}
```

Registry scope: twenty physically active male university students performed
10-RM barbell split squats at four leg-length-normalized stance lengths with
lead-limb kinematics, kinetics, and eight-muscle surface EMG. It directly
supports the stationary 100%-leg-length fixture, its lower endpoint, erect
torso, triple-extension action, and bounded roles; it contains no rear-limb
loading, soleus EMG, dynamic-lunge fixture, or arbitrary load-placement
permission.

### `stastny-2015-split-squat-dumbbell-position`

```json
{
  "id": "stastny-2015-split-squat-dumbbell-position",
  "sourceType": "experimentalKinematicsEMGStudy",
  "title": "Does the Dumbbell-Carrying Position Change the Muscle Activity in Split Squats and Walking Lunges?",
  "authors": [
    "Petr Stastny",
    "Michal Lehnert",
    "Amr M. Z. Zaatar",
    "Zdenek Svoboda",
    "Zuzana Xaverova"
  ],
  "year": 2015,
  "doi": "10.1519/JSC.0000000000000976",
  "pmid": "25968228",
  "url": "https://doi.org/10.1519/JSC.0000000000000976"
}
```

Registry scope: fourteen resistance-trained and fourteen non-resistance-
trained men performed ipsilateral and contralateral 5-RM one-dumbbell split
squats and walking lunges with bilateral EMG and three-dimensional kinematics.
It directly supports the fixed-foot versus landing boundary and demonstrates
load-position-sensitive anatomy; it does not activate a dumbbell record under
the barbell contract or establish unmeasured muscle roles.

### `wang-2003-forward-lateral-step-up-biomechanics`

```json
{
  "id": "wang-2003-forward-lateral-step-up-biomechanics",
  "sourceType": "experimentalKinematicsKineticsStudy",
  "title": "Lower-extremity biomechanics during forward and lateral stepping activities in older adults",
  "authors": [
    "Man-Ying Wang",
    "Sean Flanagan",
    "Joo-Eun Song",
    "Gail A. Greendale",
    "George J. Salem"
  ],
  "year": 2003,
  "doi": "10.1016/S0268-0033(02)00204-8",
  "pmid": "12620784",
  "url": "https://doi.org/10.1016/S0268-0033(02)00204-8"
}
```

Registry scope: twenty-one older adults performed forward and lateral 21-cm
bodyweight stepping tasks with dominant-limb three-dimensional kinematics and
kinetics. It directly supports the exact forward fixture, full two-foot return
sequence, brief top pause, no trail-leg push-off/hop, and hip/knee/ankle demand;
it contains no EMG, effective bodyweight fraction, external load, arbitrary
height, or continuous lead-foot-on-platform repetition.

### `simenz-2012-loaded-step-up-variations`

```json
{
  "id": "simenz-2012-loaded-step-up-variations",
  "sourceType": "experimentalEMGStudy",
  "title": "Electromyographical Analysis of Lower Extremity Muscle Activation During Variations of the Loaded Step-Up Exercise",
  "authors": [
    "Christopher J. Simenz",
    "Luke R. Garceau",
    "Brittney N. Lutsch",
    "Timothy J. Suchomel",
    "William P. Ebben"
  ],
  "year": 2012,
  "doi": "10.1519/JSC.0b013e3182472fad",
  "pmid": "22237139",
  "url": "https://doi.org/10.1519/JSC.0b013e3182472fad"
}
```

Registry scope: fifteen resistance-trained women performed four 45.72-cm
step-up directions at 6-RM load while seven lead-limb hip/thigh muscles were
recorded. It supports family-level triple-extension and muscle-context review;
the unreported load implement/placement, different height, and different
lead-foot transition prevent it from activating a loaded fixture or serving as
exercise provenance for the 21-cm bodyweight record.

### `comfort-2015-forward-reverse-lunge-kinetics`

```json
{
  "id": "comfort-2015-forward-reverse-lunge-kinetics",
  "sourceType": "experimentalKinematicsKineticsStudy",
  "title": "Joint Kinetics and Kinematics During Common Lower Limb Rehabilitation Exercises",
  "authors": [
    "Paul Comfort",
    "Paul A. Jones",
    "Laura Constance Smith",
    "Lee Herrington"
  ],
  "year": 2015,
  "doi": "10.4085/1062-6050-50.9.05",
  "pmid": "26418958",
  "pmcid": "PMC4641539",
  "url": "https://doi.org/10.4085/1062-6050-50.9.05"
}
```

Registry scope: nine healthy men performed five bodyweight forward- and
reverse-lunge repetitions on each limb from upright bilateral standing with
the arms crossed, using a three-second eccentric and two-second concentric
cadence. In the forward condition the selected lead foot stepped onto the
second force plate, established whole-foot contact, descended to full
self-selected depth, and returned to the start. In the reverse condition the
contralateral foot stepped backward while the selected front foot remained
planted, then returned. Three-dimensional motion capture and two force plates
directly measured lead-limb hip, knee, and ankle angles, sagittal external
moments, and foot contact/off phases. The source contains no EMG, fixed joint
depth, external load, walking or alternating locomotion, lateral path, or jump;
the active role hierarchy is therefore a conservative mechanics-and-anatomy
assignment rather than a measured cross-muscle ranking.

## Activation and test gates

Activation should land as one integration change with the rest of Batch 5 and
must include all of the following:

1. Register the five evidence entries above with the disclosed limitations.
2. Rename the roadmap candidate from `split-stance-lunge` to
   `split-stance-squat` and record that family IDs name the stationary geometry
   while the Swift `lunge` pattern stays broader.
3. Update shared axis documentation only for values actually admitted by the
   three contracts; do not pre-author generic lunge or step-up values.
4. Assert exact fixed classification, allowed equipment/load modes, roster
   IDs, names, aliases, seeds, involvement, axes, and movement definitions.
5. Assert that every admitted enum value appears in the authored roster and
   that each numeric axis is pinned to its exact reviewed value.
6. Mutate each prime action and every forbidden action to prove the
   biomechanics validator rejects boundary violations.
7. Mutate each required muscle and role, including barbell-specific split-
   squat stabilizers and step-up trunk/pelvis stabilizers.
8. Pin Song's 100%-leg-length ankle sign/reversal rationale and Wang's full
   lead-foot step-down sequence in contract-specific tests or exact surface
   assertions.
9. Assert that the step-up remains `nonComparable`, has no positive effective
   bodyweight fraction, and has no `defaultWeightKg` requirement at zero load.
10. Assert that neither `Step-Up` nor another height-free alias is globally
    owned.
11. Assert that Simenz is family-level context and is absent from the active
    step-up exercise's evidence refs.
12. Keep the zero-rule families legal through required single-value axes; do
    not invent always-true exercise rules that cannot have contrasting roster
    fixtures.
13. Pin the two dynamic-lunge roster identities and exact source surface:
    bodyweight-only non-comparable load, upright crossed-arm bilateral start,
    three-second eccentric, two-second concentric, full self-selected depth,
    and return to bilateral standing.
14. Mutate every dynamic-lunge topology axis and both binding rules so the
    forward record cannot inherit the planted-front-foot reverse path and the
    reverse record cannot inherit the selected-lead landing path.
15. Assert that both lunge records carry the exact three-action prime set and
    conservative role envelope, while walking/alternating, stationary, loaded,
    lateral, crossover, and jump variants remain absent.
16. Run the catalog validator, focused Batch-5 tests, full Python catalog test
    suite, generated-output check, and iOS compile gate.

## Remaining blockers and deliberately unresolved decisions

- MacAskill's adverse bodyweight evidence cannot enter `evidence.json` until
  the registry permits a reviewed non-DOI identifier. The prose disclosure
  must remain visible in the meantime.
- The Simenz 45.72-cm loaded record remains blocked until the resistance
  implement and placement are established from a primary source.
- No effective bodyweight fraction is available for the exact Wang step-up;
  load-based analytics remain intentionally unavailable.
- The two active dynamic-lunge records do not authorize walking or alternating
  lunges. Continuous locomotion still needs direct fixture evidence and an
  explicit between-repetition support contract.
- The 21-cm task is a research-specific stepping sequence, not permission to
  rename the record to generic `Step-Up` after activation.
