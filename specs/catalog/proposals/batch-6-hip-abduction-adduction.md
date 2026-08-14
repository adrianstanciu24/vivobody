# Batch 6 — hip abduction and adduction activation

Status: activation-ready after shared evidence registration and integration
tests. Each family begins with one condition-matched exercise rather than a
machine, standing, side-lying, cable, and band Cartesian product.

## Outcome

| Family | Active fixture | Decision |
|---|---|---|
| `hip-abduction` | Pressure-Biofeedback Side-Lying Hip Abduction | Activate narrowly |
| `hip-adduction` | Supported Standing Band Hip Adduction | Activate narrowly |

The two families remain separate because their fixed prime actions and mover
policies differ. Both are unilateral open-chain frontal-plane isolations, but
shared classification does not make opposite actions interchangeable.

## Hip abduction

McBeth et al. directly studied side-lying abduction on a treatment table with
the test limb in neutral sagittal and axial posture, the lower leg flexed for
support, a cuff weight equal to five percent of body mass just above the ankle,
and a 35-degree endpoint. Gluteus medius had the greatest measured excitation
and TFL contributed materially. The active record therefore requires gluteus
medius primary and TFL secondary. The five-pound/2.5-kilogram seed is a
conservative clean product detent, not a claim that five percent of every
user's mass equals that load.

Every analyzed repetition also used a Stabilizer Pressure Bio-feedback unit
beneath the trunk, inflated to 40 mmHg and held between 35 and 45 mmHg, plus a
horizontal contact band marking 35 degrees. Those are load-bearing setup facts:
McBeth used the feedback in every analyzed repetition, describes it as a way
to limit substitution, and cites prior work for its effect on gluteus-medius
recruitment; McBeth did not itself compare feedback with no feedback. The
initial record therefore authors
`trunkPositionFeedback: pressureBiofeedback35To45MmHg` and
`abductionEndpointReference: horizontalContactBand`; a no-feedback gym version
is deferred rather than inheriting the condition-matched role evidence. The
canonical name and aliases state the pressure-feedback condition; they do not
route a generic side-lying hip-abduction lookup to a more specific fixture.

The roster deliberately excludes the paper's abduction-plus-external-rotation
and clamshell conditions. Toes forward and `hipRotation: neutral` are
load-bearing boundaries, not naming details.

At Batch-6 activation the taxonomy had no gluteus-minimus region or body-model surface, and
the unsplit gluteus-maximus profile conservatively omits abduction because its
fiber regions do not share all actions. The active record does not proxy either
structure through another visible region. The resulting 3D highlight and
volume credit understated the full abductor system at activation and still
understate it today. The later hip-rotation
foundation added an exact unvisualized `gluteMin` region; this fixture still
leaves it unassigned because anatomical capability alone does not establish an
exercise-specific categorical role.

## Hip adduction

Serner et al. directly measured the supported standing ankle-band exercise:
the athlete begins in maximal hip abduction with band tension, keeps an upright
trunk and straight knee, and adducts until the working foot is one foot-width
from and roughly half a foot-length behind the stance foot. Jensen et al.
trained the same full-range band task for eight weeks with progressive 15-,
10-, and 8-RM loading and found a larger eccentric-strength increase than the
control condition. Those sources support the dynamic topology and the 8-to-15
recommended repetition range; elastic load remains `nonComparable`.

Neither paper reports the sagittal coordinate of the abducted start or a
three-dimensional path. The posterior endpoint therefore does not prove a
dynamic hip-extension action, but it also cannot prove that extension is
absent. The active fixture makes one transparent catalog-authored adaptation:
place the leg in the endpoint's slight posterior hip posture before starting
and hold that posture while adducting. `hipSagittalPosture:
slightExtensionHeld` excludes dynamic extension without pretending the source
measured it. The frontal plane remains the plane of the basis action,
`hip.adduction`, not a claim about an unmeasured source trajectory.

The exercise-specific EMG anchor is adductor longus. Vivobody's visible region
combines adductor longus and brevis, so the categorical primary necessarily
highlights that combined region and the limitation is explicit. Anatomy alone
does not justify awarding adductor magnus or pectineus exercise volume.
Gracilis is a mechanics-derived secondary because it produces the prime
adduction action while controlling the straight loaded knee. Gluteus medius is
a directly measured hip-and-pelvis stabilizer; Serner reported 18-percent-MVC
peak excitation on both measured sides in the band condition. Rectus abdominis
and obliques receive stabilizer credit, but Serner measured external oblique
only; the visible `obliques` region also contains internal oblique, so that
combined-region credit is an explicit taxonomy aggregation.

Serner states only that the participant held a stable support, while Jensen's
training methods explicitly fix the upper body to a stationary object with
both hands. The active record adopts the more specific directly reviewed
training setup through `handSupport: bothHandsOnStableExternalSupport`; it does
not infer contralateral support from Serner.

## Shared boundaries

Every action other than the family's one hip action is forbidden as a prime
action. Pelvis and spine position remain held; hip rotation stays neutral; the
working knee stays extended; no knee, ankle, spine, or support-leg action
creates the repetition. The fixed-path boolean is false in both families.

Deferred branches include machines, cables, bodyweight-only exercises, other
band topologies, side-lying adduction, standing abduction, Copenhagen
adduction, squeezes, clamshells, lateral walks, closed-chain tasks, and any
combined rotation exercise. Each needs its own setup and role review rather
than inheriting these contracts by name.

## Evidence registration payloads

Register only the three active sources. Brandt 2013 was reviewed as context
but has no DOI and is neither needed nor registered; no identifier is invented.

### `mcbeth-2012-side-lying-hip-abduction`

- Source type: `experimentalEMGStudy`
- DOI: `10.4085/1062-6050-47.1.15`
- PMID: `22488226`
- Direct scope: twenty healthy distance runners; cuff weight equal to five
  percent of body mass; neutral side-lying abduction from 0 to 35 degrees on a
  treatment table; pressure biofeedback beneath the trunk held at 35 to 45 mmHg;
  a horizontal endpoint contact band; and gluteus-medius, TFL,
  anterior-hip-flexor, and gluteus-maximus surface EMG. It does not support a
  no-feedback adaptation, machine, standing, band, bodyweight-only, rotated,
  or gluteus-minimus roles, a universal cuff load, or hypertrophy magnitude.

### `serner-2014-hip-adduction-exercises`

- Source type: `experimentalEMGStudy`
- DOI: `10.1136/bjsports-2012-091746`
- PMID: `23511698`
- Direct scope: forty healthy elite male soccer players; supported standing
  ankle-band adduction from maximal abduction to the reported foot-relative
  endpoint; bilateral adductor-longus plus gluteus-medius, rectus-abdominis,
  and external-oblique surface EMG. The sagittal coordinate of the start and
  three-dimensional path were not reported; the endpoint does not establish a
  separate hip-extension prime action or the catalog's held-posterior
  adaptation. It supports the topology and conservative role boundary, not
  unmeasured adductor-region ranking, internal-oblique measurement, or another
  topology.

### `jensen-2014-elastic-hip-adduction-training`

- Source type: `experimentalTrainingStudy`
- DOI: `10.1136/bjsports-2012-091095`
- PMID: `22763117`
- Direct scope: thirty-four healthy sub-elite male soccer players; eight weeks
  of supervised full-range supported standing band hip adduction, progressing
  from 3x15 RM to 3x10 RM and 3x8 RM. It supports a trainable dynamic fixture
  and the repetition range, not muscle-specific roles or comparable band load.

## Activation tests

1. Pin exactly one record per family and the globally unique IDs, names, and
   aliases.
2. Pin the fixed action, frontal plane, null pattern/direction, allowed load,
   laterality, modality, and tracking policy.
3. Require the exact 43-action complement and mutate every forbidden action.
4. Remove and demote every required role independently.
5. Pin every enum, boolean, and numeric axis and mutate each one directly with
   an exact validator message.
6. Pin stability coverage by the authored muscles rather than external
   support or an invented proxy.
7. Pin the metric cuff-weight seed and the zero/non-comparable band seed.
8. Assert that the later hip-rotation activation does not retroactively assign
   `gluteMin` here without exercise-specific role evidence.

No family-schema, validator, joint-action, or taxonomy change is required for
these two narrow activations.
