# Medicine-ball power exercises

Status: approved and activated. The nine requested exercises are represented
by seven bounded families. The shared vocabulary now includes first-class
`medicineBall` equipment plus family-scoped target-relative conditions for
reactive rotational catch-and-release phases.

## Requested roster and fixture decisions

| Requested exercise | Canonical record | Active family |
|---|---|---|
| `½ Kneeling Rotational Med Ball Throws` | Half-Kneeling Rotational Medicine Ball Throw | `medicine-ball-reactive-half-kneeling-wall-throw` |
| `Standing Med Ball Slams` | Standing Medicine Ball Slam | `medicine-ball-standing-overhead-slam` |
| `Rotational Med Ball Slams` | Rotational Medicine Ball Slam | `medicine-ball-rotational-slam` |
| `Split-Stance Rotational Throws` | Split-Stance Rotational Medicine Ball Throw | `medicine-ball-stationary-rotational-throw` |
| `Lateral Shuffle + Med Ball Throw` | Lateral Shuffle to Medicine Ball Throw | `medicine-ball-lateral-shuffle-throw` |
| `Kneeling Med Ball Slams` | Tall-Kneeling Medicine Ball Slam | `medicine-ball-tall-kneeling-overhead-slam` |
| `Standing Rotational Throw` | Standing Rotational Medicine Ball Throw | `medicine-ball-stationary-rotational-throw` |
| `Carioca to Med Ball Throw` | Crossover to Medicine Ball Rotational Throw | `medicine-ball-carioca-throw` |
| `Kneeling Rotational Throw` | Tall-Kneeling Rotational Medicine Ball Throw | `medicine-ball-stationary-rotational-throw` |

The requested spellings remain aliases. `Kneeling` means tall-kneeling when
the list already names a separate half-kneeling record. `Carioca` is bounded
as a short crossover approach into a planted throw without inventing an exact
step count. The bare rotational throws are two-hand, side-on single-release
throws. The kneeling slam is a disclosed tall-kneeling adaptation of the
reviewed self-start overhead-slam topology, not a partner-fed catch drill.

## Shared product semantics

All nine records are `power`, repetition-tracked, and `nonComparable` with a
zero bodyweight fraction. Ball mass may remain an editable resistance note,
but without velocity, distance, or another output dimension it must not create
load records, tonnage, estimated one-repetition maximum, RIR analytics, or
hypertrophy hard-set credit. The proposed browse group and training role are
`core`; the exercises remain compound whole-body power tasks.

`medicineBall` is first-class equipment. Encoding nine purpose-built
ballistic fixtures as `other` would display **Other**, hide the material
implement geometry from equipment filtering, and weaken substitution and
history semantics. The shared schema, catalog compiler, Swift `Equipment`
enum, display/filter behavior, and their tests preserve that distinction.

## Minimum family boundaries

Seven families are required:

1. the self-start standing overhead slam;
2. the self-start tall-kneeling overhead slam;
3. the standing diagonal rotational floor slam;
4. the Army-defined reactive half-kneeling rotational wall throw;
5. three stationary single-release rotational throws differing by
   stance/support;
6. a short non-crossing lateral shuffle into a rotational throw; and
7. a short crossover approach into a rotational throw.

Standing and tall-kneeling slams cannot share a support contract. Floor
slams cannot merge with wall throws. Stationary throws cannot absorb a
locomotor approach, and the shuffle and crossover approaches have different
foot-contact topology. The existing `spine-rotation` family explicitly
excludes medicine-ball throws, hip or leg contribution, and alternating
direction repetitions.

Every rotational or direction-specific record is unilateral and prescribes
both mirrored directions. Two-hand ball contact does not make directional
trunk work bilateral. Straight standing and kneeling slams are bilateral.

## Reactive rotation contract

The half-kneeling rotational wall-throw fixture receives the rebound, absorbs or
continues into a small rotation away from the target, then reverses and
releases toward it. A power movement with a receiving phase must use ordered
movement phases. The action vocabulary continues to aggregate both directions
as `spine.rotation`. Two family-scoped target-relative conditions distinguish
yielding rotation away from the external target during the receive phase from
prime rotation toward it during release. Validation compares the complete
conditioned requirement, and runtime movement actions retain the condition ID
and display name. This preserves the existing analytics action boundary
without inventing shoulder or elbow prime actions. The opening feed is
explicitly uncounted, so every logged repetition has one catch and one release.
The split-stance, standing, and tall-kneeling throws end at a single release
and reset outside the counted repetition; they do not inherit this reactive
contract.

## Evidence ledger

Web research was refreshed on 2026-09-21.

| Claim | Source | Support | Limitation |
|---|---|---|---|
| Half-kneeling side-on catch and throw | [US Army ATP 7-22.02, MB2.2 Kneeling Side-Arm Throw](https://h2f.army.mil/Portals/141/pdfs/physical/ATP%207-22.02.pdf) | Official fixture standard | Army uses `kneeling` for a one-knee-down fixture; it does not establish a muscle ranking. |
| Split-stance side toss | [Mocanu et al. 2024](https://doi.org/10.15561/20755279.2024.0306) | Direct training-protocol geometry | The multiexercise intervention did not isolate joint kinetics, muscle activity, or this drill's effect. |
| Tall-kneeling rotational toss | [Sell et al. 2015](https://doi.org/10.3233/IES-150575) | Direct stance and two-hand rotational-toss protocol | The test used a free distance throw rather than a reactive wall return and did not validate a core-strength claim. |
| Standing and side medicine-ball throw mechanics | [Ikeda et al. 2009](https://pubmed.ncbi.nlm.nih.gov/19826303/) and [Vera-Garcia et al. 2014](https://dialnet.unirioja.es/descarga/articulo/5100266.pdf) | Direct side-throw kinematics and EMG support trunk rotation | Techniques differ; results do not establish one universal upper-body role hierarchy or locomotor-transfer claim. |
| Rotational slam geometry | [UKSCA rotating medicine-ball slam technical model](https://cdn.uksca.org.uk/assets/pdfs/UkscaIqPdfs/ascc-assessment-pas-technical-model-scenario-1-637672394042677573.pdf) | Authoritative direct fixture standard | Coaching load ranges are not universal defaults or outcome evidence. |
| Shuffle-to-wall-throw geometry | [NSCA Practical Applications for Rotational Power Training](https://www.nsca.com/contentassets/6791dc5307374a4cb28464dffd417af6/ptq-4.4.7-practical-applications-for-rotational-power-training.pdf) | Authoritative photographic fixture | It does not establish detailed joint kinetics or categorical muscle rankings. |
| Shuffle and crossover are distinct approaches | [Kuntze et al. 2009](https://pmc.ncbi.nlm.nih.gov/articles/PMC3737798/) | Direct three-dimensional kinetics for lateral side-step versus crossover gait | The study did not add a medicine ball or terminal throw. |
| Standing overhead slam and rotational throw are power drills | [Shi et al. 2026](https://doi.org/10.3389/fphys.2026.1765643) | Direct intervention protocol using two-kilogram standing floor slams and rotational throws | Youth badminton protocol; sparse exact execution detail and no exercise-specific muscle measures. |
| Requested naming context | [Boxing Science Core exercise index](https://boxingscience.co.uk/courses/core/) | Coaching-library names overlap the requested roster | It is retained only as review context, not registered as active biomechanical or fixture evidence. |

Existing `christophy-2012-lumbar-spine` capability evidence supports the
categorical oblique rotation inference. No source authorizes quantitative
muscle shares, hypertrophy, rehabilitation, injury-prevention, or medical
claims.

## Activation record

The activated catalog:

1. adds only the seven bounded family contracts and nine records above;
2. registers only evidence referenced by an active capability, family, or
   exercise;
3. pins the exact rosters, aliases, classification/load tuples, stance and
   approach axes, ordered phases, role requirements, and wall-versus-floor
   boundaries with positive and negative catalog tests;
4. keeps all nine records `power + reps + nonComparable` and rejects strength
   records, tonnage, estimated one-repetition maximum, RIR, and hard-set credit;
5. generates runtime data only through `Scripts/catalog.py --emit-runtime` and
   refreshes the generated inventory;
6. runs the catalog compiler and focused catalog tests, then inspects Library
   search plus representative Exercise Detail output; and
7. reports that a successful build proves compilation, while real partner-feed,
   wall-rebound, and slam-floor safety remain manual/device checks.
