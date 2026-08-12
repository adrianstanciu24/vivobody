# Family-first catalog roadmap

Status: working roadmap for the clean-slate strength catalog. Candidate names
are discovery handles, not guaranteed final family IDs.

## Current position

- 34 reviewed families are active, containing 110 exercises.
- Batch 1 resolved nine candidates into seven active families and two evidence
  holds.
- Batch 2 resolved nine candidates into eight active families and one explicit
  task-definition hold.
- Batch 3 resolved nine candidates into four active families, four standalone
  evidence holds, and one deferred branch of an existing family.
- Batch 4 resolved five candidates into four active families and one explicit
  evidence hold.
- Batch 5 resolved five discovery candidates into four active families and two
  holds after splitting stationary split squats from dynamic lunges.
- 13 not-yet-reviewed candidates remain in Batches 6–7.
- 26 work items remain unresolved: 25 family or branch items—the 13 candidates;
  the deferred `diagonal-pull`, `scapular-retraction`, `upright-row`, and
  generic `grip` candidates; the Batch-3 `scapular-depression`, standalone
  `scapular-upward-rotation`, standalone `scapular-downward-rotation`, and
  `landmine-press` holds; and the deferred closed-chain branch of
  `vertical-press`; the Batch-4 `hip-flexion` hold; and the Batch-5
  `hip-hinge` hold; and the new `dynamic-lunge` discovery hold—plus the
  cross-family sternocostal shoulder-flexion capability hold described below.

The target is **not** to preserve every candidate as a final family. A batch
may prove that candidates should merge, split, become variants of an active
family, or be retired. A family activates only when its own contract, roster,
evidence, and tests are ready; one blocked candidate never blocks its clearer
batch siblings.

## Active families

| Family | Exercises |
|---|---:|
| `horizontal-press` | 12 |
| `incline-press` | 4 |
| `decline-press` | 4 |
| `vertical-press` | 10 |
| `vertical-pull` | 13 |
| `shoulder-extension-row` | 12 |
| `shoulder-horizontal-abduction-row` | 6 |
| `shoulder-extension-isolation` | 3 |
| `chest-fly` | 2 |
| `reverse-fly` | 4 |
| `shoulder-flexion-raise` | 1 |
| `shoulder-abduction-raise` | 2 |
| `shoulder-external-rotation` | 3 |
| `shoulder-internal-rotation` | 2 |
| `elbow-flexion` | 3 |
| `elbow-extension` | 5 |
| `forearm-pronation` | 1 |
| `forearm-supination` | 1 |
| `wrist-flexion` | 1 |
| `wrist-extension` | 1 |
| `wrist-radial-deviation` | 1 |
| `wrist-ulnar-deviation` | 1 |
| `scapular-protraction` | 1 |
| `scapular-elevation` | 1 |
| `dip` | 2 |
| `push-press` | 1 |
| `knee-extension` | 2 |
| `knee-flexion` | 2 |
| `hip-extension` | 1 |
| `ankle-plantarflexion` | 2 |
| `bilateral-squat` | 2 |
| `hip-thrust-bridge` | 2 |
| `split-stance-squat` | 1 |
| `step-up` | 1 |
| **Total** | **110** |

## Foundation gates

These are parallel prerequisite investigations, not movement families and not
part of a batch count.

### Shared upper-body conventions

Before the first upper-body batch, freeze these rules once:

- a joint action does not automatically deserve a family;
- isolation means a reviewed controlled-joint-excursion contract, not an
  exercise name;
- scapular prime actions require motion evidence rather than EMG, handle
  travel, or target-muscle copy; and
- shared axes use one meaning for elbow behavior, kinetic chain, support,
  scapular translation, humeral path, inclination, and lower-body
  contribution.

### Distal upper-body taxonomy — complete

Batch 2 retired the aggregate `biceps|forearms` regions and added eleven exact
distal regions: biceps brachii, brachialis, brachioradialis, grouped pronators,
supinator, four carpal groups, finger flexors, and finger extensors. It also
replaced the task-level `hand.grip` action with dynamic finger flexion and
extension. That migration established 41 regions; Batch 4's later lower-body
split brings the current foundation to 52 regions while preserving 62 mesh
bases and 44 actions. Every affected active family was migrated atomically
rather than inheriting anatomy from a retired aggregate.

### Sternocostal flexion from an extended start — evidence hold

The foundation currently gives `pectoralisMajorSternocostal` conditioned
`shoulder.extension` capability when returning from a flexed position, but it
does not declare the mirror capability for shoulder flexion from an extended
start toward neutral. `fromExtendedPosition` is only a proposed condition name;
it is not active vocabulary in `joint-actions.json`.

The dip family exposes the user-visible consequence. Its concentric action is
shoulder flexion from an extended bottom, yet the reviewed dip experiments
measured only the clavicular pectoral site and do not establish a regional
sternocostal role. The active records therefore assign no sternocostal
involvement rather than fabricating a capability. Until this hold is resolved,
the eventual 3D body highlight and MuscleVolume/Development credit for dips
will omit the sternocostal region. The same gap must be checked before any
future family treats flexion from extension as a training-defining action.

Resolution requires a direct review of action-capability evidence across the
relevant extended-to-neutral range and exercise-specific evidence sufficient
to choose a categorical dip role. If both gates pass, add the central
condition, update the sternocostal muscle profile, re-review every affected
family, and update the dip contract, body-highlight expectations, volume-credit
expectations, and catalog tests atomically. Merely adding the condition label,
copying the clavicular EMG site, or making shoulder flexion unconditional does
not resolve the hold.

### Lower-body taxonomy and axes — complete through Batch 5

Batch 4 replaced the action-leaking `quads`, `hamstrings`, `calves`,
`adductors`, `hipFlexors`, and `shins` aggregates with exact lower-body regions
that preserve ownership of the same body-model meshes. The foundation is now
pinned at 52 muscle regions, 62 mesh bases, and 44 joint actions. Every active
family was migrated atomically. Conservative regions such as
`bicepsFemoris`, `gluteMed`, `adductorMagnus`, `adductorLongusBrevis`, and
`pectineus` retain only capabilities that their visible mesh and current
unconditioned action vocabulary can represent truthfully. In particular, the
two latter regions do not receive unbounded hip-flexion credit when their
modeled sagittal moment direction changes or approaches zero in deeper
flexion.

The first lower-body isolation contracts standardized kinetic chain, body
position, torso and pelvis support, position-held segment motion, joint-angle,
moving-segment, load-interface, machine-type, fixed-path, and
isolated-joint-contribution spellings. `resistanceGeometry` is retained only
when it adds a fact not already encoded by a purpose-built machine type, as in
the gravity-loaded hip-extension fixture. Batch 5 extended that vocabulary with
shared stance-configuration, load-placement, range-of-motion, foot-contact,
and inter-repetition-support axes while keeping family-specific values tied to
their reviewed topology.

The squat, stationary split-squat, and step-up contracts author ankle
plantarflexion only after their kinematic records establish angular motion from
bottom-position dorsiflexion toward the standing angle. The decision is not
inferred from an ankle moment or calf excitation alone. Hip thrust/bridge
instead uses `ankleMotion: nonstandardized`: its observed ankle excursion and
variable negligible kinetics do not establish one universal prime action.

### Resisted-action semantics

Before Batch 7, extend the contract model so an isometric anti-movement family
can state the action it resists. Do not encode anti-extension as dynamic
`spine.flexion` or invent another moving prime action merely to satisfy the
current non-empty `primeActions`/`planeBasisActions` requirements.

The minimal reviewed design should add `movementSignature.resistedActions`
using existing action IDs and a central way to prove that a muscle can resist
the declared action—either explicit muscle-profile `resists` capabilities or a
validated action-opposition map. `planeBasisActions` may then use the union of
prime and resisted actions while preserving its same-region, distinct-plane,
and exact-plane rules. A contract must declare at least one prime or resisted
action; the same action cannot appear in both.

Loaded carries also need exercise-level `additionalResistedActions` and a rule
assertion equivalent to `requireAdditionalStabilityDemands` if one family is to
span bilateral farmer and unilateral suitcase variants. Otherwise those
variants must split rather than hiding directional anti-motion behind a generic
`spine` stability demand. Review the current `lowerBack` aggregation before
assigning lateral-flexion roles because it combines lumbar-extensor and
quadratus-lumborum meshes.

## Batch 1 — Shoulder-action boundaries (9)

Status: complete. It reused the existing press, pull, row, split-pectoral,
split-deltoid, cuff, and trapezius work.

1. `shoulder-extension-isolation`
2. `chest-fly`
3. `reverse-fly`
4. `shoulder-flexion-raise`
5. `shoulder-abduction-raise`
6. `shoulder-external-rotation`
7. `shoulder-internal-rotation`
8. `scapular-retraction` — deferred
9. `upright-row` — deferred

The load-bearing contrasts are fly versus press, reverse fly versus
shoulder-height row, reverse fly versus scapular retraction, abduction raise
versus upright row, and shoulder-extension isolation versus row/pulldown.
The first seven candidates activated with narrow rosters. Scapular retraction
remains deferred until a loaded dynamic fixture separates retraction from
coupled scapular and humeral actions. Upright row remains deferred until loaded
kinematics establish its humeral path, axial rotation, endpoint, and scapular
signature. Their proposal files record exact unlocks and negative boundaries.

## Batch 2 — Arm and forearm actions (9)

Status: complete. Eight candidates activated with narrow rosters after the
distal taxonomy migration; generic grip remains a resolved design hold.

1. `elbow-flexion`
2. `elbow-extension`
3. `forearm-pronation`
4. `forearm-supination`
5. `wrist-flexion`
6. `wrist-extension`
7. `wrist-radial-deviation`
8. `wrist-ulnar-deviation`
9. `grip` — deferred

The activated contracts share explicit elbow/forearm/wrist posture, resistance
geometry, hand-task, support, and free-path semantics. Generic grip did not
activate because crush, pinch, dynamic closing, support grip, and hanging are
different biomechanical tasks. Resume it only after choosing the first exact
task and its measurable contract; do not recreate the retired catch-all
`hand.grip` action.

## Batch 3 — Scapular/press frontier (9)

Status: complete. Four candidates activated as narrow families, four remain
evidence holds, and closed-chain vertical press was assigned to a deferred
branch of the existing `vertical-press` family.

1. `scapular-protraction`
2. `scapular-elevation`
3. `scapular-depression` — deferred
4. `scapular-upward-rotation` — deferred as a standalone family
5. `scapular-downward-rotation` — deferred as a standalone family
6. `dip`
7. `landmine-press` — deferred
8. `closed-chain-vertical-press` — merged into `vertical-press`; branch deferred
9. `leg-driven-overhead-press` — activated as `push-press`

The activated scapular contracts are deliberately narrow: one reviewed supine
dumbbell punch for protraction and one reviewed single-arm dumbbell shrug for
elevation with coupled upward rotation. EMG alone did not create scapular prime
actions. Depression lacks direct loaded dynamic evidence, and neither rotation
candidate yet has a clean standalone fixture rather than a coupled arm or shrug
task.

Dip activated only for parallel bars and rings. Its concentric signature is
shoulder flexion from the extended bottom plus elbow extension; unmeasured
scapular motion was not promoted into the contract. `push-press` activated as a
one-exercise barbell power family whose leg countermovement, triple extension,
continuous foot contact, and no-redip standing reception distinguish it from
strict press, thruster, push jerk, and split jerk.

Landmine press remains blocked because implement travel does not establish the
athlete-relative shoulder and scapular geometry. Closed-chain vertical press
belongs conceptually inside `vertical-press`, but the branch remains blocked by
the absence of direct dynamic action and loading evidence for its proposed
bodyweight fixtures. Neither hold pre-approves new shared axis values.

## Batch 4 — Lower-body sagittal primitives (5)

Status: complete. Four one-action isolation families activated after the
52-region lower-body taxonomy migration; `hip-flexion` remains a direct-evidence
hold.

1. `knee-extension`
2. `knee-flexion`
3. `hip-extension`
4. `hip-flexion` — deferred
5. `ankle-plantarflexion`

The seven active records are deliberately narrow: two unilateral machine leg
extensions at reviewed 40- and 90-degree hip-flexion postures, two unilateral
machine leg curls at reviewed 90- and 30-degree postures, one unsupported-limb
prone-table bent-knee hip extension, and standing/seated unilateral machine calf
raises at zero and 90 degrees of knee flexion. Posture-conditioned rules make
rectus femoris primary only in the reclined leg extension and gastrocnemius
primary only in the knee-extended calf raise. The ankle-unreported leg-curl
fixtures do not fabricate gastrocnemius credit.

`hip-flexion` remains deferred because the reviewed sources establish muscle
activity and load sensitivity but do not prove the intended dynamic
femur-relative-to-position-held-pelvis isolation contract. Sit-ups, hanging
knee raises, and similar multi-segment tasks cannot fill that evidence gap by
name. Resume only with condition-matched dynamic motion evidence and a reviewed
external-load or limb-load model.

## Batch 5 — Lower-body compound sagittal patterns (5)

Status: complete. Four candidates activated as narrow families. `hip-hinge`
remains an explicit motion-evidence hold, while the former
`split-stance-lunge` discovery handle split into active stationary
`split-stance-squat` and an unresolved `dynamic-lunge` discovery hold.

1. `hip-hinge` — deferred
2. `hip-thrust-bridge`
3. `bilateral-squat`
4. `split-stance-squat` — renamed from the discovery handle
   `split-stance-lunge`
5. `step-up`

The six active records are deliberately narrow: parallel straight-bar back and
front squats; barbell hip thrust and floor glute bridge; one stationary
approximately-leg-length barbell split squat using the study's 100-percent
condition; and one exact 21-cm bodyweight forward
stepping sequence. The latter includes the studied trail-foot return followed
by lead-foot return and requires the same lead foot to be replaced before the
next repetition. `split-stance-squat` keeps the coarse app-level `lunge`
pattern, but its family ID names the stationary fixed-foot geometry and does
not pre-authorize a dynamic lunge.

`dynamic-lunge` remains unresolved for forward and reverse step-and-return
tasks, whose impact, deceleration, changing support, and return transitions are
not stationary split-squat axes. Walking lunges may ultimately belong to a
separate locomotion family; this hold does not decide that ownership.

`hip-hinge` did not activate. Reviewed Romanian-deadlift fixtures showed
material knee excursion, so they cannot satisfy the shared
`kneeMotion: positionHeld` meaning. Adding knee extension merely to force a
record through would erase the intended hinge boundary. Leg press, walking
lunges, knee-extension-heavy floor pulls, generic-height step-ups, and
lateral/crossover step-ups remain explicit future decisions rather than
automatic variants.

## Batch 6 — Lower-body taxonomy-sensitive isolation (5)

1. `hip-abduction`
2. `hip-adduction`
3. `ankle-dorsiflexion`
4. `hip-internal-rotation`
5. `hip-external-rotation`

Dorsiflexion remains grouped here because the Batch-4 foundation migration
already replaced the old aggregate `shins` profile with exact anterior and
lateral lower-leg regions, while the hip-rotation candidates still need a
truthful policy for the unsplit gluteus-medius mesh and deep rotators. Internal
and external rotation remain separate candidates because their fixed actions
and muscle contracts differ; do not hide them behind a direction axis. Before
`hip-internal-rotation` activates, resolve the fact that
`tensorFasciaeLatae` is the only currently authored producer: the single
gluteus-medius mesh cannot truthfully inherit its anterior fibers' rotation
without also crediting oppositely acting fibers, and gluteus minimus has no
scene mesh. Pin the family's hip-flexion range, re-review TFL for that posture,
and decide whether a position-conditioned explicitly unvisualized
gluteus-minimus region is warranted. Do not add a blanket `deepRotators`
internal-rotation aggregate: those muscles do not share one direction across
hip position. Do not let the validator's one-producer minimum force TFL to
become the sole primary by default. Before
`hip-external-rotation` activates, re-review the pre-existing whole-region
`gluteMax -> hip.externalRotation` capability against hip position: modeled
anterior fibers can change rotational direction in deep flexion, so the
current unconditional spelling must not be copied into a family role without
that positional audit. Both gates belong to their already-counted family
candidates rather than adding roadmap items.

Generic `foot.toeFlexion` remains a valid action rather than being narrowed to
great-toe flexion merely because flexor hallucis longus is its only currently
authored producer. The body asset also contains intrinsic flexor-hallucis-
brevis, flexor-digitorum-brevis, and flexor-digiti-minimi-brevis surfaces.
Before any toe-flexion family or exercise role activates, audit those meshes,
add the truthful intrinsic regions, and decide the required joint/segment
granularity. This is a foundation gate for a non-roadmapped candidate, not a
new item in the current 26-item count.

## Batch 7 — Core and carry (8)

1. `spine-flexion`
2. `spine-extension`
3. `spine-lateral-flexion`
4. `spine-rotation`
5. `anti-extension`
6. `anti-lateral-flexion`
7. `anti-rotation`
8. `loaded-carry`

Research this as one umbrella batch, but activate it in three internal waves:
dynamic spine actions, resisted/anti-movement actions, then loaded carry. Carry
must reuse the resisted-action vocabulary rather than pretending that a held
load creates dynamic trunk motion.

## Evidence holds

`diagonal-pull` remains deferred. Its joint-action signature does not
distinguish it from vertical pull, while public sources do not provide the
human-relative geometry or condition-matched muscle hierarchy needed to make
geometry the boundary. Resume it only through the tracked measurement protocol;
do not let it trigger speculative migrations across active pull/row families.

`scapular-retraction` and `upright-row` are resolved Batch-1 holds rather than
unreviewed future-batch candidates. Their tracked proposals define the direct
motion or geometry evidence required to resume them. Neither hold should be
filled by EMG-based action inference or by copying a neighboring family.

Generic `grip` is a resolved Batch-2 hold. The taxonomy now distinguishes
dynamic finger flexion/extension from a static implement hold, but the product
still needs separate decisions for crush, pinch, support, hanging, and dynamic
closing tasks before any one of them becomes a family.

Batch 4 leaves one evidence hold: `hip-flexion`. Available studies do not yet
establish the proposed dynamic femur-relative-to-position-held-pelvis action
boundary in a condition-matched isolation fixture. It must not be activated by
borrowing sit-up or hanging-knee-raise evidence, which moves other segments and
adds other prime actions.

Batch 5 leaves one evidence hold: `hip-hinge`. The reviewed Romanian-deadlift
fixtures show material knee excursion, so training intent cannot substitute
for the shared no-material-excursion meaning of `positionHeld`. Resume only
with a condition-matched no-floor-reset fixture that directly establishes a
materially held knee, or with a reviewed small-knee-extension branch whose
quantitative motion band and muscle policy preserve the squat/floor-pull
boundary.

Batch 5 also leaves `dynamic-lunge` as a discovery hold created when the old
`split-stance-lunge` candidate was narrowed to stationary
`split-stance-squat`. Forward and reverse step-and-return lunges require a
reviewed transition, impact, deceleration, and support-phase contract. Walking
lunges may instead belong to locomotion and remain intentionally undecided.

Batch 3 leaves four standalone evidence holds: `scapular-depression`,
`scapular-upward-rotation`, `scapular-downward-rotation`, and
`landmine-press`. The first three require direct loaded motion evidence for a
truthful standalone action rather than EMG or a coupled-task inference.
Landmine press requires athlete-relative joint geometry and a defensible
loading model rather than classification from the implement angle.

Closed-chain vertical press is not a fifth standalone hold. The candidate was
merged into the scope of `vertical-press`, where its bodyweight branch remains
deferred until direct dynamic evidence supports the proposed action, scapular,
and loading contract. Resuming it means reviewing that branch of the active
family, not creating a parallel family ID.

## Multi-agent batch workflow

Every batch uses parallel discovery and a controlled integration pass:

1. Agent A reviews roughly half the candidates and their closest active-family
   boundaries.
2. Agent B reviews the other candidates and their evidence/roster surface.
3. Agent C audits shared vocabulary, anatomy gaps, evidence identity, schema,
   and the cross-family negative-fixture matrix.
4. The primary agent integrates the results, owns edits to shared taxonomy,
   evidence, schemas, READMEs, and central tests, and flags disagreements rather
   than silently choosing the permissive interpretation.
5. Unblocked families receive individual JSON contracts and exact rosters in
   the same batch change. Blocked candidates remain proposal documents with a
   concrete unlock.
6. Per-family rule mutations and roster coverage remain mandatory, followed by
   batch-level cross-family boundary tests and global identity/evidence checks.

Only one agent writes each shared file during a batch. Reviewers swap contracts
instead of approving their own work; parallelism comes from independent
research/proposal surfaces, not competing edits to the same registry or test
file.

Register evidence only when an active capability profile, family, or exercise
references it; the validator intentionally rejects unused sources.
