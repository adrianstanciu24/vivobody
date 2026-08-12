# Family-first catalog roadmap

Status: working roadmap for the clean-slate strength catalog. Candidate names
are discovery handles, not guaranteed final family IDs.

## Current position

- 26 reviewed families are active, containing 97 exercises.
- Batch 1 resolved nine candidates into seven active families and two evidence
  holds.
- Batch 2 resolved nine candidates into eight active families and one explicit
  task-definition hold.
- Batch 3 resolved nine candidates into four active families, four standalone
  evidence holds, and one deferred branch of an existing family.
- 23 not-yet-reviewed candidates remain in Batches 4–7.
- 33 work items remain unresolved: 32 family or branch items—the 23 candidates;
  the deferred `diagonal-pull`, `scapular-retraction`, `upright-row`, and
  generic `grip` candidates; the Batch-3 `scapular-depression`, standalone
  `scapular-upward-rotation`, standalone `scapular-downward-rotation`, and
  `landmine-press` holds; and the deferred closed-chain branch of
  `vertical-press`—plus the cross-family sternocostal shoulder-flexion
  capability hold described below.

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
| **Total** | **97** |

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
extension. The resulting foundation is pinned at 41 muscles, 62 mesh bases,
and 44 actions; every previously active family was migrated atomically rather
than inheriting anatomy from either retired aggregate.

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

### Lower-body taxonomy and axes

Before Batch 4, audit the aggregate `quads`, `calves`, `shins`, `hipFlexors`,
and `gluteMed` capability profiles. They currently assign whole-region actions
that may belong only to one constituent muscle or fiber region. Any split must
be approved explicitly, remain compatible with the body-model meshes, and
update the exact taxonomy count, capability evidence, README, validator, and
tests atomically.

Also standardize lower-body support, posture, path, stance, load-placement,
range-of-motion, and inter-repetition-support axes before family-local spellings
drift. The squat/lunge/step-up group must make one shared decision about whether
ankle plantarflexion is an authored prime angular action; a net ankle moment is
not automatically proof of that action.

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

1. `knee-extension`
2. `knee-flexion`
3. `hip-extension`
4. `hip-flexion`
5. `ankle-plantarflexion`

These one-prime-action contracts establish shared posture, support, and path
semantics before compound lower-body work. Knee/hip posture is load-bearing for
biarticular contributors. Straight- and bent-knee plantarflexion must not be
given identical anatomy by convenience; split the relevant taxonomy or narrow
the admitted scope.

## Batch 5 — Lower-body compound sagittal patterns (5)

1. `hip-hinge`
2. `hip-thrust-bridge`
3. `bilateral-squat`
4. `split-stance-lunge`
5. `step-up`

The boundary matrix must prove hinge versus squat, isolated hip extension
versus thrust/bridge, and lunge versus step-up. The initial hinge should defer
knee-extension-heavy floor pulls unless a reviewed branch represents them.
Leg press, walking lunges, and lateral/crossover step-ups remain explicit
discovery decisions rather than automatic variants.

## Batch 6 — Lower-body taxonomy-sensitive isolation (5)

1. `hip-abduction`
2. `hip-adduction`
3. `ankle-dorsiflexion`
4. `hip-internal-rotation`
5. `hip-external-rotation`

Dorsiflexion is grouped here because the current aggregate `shins` profile is
the same type of anatomy blocker as the hip-rotation profiles. Internal and
external rotation remain separate candidates because their fixed actions and
muscle contracts differ; do not hide them behind a direction axis.

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
