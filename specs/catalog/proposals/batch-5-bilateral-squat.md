# Batch 5 bilateral-squat activation record

Status: **activated with two reviewed fixtures, registered evidence, and
contract/mutation tests**.

This document records the decisions behind
`families/bilateral-squat.json`. It does not activate a broad class of things
called squats. The first family owns only two directly reviewable, unsupported,
free-weight, straight-bar exercises:

1. `barbell-back-squat`; and
2. `barbell-front-squat`, using a canonical clean-grip front rack.

The reviewed studies support the anterior load placement and squat mechanics,
but clean grip was not a controlled experimental factor. The active grip is a
figure- and canonical-mechanics-derived product setup, retained as a narrow
fixture rather than presented as a directly compared evidence condition.

Both use a hip-width symmetric stance, continuous bilateral floor contact, a
thigh-parallel bottom position, and no inter-repetition support. Both descend
through hip and knee flexion plus ankle dorsiflexion and return to standing
through hip extension, knee extension, and ankle plantarflexion. The family
authors the concentric actions, consistent with every active dynamic contract.

## Why this is a squat family

The distinguishing feature is not merely simultaneous hip and knee motion.
The reviewed task keeps both feet planted while the athlete lowers the pelvis
between and behind the feet to a thigh-parallel bottom, then returns to
standing. Hip and knee extension are both training-defining actions. This
separates the family from:

- a hinge, where posterior hip travel and hip extension dominate while knee
  angle changes less;
- a floor pull, where every repetition begins from external floor support and
  may use a knee-extension-heavy first pull;
- a leg press, where the torso and pelvis are externally supported and the
  distal interface or sled moves on a machine path;
- a hip thrust or bridge, where the pelvis supplies the visible load path and
  the torso or shoulders are externally supported;
- a split squat, lunge, or step-up, where the two legs do not share the same
  symmetric stance and support task; and
- squat-shaped power tasks, where jumping, receiving, or pressing changes the
  movement's modality and action contract.

The app-level fixed classification is therefore:

```json
{
  "mechanic": "compound",
  "pattern": "squat",
  "direction": null,
  "planes": ["sagittal"]
}
```

`direction` remains `null`: horizontal and vertical direction values describe
the principal path distinctions used by presses and pulls, not a reason to call
every standing exercise vertical. Hip extension is the one sagittal plane-
basis action. Knee and ankle remain prime actions at other joints; the basis
list is not a second copy of every action in the repetition.

## Exercise-specific evidence decisions

### The two fixtures

Goršič et al. directly compared straight-bar back and front squats in the same
study. Participants began with their heels hip-width apart, used a fixed 70%
of straight-bar front-squat 1-RM, touched an elastic band at the bottom, and
performed two-second descents and ascents. The paper calculated hip, knee, and
ankle extension moments at the estimated parallel position. This directly
anchors the two load placements, stance width, continuous repetitions, and
compound lower-limb demand. It does not contain exercise EMG and must not be
used by itself to rank muscles.

McCormick et al. tested loaded barbell back and front squats with feet
hip-width apart and thighs near parallel. It measured hip, knee, ankle, and
lumbar kinematics plus internal/external oblique, rectus abdominis,
iliocostalis, multifidus, rectus femoris, vastus lateralis, biceps femoris, and
gluteus maximus EMG. Trunk activity was higher in the front squat for internal
oblique, external oblique, and iliocostalis. This supports explicit whole-trunk
stabilizers in both records and makes clear that a front rack does not remove
the spine demand. The front-squat load was deliberately lower than the
back-squat load, so the study does not justify a numeric cross-variant muscle
ranking.

Joseph et al. tested parallel barbell back squats and belt squats at an
external load equal to body weight. Its panel directly included rectus femoris,
two vastus sites, biceps femoris, gluteus maximus, adductors, medial
gastrocnemius, lumbar extensors, rectus abdominis, and external oblique. It is a
condition-matched muscle and trunk anchor for the back-squat record and an
adverse comparison showing why belt squat is not a load-placement delta inside
the same initial contract. Belt loading materially reduced gluteus-maximus and
trunk excitation. The paper did not perform a kinematic equivalence analysis,
so it cannot activate a belt branch.

Yavuz et al. measured front and back squats under maximal loading with vastus
lateralis, vastus medialis, rectus femoris, semitendinosus, biceps femoris,
gluteus maximus, and erector-spinae EMG. Vastus medialis was greater in the
front squat and semitendinosus was greater in the back squat during ascent,
while knee kinematics did not differ. Excitation alone does not prove that a
biarticular hamstring supplied net hip-extension work while also opposing knee
extension. The visible medial-hamstring region is therefore retained only as a
hip, pelvis, and knee stabilizer rather than promoted to a dynamic secondary.

Kubo et al.'s ten-week MRI study found knee-extensor, adductor, and gluteus-
maximus hypertrophy after squat training, with greater adductor and gluteus-
maximus growth after full than half squats. Rectus femoris and hamstrings did
not significantly grow in either group. This supports practical emphasis on
the vasti and gluteus maximus while keeping rectus femoris secondary and the
medial hamstrings in a control role. It does **not** prove that every
anatomically capable
adductor compartment is a dynamic contributor across the active parallel
range. Vivobody's visible adductor-magnus profile deliberately omits sagittal
actions because its unsplit compartments have different moment directions;
the family therefore does not fabricate an adductor role merely from a group-
level hypertrophy result.

### Ankle plantarflexion is an authored action

Batch 4 correctly left this as a gate: an ankle plantarflexor **moment** does
not by itself prove ankle plantarflexion motion. This family clears the gate
with kinematic evidence rather than silently equating kinetics with movement.

- Armstrong et al. reported approximately 40 degrees of ankle range during
  traditional squat repetitions. In the barbell comparison cohort, positive
  ankle angle represented dorsiflexion and negative angle represented
  plantarflexion; the front- and back-squat angle curves traversed the ankle
  range over descent and ascent.
- Pürzel et al. explicitly reported earlier ankle plantarflexion during the
  concentric phase of low-bar squats as intensity increased. The study defined
  positive internal ankle moments as plantarflexion moments and separately
  analyzed the ankle-angle waveform, so its kinematic statement is not merely
  a relabeled net moment.
- Sinclair et al.'s modeled back-squat conditions included gastrocnemius and
  soleus force and showed both were sensitive to foot-placement angle. This is
  muscle-force support for the plantarflexor contributors, not the source of
  the movement label.

Pürzel's cohort was 29 elite powerlifters performing IPF-style low-bar squats
at 70--90% estimated 1-RM. It is not a condition-matched canonical back- or front-rack
fixture and cannot activate a low-bar record or define the roles of the two
active exercises. Its deliberately narrow use is to confirm that concentric
squat ascent contains ankle plantarflexion as an angular action. Armstrong's
separate front/back barbell comparison prevents that conclusion from resting
only on elite low-bar technique.

The family therefore declares:

```json
{
  "planeBasisActions": [
    "hip.extension"
  ],
  "primeActions": [
    "hip.extension",
    "knee.extension",
    "ankle.plantarflexion"
  ]
}
```

`primeAction` means the action belongs to the repetition, not that each action
receives equal training emphasis. Gastrocnemius and soleus remain secondary in
a squat even though they produce an authored action.

## Muscle policy

| Role | Regions | Decision |
|---|---|---|
| Required primary | `vasti`, `gluteMax` | Principal knee- and hip-extension training emphases in the reviewed parallel squat. |
| Required secondary | `rectusFemoris` | Meaningful knee extensor, but the biarticular region is not promoted over the vasti and did not hypertrophy in Kubo's intervention. |
| Required secondary | `gastrocnemius`, `soleus` | Ankle plantarflexors contributing to the authored ankle action; the family is not a calf-emphasis exercise. |
| Required stabilizer | `medialHamstrings` | Yavuz establishes squat excitation, but biarticular co-contraction does not establish net hip-extension contribution while the knee extends. The conservative role credits control of hip, pelvis, and knee. |
| Required stabilizer | `fingerFlexors`, `extensorCarpiRadialis` | Shared static loaded-grip convention: hold the bar and control the wrist without inventing dynamic finger or wrist prime actions. |
| Required stabilizer | `brachialis` | Controls the maintained flexed-elbow bar position; it does not imply dynamic elbow flexion. |
| Required stabilizer | `trapeziusUpper` | Controls the scapular/shoulder-girdle support task under either free-bar placement. |
| Required stabilizer | one of `externalRotators` or `deltoidAnterior` | Back-squat and clean-grip front-rack shoulder demands differ. A cross-rule pins external rotators to the upper-back bar and anterior deltoid to front rack rather than assigning both universally. |
| Required stabilizer | `abs`, `obliques`, `lowerBack` | The complete unsupported free-bar trunk set; directly measured trunk bracing is load-bearing in this family. |

The plantarflexor pair is not inferred from capability alone. Joseph directly
measured medial-gastrocnemius excitation in the condition-matched parallel back
squat, while Sinclair estimated both gastrocnemius and soleus force during
loaded back squats. Goršič measured an ankle plantarflexion moment in both
active straight-bar conditions, and the anatomical profile establishes that
these two admitted regions can supply that action. Soleus on the front-squat
record remains a disclosed mechanics-derived transfer rather than a direct
front-squat EMG observation.

The unsplit `bicepsFemoris` profile has only the common knee-flexion capability
of its long and short heads. Assigning it as a secondary hip extensor would
falsely credit the short head. The active family instead uses the visible
medial-hamstring region for its honest hip, pelvis, and knee control assignment
without claiming net hip-extension work. Biceps-femoris EMG in Joseph and
McCormick remains disclosed evidence, not permission to override the taxonomy
gate.

`adductorMagnus` is also deliberately absent. The current scene region combines
compartments with different sagittal moment directions and advertises only hip
adduction. An exercise-specific adductor EMG or hypertrophy result cannot make
that whole visible region capable of unrestricted hip extension.

## Variant vocabulary

| Axis | Values | Meaning |
|---|---|---|
| `kineticChain` | `closed` | Both feet remain fixed against the floor as the body moves. |
| `bodyPosition` | `standing` | Start and finish posture. |
| `torsoSupport` | `none` | No pad, bench, rail, or other surface supports the torso. |
| `stanceConfiguration` | `symmetricBilateral` | Both feet share a non-split bilateral stance. |
| `stanceWidth` | `hipWidth` | The direct front/back comparison pinned the heels hip-width apart. |
| `loadPlacement` | `upperBackBarbell\|anteriorDeltoidClavicleBarbell` | The reviewed straight-bar support site. The back-squat evidence does not consistently report a high- versus low-bar site, so `upperBackBarbell` remains deliberately broader than either claim. |
| `gripOrientation` | `pronated\|cleanGrip` | The canonical back-squat or front-rack hand setup. |
| `rangeOfMotion` | `thighParallel` | Upper thighs reach approximately parallel; not a generic full/half/deep claim. |
| `spineMotion` | `nonstandardized` | McCormick measured load- and bracing-sensitive lumbar alignment. The spine controls the task but is not literally angle-held or a deliberate prime mover. |
| `hipMotion` | `extends` | Dynamic concentric hip action. |
| `kneeMotion` | `extends` | Dynamic concentric knee action. |
| `ankleMotion` | `plantarflexes` | Dynamic return from bottom-position dorsiflexion toward standing. |
| `footMotion` | `positionHeld` | No toe or foot articulation creates the repetition. |
| `footContact` | `continuous` | Both feet stay on the floor throughout. |
| `interRepSupport` | `none` | No box or floor reset receives the athlete or load. |
| `fixedPath` | `false` | No Smith rails, sled, or machine lever constrains the external load. |
| `lowerBodyContribution` | `compoundHipKneeAnkleExtension` | Names the three deliberately dynamic lower-body concentric actions. |

The shared Batch-5 IDs are `stanceConfiguration`, `loadPlacement`,
`rangeOfMotion`, `footContact`, and `interRepSupport`. Values stay
family-reviewed. For example, `symmetricBilateral` must not be copied to a
split squat, and `thighParallel` must not be interpreted as the front-leg
bottom criterion of a lunge.

`stanceWidth` is separate from `stanceConfiguration`. One identifies topology
(symmetric versus split or platform-leading); the other records the reviewed
distance between the feet. Combining them into `hipWidthSymmetric` would make
future cross-family comparison and mutation rules less precise.

## Cross-field rules

The two admitted load placements and product grip setups form exact reciprocal
pairs. These rules bound the selected fixture; they do not turn clean grip into
a controlled study factor:

1. `upper-back-load-uses-back-squat-setup`: upper-back placement
   requires a pronated grip and `externalRotators: stabilizer`.
2. `pronated-grip-is-back-squat`: pronated requires upper-back
   placement.
3. `anterior-load-uses-clean-grip`: anterior-deltoid/clavicle placement
   requires a clean grip and `deltoidAnterior: stabilizer`.
4. `clean-grip-is-front-rack-squat`: clean grip requires anterior-deltoid/
   clavicle placement.

Single-value axes provide the remaining hard boundary without always-true
exercise rules. In particular, `fixedPath: false` is an axis-level invariant;
an exercise rule with an always-true predicate could not have the contrasting
fixture required by the family test pattern.

## Initial roster

| Exercise | Placement / grip | Direct support | Seed |
|---|---|---|---:|
| Barbell Back Squat | Upper back / pronated | Armstrong, Goršič, Joseph, McCormick, Yavuz; Sinclair for plantarflexor force; Pürzel only for the cross-squat ankle-motion gate | 45 lb / 20 kg, 8 reps |
| Barbell Front Squat | Anterior deltoid and clavicle / canonical clean grip (figure-/mechanics-derived) | Armstrong, Goršič, McCormick, Yavuz | 45 lb / 20 kg, 8 reps |

Both use an unloaded standard bar as the conservative clean scrubber seed.
The seed is a product default, not an evidence claim about training intensity.

## Boundary and ownership matrix

| Candidate | Decision | Reason / future owner |
|---|---|---|
| Explicit high-bar or low-bar variants | Defer | The active canonical back-squat record does not fabricate an unreported site. Distinct variants require sources that pin bar site plus reviewed stance, trunk strategy, and role deltas. Pürzel directly supports low-bar mechanics but cannot establish the unreviewed high-bar contrast alone. |
| Safety-bar or transformer-bar squat | Defer | Different implement, handle, shoulder, and load-placement semantics. Goršič's transformer-bar trials are evidence of meaningful posture compensation, not permission to emit a barbell alias. |
| Smith squat | Defer | Requires `fixedPath: true`, a machine type, foot-position review relative to the rails, and machine-specific roles. |
| Hack squat | Exclude from this branch | Supported torso and guided sled/lever path; future machine-squat branch or family. |
| Pendulum squat | Exclude from this branch | Supported torso and arc-guided machine mechanism; not a straight-bar placement delta. |
| Belt squat | Defer | Pelvic load placement and machine restraint materially reduce trunk and glute demand in Joseph; requires its own reviewed branch. |
| Leg press | Exclude | Seated/reclined torso and pelvis support plus guided sled or footplate; future leg-press family. |
| Goblet squat | Defer | Hands-front implement, load ceiling, shoulder/hand demands, and stance require direct review. |
| Dumbbell squat | Defer | Hands-at-sides loading changes grip, trunk, and external moment geometry. |
| Bodyweight squat | Defer | Load mode and volume-credit semantics differ; no external-load seed or reviewed bodyweight fraction. |
| Heel-elevated squat | Defer | Changes ankle posture and work distribution; it is not merely a stance value. |
| Box squat | Exclude from initial branch | `interRepSupport` would be `box`; sitting/reset mechanics and posterior strategy need direct evidence. |
| Pin or Anderson squat | Exclude from initial branch | External bar support and dead-start semantics differ. |
| Full/deep squat | Defer | Depth changes glute/adductor demand; the active axis intentionally admits only thigh-parallel. |
| Half/quarter squat | Defer | Partial range changes joint moments and training emphasis. |
| Overhead squat | Exclude | Adds dynamic shoulder/scapular support and mobility requirements outside the narrow lower-body family. |
| Squat jump | Exclude | Power modality, flight, and landing replace continuous foot contact. |
| Thruster | Exclude | Adds a full press family signature after the squat. |
| Zercher squat | Defer | Elbow-cradle load interface and upper-body demands need direct review. |
| Split squat / lunge | Exclude | Stationary split squats are owned by `split-stance-squat`; dynamic lunges remain deferred because asymmetric support and laterality are not stance-width deltas. |
| Step-up | Exclude | Owned by `step-up`; the lead foot begins on an elevated platform. |
| Hip hinge / floor pull | Exclude | Owned by `hip-hinge` or a future floor-pull branch; squat requires the reviewed knee-extension contribution and no floor reset. |
| Hip thrust / bridge | Exclude | Owned by `hip-thrust-bridge`; pelvis path and torso support distinguish it. |

## Activation gates and tests

Activation should land atomically with the other Batch-5 families:

1. Register every evidence ID below with the exact DOI URL and reviewed scope.
2. Validate global name and alias uniqueness; in particular, no other family
   may own `Front Squat`, `Back Squat`, or `Straight-Bar Back Squat`.
3. Update the active family/exercise totals and Batch-5 README vocabulary.
4. Assert the exact two-record roster, family classification, prime actions,
   forbidden-action complement, stability demands, muscle-policy surface,
   axis definitions, defaults, aliases, and evidence references.
5. Copy the enum/boolean-aware roster-axis coverage test. Every admitted enum
   value must appear, and `fixedPath` must be checked as a boolean rather than
   passed to `set(...)`.
6. For every cross-field JSON rule ID, provide one matching record and one
   contrasting record. Mutate every `then` assertion and every
   `requireInvolvement` assertion independently.
7. Mutate `upperBackBarbell` to clean grip and
   `anteriorDeltoidClavicleBarbell` to pronated; both reciprocal rules must
   reject the invalid cross-products with their rule-specific messages.
8. Remove `externalRotators` from the back-squat record and `deltoidAnterior`
   from the front-rack record; the corresponding load-placement rule must
   reject each mutation.
9. Mutate each single-value boundary: bilateral to unilateral, barbell to
   machine, dynamic strength to power, external to bodyweight, closed to open,
   symmetric to split, hip-width to another width, parallel to partial/full,
   continuous contact to flight, no inter-rep support to floor/box, and free to
   fixed path.
10. Mutate or remove each prime action and add every forbidden action one at a
    time. A dedicated assertion must pin ankle plantarflexion as prime so a
    future editor cannot revert the reviewed decision to moment-only language.
11. Remove each required muscle. Also mutate each role one level below its
    minimum. Pin the exact current back-squat/front-rack shoulder assignments
    and prove each setup-specific minimum is enforced. The present rule schema
    does not claim that adding the other setup's stabilizer is impossible.
12. Assert every stability demand is covered by at least one assigned anatomy
    profile under the normal role-agnostic policy. External load placement does
    not itself satisfy shoulder, scapular, wrist, hand, spine, or pelvis
    control.
13. Assert every positive default weight has a clean-grid metric seed.
14. Run the full catalog validator, Python suite, `git diff --check`, JSON
    parsing, and the required app build.

## Evidence IDs to register

| ID | Exact source | DOI / PMID | Load-bearing scope and limits |
|---|---|---|---|
| `armstrong-2022-squat-movement-dynamics` | Richard Armstrong, Vasilios Baltzopoulos, Carl Langan-Evans, Dave Clark, Jonathan Jarvis, Claire Stewart, Thomas O'Brien, “An investigation of movement dynamics and muscle activity during traditional and accentuated-eccentric squatting,” *PLOS ONE* 17(11):e0276096 (2022) | DOI `10.1371/journal.pone.0276096`; PMID `36318527`; PMC `PMC9624406` | Primary cohort: nine trained men performing motorized-cable squats across traditional/accentuated loads. Secondary cohort directly compared barbell back, barbell front, and Kineo squats at 50, 85, and 100% body mass, recording joint kinematics and glute-max/vastus-lateralis EMG. It supports front/back ankle-range transfer and is not a muscle-policy ranking, precise back-bar placement report, or permission to activate the Kineo fixture. |
| `gorsic-2024-squat-load-placement` | Maja Goršič, LuAnna E. Rochelle, Jacob S. Layer, Derek T. Smith, Domen Novak, Boyi Dai, “Biomechanical comparisons of back and front squats with a straight bar and four squats with a transformer bar,” *Sports Biomechanics* 23(2):166--181 (2024; online 2020) | DOI `10.1080/14763141.2020.1832563`; PMID `33161870`; PMC `PMC8106690` | Eighteen trained adults; hip-width straight-bar front/back and transformer-bar conditions at 70% straight-bar front-squat 1-RM; estimated parallel-position trunk, pelvis, hip, knee, and ankle kinetics. Direct fixture and load-placement evidence, not exercise EMG or fixed universal role ranking. |
| `joseph-2020-back-belt-squat` | Lori Joseph et al., “Activity of Trunk and Lower Extremity Musculature: Comparison Between Parallel Back Squats and Belt Squats,” *Journal of Human Kinetics* 72:223--228 (2020) | DOI `10.2478/hukin-2019-0126`; PMID `32269663`; PMC `PMC7126258` | Ten experienced participants, three sets of five at bodyweight external load; direct parallel back-squat muscle panel and adverse belt-squat comparison. No kinematic equivalence analysis and no front squat. |
| `kubo-2019-squat-depth-hypertrophy` | Keitaro Kubo, Toshihiro Ikebukuro, Hideaki Yata, “Effects of squat training with different depths on lower limb muscle volumes,” *European Journal of Applied Physiology* 119(9):1933--1942 (2019) | DOI `10.1007/s00421-019-04181-y`; PMID `31230110` | Ten-week MRI intervention comparing full and half squat training. Supports training-emphasis decisions and depth sensitivity; group-level adductor data cannot override the visible-region action model or activate a new depth value. |
| `mccormick-2023-front-back-squat-bracing` | Joseph B. McCormick et al., “The Effect of Volitional Preemptive Abdominal Contraction on Biomechanical Measures During A Front Versus Back Loaded Barbell Squat,” *International Journal of Sports Physical Therapy* 18(4):831--844 (2023) | DOI `10.26603/001c.84306`; PMID `37547830`; PMC `PMC10399089` | Twenty-six men; hip-width near-parallel loaded back/front squats, trunk/lower-limb EMG and kinematics. Front load was a conservative fraction of back-squat working load; no numeric cross-variant ranking. |
| `purzel-2026-powerlifting-squat-joint-moments` | Alexander Pürzel, Paul Kaufmann, Willi Koller, David Deimel, Arnold Baca, Hans Kainz, “Differences in hip, knee, and ankle joint moments during squats across load intensities, gender classes, and performance level in elite powerlifters,” *Scientific Reports* 16:13418 (2026) | DOI `10.1038/s41598-026-43999-3`; PMID `41826687`; PMC `PMC13111623` | Twenty-nine elite powerlifters performing IPF low-bar squats at 70--90% estimated 1-RM. Direct separation of ankle moment and angle waveforms and explicit concentric plantarflexion; used only for the ankle-action gate, not to activate a distinct low-bar record or define canonical back/front-rack roles. |
| `sinclair-2022-back-squat-foot-angle` | Jonathan Sinclair et al., “Two-Experiment Examination of Habitual and Manipulated Foot Placement Angles on the Kinetics, Kinematics, and Muscle Forces of the Barbell Back Squat in Male Lifters,” *Sensors* 22(18):6999 (2022) | DOI `10.3390/s22186999`; PMID `36146352`; PMC `PMC9501107` | Back-squat 3D kinematics, kinetics, and modeled muscle forces at 70% 1-RM; direct gastrocnemius/soleus force support and proof that foot angle is anatomy-bearing. Does not pre-authorize a foot-orientation axis in the narrow roster. |
| `yavuz-2015-front-back-squat-emg` | Hasan Ulas Yavuz, Deniz Erdağ, Arif Mithat Amca, Serdar Aritan, “Kinematic and EMG activities during front and back squat variations in maximum loads,” *Journal of Sports Sciences* 33(10):1058--1066 (2015) | DOI `10.1080/02640414.2014.984240`; PMID `25630691` | Twelve trained participants; maximal front/back squat kinematics and EMG of vasti, rectus femoris, semitendinosus, biceps femoris, gluteus maximus, and erector spinae. Direct medial-hamstring excitation contrast; surface EMG cannot establish net hip-extension contribution, so the contract assigns stabilization only. |

`arnold-2010-lower-limb` is already registered and remains the independent
muscle-capability source. It permits a role; it never determines an exercise
role without the exercise-specific studies above.

## Known limits

- Neither active record claims a measured bodyweight fraction because both use
  external-load semantics; `bodyweightFraction: 0` is the established catalog
  spelling for externally loaded exercises.
- Surface EMG cannot prove force contribution, hypertrophy, or the absence of
  an unmeasured muscle. Roles combine direct exercise evidence, longitudinal
  training evidence, the independent anatomical capability map, and the
  product's categorical emphasis policy.
- The roster deliberately does not turn every observed posture difference
  between front and back squats into another axis. Trunk lean and pelvic tilt
  are continuous athlete responses in the reviewed studies, not stable catalog
  variant labels.
- The shoulder, scapula, elbow, and loaded-grip assignments are mechanics-
  grounded control requirements rather than claims of condition-matched
  upper-body EMG. The load-placement rules make that inference narrow and
  reviewable: `externalRotators` controls the externally rotated back-squat
  shoulder, `deltoidAnterior` supports the clean-grip front rack,
  `trapeziusUpper` stabilizes the shoulder girdle, and `brachialis` controls the
  maintained flexed elbow. None receives a dynamic prime action.
- The canonical back-squat record must not inherit Pürzel's elite low-bar participant and
  stance assumptions. Only the explicitly reported existence of concentric
  ankle plantarflexion is transported across that boundary, with Armstrong's
  front/back barbell kinematics as the second anchor.
