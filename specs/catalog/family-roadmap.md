# Family-first catalog roadmap

Status: working roadmap for the clean-slate strength catalog. Candidate names
are discovery handles, not guaranteed final family IDs.

## Current position

- 48 reviewed families are active, containing 124 exercises.
- The current foundation contains 58 muscle regions, 60 trainable mesh bases,
  44 joint actions, and 140 registered evidence sources.
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
- Batch 6 resolved five taxonomy-sensitive candidates into five active
  single-exercise families after the hip-rotation anatomy and evidence gates
  closed atomically.
- Batch 7 now contains nine active families. Eight discovery candidates
  resolved through a carry split and the later lumbar closure; the carry
  candidate split into separate farmer and suitcase families, and the two
  lumbar holds activated after an atomic anatomy/evidence repair.
- 12 work items remain unresolved, all family or branch items—the deferred
  `diagonal-pull`, `scapular-retraction`, `upright-row`, and
  generic `grip` candidates; the Batch-3 `scapular-depression`, standalone
  `scapular-upward-rotation`, standalone `scapular-downward-rotation`, and
  `landmine-press` holds; and the deferred closed-chain branch of
  `vertical-press`; the Batch-4 `hip-flexion` hold; and the Batch-5
  `hip-hinge` hold; and the `dynamic-lunge` discovery hold.

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
| `hip-abduction` | 1 |
| `hip-adduction` | 1 |
| `ankle-dorsiflexion` | 1 |
| `hip-internal-rotation` | 1 |
| `hip-external-rotation` | 1 |
| `spine-flexion` | 1 |
| `spine-extension` | 1 |
| `spine-lateral-flexion` | 1 |
| `spine-rotation` | 1 |
| `anti-extension` | 1 |
| `anti-lateral-flexion` | 1 |
| `anti-rotation` | 1 |
| `farmer-carry` | 1 |
| `suitcase-carry` | 1 |
| **Total** | **124** |

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
split brought that foundation to 52 regions while preserving 62 mesh bases.
The later lumbar repair brought the taxonomy to 53 regions and 60 trainable
mesh bases. The Batch-6 hip-rotation migration added five explicitly
unvisualized exact regions, bringing the current taxonomy to 58 regions while
retaining the same 60 trainable mesh bases and 44 actions. Every affected
active family was migrated atomically rather than inheriting anatomy from a
retired aggregate.

### Sternocostal flexion from an extended start — complete

The foundation now admits `fromExtendedPosition` only for shoulder flexion that
starts behind anatomical neutral and returns toward neutral. The
`pectoralisMajorSternocostal` capability remains conditioned: it cannot satisfy
ordinary flexion beginning at or in front of neutral. This is a bounded evidence
synthesis rather than a direct negative-angle moment-arm result. Çınarlı et al.
measured the sternocostal pectoral site during the concentric phase of strict
parallel-bar dips, while McKenzie et al. separately measured the extended
bottom and shoulder-flexion ascent on bars and rings. Ackland et al. supplies
the adverse boundary at positive elevation, where the sternocostal subregions
must not inherit broad clavicular flexor behavior.

Both active dip records therefore assign clavicular and sternocostal pectoralis
as categorical primaries. The bar assignment has direct regional exercise EMG;
the ring assignment is a disclosed mechanics transfer across the same measured
action and apparatus comparison, with a clinical rupture case used only as
corroborating tissue-loading context. The sources do not rank pectoral heads or
make the measured EMG magnitudes interchangeable. No other active family starts
shoulder flexion behind neutral, and any future consumer requires its own
exercise-specific review. This closes the former zero-highlight and zero-volume
gap without granting unconditional sternocostal shoulder flexion.

### Lower-body taxonomy and axes — complete through Batch 6

Batch 4 replaced the action-leaking `quads`, `hamstrings`, `calves`,
`adductors`, `hipFlexors`, and `shins` aggregates with exact lower-body regions
that preserve ownership of the same body-model meshes. The foundation is now
pinned at the then-current 52 muscle regions, 62 mesh bases, and 44 joint actions. Every active
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

Batch 6 first added narrow hip-abduction, hip-adduction, and
ankle-dorsiflexion isolations without changing the then-current 52-region
taxonomy or 44-action vocabulary. Its later hip-rotation closure added
gluteus minimus and four exact short-rotator regions as explicitly
unvisualized identities, conditioned rotation capability on 0, 30, or 90
degrees of hip flexion, and activated one exact internal- and one exact
external-rotation fixture. No visible muscle serves as a proxy for those
unvisualized regions, and surface EMG is not treated as a torque-direction
measurement.

### Resisted-action semantics — complete

Batch 7 added `movementSignature.resistedActions` so an isometric family names
the external joint-action tendency it opposes without inventing a dynamic prime
action. A central, total, symmetric action-opposition map proves that an
assigned primary or secondary muscle can produce the opposing action.
`planeBasisActions` now draws from the union of prime and resisted actions while
preserving its same-region, distinct-plane, and exact-plane rules. A contract
must declare at least one prime or resisted action, and one action cannot be
both.

Farmer and suitcase carries use separate family-level resisted signatures:
the suitcase contract adds lateral flexion and uses it as the frontal plane
basis, while the farmer contract remains sagittal and grip-dominant. No
exercise-level resisted-action exception is needed or admitted. The active
anti-lateral-flexion and carry contracts now distinguish visible
`quadratusLumborum` from the explicitly unvisualized erector-spinae and
multifidus `lumbarExtensors` region. Posterior-serratus surfaces are not
trainable lumbar proxies.

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

Status: complete. All five candidates activated as deliberately narrow
single-exercise families. Internal and external hip rotation activated only
after their posture-conditioned anatomy and exact-fixture evidence changed
atomically.

1. `hip-abduction`
2. `hip-adduction`
3. `ankle-dorsiflexion`
4. `hip-internal-rotation`
5. `hip-external-rotation`

The active roster contains one reviewed pressure-biofeedback side-lying
cuff-weight hip-abduction fixture, one reviewed supported standing-band
hip-adduction fixture, one seated unilateral band ankle-dorsiflexion fixture,
one seated 90-degree flywheel internal-rotation fixture, and one supine
30-degree therapist-held band external-rotation fixture. The first three keep
their original narrow boundaries. Gluteus minimus now has an explicitly
unvisualized taxonomy identity, but the abduction record still omits it because
capability alone does not establish exercise involvement; no visible region is
assigned as a proxy.

The Lahuerta-Martín internal-rotation record preserves the 75-cm treatment
table, held 90-degree hips and knees, suspended feet, crossed hands, neutral
pelvis, bilateral ASIS belts, distal-femur belt, ankle-brace-to-flywheel cable,
and source-reported device geometry. It assigns gluteus medius and TFL as
non-ranked co-primaries, unvisualized gluteus minimus as a mechanics-derived
secondary, and obliques as stabilizers. The flywheel study supplies the dynamic
topology but measured no muscle activity, so condition-matched position and
EMG sources bound the roles without claiming a numeric hierarchy.

The FOHX external-rotation record preserves the supine table, both hips at 30
degrees over a wedge, source-shown but non-numeric knee flexion, therapist-
stabilized working knee, therapist-held ankle band, and neutral-to-mid-
available-range endpoint. It assigns unvisualized
obturator-internus/gemelli as primary and unvisualized obturator externus,
piriformis, and quadratus femoris as mechanics-derived secondaries. The
protocol does not report exact band force or deep-muscle recruitment, and the
completed trial evaluates the whole multi-exercise program rather than this
record in isolation. No visible hip muscle receives proxy mover credit.

Internal and external rotation remain separate families because their fixed
actions, exact postures, fixtures, and muscle contracts differ. The foundation
does not add a blanket `deepRotators` aggregate: these muscles do not share one
direction across hip position. Whole gluteus maximus retains external rotation
only at neutral flexion and is not copied into the 30-degree family. The
reviewed proposal records the complete atomic migration and the adverse source
limits that prevent either active record from generalizing to another posture
or apparatus.

Generic `foot.toeFlexion` remains a valid action rather than being narrowed to
great-toe flexion merely because flexor hallucis longus is its only currently
authored producer. The body asset also contains intrinsic flexor-hallucis-
brevis, flexor-digitorum-brevis, and flexor-digiti-minimi-brevis surfaces.
Before any toe-flexion family or exercise role activates, audit those meshes,
add the truthful intrinsic regions, and decide the required joint/segment
granularity. This is a foundation gate for a non-roadmapped candidate, not a
new item in the current 12-item count.

## Batch 7 — Core and carry (8)

Status: complete. Eight discovery candidates resolved into nine active
families because the carry candidate split into separate farmer and suitcase
contracts and both lumbar holds later closed through an atomic foundation
repair.

1. `spine-flexion`
2. `spine-extension`
3. `spine-lateral-flexion`
4. `spine-rotation`
5. `anti-extension`
6. `anti-lateral-flexion`
7. `anti-rotation`
8. `loaded-carry`

The batch activates four narrow dynamic fixtures: a 30-degree curl-up, a MedX
isolated lumbar extension, a fixed-crossed-foot side-lying trunk lift, and a
seated machine torso twist performed one rotation direction at a time. The
torso-twist record prescribes both separately logged directions; right-to-left
is a disclosed mirrored mechanics-and-training adaptation because the reviewed
source measured only left-to-right. The curl-up angles describe whole-trunk
elevation, not segmental lumbar angles. The torso-twist fixture distinguishes
the shoulder-height hand grips from the shoulder-pad load interface and labels
its held-pelvis instruction as a catalog adaptation because the source did not
measure pelvic kinematics.

The three anti-movement families use empty `primeActions` and name extension,
lateral flexion, or rotation as the resisted tendency. Their rosters are a
stable forearm plank, the exact reviewed floor side plank, and a feet-together
band Pallof hold. The carry candidate split into `farmer-carry` and
`suitcase-carry`: both resist finger extension, while suitcase additionally
resists spine lateral flexion and therefore uses a different plane basis and
muscle-role contract. Ordinary walking
propulsion and nonstandardized gait-related spine motion are not promoted to
training-defining dynamic actions.

`spine-extension` activates only after separating visible quadratus lumborum
from the explicitly unvisualized erector-spinae/multifidus region. The MedX
record credits that truthful lumbar-extensor region without painting QL or
posterior serratus as substitutes. `spine-lateral-flexion` uses Konrad's exact
dynamic crossed-foot fixture, condition-matched QL triangulation, and a
disclosed position-held hip/pelvis coaching adaptation. Its 30-degree value is
an upper-body/trunk-lift endpoint, not a segmental lumbar angle. The evidence
registry now admits canonical DOI, PMCID, or PMID routes with deterministic
priority, strict formatting, and cross-source uniqueness.

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
