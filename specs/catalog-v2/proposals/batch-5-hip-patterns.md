# Batch 5 — hip-pattern compound review

Status: mixed final outcome. `hip-thrust-bridge` is active with one barbell hip
thrust plus one barbell glute bridge. `hip-hinge` is deferred: the
direct Romanian-deadlift kinematics show material knee excursion, so the
existing `positionHeld` vocabulary cannot encode the desired strict static-
knee boundary. Neither review surveys every exercise commonly given these
names.

## Outcome

| Candidate | Decision | Initial roster |
|---|---|---:|
| `hip-hinge` | Defer — material knee excursion conflicts with the proposed contract | 0 |
| `hip-thrust-bridge` | Activate after shared Batch-5 integration gates pass | 2 |

The active contract uses the post-Batch-4 52-region taxonomy. This review does
not inspect the legacy catalog. Its roster is the smallest set that exercises
the reviewed mechanical boundary without treating equipment substitutions as
facts.

## Boundary matrix

| Boundary | `hip-hinge` | `hip-thrust-bridge` | Outside owner |
|---|---|---|---|
| Main proximal motion | Pelvis and torso rotate together over planted feet | Loaded pelvis rises between planted feet and an upper-torso anchor | `hip-extension` moves the femur relative to a supported, held pelvis |
| Knee behavior | Intended: slightly flexed and materially held; no reviewed fixture yet satisfies it | Knee extension accompanies hip extension | Squat, lunge, step-up, and knee-extension-heavy floor pulls |
| Spine claim | Intended: position-held; deferred with the family | Pelvic-trunk excursion was variable and is explicitly nonstandardized | Deliberate spinal extension belongs to a future spine family |
| Inter-repetition support | Intended: none; no active fixture | Plates return to the floor in the reviewed full-range fixtures | Floor pulls require a separately reviewed branch |
| Initial load | Candidate free barbell in the hands | Free padded barbell across the pelvis | Smith, lever machine, band, dumbbell, cable, and bodyweight branches are deferred |
| Initial stance | Candidate symmetric bilateral | Symmetric bilateral | Unilateral and staggered variants require separate stability review |

This makes family membership depend on segment and joint behavior rather than
the word “deadlift,” “bridge,” or “glute.”

## Shared Batch-5 vocabulary

The active thrust/bridge contract reuses the Batch-5 axis names wherever the
underlying fact is the same. The deferred hinge notes preserve the same
candidate spellings for a future resolvable contract:

- `stanceConfiguration: symmetricBilateral` describes topology, while the
  separate `stanceWidth` axis records the directly reviewed hip-width RDL and
  shoulder-width thrust/bridge setups;
- `rangeOfMotion` names a reviewed endpoint convention rather than an
  unmeasured universal joint angle;
- `interRepSupport` says whether an external surface supports the load between
  repetitions;
- `footContact: continuous` says the feet remain planted; and
- `loadPlacement` records hands-in-front versus across-pelvis loading.

The active contract also retains Batch 4's `movingSegment` spelling and sets
it to `pelvis`; it does not invent a thrust-specific synonym for the externally
loaded proximal segment that rises relative to the planted lower limbs.

`kineticChain: closed` is lower-limb-relative in the active family: the feet
are the fixed distal contacts while the pelvis and proximal segments move. It
says nothing about whether the external barbell path is fixed. `fixedPath`
retains the existing external-load definition and is `false` for both active
fixtures. A future hinge should reuse those meanings if its evidence gate is
resolved.

## Family 1: `hip-hinge` — deferred

### Intended contract

The intended contract would use `hip.extension` as its only prime and plane-
basis action. The knees would start slightly flexed and show no material joint
excursion, while the spine remained position-held. That is the desired boundary
from a squat or floor pull. The reviewed Romanian-deadlift fixtures do not meet
it, so no family JSON or exercise record activates.

The rejected draft fixture was a bilateral hip-width, shoulder-width double-
overhand barbell Romanian deadlift with no floor reset. It is not an approved
roster record, alias set, seed, or role envelope.

Any future role decision must remain deliberately regional. Coratella et al.
directly measured semitendinosus, biceps femoris, gluteus maximus, gluteus
medius, longissimus, and iliocostalis in trained bodybuilders. Romanian
deadlift produced greater semitendinosus excitation than the stiff-leg
condition, while the stiff-leg condition produced greater glute-max
excitation. That makes the visible `medialHamstrings` region a candidate
primary and `gluteMax` a candidate secondary, but EMG does not repair the
missing motion contract.
Semimembranosus was not separately measured; it shares the same authored hip-
extension capability and the body asset intentionally combines it with
semitendinosus in `medialHamstrings`, so this remains a visible-region credit
rather than a claim that the two muscles had equal EMG amplitude.

The experiment measured biceps femoris, but the scene has one unsplit
biceps-femoris mesh. The catalog cannot truthfully give the whole region the
long head's hip-extension action because the same mesh includes the
monoarticular short head. It therefore receives only held-knee stabilizer
credit if a fixture later activates. `gluteMed` and `lowerBack` remain
candidate directly measured pelvis/hip and spine-control roles. Static bar
control would use the established loaded-grip `fingerFlexors` and
`extensorCarpiRadialis` convention without adding dynamic finger or wrist prime
actions.

### Activation blocker

Coratella et al. introduce Romanian and stiff-leg deadlifts as isometric-knee
variations and distinguish the Romanian version by a slightly flexed knee, but
their technique paragraph says participants finished by fully extending both
knees and hips. Lee et al. prescribed approximately 15 degrees of knee flexion,
required floor contact, and reported 33.86 ± 12.59 degrees of knee flexion.
Lyons et al. then directly measured about 33 degrees of knee range of motion in
participants' typical Romanian-deadlift technique at 50 percent one-repetition
maximum. That is material excursion, not measurement noise.

The shared catalog meaning of `positionHeld` is no material joint excursion;
it cannot be locally weakened to mean merely “do not squat much.” Adding
`knee.extension` would accurately describe the reviewed fixtures but would
erase the intended strict hinge/squat boundary unless a reviewed quantitative
band and muscle policy represented it. Net knee moment or muscle activity
cannot by itself prove angular knee extension. The family therefore remains
absent until one of two evidence paths succeeds:

1. direct condition-matched kinematics establish a reproducible, materially
   held-knee RDL fixture with no floor reset; or
2. a reviewed small-knee-extension hinge branch defines a quantitative motion
   band, proves why that band remains distinct from squat/floor-pull mechanics,
   and supports the corresponding knee-extensor role policy.

### Explicit exclusions and deferrals

| Exercise | Decision | Reason |
|---|---|---|
| Conventional and sumo deadlift | Defer | Directly reviewed versions add large knee excursion and floor-pull mechanics. |
| Hex/trap-bar deadlift | Defer | Handle geometry and knee-extensor demand move it toward the squat boundary. |
| Stiff-leg deadlift | Defer | Extended-knee posture and floor relationship require their own role and range review. |
| Deficit or step RDL | Defer | Coratella measured it, but the elevated range materially changed posterior-chain excitation. |
| Good morning | Defer | Posterior-shoulder load placement and measured lumbar excursion need their own rules. |
| Dumbbell, kettlebell, cable, Smith RDL | Defer | No reviewed source establishes equivalence to the active barbell path and grip contract. |
| Single-leg or staggered RDL | Defer | Pelvic and frontal/transverse stability demands differ. |
| Kettlebell swing | Exclude | Ballistic power and deliberate momentum are not the reviewed controlled dynamic-strength task. |
| Back extension | Exclude | External support changes the moving segments and joint relationship. |

## Family 2: `hip-thrust-bridge`

### The knee-extension correction

The family has two prime actions: `hip.extension` and `knee.extension`.
Brazil et al. measured the barbell hip thrust and found about 21 ± 7 degrees of
knee extensor range during the lifting phase, along with a substantial knee
extensor demand. Kennedy et al. likewise describe simultaneous knee and hip
extension and report greater vastus-lateralis activity for hip thrust than
bridge. Calling the knee “held” would be biomechanically false and would blur
the boundary with the active open-chain `hip-extension` isolation family.

Ankle plantarflexion is not promoted to a prime action. Brazil et al. observed
predominantly dorsiflexion during the lifting phase, with some participants
transitioning toward plantarflexion late, while ankle kinetics were small and
varied in moment direction. The contract therefore records `ankleMotion:
nonstandardized`: observed joint excursion is not position-held, but neither
that excursion nor a variable net moment establishes a universal,
training-defining dynamic ankle action.

### Pelvic-trunk disclosure

Brazil et al. found average pelvic-trunk extension of approximately 12 ± 21
degrees and both flexion- and extension-direction behavior across
participants. The active data therefore do not prove a zero-motion spine.
They also do not prove that deliberate spinal extension defines the exercise.
The contract records `spineMotion: nonstandardized`, retains a spine stability
demand, and forbids spinal extension as a prime action. This is an explicit
evidence limitation, not an invitation to coach lumbar extension.

### Exact roster

| Catalog ID | Upper-torso anchor | Reviewed knee endpoint | Seed | Roles |
|---|---|---:|---:|---|
| `barbell-hip-thrust` | 35.5 cm bench at inferior scapular region | 90° flexion | 95 lb / 42.5 kg; 8 reps | gluteMax P; vasti S; bicepsFemoris, gluteMed, lowerBack, soleus St |
| `barbell-glute-bridge` | upper torso on floor | approximately 115° flexion | 95 lb / 42.5 kg; 10 reps | same categorical envelope |

The four reciprocal rules prevent the numeric range from admitting arbitrary
intermediate fixtures: bench support requires the elevated hip-thrust position,
90-degree endpoint, and reviewed bench height; floor support requires the
floor-bridge position, 115-degree endpoint, and absence of bench height.

Glute max is the sole primary. Brazil measured hip extensor demand as larger
than knee and pelvic-trunk extensor demands. Kennedy measured both upper and
lower glute-max sites and found the bridge produced higher peak and mean
amplitudes than hip thrust, but this does not justify splitting the one visible
glute-max region or changing its categorical role. Vasti are secondary in both:
the hip thrust has direct knee kinetics and much higher vastus-lateralis EMG,
while the bridge still has a smaller knee-extension component and measurable
vastus activity.

Kennedy measured biceps femoris, but the unsplit-region limitation again bars
dynamic hip-extension credit. Its anatomy profile permits the conservative
knee-control stabilizer role. Glute medius was also directly measured; its
profile, rather than EMG magnitude alone, supplies the hip/pelvis stabilizer
capability while no abduction prime action is claimed. `lowerBack` is the
conservative anatomy- and mechanics-derived spine-control provider; it was not
measured as a muscle and is not being called a dynamic extensor from Brazil's
net pelvic-trunk moment. The continuously planted feet materially transmit the
force while Brazil observed nonstandardized ankle motion, so ankle and foot
remain stability demands. `soleus` is the smallest conservative provider for
both regions under the anatomy profile; this stabilizer assignment is
mechanics-derived, not condition-matched EMG and not a plantarflexion prime
action. Kennedy explicitly reports a comfortable supinated grip used to steady
the pelvic bar in both fixtures, so the setup is encoded. The pelvis bears the
load, however: no wrist/hand demand or loaded-grip muscle credit is fabricated
from that incidental steadying contact.

### Explicit exclusions and deferrals

| Exercise | Decision | Reason |
|---|---|---|
| Bodyweight glute bridge | Defer | The active contract has external load and no reviewed bodyweight-fraction semantics. |
| Dumbbell bridge or thrust | Defer | Load-interface and stable-load geometry were not tested. |
| Smith or lever-machine hip thrust | Defer | Fixed path, mechanism, and support constraints require new axes and direct review. |
| Band-resisted or American hip thrust | Defer | Resistance direction and endpoint technique differ from the active padded-barbell fixtures. |
| Single-leg bridge or thrust | Defer | Adds unilateral pelvis and trunk-control demands. |
| Feet-elevated bridge | Defer | Changes support height, joint angles, and hamstring contribution. |
| Frog pump or band-abduction thrust | Exclude | Adds abduction/external-rotation geometry not present in this sagittal contract. |
| Articulated spinal bridge | Exclude | Deliberate sequential spinal motion belongs outside this hip/knee compound contract. |

## Evidence metadata

The active thrust/bridge family requires the final two IDs below. The first
three are reviewed hold evidence and must not be registered merely because
they were reviewed; unused registry entries fail evidence-coverage validation.

### `coratella-2022-romanian-step-stiff-leg-deadlift`

- Source type: `experimentalEMGStudy`
- Title: *An Electromyographic Analysis of Romanian, Step-Romanian, and
  Stiff-Leg Deadlift: Implication for Resistance Training*
- Authors: Giuseppe Coratella; Gianpaolo Tornatore; Stefano Longo; Fabio
  Esposito; Emiliano Cè
- Year: 2022
- DOI: `10.3390/ijerph19031903`
- PMID: `35162922`
- PMCID: `PMC8835508`
- URL: `https://doi.org/10.3390/ijerph19031903`
- Scope: Ten competitive bodybuilders performed barbell Romanian, 15-cm-step
  Romanian, and stiff-leg deadlifts at 80 percent one-repetition maximum.
  Surface EMG measured gluteus maximus, gluteus medius, biceps femoris,
  semitendinosus, longissimus, and iliocostalis in both phases. It supports the
  posterior-chain panel, initial Romanian-deadlift role emphasis, and static-
  versus extended-knee vocabulary; it does not prove a literal zero-degree
  knee excursion, other equipment, unilateral geometry, or a universal depth.

### `lee-2018-conventional-romanian-deadlift`

- Source type: `experimentalKinematicsEMGStudy`
- Title: *An electromyographic and kinetic comparison of conventional and
  Romanian deadlifts*
- Authors: Sangwoo Lee; Jacob Schultz; Joseph Timgren; Katelyn Staelgraeve;
  Michael Miller; Yuanlong Liu
- Year: 2018
- DOI: `10.1016/j.jesf.2018.08.001`
- PMID: `30662500`
- PMCID: `PMC6323186`
- URL: `https://doi.org/10.1016/j.jesf.2018.08.001`
- Scope: Twenty-one trained men performed conventional and Romanian deadlifts
  at the same 70-percent Romanian-deadlift one-repetition-maximum load while
  three-dimensional motion, ground reaction force, joint kinetics, and rectus
  femoris, biceps femoris, and gluteus-maximus EMG were collected. It directly
  supports the hip-dominant versus knee-extension-heavy floor-pull boundary;
  its floor-touch instruction is not evidence for the active no-floor-reset
  geometry or a static numeric knee angle.

### `lyons-2026-conventional-romanian-deadlift`

- Source type: `experimentalKinematicsEMGStudy`
- Title: *The effects of the conventional deadlift and Romanian deadlift on
  muscle activation and joint angles at a submaximal intensity*
- Authors: Michelle Lyons; Louise Burnie; Liam T. Pearson; Gill Barry
- Year: 2026 issue (published online 2025-02-14)
- DOI: `10.19164/gjsscmr.v2i1.1595`
- URL: `https://doi.org/10.19164/gjsscmr.v2i1.1595`
- Scope: Fifteen recreationally active adults performed their typical
  conventional and Romanian deadlift techniques at 50 percent of self-reported
  or estimated Romanian-deadlift one-repetition maximum. Sagittal two-
  dimensional motion analysis measured hip, knee, and ankle angles while
  surface EMG measured biceps femoris and vastus lateralis. The approximately
  33-degree Romanian-deadlift knee range is direct adverse evidence against a
  `positionHeld` contract; the study did not coach or isolate a strict static-
  knee, no-floor-reset fixture and therefore cannot activate one.

### `brazil-2021-barbell-hip-thrust`

- Source type: `experimentalKinematicsKineticsStudy`
- Title: *A comprehensive biomechanical analysis of the barbell hip thrust*
- Authors: Adam Brazil; Laurie Needham; Jac L. Palmer; Ian N. Bezodis
- Year: 2021
- DOI: `10.1371/journal.pone.0249307`
- PMID: `33780488`
- PMCID: `PMC8006986`
- URL: `https://doi.org/10.1371/journal.pone.0249307`
- Scope: Nineteen resistance-trained men performed three barbell hip-thrust
  repetitions at 70 percent one-repetition maximum with three-dimensional
  kinematics and force plates under both feet and the thorax support. It
  supports hip and knee extension, the dominant hip-extensor demand, observed
  but nonstandardized ankle motion with negligible and inconsistent kinetics,
  free bar path, and the disclosure that pelvic-trunk excursion was variable.
  It does not supply muscle-specific EMG, a bridge fixture, or zero-motion
  spine or ankle claims.

### `kennedy-2024-hip-thrust-glute-bridge`

- Source type: `experimentalEMGStudy`
- Title: *Electromyographic differences of the gluteus maximus, gluteus
  medius, biceps femoris, and vastus lateralis between the barbell hip thrust
  and barbell glute bridge*
- Authors as published: D. Kennedy; J. B. Casebolt; G. L. Farren; V. Fiaud;
  M. Bartlett; L. Strong
- Year: 2024 issue (published online 2022-05-19)
- DOI: `10.1080/14763141.2022.2074875`
- PMID: `35586943`
- URL: `https://doi.org/10.1080/14763141.2022.2074875`
- Scope: Ten trained men performed five-repetition-maximum barbell hip thrusts
  and glute bridges. The study standardized shoulder-width feet, a 35.5-cm
  thrust bench, 90-degree thrust endpoint, 135-degree bridge starting knee
  angle, approximately 115-degree bridge endpoint knee flexion, floor versus
  bench torso anchors, padded pelvic bar placement,
  supinated stabilizing grip, and hip-neutral endpoint while measuring upper
  and lower glute max, glute medius, biceps femoris, and vastus lateralis. It
  uses the study's knee-flexion angle convention and
  supports both active fixtures and categorical roles, not bodyweight,
  unilateral, machine, or band variants or precise spinal kinematics.

## Activation and mutation gates

1. Register the exact Brazil and Kennedy evidence entries and reference each
   at least once; leave the three hinge hold sources out of the registry.
2. Validate the exact two-record thrust/bridge roster plus global name/alias
   uniqueness, and prove `hip-hinge.json` remains absent.
3. Pin the 42-action thrust/bridge forbidden complement.
4. Mutate every thrust/bridge required muscle assignment independently and
   prove rejection.
5. Prove every thrust/bridge discrete axis value appears in the authored roster.
6. Mutate each hip-thrust/bridge JSON rule assertion and required/absent field
   independently; each rule must also retain a contrasting exercise.
7. Prove the 90/115 knee endpoints cannot swap and no intermediate numeric
   value enters without a new reviewed rule branch.
8. Pin the hinge evidence hold: no active family may substitute “training
   intent” for the shared no-material-excursion meaning of `positionHeld`.
9. Prove hip thrust/bridge requires knee extension but rejects every ankle and
   spine action as a prime.
10. Keep the explicit `spineMotion: nonstandardized` and `ankleMotion:
    nonstandardized` disclosures; do not rewrite either to `positionHeld`
    merely for vocabulary symmetry.
11. Confirm the shared Batch-5 spellings for `stanceConfiguration`,
    `rangeOfMotion`, `interRepSupport`, `footContact`, and `loadPlacement` in
    the families README.
12. Run the catalog validator, full Python catalog suite, `git diff --check`,
    and the required generic iOS simulator build after shared integration.
