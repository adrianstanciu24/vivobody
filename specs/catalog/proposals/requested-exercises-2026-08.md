# Requested exercise expansion — August 2026

Status: all ten source-bounded fixtures are active. Six were activated on
2026-08-27; Kneeling Cable Crunch, Hollow Hold, Passive Dead Hang, and Active
Dead Hang followed on 2026-08-28 after the evidence policy was made
proportional.

## Outcome

The original request contained nine named items. The owner later corrected
Flexed-Arm Hang to a straight-arm hang and requested both passive and active
shoulder positions. That replaces one candidate with two, so the current scope
contains ten exact fixtures. None is a duplicate or safe alias of an active
record, and none fits an active family contract unchanged.

| Requested exercise | Outcome | Owner | Reason |
|---|---|---|---|
| Nordic Curl | Activated | New `nordic-curl` family plus shared phase-schema expansion | The source-exact repetition yields through knee extension, then actively returns through knee flexion; the approved capability is phase-bound to produced-plus-yielding dynamic-strength records. |
| Kneeling Cable Crunch | Activated | `spine-flexion` expansion | ACE directly defines the conventional tall-kneeling high-rope fixture; hips-held and support-chain roles are disclosed catalog inferences. |
| Preacher Curl | Activated as Barbell Preacher Curl | `elbow-flexion` expansion | “Preacher Curl” is implement-ambiguous; the activated fixture is specifically a bilateral barbell preacher curl with unreported bar shape and pad angle. |
| Incline Dumbbell Curl | Activated as Bilateral Incline Dumbbell Curl | `elbow-flexion` expansion | The activated fixture uses a 45-degree bench and held supination; simultaneous bilateral movement is an explicit catalog adaptation because source sequencing is unreported. |
| Mid-Thigh Clean Pull | Activated as Barbell Mid-Thigh Clean Pull | New `mid-thigh-clean-pull` family | It omits the pull-under and catch and cannot inherit the Power Clean phase or muscle contract. |
| Full Clean | Activated as Barbell Squat Clean | New `squat-clean` family | A full front-squat receive and recovery are deliberately excluded by the active `power-clean` identity and contract. |
| Full Snatch | Activated as Barbell Squat Snatch | New `full-snatch` family | Its floor first pull and full overhead-squat receive/recovery differ from Hang Power Snatch; the second pull and pull-under overlap. |
| Hollow Hold | Activated | New `hollow-hold` family | The official standard defines the exact long-lever shape; component research and existing anatomy support bounded categorical roles without an exact-fixture ranking. |
| Passive Dead Hang | Activated | New `passive-dead-hang` family | The exact relaxed-shoulder fixture resists finger opening and uses conservative support-chain roles; involvement is not treated as an exhaustive passive-tissue atlas. |
| Active Dead Hang | Activated | New `active-dead-hang` family plus `hang` pattern | The exact active-shoulder fixture resists scapular elevation and finger opening without being mislabeled as a Vertical Pull. |

Bundled workout history is keyed by stable `catalogID`, never by canonical name
or alias. The integration uses implement-specific IDs and canonical names so
users do not log mechanically incompatible variants into one series; token
search finds the requested generic words without consuming a globally unique
alias.

Product consequences stay explicit: external-load dynamic curls receive the
ordinary load/repetition records, tonnage, e1RM, RIR, and hard-set treatment;
Nordic Curl receives unranked repetitions and authored hard-set credit but no
load-based PR; Power exercises receive load/repetition records and tonnage but
no e1RM, RIR, or hard-set credit. The three activated Power records remain
excluded from routine-builder hard-set selection, while Nordic and both curls
follow the existing strength-exercise eligibility. Hollow Hold and both hangs
use duration-only bodyweight logging with no comparable load, tonnage, e1RM,
RIR, or stale pounds.

## Candidate fixtures

### Nordic Curl

- **Canonical name and aliases:** `Nordic Curl`; no aliases; active ID
  `nordic-curl`.
- **Exact setup and movement:** bilateral tall kneeling with the lower legs
  fixed by a partner; hips and trunk held neutral; three-second controlled
  forward knee extension followed by a three-second active, unassisted
  knee-flexion return over the achieved range. Hands do not reset the
  repetition.
- **Product semantics:** bodyweight, bilateral, `dynamicStrength`, repetitions,
  `nonComparable`, zero bodyweight fraction. The ankle fixation is support
  topology, not primary equipment. A fixed effective bodyweight would create
  false precision across body proportions and range. Product defaults: five
  repetitions and search priority 92.
- **Role boundary:** semitendinosus and biceps-femoris activity are measured
  directly. Mapping semitendinosus to the broader `medialHamstrings` region and
  categorizing both visible regions as knee-flexor primaries are disclosed
  anatomy/mechanics inferences, not a measured rank. Trunk and gluteal activity
  is supporting evidence, not a universal magnitude ranking.
- **Contract delta:** create a separate family and extend the shared family
  schema and validator to permit ordered yielding actions in
  `dynamicStrength`: yielding `knee.extension`, then produced `knee.flexion`.
- **Negative boundary:** eccentric-only repetitions with a hand-assisted reset,
  a hip-breaking razor curl or glute-ham raise, and Reverse Nordic remain
  separate fixtures.

### Kneeling Cable Crunch

- **Active fixture:** bilateral tall kneeling on the knees and shins, facing a
  high cable with a rope held stationary beside the head; hips and pelvis stay
  held while the spine flexes and returns under control.
- **Product semantics:** cable, external load, `dynamicStrength`, repetitions;
  30 lb / 15 kg by 12 and search priority 92.
- **Evidence and role boundary:** ACE directly defines the setup and execution.
  The held hip/pelvis constraint and categorical support-chain stabilizers are
  transparent anatomy-and-mechanics inferences, not measured rankings.
- **Contract integration:** expand `spine-flexion` with one required fixture
  discriminator and rules that keep the original 30-degree curl-up and cable
  branches exact rather than admitting a Cartesian product.
- **Negative boundary:** standing or seated cable crunches, arm-driven
  pulldowns, hip hinges, machine crunches, sit-ups, and oblique crunches.

### Barbell Preacher Curl

- **Canonical name and aliases:** `Barbell Preacher Curl`; no aliases; active
  ID `barbell-preacher-curl`. Token search still matches “Preacher Curl” without
  assigning the globally unique generic alias to one implement. Do not claim
  straight-bar or EZ-bar geometry because the defining source does not report
  bar shape.
- **Exact setup and movement:** bilateral barbell curl on a preacher apparatus,
  shoulder-width supinated grip, full elbow range, one-second concentric and
  two-second eccentric phases; pad angle is unreported and remains so.
- **Product semantics:** barbell, bilateral, `dynamicStrength`, repetitions,
  external load. Product defaults: 30 lb / 15 kg, ten repetitions, and search
  priority 90.
- **Role boundary:** biceps-brachii adaptation and elbow-flexion torque are
  direct. Brachialis, brachioradialis, grip, and wrist roles remain bounded
  anatomy/mechanics inference under the active Elbow Flexion policy.
- **Contract delta:** expand `elbow-flexion` with supported seated posture,
  upper-arm contact on a preacher pad, unreported pad angle, and an
  unreported-shape barbell handle. Preserve fixed supination and prohibit
  shoulder-generated motion as a fixture-defining mechanics inference.
- **Negative boundary:** dumbbell, cable, machine, EZ-bar-specific, spider,
  concentration, and Bayesian curls.

### Bilateral Incline Dumbbell Curl

- **Canonical name and aliases:** `Bilateral Incline Dumbbell Curl`; no aliases;
  active ID `bilateral-incline-dumbbell-curl`. The requested words
  remain discoverable through token search without claiming all incline curls.
- **Exact setup and movement:** lie against a 45-degree bench holding two
  dumbbells with both hands continuously fully supinated; begin with the
  forearms perpendicular to the floor and flex both elbows to 90–110 degrees.
  The source trained both arms but does not report simultaneous versus
  alternating sequencing. Moving both arms simultaneously is therefore an
  explicit catalog adaptation, not a measured protocol detail.
- **Product semantics:** dumbbell, bilateral, `dynamicStrength`, repetitions,
  external load. Product defaults: 15 lb / 7.5 kg, ten repetitions, and search
  priority 90.
- **Role boundary:** the source directly measures regional arm thickness but
  found no significant incline-group growth. Biceps-brachii long-head EMG is
  supporting evidence from a different unilateral 50-degree-trunk-
  hyperextension fixture. Brachialis, brachioradialis, grip, wrist, shoulder,
  scapular, and trunk roles remain bounded anatomy/mechanics inferences.
- **Contract delta:** expand `elbow-flexion` with 45-degree posterior bench
  support, shoulder-extended upper-arm posture, unstandardized scapular
  translation, held supination, and the disclosed bilateral-simultaneous
  catalog adaptation. Re-review the standing family's universal shoulder,
  scapular, and trunk stabilizer requirements.
- **Negative boundary:** standing, preacher, spider, Bayesian cable, hammer,
  rotating, and shoulder-swing curls.

### Barbell Mid-Thigh Clean Pull

- **Canonical name and aliases:** `Barbell Mid-Thigh Clean Pull`; aliases
  `Mid-Thigh Clean Pull` and `Clean Pull from Mid-Thigh`; active ID
  `barbell-mid-thigh-clean-pull`. Do not use `Mid-Thigh Pull`, which is also the
  established name of an isometric assessment.
- **Exact setup and movement:** lower a strapped barbell from the hang to
  midway between the patella and inguinal crease, pause without a
  countermovement, extend the ankles, knees, and hips and shrug upward while
  keeping the elbows extended, then place the bar on rack supports between
  repetitions. Use the individualized pronated clean-grip selection supplied
  by the NSCA/IWF technical standards; Comfort does not establish its width.
- **Product semantics:** barbell, bilateral, `power`, repetitions, external
  load. Straps and rack support are required fixture axes, not separate primary
  equipment. Product defaults: 45 lb / 20 kg, three repetitions, and search
  priority 90.
- **Role boundary:** triple-extension and shrug roles are mechanics-derived;
  the direct sources supply kinetics and kinematics, not EMG rankings. Elbow
  flexors must not inherit Power Clean's pull-under role.
- **Contract delta:** create a family with a paused mid-thigh start,
  straight-arm triple-extension/shrug phase, no pull-under, no receive, and
  rack-supported reset.
- **Negative boundary:** isometric mid-thigh pull, clean high pull with elbow
  flexion, floor clean pull, snatch-grip pull, and any clean with a catch.

### Barbell Squat Clean

- **Canonical name and aliases:** `Barbell Squat Clean`; aliases `Full Clean`
  and `Squat Clean`; active ID `barbell-squat-clean`. Do not reserve bare
  `Clean` as an exact alias while Power Clean remains an active neighboring
  search result.
- **Exact setup and movement:** bilateral pronated clean grip; floor start;
  first pull, transition/rebend, second pull, turnover, full front-squat catch,
  then recovery to standing.
- **Product semantics:** barbell, bilateral, `power`, repetitions, external
  load. Product defaults: 45 lb / 20 kg, three repetitions, and search priority
  95, below Barbell Power Clean and the canonical squat fixture for broad
  searches.
- **Role boundary:** specified lower-limb motion and EMG are direct. Every
  categorical role assignment, including upper-body and trunk roles, requires
  the field-by-field action-capability audit described below and is not an
  inherited magnitude ranking from Power Clean.
- **Contract delta:** create `squat-clean` rather than changing the active
  `power-clean` identity. The new owner records the full-squat catch and
  recovery phases. Recovery ankle plantarflexion is an explicit
  anatomy/mechanics inference rather than a Khuyagbaatar measurement. The
  observed transition/rebend is a required topology axis, not a separately
  credited prime phase because the reviewed evidence does not resolve its
  action mode.
- **Negative boundary:** Power Clean, Hang Clean, Clean Pull, Front Squat,
  Thruster, and the jerk phase of Clean and Jerk.

### Barbell Squat Snatch

- **Canonical name and aliases:** `Barbell Squat Snatch`; aliases `Full Snatch`
  and `Squat Snatch`; active ID `barbell-squat-snatch`. Do not reserve bare
  `Snatch` as an exact alias while Hang Power Snatch remains a neighboring
  search result.
- **Exact setup and movement:** bilateral wide pronated grip; floor start;
  first pull, transition/rebend, second pull, turnover/pull-under, full
  overhead-squat catch with extended elbows, then recovery to standing.
- **Product semantics:** barbell, bilateral, `power`, repetitions, external
  load. Product defaults: 45 lb / 20 kg, three repetitions, and search priority
  95, immediately below Barbell Hang Power Snatch.
- **Role boundary:** measured lower-limb EMG supports lower-body involvement;
  shoulder and scapular roles are bounded kinematic/anatomical inference and
  must not be presented as direct EMG rankings.
- **Contract delta:** create `full-snatch` with floor-start ordered phases and
  full overhead-squat receive/recovery. Reuse vocabulary only where the
  Hang Power Snatch and full-lift evidence actually agree.
- **Negative boundary:** Hang Power Snatch, floor Power Snatch, Hang Squat
  Snatch, Snatch Pull, and Overhead Squat.

### Hollow Hold

- **Exact fixture:** supine with no lumbar gap, posterior pelvic tilt, shoulder
  blades and straight legs raised from the floor, knees and elbows locked, and
  arms by the ears with active shoulders. “Shoulder blades raised from the
  floor” is a spatial setup description, not an authored
  `scapula.elevation` action.
- **Product semantics:** bilateral bodyweight
  `isometricStrength`, duration, `nonComparable`, and zero weight/fraction;
  30-second seed and search priority 94. It exposes no load, tonnage, e1RM, or
  RIR and ranks history by longest hold.
- **Evidence and role boundary:** CrossFit directly fixes the long-lever shape;
  Drysdale and Okubo support its posterior-pelvic-control and straight-leg-hold
  components. Resisted spine and hip extension plus categorical muscle roles
  are explicitly labeled anatomy-and-mechanics inference, not exact-fixture
  rankings.
- **Contract integration:** a separate `hollow-hold` owner; it does not inherit
  the plank-specific `anti-extension` support topology.
- **Negative boundary:** tuck hollow, Dead Bug, V-sit, dynamic leg raise,
  Curl-Up, and prone Plank.

### Passive Dead Hang

- **Canonical name and ID:** `Passive Dead Hang` / `passive-dead-hang`; no
  aliases. Bare `Dead Hang` remains intentionally unreserved because it does
  not distinguish the shoulder contract.
- **Exact setup and movement:** hang still from a horizontal pull-up bar with a
  bilateral shoulder-width closed pronated grip, feet unsupported, and elbows
  fully extended. Maintain the secure grip while allowing the shoulders to
  rise naturally toward the ears; do not deliberately depress the shoulder
  blades or cycle between shoulder positions.
- **Product semantics:** bodyweight `isometricStrength`, duration,
  `nonComparable`, and zero weight/fraction; 30-second seed, search priority
  94, arms grouping, and longest-hold history. User-facing copy must say
  “allow the shoulders to rise naturally,” not “relax completely,” because the
  grip remains active. No decompression or shoulder-health claim is authored.
- **Contract integration:** a separate compound `hang` owner with no prime
  actions and resisted `hand.fingerExtension`. Conservative grip and
  support-chain roles are disclosed anatomy-and-mechanics inferences. Catalog
  involvement is a training-contributor model, not an exhaustive passive-
  tissue atlas, so relaxed shoulder loading does not require invented benefits
  or a passive-tissue schema.
- **Evidence boundary:** Army and CrossFit standards establish the bar, closed
  overhand grip, straight arms, unsupported suspension, and naturally elevated
  shoulder posture; climbing-hang EMG supports grip involvement only.
- **Negative boundary:** Active Dead Hang, Scapular Pull-Up, flexed-arm hang,
  Pull-Up, climbing-edge hang, weighted hang, and foot-assisted hang.

### Active Dead Hang

- **Canonical name and ID:** `Active Dead Hang` / `active-dead-hang`; no
  aliases and no shared history with Passive Dead Hang.
- **Exact setup and movement:** use the same bilateral shoulder-width closed
  pronated bar grip, unsupported feet, and fully extended elbows, then hold the
  shoulder blades down with the shoulders away from the ears. Do not bend the
  elbows or repeatedly elevate and depress the shoulder blades.
- **Product semantics:** bodyweight `isometricStrength`, duration,
  `nonComparable`, and zero weight/fraction; 30-second seed, search priority
  92, back grouping, and longest-hold history. It exposes no load, tonnage,
  e1RM, RIR, or stale pounds.
- **Contract integration:** a separate compound `hang` owner with no prime
  actions and resisted `scapula.elevation` plus `hand.fingerExtension`.
  Scapular depression is the opposing capacity held isometrically, not a
  dynamic prime action. Repeated motion remains a Scapular Pull-Up.
- **Evidence boundary:** Army and CrossFit standards establish the bar, grip,
  straight arms, and shoulders-away-from-ears position. Lower-trapezius and
  support-chain categories are bounded anatomy-and-mechanics inferences; no
  numeric activation ranking is claimed.
- **Negative boundary:** Passive Dead Hang, Scapular Pull-Up, flexed-arm hang,
  Pull-Up, climbing-edge hang, weighted hang, and foot-assisted hang.

Both hangs use the additive `hang` compound pattern. They remain distinct
families and histories and do not satisfy Vertical Pull coverage.

## Approved contract surfaces

These are the approval surfaces for the four new families. All actions outside
each declared produced/yielding union remain forbidden as deliberate prime
actions. Product seed weights and repetitions are initialization, not source
claims.

### `elbow-flexion` expansion

The fixed classification, allowed equipment/modality/tracking/load values,
elbow-flexion signature, and supinated elbow-flexor baseline remain unchanged.
The expansion is conditional, not a Cartesian broadening:

| Surface | Approved value |
|---|---|
| Fixture discriminator | Add required `curlFixture` with one value per exact branch: the three existing standing cable-grip fixtures, existing standing straight-barbell fixture, existing standing single-arm dumbbell fixture, `preacherBarbellUnreportedShape`, and `inclineBilateralSupinatedDumbbell`. Each rule can use that single predicate, matching the validator's current rule model. |
| Shared axes | Add `upperArmSupport` and required `armSequence` (`simultaneousBilateral` or `singleArmThenMirror`); broaden body position, torso support, scapular translation, and upper-arm posture only through fixture-specific values. `forearmSupport` remains `none` because a preacher pad contacts the upper arm, not the forearm. |
| Preacher rule | `preacherBarbellUnreportedShape` alone pins barbell, bilateral, `simultaneousBilateral`, seated, no claimed torso support, unstandardized scapular translation, upper arm on preacher pad, shoulder flexed over the pad, held supination, `barbellShapeUnreported`, gravity resistance, unreported pad angle, and the reviewed 1-second up / 2-second down cadence. |
| Incline rule | `inclineBilateralSupinatedDumbbell` alone pins dumbbell, bilateral, `simultaneousBilateral`, 45-degree posterior bench support, unstandardized scapular translation, no upper-arm support, upper arm behind torso, held supination, dumbbell handles, and gravity resistance. Simultaneous sequencing is the disclosed catalog adaptation. |
| Existing-record rules | Replace equipment-only barbell/dumbbell rules with five fixture-keyed rules for the existing records. Each pins its current equipment, laterality, sequence, posture, support, forearm orientation, handle, and resistance geometry without changing behavior. |
| Muscle rules | Keep brachialis and biceps-brachii primary, brachioradialis secondary, and grip/wrist stabilizers for both new supinated fixtures as disclosed action-capability inferences; the incline training result is not used as a magnitude ranking. Make deltoid-anterior, middle-trapezius, and oblique requirements standing-only; supported records may not inherit them without record-specific support. |
| Leakage rules | Each `curlFixture` rule pins equipment, laterality, arm sequence, support, handle, resistance geometry, and upper-arm posture. Contract tests mutate every pinned field and reject preacher dumbbells/cables/machines, incline barbells, unsupported supported-fixture combinations, and every unreviewed cross-product. |

This replaces, rather than weakens, the current broad equipment rules that
force every barbell to `straightBarbell` and every dumbbell record to unilateral
standing execution. It needs no conjunctive-rule schema expansion.

### `nordic-curl`

| Surface | Approved value |
|---|---|
| Fixed and group | isolation; `trainingRole: legs`; null pattern/direction; sagittal; group `legs` only |
| Allowed | bodyweight; `dynamicStrength`; repetitions; `nonComparable`; bilateral; zero weight/fraction; five-repetition seed; search priority 92 |
| Signature | plane basis `knee.flexion`; lowering phase yields through `knee.extension`; return phase produces `knee.flexion`; stability: spine, pelvis, hip, knee |
| Muscle policy | `bicepsFemoris` and `medialHamstrings` required primary by disclosed region/action inference; measured semitendinosus maps only to the latter aggregate; source-measured trunk/gluteal regions may be allowed only as stabilizers with explicit per-role support |
| Required axes | closed chain; tall kneeling; partner-fixed lower legs; neutral held hip/trunk; arms forward without floor support; three-second lowering; three-second active return; achieved controlled range; free path |
| Rules | pin the single initial record to every value above; forbid hand reset, external load, unilateral work, hip extension, and a return that omits active knee flexion |

This family requires a shared-schema and validator change allowing ordered
`yieldingActions` in `dynamicStrength`; the capability remains phase-bound and
does not make yielding motion a concentric prime action.

### `mid-thigh-clean-pull`

| Surface | Approved value |
|---|---|
| Fixed and group | compound; `trainingRole: legs`; pattern `hinge`; null direction; sagittal; group `legs` only |
| Allowed | barbell; `power`; repetitions; external load; bilateral; 45 lb / 20 kg and three-repetition seeds; search priority 90 |
| Signature | plane basis `hip.extension`; pull phase produces `hip.extension`, `knee.extension`, `ankle.plantarflexion`, and `scapula.elevation`; stability: shoulder, scapula, elbow, wrist, hand, spine, pelvis, hip, knee, ankle, foot |
| Muscle policy | inferred primaries `gluteMax`, `vasti`; inferred secondaries limited to `medialHamstrings`, `rectusFemoris`, `gastrocnemius`, `soleus`, `trapeziusUpper`; stabilizers limited to `bicepsFemoris`, `fingerFlexors`, `extensorCarpiRadialis`, `abs`, `obliques`, `lumbarExtensors`; no elbow-flexor secondary requirement |
| Required axes | entry from hang; bar paused midway between patella and inguinal crease; no countermovement; pronated self-selected clean grip; lifting straps; straight elbows; triple extension plus shrug; no pull-under/catch; rack-supported inter-rep reset; free path |
| Rules | exact conjunction above; forbid elbow flexion, catch/receive axes, floor start, snatch grip, unstrapped equivalence, and isometric-only pulling |

The role categories describe reviewed action capability, not EMG magnitude; the
defining studies do not supply an exercise-specific muscle ranking.

### `squat-clean`

| Surface | Approved value |
|---|---|
| Fixed and group | compound; `trainingRole: legs`; pattern `hinge`; null direction; sagittal; group `legs` only |
| Allowed | barbell; `power`; repetitions; external load; bilateral; 45 lb / 20 kg and three-repetition seeds; search priority 95 |
| Signature | plane basis `hip.extension`; first pull produces hip/knee extension; second pull produces hip/knee extension, ankle plantarflexion, scapular elevation; pull-under produces elbow flexion; catch yields through hip/knee flexion and ankle dorsiflexion; recovery produces hip/knee extension plus anatomy/mechanics-inferred ankle plantarflexion |
| Muscle policy | inferred primaries `gluteMax`, `vasti`; secondaries limited to `medialHamstrings`, `rectusFemoris`, `gastrocnemius`, `soleus`, `trapeziusUpper`, `bicepsBrachii`, `brachialis`, `brachioradialis`; stabilizers limited to `bicepsFemoris`, `gluteMed`, `fingerFlexors`, `extensorCarpiRadialis`, `externalRotators`, `subscapularis`, `abs`, `obliques`, `lumbarExtensors` |
| Required axes | floor start; self-selected pronated clean grip; observed transition/rebend with no separate role credit; first/second pull then elbow-led pull-under; full-squat front-rack receive; stand from full squat; floor inter-rep support; free path |
| Rules | pin full-squat receive to full-squat recovery; require the floor start and front-rack endpoint; forbid power-depth catch, hang start, no-catch pull, overhead receive, and jerk phase |

The family is separate from `power-clean`; no neighboring family ID, name,
definition, phase signature, or rule was broadened by this integration.

### `full-snatch`

| Surface | Approved value |
|---|---|
| Fixed and group | compound; `trainingRole: legs`; pattern `hinge`; null direction; sagittal and frontal; group `legs` only |
| Allowed | barbell; `power`; repetitions; external load; bilateral; 45 lb / 20 kg and three-repetition seeds; search priority 95 |
| Signature | plane basis shoulder flexion/abduction; first pull produces hip/knee extension; second pull produces hip/knee extension, ankle plantarflexion, scapular elevation; pull-under produces elbow flexion; catch produces shoulder flexion/abduction, scapular upward rotation/posterior tilt, elbow extension while yielding through hip/knee flexion and ankle dorsiflexion; recovery produces hip/knee extension plus anatomy/mechanics-inferred ankle plantarflexion |
| Muscle policy | inferred primaries `gluteMax`, `vasti`; secondaries limited to `medialHamstrings`, `rectusFemoris`, `gastrocnemius`, `soleus`, `trapeziusUpper`, `bicepsBrachii`, `brachialis`, `brachioradialis`, `deltoidAnterior`, `deltoidLateral`, `supraspinatus`, `triceps`, `serratus`, `trapeziusLower`; stabilizers limited to `bicepsFemoris`, `gluteMed`, `fingerFlexors`, `extensorCarpiRadialis`, `externalRotators`, `subscapularis`, `abs`, `obliques`, `lumbarExtensors` |
| Required axes | floor start; self-selected wide pronated grip; observed transition/rebend with no separate role credit; first/second pull then pull-under; full overhead-squat receive; extended-elbow overhead endpoint; stand from full squat; floor inter-rep support; free path |
| Rules | require floor start, wide grip, overhead lockout, paired full-squat receive/recovery; forbid hang loading, power-depth catch, no-catch pull, clean/front-rack receive, and overhead-squat-only start |

The second pull and pull-under intentionally overlap Hang Power Snatch. Family
separation comes from the floor first pull plus full-squat receive/recovery, not
from claiming that every phase differs.

## Gate decisions

- **Duplicate gate:** exact normalized names, aliases, IDs, and fuzzy neighbors
  were checked. No active duplicate or alias-only integration exists.
- **Closest-family gate:** Nordic, Mid-Thigh Clean Pull, Full Snatch, Hollow
  Hold, Squat Clean, Passive Dead Hang, and Active Dead Hang require new
  owners; Preacher and Bilateral Incline Dumbbell Curl expand
  `elbow-flexion`; Kneeling Cable Crunch expands `spine-flexion`.
- **Evidence gate:** all ten exact fixtures are sufficient for activation. An
  authoritative standard may establish conventional geometry, while existing
  primary anatomy may support transparently bounded categorical roles. Exact
  exercise-specific EMG remains necessary for novel capabilities or
  quantitative, comparative, medical, or surprising claims—not every ordinary
  fixture.
- **Contract gate:** every evidence-ready candidate changes a family contract,
  creates a family, or broadens shared semantics. Owner approval was explicit:
  six fixtures on 2026-08-27 and the four follow-up fixtures plus proportional
  policy and `hang` vocabulary on 2026-08-28.
- **Independent review gate:** biomechanics/evidence, family-boundary, and
  product-semantics reviews were performed independently before synthesis, then
  re-run against all four follow-up fixtures under the proportional policy.
  All four pass with bounded inference and no medical or ranking claims. No
  reviewer edited catalog files.

## Evidence ledger

Web search and source verification date: **2026-08-28**.

| Claim | Primary source | Support | Limitation |
|---|---|---|---|
| Nordic down-and-active-return fixture and hamstring activity | [Narouei et al. 2018](https://pmc.ncbi.nlm.nih.gov/articles/PMC5931159/) | Direct | The achieved range varies; trunk/glute EMG is not a universal role ranking. |
| Nordic fixation and execution variants materially change mechanics | [Šarabon et al. 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6808554/) | Supporting | Does not make different anchors interchangeable. |
| Requested kneeling cable-crunch fixture | [ACE Certified News](https://www.acefitness.org/cp/pdfs/CertifiedNews/AugSept09Cert.pdf) | Direct technical standard | Hip/pelvis constraint and categorical support-chain roles are disclosed catalog inferences. |
| Bilateral barbell preacher fixture, torque profile, and biceps adaptation | [Nunes et al. 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7460162/) | Direct | Bar shape and pad angle are unreported; no brachialis/brachioradialis measurement. |
| 45-degree fully supinated incline-dumbbell fixture | [Zabaleta-Korta et al. 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10407320/) | Direct setup; adapted sequence | Both arms were trained, but sequence is unreported and the incline group had no significant regional growth; simultaneous movement is a disclosed catalog adaptation. |
| Incline-curl biceps long-head activity | [Oliveira et al. 2009](https://pmc.ncbi.nlm.nih.gov/articles/PMC3737788/) | Supporting | Uses a unilateral 50-degree trunk-hyperextension fixture; it does not define the active bench angle, bilateral sequence, grip, or a head-specific hierarchy. |
| Paused dynamic Mid-Thigh Clean Pull kinetics and exact reset | [Comfort et al. 2015](https://doi.org/10.1080/14763141.2015.1025237) | Direct | Uses straps and rack supports; supplies no EMG hierarchy or numeric clean-grip width. |
| Dynamic mid-thigh start and loading | [Kawamori et al. 2006](https://doi.org/10.1519/18025.1) | Supporting | Omits grip, arm endpoint, and reset details. |
| Clean-grip pulling derivative and no-catch boundary | [NSCA position statement 2023](https://dxpprod.nsca.com/globalassets/about/position-statements/weighlifting-for-sports-performance.pdf) | Direct technical standard | Does not supply exercise-specific muscle rankings. |
| Competition Clean and Snatch start, receive, and recovery boundaries | [IWF TCRR, 5 November 2025](https://iwf.sport/wp-content/uploads/downloads/2025/11/IWF-TCRR-2025-as-of-05-November-2025.pdf) | Direct official boundary standard | Permits split/power receiving; the active records deliberately narrow both fixtures to a squat catch and do not treat the standard as muscle evidence. |
| Full Clean and Snatch phase kinematics | [Khuyagbaatar et al.](https://doi.org/10.5334/paah.306) | Direct | Does not establish a complete muscle-role hierarchy. |
| Full Clean versus Snatch lower-limb EMG and biomechanics | [Arauz et al. 2026](https://pubmed.ncbi.nlm.nih.gov/41352184/) | Direct | Upper-body and trunk roles remain inferred. |
| Official long-lever Hollow Hold shape | [CrossFit Gymnastics Training Guide](https://assets.crossfit.com/pdfs/seminars/SMERefs/Gymnastics/GymnasticsCourse_SeminarGuide.pdf) | Direct technical standard | Categorical roles remain bounded inference, not exact-fixture rankings. |
| Pelvic-tilt abdominal EMG | [Drysdale et al. 2004](https://pmc.ncbi.nlm.nih.gov/articles/PMC385259/) | Supporting component | Flexed-hip/knee geometry does not exactly match the long-lever Hollow Hold. |
| Closed-overhand straight-arm bar geometry | [U.S. Army ATP 7-22.02](https://www.benning.army.mil/tenant/wtc/content/PDF/ARN45013-ATP_7-22.02-001-WEB-4.pdf) | Direct technical standard | Does not distinguish active and passive scapular posture or rank muscles. |
| Active versus passive shoulder position in a straight-arm bar hang | [CrossFit, 2026](https://www.crossfit.com/essentials/crossfit-bar-hanging) | Direct technical distinction | No muscle measurement, fixed grip width, or complete grip geometry. |
| Fully extended hang loading and forearm EMG | [Exel et al. 2023](https://doi.org/10.3389/fspor.2023.1251089) | Supporting | Uses a 22-mm climbing edge and open-crimp grip, not a horizontal bar; scapular state is unspecified. |
| Sustained dead-hang coordination | [Exel et al. 2026](https://doi.org/10.1002/ejsc.70197) | Supporting | Uses a 20-mm climbing edge and half-crimp grip; scapular state is unspecified and coordination does not establish categorical muscle roles. |

## Integration

- **Active family or proposal:** `nordic-curl`, `mid-thigh-clean-pull`,
  `squat-clean`, and `full-snatch` are active families; Barbell Preacher Curl
  and Bilateral Incline Dumbbell Curl are active `elbow-flexion` fixtures;
  Kneeling Cable Crunch is an active `spine-flexion` fixture; and
  `hollow-hold`, `passive-dead-hang`, and `active-dead-hang` are active
  families.
- **Second-review scope:** the proportional evidence policy, official-standard
  evidence route, `hang` pattern, three new families, and one family expansion
  were integrated for the four follow-up fixtures.
- **Changed files:** canonical family, evidence, and schema source under
  `specs/catalog/`; catalog compiler, mutation/search/runtime tests, and catalog
  documentation; resistance-capability normalization across workout, template,
  history, analytics, widget, and active-workout boundaries; generated runtime
  catalog.
- **Generated output:** `Scripts/catalog.py --emit-runtime` regenerated
  `vivobody/Resources/catalog.json`; the checked foundation has 58 muscles,
  60 mesh bases, 44 actions, 201 evidence sources, 79 validated family
  contracts including the synthetic fixture, and 176 active exercise records.
- **Tests and catalog gates:** the generated catalog is byte-identical to the
  compiler output; all 420 catalog mutation tests and the targeted biomechanics,
  search, substitution, and routine-builder iOS suites pass.
- **UI evidence:** `catalog-active-dead-hang` passes with inspected
  `.verify/scenarios/catalog-active-dead-hang/final.jpg` and
  `final-ui.json`; the detail exposes Strength · Hold plus Hang, Compound, and
  Frontal movement semantics without clipping.

## Remaining uncertainty or unlock

No additional unlock remains for the ten approved fixtures. Bodyweight plus
`nonComparable` now defines an unloaded capability across active workout,
template, completed-set, receipt, history, analytics, widget, and save paths.
Stale values are interpreted as zero and normalized at write boundaries without
a SwiftData schema migration; band resistance remains tracked.

Remaining uncertainty is intentionally bounded: the new standards establish
fixture geometry, while some categorical roles are anatomy-and-mechanics
inferences rather than exact-fixture measurements. The catalog makes no
numeric activation ranking, medical benefit, decompression, rehabilitation,
or injury-prevention claim for these records.
