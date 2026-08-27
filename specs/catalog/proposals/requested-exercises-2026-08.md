# Requested exercise expansion — August 2026

Status: six source-bounded fixtures approved and activated on 2026-08-27;
Kneeling Cable Crunch and Hollow Hold remain blocked by evidence, while
Flexed-Arm Hang remains blocked by fixture and contract definition.

## Outcome

The request contained nine distinct exercises. None was a duplicate or a safe
alias of an active record, and none fit an active family contract unchanged.

| Requested exercise | Outcome | Owner | Reason |
|---|---|---|---|
| Nordic Curl | Activated | New `nordic-curl` family plus shared phase-schema expansion | The source-exact repetition yields through knee extension, then actively returns through knee flexion; the approved capability is phase-bound to produced-plus-yielding dynamic-strength records. |
| Kneeling Cable Crunch | Blocked by evidence | Future `spine-flexion` expansion | Available primary evidence does not define the requested tall-kneeling, high-rope fixture. |
| Preacher Curl | Activated as Barbell Preacher Curl | `elbow-flexion` expansion | “Preacher Curl” is implement-ambiguous; the activated fixture is specifically a bilateral barbell preacher curl with unreported bar shape and pad angle. |
| Incline Dumbbell Curl | Activated as Bilateral Incline Dumbbell Curl | `elbow-flexion` expansion | The activated fixture uses a 45-degree bench and held supination; simultaneous bilateral movement is an explicit catalog adaptation because source sequencing is unreported. |
| Mid-Thigh Clean Pull | Activated as Barbell Mid-Thigh Clean Pull | New `mid-thigh-clean-pull` family | It omits the pull-under and catch and cannot inherit the Power Clean phase or muscle contract. |
| Full Clean | Activated as Barbell Squat Clean | New `squat-clean` family | A full front-squat receive and recovery are deliberately excluded by the active `power-clean` identity and contract. |
| Full Snatch | Activated as Barbell Squat Snatch | New `full-snatch` family | Its floor first pull and full overhead-squat receive/recovery differ from Hang Power Snatch; the second pull and pull-under overlap. |
| Hollow Hold | Blocked by evidence | Future `hollow-hold` family | The official fixture is exact, but no exact long-lever primary study establishes the complete action and muscle-role contract. |
| Flexed-Arm Hang | Blocked by fixture and contract | Future `flexed-arm-hang` family | The protocol fixes grip and endpoint but not shoulder/scapular posture, exact resisted actions, or a defensible muscle policy. |

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
follow the existing strength-exercise eligibility. Duration-only behavior for
the blocked isometric candidates is not activated here.

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

- **Intended fixture:** bilateral tall kneeling, high cable with a rope
  attachment, hips and pelvis held, deliberate spinal flexion, and controlled
  return; cable, external load, `dynamicStrength`, repetitions.
- **Evidence failure:** the located cable-crunch abstract does not report
  kneeling posture, pulley height, attachment, hip constraint, range, or full
  execution and measured only right paraspinals.
- **Contract impact if unlocked:** investigate an expansion of `spine-flexion`
  for cable equipment, external load, tall-kneeling support, high-rope
  resistance geometry, and the possible shoulder, elbow, hand, hip, and knee
  stability demands. Those demands are hypotheses until directly reviewed.
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

- **Intended fixture:** supine with no lumbar gap, posterior pelvic tilt,
  scapulae and straight legs raised, knees and elbows locked, and arms by the
  ears; bilateral bodyweight `isometricStrength`, duration, `nonComparable`.
- **Evidence failure:** the official CrossFit standard defines the shape, but
  the located primary EMG work uses flexed-hip and flexed-knee pelvic-tilt
  conditions. It does not establish the complete action or categorical role
  policy for the requested long-lever hold.
- **Contract impact if unlocked:** investigate a new `hollow-hold` owner; it
  cannot inherit the plank-specific `anti-extension` support chain. Possible
  resisted spinal, hip, and shoulder tendencies and the abdominal, gluteal,
  hip-flexor, knee-extensor, and shoulder roles remain hypotheses to test, not
  predetermined contract requirements.
- **Negative boundary:** tuck hollow, Dead Bug, V-sit, dynamic leg raise,
  Curl-Up, and prone Plank.

### Flexed-Arm Hang

- **Candidate name:** `Pronated Flexed-Arm Hang`; no aliases. The requested
  generic words remain discoverable through token search, but no global name is
  reserved while neutral- and supinated-grip variants remain outside scope.
- **Exact setup and movement:** bilateral timed hold on a horizontal bar with a
  shoulder-width pronated grip, chin initially above the bar, elbows flexed,
  and feet unsupported; end at fatigue or loss of the chin-above-bar position.
- **Provisional product semantics:** bodyweight, bilateral,
  `isometricStrength`, duration, `nonComparable`, zero bodyweight fraction.
  This would record an unweighted fixture without inventing a comparable load
  or exposing an unsupported added-weight variant.
- **Role boundary:** the protocol defines the task but not muscle activation.
  Elbow-flexor, shoulder/scapular, and grip roles must remain conservative
  action-capability inferences without numeric or rank claims.
- **Contract blocker:** the reviewed protocols do not fix shoulder or scapular
  posture. Without that geometry, the proposal cannot truthfully select a plane
  basis, exact `resistedActions`, stability demands, or muscle requirements.
  It must not inherit dynamic Vertical Pull prime actions.
- **Negative boundary:** supinated or neutral-grip hangs, dead hang, scapular
  hang, dynamic Pull-Up or Chin-Up, mid-range isometric, climbing edge hang,
  and foot-assisted holds.

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
  Hold, Squat Clean, and Flexed-Arm Hang require new owners; Preacher and
  Bilateral Incline Dumbbell Curl expand `elbow-flexion`; Kneeling Cable Crunch
  would expand `spine-flexion` if evidence is found.
- **Evidence gate:** six exact fixtures are sufficient for activation.
  Kneeling Cable Crunch and Hollow Hold fail the evidence gate; Flexed-Arm Hang
  has a protocol but fails the exact-fixture/contract gate.
- **Contract gate:** every evidence-ready candidate changes a family contract,
  creates a family, or broadens shared schema semantics. Owner approval for the
  six reviewed surfaces was granted explicitly on 2026-08-27; no approval was
  inferred for the three blocked candidates.
- **Independent review gate:** biomechanics/evidence, family-boundary, and
  product-semantics reviews were performed independently before synthesis, then
  re-run against each corrected surface. All three final reviews pass. No
  reviewer edited catalog files.

## Evidence ledger

Web search and source verification date: **2026-08-27**.

| Claim | Primary source | Support | Limitation |
|---|---|---|---|
| Nordic down-and-active-return fixture and hamstring activity | [Narouei et al. 2018](https://pmc.ncbi.nlm.nih.gov/articles/PMC5931159/) | Direct | The achieved range varies; trunk/glute EMG is not a universal role ranking. |
| Nordic fixation and execution variants materially change mechanics | [Šarabon et al. 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6808554/) | Supporting | Does not make different anchors interchangeable. |
| Requested kneeling cable-crunch fixture | [Mitchell et al. 1998](https://doi.org/10.1097/00005768-199805001-01634) | Insufficient | Abstract omits the defining setup and most relevant muscle/action data. |
| Bilateral barbell preacher fixture, torque profile, and biceps adaptation | [Nunes et al. 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7460162/) | Direct | Bar shape and pad angle are unreported; no brachialis/brachioradialis measurement. |
| 45-degree fully supinated incline-dumbbell fixture | [Zabaleta-Korta et al. 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10407320/) | Direct setup; adapted sequence | Both arms were trained, but sequence is unreported and the incline group had no significant regional growth; simultaneous movement is a disclosed catalog adaptation. |
| Incline-curl biceps long-head activity | [Oliveira et al. 2009](https://pmc.ncbi.nlm.nih.gov/articles/PMC3737788/) | Supporting | Uses a unilateral 50-degree trunk-hyperextension fixture; it does not define the active bench angle, bilateral sequence, grip, or a head-specific hierarchy. |
| Paused dynamic Mid-Thigh Clean Pull kinetics and exact reset | [Comfort et al. 2015](https://doi.org/10.1080/14763141.2015.1025237) | Direct | Uses straps and rack supports; supplies no EMG hierarchy or numeric clean-grip width. |
| Dynamic mid-thigh start and loading | [Kawamori et al. 2006](https://doi.org/10.1519/18025.1) | Supporting | Omits grip, arm endpoint, and reset details. |
| Clean-grip pulling derivative and no-catch boundary | [NSCA position statement 2023](https://dxpprod.nsca.com/globalassets/about/position-statements/weighlifting-for-sports-performance.pdf) | Direct technical standard | Does not supply exercise-specific muscle rankings. |
| Competition Clean and Snatch start, receive, and recovery boundaries | [IWF TCRR, 5 November 2025](https://iwf.sport/wp-content/uploads/downloads/2025/11/IWF-TCRR-2025-as-of-05-November-2025.pdf) | Direct official boundary standard | Permits split/power receiving; the active records deliberately narrow both fixtures to a squat catch and do not treat the standard as muscle evidence. |
| Full Clean and Snatch phase kinematics | [Khuyagbaatar et al.](https://doi.org/10.5334/paah.306) | Direct | Does not establish a complete muscle-role hierarchy. |
| Full Clean versus Snatch lower-limb EMG and biomechanics | [Arauz et al. 2026](https://pubmed.ncbi.nlm.nih.gov/41352184/) | Direct | Upper-body and trunk roles remain inferred. |
| Official long-lever Hollow Hold shape | [CrossFit Gymnastics Training Guide](https://assets.crossfit.com/pdfs/seminars/SMERefs/Gymnastics/GymnasticsCourse_SeminarGuide.pdf) | Direct technical standard | No exact categorical muscle-role evidence. |
| Pelvic-tilt abdominal EMG | [Drysdale et al. 2004](https://pmc.ncbi.nlm.nih.gov/articles/PMC385259/) | Supporting only | Flexed-hip/knee geometry does not match the long-lever Hollow Hold. |
| Pronated chin-above-bar timed hold | [Clemons et al. 2004](https://doi.org/10.1519/R-12342.1) | Direct protocol | Tests relationships with selected relative-strength measures; it does not establish broad task validity or muscle activation. |
| Shoulder-width pronated Flexed-Arm Hang protocol | [Imanian et al. 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12473082/) | Direct fixture | Training outcomes do not establish exercise-specific muscle rankings. |

## Integration

- **Active family or proposal:** `nordic-curl`, `mid-thigh-clean-pull`,
  `squat-clean`, and `full-snatch` are active families; Barbell Preacher Curl
  and Bilateral Incline Dumbbell Curl are active `elbow-flexion` fixtures. The
  other three requests remain blocked in this record.
- **Changed files:** canonical family, evidence, and schema source under
  `specs/catalog/`; catalog compiler, mutation/search/runtime tests, and catalog
  documentation; resistance-capability normalization across workout, template,
  history, analytics, widget, and active-workout boundaries; generated runtime
  catalog.
- **Generated output:** `Scripts/catalog.py --emit-runtime` regenerated
  `vivobody/Resources/catalog.json`; the checked foundation has 58 muscles,
  60 mesh bases, 44 actions, 196 evidence sources, 76 family contracts,
  172 exercise records, and digest `21faa9c33b0a`.
- **Tests and catalog gates:** the focused catalog suite passes 417 tests.
  Focused Swift tests pass for biomechanics/catalog contracts, requested-name
  and Clean/Snatch ordering, set carry-forward, and template prefill.
  `Scripts/check.sh` passes, including generated-data checks and app build.
- **UI evidence:** `catalog-nordic-curl` passes Library discovery, detail anatomy,
  and Movement semantics with inspected screenshot/tree evidence.
  `active-no-load` passes with a deliberately stale 45 lb seed while exposing
  only repetitions and no Resistance or Weight control.

## Remaining uncertainty or unlock

No additional unlock remains for the six approved fixtures. Bodyweight plus
`nonComparable` now defines an unloaded capability across active workout,
template, completed-set, receipt, history, analytics, widget, and save paths.
Stale values are interpreted as zero and normalized at write boundaries without
a SwiftData schema migration; band resistance remains tracked.

Kneeling Cable Crunch needs a primary motion/EMG study or authoritative
technical standard that fixes tall-kneeling posture, high-pulley rope geometry,
hip/pelvis constraint, range, and execution. Hollow Hold needs exact long-lever
biomechanics/EMG evidence sufficient to assign its resisted actions and muscle
roles without transferring the plank contract.

Flexed-Arm Hang additionally needs a source-exact shoulder/scapular posture or
another defensible geometry decision before resisted actions, plane basis,
stability demands, and muscle requirements can be reviewed.
