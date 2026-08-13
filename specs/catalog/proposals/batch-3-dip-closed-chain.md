# Batch 3 — dip and closed-chain vertical-press review

Status: `dip` is approved for narrow activation. `closed-chain-vertical-press`
is resolved as a future branch of `vertical-press`, not a separate family, but
remains evidence-gated.

## Outcome

| Candidate | Decision | Load-bearing boundary |
|---|---|---|
| `dip` | Activate narrowly | A suspended closed-chain push whose ascent combines shoulder flexion from an extended bottom position with elbow extension |
| `closed-chain-vertical-press` | Merge into `vertical-press`, defer branch | Same flexion/abduction, upward-rotation/posterior-tilt, and elbow-extension signature as vertical press; dynamic exercise-specific anatomy and load evidence remain missing |

The two decisions deliberately use different standards. Two peer-reviewed dip
trials directly measured the dynamic exercise with three-dimensional motion
capture and surface electromyography. The handstand-push-up literature located
for this review provides a peer-reviewed technique description, a repeatable
field-test fixture, and static-handstand EMG, but no condition-matched dynamic
kinematics plus muscle-role study for the strict repetition. A plausible name
and a mechanically coherent model are not enough to activate a record.

## Dip: corrected concentric action

The dip's concentric shoulder action is **shoulder flexion**, not shoulder
extension. McKenzie et al. describe the lowering phase as elbow flexion plus
shoulder extension and the return as elbow extension plus shoulder flexion.
Their three-dimensional measurements found mean peak shoulder extension of
about 88 degrees for the bench dip, 79 degrees for the parallel-bar dip, and 62
degrees for the ring dip. The separate fatigue trial found approximately 68
degrees of peak extension in the parallel-bar setup. Those values describe the
extended bottom position; they do not turn extension into the ascent's
concentric action.

This distinction makes `dip` a sagittal vertical-push contract with fixed prime
actions:

```json
{
  "planeBasisActions": ["shoulder.flexion"],
  "primeActions": ["shoulder.flexion", "elbow.extension"]
}
```

`vertical` and `sagittal` answer different questions. The direction describes
the gross resisted body path: the suspended torso travels vertically between
fixed hand supports. The cardinal plane is derived only from the basis-joint
action: shoulder flexion from the extended bottom toward neutral is sagittal.
The bars' position beside the torso and any small frontal/transverse setup
angles do not add an anatomical plane. The ascent is flexion because shoulder
extension increased during descent and is reversed on the way up; an exercise
is not classified from the name of its deepest joint position.

The family is not a `decline-press` variant. Decline press is an open-chain,
supported transverse press built on shoulder horizontal adduction. The dip is
a closed-chain, unsupported sagittal push that starts with the humerus behind
the torso. It is also not elbow-extension isolation because shoulder angle
changes materially under load.

## Dip: scapular evidence boundary

Neither reviewed dip trial measured scapular kinematics. The fatigue paper
explicitly says that scapular kinematics warrant future investigation and
discusses possible protraction or depression changes as unmeasured
explanations. Serratus anterior, lower trapezius, and upper trapezius were all
measured as candidate scapular stabilizers, but that panel cannot prove which
scapular orientation action occurred. The initial catalog uses serratus alone
as the minimum directly observed scapula-capable stabilizer; it does not turn
every measured candidate into mandatory involvement. Omitting the two
trapezius regions is not a claim of inactivity.

The activated contract therefore forbids `scapula.depression` and the other
scapular actions as **training-defining prime actions**. That is an evidence
boundary, not a claim that the scapula has zero motion during a real dip. A
future dynamic scapular-motion study may justify revising the signature, but a
coaching cue such as “keep the shoulders down” may not.

This also preserves the roadmap's depression boundary: a straight-arm
scapular-depression repetition holds shoulder and elbow angles while the
scapula moves. A dip changes both the shoulder and elbow angles and cannot be
used as the fixture for a scapular-only family.

## Dip: initial scope and anatomy

The initial roster contains only the two dynamic conditions directly compared
in the reviewed trial:

| Exercise | Owned setup | Evidence limit |
|---|---|---|
| Bar Dip | Full suspended bodyweight on fixed V-shaped dip bars | Exact kinematics and nine-muscle EMG are directly measured; the authored `fixedDipBars` value is categorical rather than pretending the unreported laboratory V angle is a universal geometry |
| Ring Dip | Full suspended bodyweight on two independent rings | Exact kinematics and the same nine-muscle panel are directly measured; the independent supports explain the extra observed biceps and latissimus stabilization |

Both records use `bodyweightFraction: 1`, `bodyweightAdded`, a closed kinetic
chain, no lower-body contact or propulsion, and a free rather than guided body
path. Added belt load remains expressible through `bodyweightAdded`; it does
not create a second exercise record.

The contract reuses the existing `bodyweightApparatus` axis rather than
inventing a dip-local synonym. Shoulder-extension row admits `fixedBar`; dip
adds the family-local reviewed values `fixedDipBars|rings` under the same
meaning: the apparatus held during a bodyweight exercise.

The study supplied no grip-orientation instruction and explicitly allowed
self-moderated technique. The contract therefore does not manufacture a
`gripOrientation` value—especially for freely rotating rings. Apparatus and
fixed-versus-independent support are reviewed axes; hand orientation is not.

The family assigns pectoralis-major clavicular head and triceps as co-primary
training targets, with anterior deltoid secondary. This is a categorical
contract rather than a numeric force ranking. McKenzie measured the clavicular
pectoral site, anterior deltoid, and triceps and repeatedly identifies
pectoralis major and triceps as the dip's target agonists. The sternal head was
not measured, and the current anatomy profile does not give that region an
unconditioned shoulder-flexion capability. It is therefore not copied into the
contract by intuition.

The role choice has two disclosed limits:

- the variation comparison reports raw within-muscle EMG amplitudes, so its
  values cannot establish a pectoralis-versus-triceps magnitude ranking; and
- surface EMG from one pectoral site cannot establish whole-pectoralis or
  regional force contribution.

Both target actions nevertheless need a training-defining mover, and the
exercise-specific authors identify both tissues as intended targets. The
contract consequently uses two categorical primaries instead of manufacturing
a sole-primary hierarchy from incomparable amplitudes.

### Tracked foundation hold: sternocostal flexion from extension

This omission has a user-visible cost and is not considered finished anatomy.
The active dip records will eventually highlight and credit only the
clavicular pectoral region, while `pectoralisMajorSternocostal` receives no 3D
highlight or MuscleVolume/Development credit. The gap can also affect any
future family whose resisted shoulder flexion begins behind anatomical neutral.

The missing capability cannot be repaired by copying the measured clavicular
site or by granting the sternocostal region unconditional shoulder flexion.
The proposed `fromExtendedPosition` condition remains inactive until reviewed
action-capability evidence establishes sternocostal flexion across the
dip-relevant extended-to-neutral range. Exercise-specific evidence must then
support whether the region is primary, secondary, or merely stabilizing in the
dip; the present studies' clavicular surface-EMG electrode cannot answer that
regional-role question.

If those two evidence gates pass, activation must add the condition centrally,
add the conditioned sternocostal capability, re-review every family using
flexion from extension, and update the dip family, body-highlight expectations,
volume-credit expectations, and tests in one change. Until then, zero authored
sternocostal involvement is the honest temporary result, and this hold is
counted explicitly in the family roadmap rather than disappearing behind a
valid contract.

External rotators use the directly measured infraspinatus site as a shoulder
stabilizer. The static hand/wrist and trunk entries are narrower mechanics
inferences because the dip studies did not measure those regions: the shared
loaded-grip convention contributes finger flexors plus radial wrist extensors,
while rectus abdominis, obliques, and lower back are all assigned as
stabilizers. That three-muscle trunk set follows the existing unsupported,
fully suspended pull-up convention: opposing anterior, lateral/rotational, and
posterior trunk capabilities maintain the spine and pelvis while the full body
hangs from the hands. This is a categorical mechanics inference, not an
exercise-specific EMG ranking, and it does not make trunk motion part of the
repetition. The contract does not list every plausible scapular stabilizer
merely to appear anatomically complete.

The ring record additionally assigns latissimus dorsi and biceps brachii as
stabilizers. In the direct comparison they were among the three muscles with
significantly greater peak activation on rings than bars, and the authors
interpret them as shoulder-adduction/joint-stiffening contributors. They are
not promoted to dynamic prime movers because adduction is not an admitted
repetition action.

## Dip: explicit exclusions

| Candidate variant | Decision | Reason |
|---|---|---|
| Bench dip | Exclude from the family | The direct trial found a materially different body relationship, foot support, lower load, and shoulder extension beyond the subjects' self-selected passive-ROM test; its authors advise against regular strength or rehabilitation use |
| Assisted dip machine | Defer | A guided assistance platform changes load semantics and body-path vocabulary; no reviewed condition-matched trial anchors its fraction or anatomy |
| Standing-assisted dip | Defer | Lower-body contact makes effective bodyweight and propulsion variable |
| Band-assisted dip | Defer | Non-comparable assistance changes through the range and lacks a reviewed load representation |
| Weighted dip | No separate record | The base bar or ring record already tracks added weight through `bodyweightAdded` |
| Straight-bar, Korean, Russian, kipping, or muscle-up-transition dip | Exclude | Each changes the apparatus, body path, action set, or propulsion beyond the reviewed strict repetition |
| One-arm dip | Exclude | No unilateral condition is reviewed, and its balance/stability demands are not a bounded delta from the bilateral trial |

## Closed-chain vertical press: ownership decision

A strict handstand push-up should not become a ninth-direction or
bodyweight-named sibling. At the top, the fixed hands and elevated torso form
the same anatomical overhead relationship reached by an open-chain vertical
press. The proposed concentric signature remains shoulder flexion and
abduction, scapular upward rotation and posterior tilt, and elbow extension.
Its family classification therefore remains compound, push, vertical, and
sagittal plus frontal. `kineticChain`, body/load support, and apparatus are
variant properties, not a different family contract.

Accordingly, the roadmap candidate is resolved as a future branch of
`vertical-press`. The active family's current exclusion of closed-chain
bodyweight work remains correct until the evidence gate below is met.

## Exact deferred branch

If the branch unlocks, its smallest useful roster is:

| Proposed record | Setup that must be pinned |
|---|---|
| `handstand-push-up` | Strict freestanding floor handstand; pronated palms; head-limited range; no wall contact, kick, hip drive, or kip |
| `parallette-handstand-push-up` | Strict freestanding neutral-grip parallette handstand; head travels below hand level; no wall contact, kick, hip drive, or kip |

Wall-supported handstand push-ups remain a later branch because foot-wall
contact can alter balance, path, and effective support. Pike and box pike
push-ups remain deferred because hand/foot load distribution changes with body
geometry and no reviewed bodyweight fraction is available. Headstand-start
tests describe an auditable repetition endpoint but do not establish the
fraction of load carried through the hands while the head is in contact.
Kipping handstand push-ups add hip and knee propulsion and route to a future
power or leg-driven contract rather than this strict branch.

The eventual vertical-press migration would need to:

1. add `bodyweight` equipment and `bodyweightAdded` load mode;
2. admit `kineticChain: closed` and `bodyPosition: inverted`;
3. keep `scapularTranslation: free`, `fixedPath: false`,
   `lowerBodyContribution: none`, and the 90-degree torso-relative press
   orientation for the strict branch;
4. add a bodyweight-only `bodyweightApparatus: floor|parallettes` axis and a
   range boundary such as `headLimited|deficit`, with both absent on external
   load records;
5. require hand and wrist stability demands plus exact capable stabilizers;
6. pin floor support to pronated grip and parallette support to neutral grip;
   and
7. reject wall contact, head/neck loading as propulsion, lower-body drive, and
   any reclassification of the branch as a horizontal push-up.

This is a family-contract migration only. It does not require a new joint
action, condition, schema keyword, or validator feature.

## Why the branch remains deferred

Johnson et al. provide a peer-reviewed technique article and explicitly call
the handstand push-up a dynamic upper-extremity exercise combining handstand,
shoulder-press, and push-up components. Sleeper et al. provide a reproducible
wall-adjacent head-to-floor field test with elbow lockout. Those sources define
the task but do not measure dynamic three-dimensional shoulder/scapular
kinematics, changing hand force, or muscle-role hierarchy.

Kochanowicz et al. measured 13-muscle EMG during a **five-second static
handstand** on floor, parallel bars, and rings. It supports the importance of
hand-support conditions and the need to model wrist/hand and whole-body
stability. It does not establish the concentric roles of a handstand push-up,
the scapular actions during descent/ascent, or the load fraction at a
head-contact bottom position. Static support EMG must not be promoted into a
dynamic family contract.

The branch unlocks only when a directly reviewed strict handstand-push-up
source or a tracked measurement protocol establishes, for the same setup:

- dynamic humeral and scapular kinematics through the repetition;
- elbow excursion and explicit absence of hip/knee propulsion;
- time-varying hand/head support forces or a defensible catalog load anchor;
- a condition-matched muscle panel sufficient to defend the existing
  vertical-press role requirements; and
- the exact wall, floor/parallette, grip, and range-of-motion condition.

Until then, copying the open-chain vertical-press anatomy would hide a
mechanics-derived assumption behind an apparently evidence-backed record.

## Evidence metadata and integration needs

The dip activation requires these two new registry entries:

| Proposed ID | Metadata | Load-bearing scope |
|---|---|---|
| `mckenzie-2022-dip-variations` | Alec McKenzie, Zachary Crowley-McHattan, Rudi Meir, John Whitting, Wynand Volschenk. “Bench, Bar, and Ring Dips: Do Kinematics and Muscle Activity Differ?” *International Journal of Environmental Research and Public Health* 19(20):13211. DOI `10.3390/ijerph192013211`; PMID `36293792`; published 2022-10-14. | Thirteen experienced males; direct 3D kinematics and nine-muscle sEMG for bench, parallel-bar, and ring dips. Supports the two admitted fixtures, action boundary, and apparatus-conditioned stabilization; raw EMG does not rank muscles against each other. |
| `mckenzie-2022-bar-dip-fatigue` | Alec McKenzie, Zachary Crowley-McHattan, Rudi Meir, John Whitting, Wynand Volschenk. “Fatigue Increases Muscle Activations but Does Not Change Maximal Joint Angles during the Bar Dip.” *International Journal of Environmental Research and Public Health* 19(21):14390. DOI `10.3390/ijerph192114390`; PMID `36361276`; published 2022-11-03. | Fifteen experienced males; direct 3D kinematics and nine-muscle sEMG for a parallel-bar set to exhaustion. Confirms the extended bottom, flexion/extension reversal, pectoralis/triceps target, and explicitly unmeasured scapular kinematics. |

The following reviewed sources belong in this proposal but should **not** be
registered during this activation because the deferred branch will not cite
them and unused evidence fails validation:

- Abigail Johnson, Melanie Meador, Meghan Bodamer, Emily Langford, Ronald L.
  Snarr. “Exercise Technique: Handstand Push-up.” *Strength & Conditioning
  Journal* 41(2):119–123, 2019. DOI `10.1519/SSC.0000000000000427`.
- Andrzej Kochanowicz, Bartlomiej Niespodzinski, Jan Mieszkowski, Michel
  Marina, Kazimierz Kochanowicz, Mariusz Zasada. “Changes in the Muscle
  Activity of Gymnasts During a Handstand on Various Apparatus.” *Journal of
  Strength and Conditioning Research* 33(6):1609–1618, 2019. DOI
  `10.1519/JSC.0000000000002124`; PMID `28700510`.
- Mark D. Sleeper, Lisa K. Kenyon, James M. Elliott, M. Samuel Cheng.
  “Measuring Sport-Specific Physical Abilities in Male Gymnasts: The Men's
  Gymnastics Functional Measurement Tool.” *International Journal of Sports
  Physical Therapy* 11(7):1082–1100, 2016. PMID `27999723`; PMCID
  `PMC5159633`. No DOI was located, so the current evidence schema cannot
  register it without the separately tracked alternative-identifier change.

No validator or schema extension is needed for the activated dip contract.
Shared integration needs are limited to registering the two dip sources,
adding the active-family counts and shared apparatus vocabulary to the family
README/roadmap, and adding exact contract tests.

## Test gate

Activation must add tests that prove:

- exact fixed classification, shoulder-flexion basis, and elbow-extension
  companion action;
- both support apparatus and both hand-support-constraint values are covered;
- each of the two apparatus rules has a matching and contrasting fixture;
- mutating either apparatus/constraint pairing fails with the named rule;
- removing either ring-only latissimus or biceps stabilization fails the named
  ring rule;
- every forbidden scapular action and shoulder extension is rejected as an
  exercise-level prime action;
- bench/foot-supported, unilateral, assisted, non-bodyweight, and propelled
  mutations are rejected by the fixed scope; and
- the global catalog-ID, name, alias, evidence-use, metric-seed, and discrete
  axis-coverage tests continue to include the family automatically.

The roadmap and proposal tests should separately pin the closed-chain vertical
press decision as “merge into `vertical-press`, deferred” so a later author
does not create a duplicate sibling family merely from the candidate name.
