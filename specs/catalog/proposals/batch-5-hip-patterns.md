# Batch 5 — hip-pattern compound review

Status: final. `hip-hinge` is active with one barbell good morning, and
`hip-thrust-bridge` is active with one barbell hip thrust plus one barbell
glute bridge. The hinge activation follows Schellenberg et al.'s directly
measured good-morning fixture; it does not revive the rejected static-knee
Romanian-deadlift draft. Neither review surveys every exercise commonly given
these names.

## Outcome

| Candidate | Decision | Initial roster |
|---|---|---:|
| `hip-hinge` | Activate the exact Schellenberg good-morning fixture | 1 |
| `hip-thrust-bridge` | Activate after shared Batch-5 integration gates pass | 2 |

The active contracts use the current split taxonomy. Their three-record roster
is the smallest set that exercises the reviewed mechanical boundaries without
treating equipment substitutions as facts.

## Boundary matrix

| Boundary | `hip-hinge` | `hip-thrust-bridge` | Outside owner |
|---|---|---|---|
| Main proximal motion | Pelvis and torso hinge over planted feet, then extend together | Loaded pelvis rises between planted feet and an upper-torso anchor | `hip-extension` moves the femur relative to a supported, held pelvis |
| Knee behavior | Small measured excursion is disclosed but does not define the task | Knee extension accompanies hip extension | Squat, lunge, step-up, and knee-extension-heavy floor pulls |
| Spine claim | Measured segmental excursion makes `spine.extension` an explicit prime | Pelvic-trunk excursion was variable and is explicitly nonstandardized | A position-held spine cannot be inferred from a posture cue |
| Inter-repetition support | None; the bar remains on the athlete for eight repetitions | Plates return to the floor in the reviewed full-range fixtures | Floor pulls require a separately reviewed branch |
| Initial load | Free barbell across the posterior shoulder/upper-back surface at 25% of body mass | Free padded barbell across the pelvis | Smith, lever machine, band, dumbbell, cable, and bodyweight branches are deferred |
| Initial stance | Symmetric, shoulder-width, and slightly externally turned | Symmetric bilateral | Unilateral and staggered variants require separate stability review |

This makes family membership depend on segment and joint behavior rather than
the word “deadlift,” “bridge,” or “glute.”

## Shared Batch-5 vocabulary

The active contracts reuse the Batch-5 axis names wherever the underlying fact
is the same:

- `stanceConfiguration: symmetricBilateral` describes topology, while the
  separate `stanceWidth` axis records the directly reviewed shoulder-width
  good-morning and thrust/bridge setups;
- `rangeOfMotion` names a reviewed endpoint convention rather than an
  unmeasured universal joint angle;
- `interRepSupport` says whether an external surface supports the load between
  repetitions;
- `footContact: continuous` says the feet remain planted; and
- `loadPlacement` records hands-in-front versus across-pelvis loading.

The active contract also retains Batch 4's `movingSegment` spelling and sets
it to `pelvis`; it does not invent a thrust-specific synonym for the externally
loaded proximal segment that rises relative to the planted lower limbs.

`kineticChain: closed` is lower-limb-relative in both active families: the feet
are the fixed distal contacts while the pelvis and proximal segments move. It
says nothing about whether the external barbell path is fixed. `fixedPath`
retains the existing external-load definition and is `false` for all three
active fixtures.

## Family 1: `hip-hinge`

### Exact fixture and action boundary

Schellenberg et al. directly measured a bilateral barbell good morning using a
12-camera motion-capture system, force plates, 55 body markers, 22 additional
spinal markers, and two bar markers. Thirteen experienced trainees performed
eight repetitions with additional barbell load equal to 25 percent of body
mass. The standardized setup used shoulder-width feet with a slight natural
toe-out, a free bar across the posterior shoulder and upper-back surface, a
comfortable hand position, no external torso support, and the same normal
self-selected speed during descent and ascent. The bar remained on the athlete
between repetitions.

The family uses `hip.extension` as its sagittal plane-basis action and declares
both `hip.extension` and `spine.extension` as primes. Schellenberg et al.
reported 58.4 +/- 10.0 degrees of hip range, 16.8 +/- 4.7 degrees of
pelvis-lumbar range, and 8.9 +/- 3.8 degrees of lumbar-thoracic range during the
good morning. The instruction to preserve a natural spine therefore cannot be
encoded as `positionHeld`: measured segmental motion is material and reverses
during the ascent.

The measured knee range was 7.8 +/- 5.5 degrees, with maximum knee flexion of
5.3 +/- 6.7 degrees. That small but nonzero excursion is recorded as
`measuredSmallNondefiningExcursion`; it is neither falsely called held nor
promoted to `knee.extension`. The family remains mechanically distinct from a
squat or floor pull because knee motion is not a training-defining action and
the load never returns to an external support. No net knee moment or technique
label is used as a substitute for an angular prime action.

The source uses both “upper trapezius” in its method summary and “rear
deltoid” in its standardized instruction. The contract therefore records the
placement conservatively as `posteriorShoulderUpperBack` rather than claiming
a more precise contact site that the paper itself does not resolve.

### Role policy and limitations

`medialHamstrings`, `gluteMax`, and `lumbarExtensors` are non-ranked
co-primaries. The first two satisfy the explicit hip-extension action and the
third satisfies the explicit spine-extension action. This categorical policy
comes from the measured action topology plus the registered lower-limb and
lumbar anatomy profiles. Schellenberg et al. did not collect EMG, so the
contract does not claim that these three regions had equal activation or rank
their relative contribution.

The scene's `bicepsFemoris` region combines the biarticular long head and
monoarticular short head. It therefore receives knee-control stabilizer credit
only; the contract does not project a whole-region hip-extension prime from
the long head. `gluteMed`, `abs`, and `obliques` provide conservative pelvis
and trunk control. `gastrocnemius` and `soleus` cover the materially planted
knee, ankle, and foot demands without creating an ankle prime. The free bar
also makes shoulder, scapular, elbow, wrist, and hand control material, covered
by the established `externalRotators`, `trapeziusUpper`, `brachialis`,
`fingerFlexors`, and `extensorCarpiRadialis` stabilizer convention. These are
mechanics- and anatomy-derived assignments, not condition-matched EMG claims.

The source prescribes a body-mass-relative external barbell load, while the
runtime seed is a fixed mass. The study cohort averaged 80.1 kilograms, so the
record uses a representative 45-pound / 20-kilogram seed, approximately 25
percent of that mean, and explicitly instructs the athlete to replace it with
25 percent of their own body mass. `loadMode` remains `external`; the seed is
product initialization rather than a bodyweight fraction or a
`nonComparable` load.

### Explicit exclusions and deferrals

| Exercise | Decision | Reason |
|---|---|---|
| Conventional and sumo deadlift | Defer | Directly reviewed versions add large knee excursion and floor-pull mechanics. |
| Hex/trap-bar deadlift | Defer | Handle geometry and knee-extensor demand move it toward the squat boundary. |
| Stiff-leg deadlift | Defer | Extended-knee posture and floor relationship require their own role and range review. |
| Deficit or step RDL | Defer | Coratella measured it, but the elevated range materially changed posterior-chain excitation. |
| Romanian deadlift | Defer | Reviewed fixtures show material knee excursion, and floor/no-floor conventions vary; none is silently generalized from the good morning. |
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
| `barbell-hip-thrust` | 35.5 cm bench at inferior scapular region | 90° flexion | 95 lb / 42.5 kg; 8 reps | gluteMax P; vasti S; bicepsFemoris, gluteMed, lumbarExtensors, soleus St |
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
capability while no abduction prime action is claimed. `lumbarExtensors` is the
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

The active families require the Schellenberg, Brazil, and Kennedy IDs below.
The Coratella, Lee, and Lyons studies remain reviewed adverse or boundary
evidence for excluded Romanian and stiff-leg variants; they must not be
registered merely because they were reviewed, because unused registry entries
fail evidence-coverage validation.

### `schellenberg-2013-deadlift-goodmorning-kinematics`

- Source type: `experimentalKinematicsKineticsStudy`
- Title: *Kinetic and kinematic differences between deadlifts and
  goodmornings*
- Authors: Florian Schellenberg; Julia Lindorfer; Renate List; William R.
  Taylor; Silvio Lorenzetti
- Year: 2013
- DOI: `10.1186/2052-1847-5-27`
- PMID: `24314057`
- PMCID: `PMC3878967`
- URL: `https://doi.org/10.1186/2052-1847-5-27`
- Scope: Nine male and four female experienced trainees performed eight good
  mornings with external barbell load equal to 25 percent of body mass.
  Twelve-camera three-dimensional motion capture, force plates, 55 body
  markers, 22 additional spinal markers, and two bar markers quantified hip,
  knee, pelvis-lumbar, and lumbar-thoracic motion. The fixture directly
  supports the active bilateral standing topology, small but nonzero knee
  excursion, material segmental spine excursion, no inter-repetition support,
  free external bar path, and exact load and repetition prescription. It did
  not collect EMG, did not compare equipment substitutions, and does not prove
  that the anatomy-derived co-primary regions had equal or ranked activation.

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
  its floor-touch instruction is not evidence for the active good-morning
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

1. Register the exact Schellenberg, Brazil, and Kennedy evidence entries and
   reference each at least once; leave the three rejected Romanian/stiff-leg
   review sources out of the registry.
2. Validate the exact one-record hinge and two-record thrust/bridge rosters plus
   global catalog-ID, name, and alias uniqueness.
3. Pin the exact 42-action forbidden complement for each family and prove the
   hinge has exactly `hip.extension` plus `spine.extension` as primes, with no
   knee prime.
4. Mutate every required muscle assignment in both families independently and
   prove rejection, including each of the hinge's three non-ranked
   co-primaries and the stabilizer-only biceps-femoris region.
5. Prove every required discrete axis value appears in the authored rosters;
   directly mutate each one-record hinge invariant and require a specific
   diagnostic.
6. Pin the hinge's exact 25-percent-body-mass external-load prescription,
   representative 45-pound / 20-kilogram seed, eight repetitions, bilateral
   shoulder-width slightly toe-out stance,
   posterior-shoulder/upper-back placement, no inter-repetition support, and
   free path.
7. Prove hinge knee motion remains
   `measuredSmallNondefiningExcursion`, spine motion remains
   `extendsWithMeasuredSegmentalExcursion`, and neither can be rewritten as
   `positionHeld`.
8. Mutate each hip-thrust/bridge JSON rule assertion and required/absent field
   independently; each rule must also retain a contrasting exercise.
9. Prove the 90/115 thrust/bridge knee endpoints cannot swap and no intermediate
   numeric value enters without a new reviewed rule branch.
10. Prove hip thrust/bridge requires knee extension but rejects every ankle and
   spine action as a prime.
11. Keep the explicit `spineMotion: nonstandardized` and `ankleMotion:
    nonstandardized` disclosures; do not rewrite either to `positionHeld`
    merely for vocabulary symmetry.
12. Confirm the shared Batch-5 spellings for `stanceConfiguration`,
    `rangeOfMotion`, `interRepSupport`, `footContact`, and `loadPlacement` in
    the families README.
13. Run the catalog validator, full Python catalog suite, `git diff --check`,
    and the required generic iOS simulator build after shared integration.
