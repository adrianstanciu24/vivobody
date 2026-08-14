# Catalog families

This directory contains one reviewed JSON source file per movement family.
Fifty-one reviewed family files containing 128 exercises are currently
active. They span the reviewed press, pull, row, shoulder, arm, lower-body,
hip-rotation, spine, anti-movement, and carry contracts listed in the family
roadmap and validate against the current 58-region, 60-trainable-mesh-base,
146-source foundation. Each uses a coverage batch whose exercises
collectively exercise every admitted discrete axis value without generating
the Cartesian product. A continuous numeric
range is instead gated by truthful fixtures plus in-range/out-of-range tests;
records are never assigned artificial endpoints merely to cover a range.
Shoulder-extension row uses 12 reviewed exercises to cover five equipment
classes, open and closed chains, supported and unsupported torsos, unilateral
control, free and fixed external paths, and its pinned bodyweight setup.
Shoulder-horizontal-abduction row uses six reviewed exercises to cover four
equipment classes, three torso relationships, bilateral and unilateral
control, free and fixed paths, and linked versus independent machine levers.
The Batch-1 shoulder families initially began much narrower: 17 exercises
total across seven contracts. Later primary-source closures activated one
strict band scapular-retraction fixture and one bounded low-cable upright-row
fixture. Retraction keeps the glenohumeral and elbow angles held; upright row
uses mixed shoulder flexion/abduction plus elbow flexion without inventing
scapular retraction, elevation, or humeral axial rotation as prime actions.

Batch 2 adds fourteen exercises across `elbow-flexion`, `elbow-extension`,
conditioned `forearm-pronation|forearm-supination`, and the four cardinal wrist
actions. Generic `grip` remains deferred: dynamic finger closing, isometric
support, hanging, and pinch are different biomechanical tasks, not variants of
one cardinal joint action.

Batch 3 initially added five exercises across `scapular-protraction`,
`scapular-elevation`, `dip`, and `push-press`. Later review activated the exact
standing-band scapular-depression fixture and resolved upward rotation inside
`scapular-elevation`, bringing the batch-owned active roster to seven
exercises across five family contracts. Downward rotation is intentionally not
a standalone family: the reviewed foundation has no clean training-defining
fixture that should exist independently of its coupled task. It is retired as
a standalone candidate, not deferred. Landmine press remains deferred until
human-relative joint geometry, rather than bar angle alone, supports a
contract. Closed-chain vertical press belongs as a future branch of
`vertical-press`, but that branch remains deferred until direct dynamic
evidence supports its bodyweight-loading and action contract.

Batch 4 adds seven exercises across `knee-extension`, `knee-flexion`,
`hip-extension`, and `ankle-plantarflexion`. The rosters preserve the exact
reviewed posture contrasts: reclined versus upright leg extension, seated
versus prone leg curl, bent-knee prone-table hip extension, and straight- versus
bent-knee machine calf raise. `hip-flexion` remains deferred because the
available evidence does not establish the proposed dynamic
femur-relative-to-position-held-pelvis isolation contract.

Batch 5 adds six exercises across `bilateral-squat`, `hip-thrust-bridge`,
`split-stance-squat`, and `step-up`. The active rosters are limited to two
parallel straight-bar squats, two padded-barbell thrust/bridge fixtures, one
stationary approximately-leg-length barbell split squat using the study's
100-percent condition, and one complete 21-cm
bodyweight forward stepping sequence. `hip-hinge` remains deferred because the
reviewed Romanian-deadlift fixtures show material knee excursion and therefore
cannot satisfy the shared `positionHeld` boundary. Narrowing the old
`split-stance-lunge` discovery handle also leaves `dynamic-lunge` unresolved:
forward/reverse step-and-return tasks need reviewed impact, deceleration,
support-transition, and return semantics, while walking lunges may ultimately
belong to locomotion.

Batch 6 adds one exercise each across `hip-abduction`, `hip-adduction`,
`ankle-dorsiflexion`, `hip-internal-rotation`, and
`hip-external-rotation`. The first two hip families admit only their reviewed side-lying
pressure-biofeedback abduction and supported standing-band adduction fixtures;
the dorsiflexion family admits only unilateral seated band
dorsiflexion against a foot-board anchor and an individualized physical stop.
Internal rotation admits only the seated 90-degree Lahuerta-Martín flywheel
fixture. External rotation admits only the supine 30-degree FOHX
therapist-held ankle-band fixture. Their action capabilities are conditioned
on the exact hip-flexion postures, and their unvisualized exact regions remain
text-and-analytics visible without painting a substitute body-model mesh.
Neither contract turns anatomy-level capability into unmeasured exercise
volume.

Batch 7 adds nine exercises across `spine-flexion`, `spine-extension`,
`spine-lateral-flexion`, `spine-rotation`,
`anti-extension`, `anti-lateral-flexion`, `anti-rotation`, `farmer-carry`, and
`suitcase-carry`. The dynamic families each admit one narrow fixture; the
spine-rotation record is unilateral at the set level and prescribes both
rotation directions. The anti-movement families each admit one isometric hold,
and each carry family admits one reviewed load topology. MedX extension uses an
explicitly unvisualized erector-spinae/multifidus region, while the side-lying
lateral trunk lift assigns visible quadratus lumborum only through disclosed
condition-matched evidence triangulation. Posterior-serratus meshes are not
used as lumbar training proxies. `spine-extension` and
`spine-lateral-flexion` are active, and posterior serratus is excluded from
trainable ownership.

Every positive `defaultWeight` seed must also declare `defaultWeightKg` on the
2.5 kg grid. The metric value is an independently reviewed clean scrubber
detent, not a raw conversion from pounds. Zero-weight bodyweight, duration, and
non-comparable-resistance records may omit it.

Files here are the canonical exercise roster. `Scripts/catalog.py --check`
discovers and validates every
`*.json` file in this directory.

Press families reuse the same mechanical vocabulary. `kineticChain` describes
distal fixation, `scapularTranslation` records only external support limits on
translation rather than rotation or tilt, and signed `pressInclinationDegrees`
uses horizontal as zero. Family-specific synonyms for these axes are not
allowed.

`lowerBodySupport` has one cross-family meaning: the lower-body contact or
support that materially changes effective bodyweight loading. A family that
declares this axis makes it required and includes an explicit `none` value when
no such contact participates. Family-specific non-`none` values describe the
actual mechanism: horizontal press uses `feet|knees`, vertical pull uses
`thighPad|assistancePlatform`, and shoulder-extension row uses `feet` only for
its pinned bodyweight branch.

When a variant axis implies extra trunk or segment control, an exercise rule
uses `requireAdditionalStabilityDemands` to require the region explicitly in
`additionalStabilityDemands`. The normal anatomy validation separately proves
that an assigned muscle at any role can stabilize every declared region.
Primary and secondary movers can simultaneously control a joint; they are not
duplicated as `role: stabilizer`. `allowedByRole.stabilizer` only admits
muscles whose principal authored role is control rather than prime-action
production, so an empty list is valid when the reviewed movers cover every
demand. When the setup
requires one member of a biomechanically valid muscle set rather than one exact
assignment, `requireMuscleRequirements` reuses the family muscle-requirement
shape (`anyOf` plus `minimumRole`) without forcing an arbitrary muscle.

Batch 4 exercises make that convention concrete:

| Family | Demand coverage in the active roster |
|---|---|
| `knee-extension` | Hip: rectus femoris; knee: rectus femoris and vasti. All are movers, so no separate stabilizer role is authored. |
| `knee-flexion` | Pelvis/hip: medial hamstrings, sartorius, and gracilis; knee: all four assigned movers. |
| `ankle-plantarflexion` | Knee: gastrocnemius; ankle/foot: gastrocnemius and soleus. |
| `hip-extension` | Hip: glute max and medial hamstrings; pelvis: both movers plus lower back; knee: medial hamstrings plus the explicitly reviewed biceps-femoris stabilizer; spine: the explicitly measured lower-back stabilizer. |

Hip extension's two explicit stabilizers are exercise-evidence decisions, not
objects added merely to make validation pass: Jeon measured biceps femoris and
erector spinae in the exact fixture, while the conservative biceps-femoris
profile permits only held-knee credit.

A `spine|pelvis` demand does not by itself prescribe a universal number of
trunk-muscle assignments; the reviewed setup does. Unsupported exercises in
which the full body is suspended from the hands use the complete categorical
trunk set (`abs`, `obliques`, and `lumbarExtensors`) to represent anterior,
lateral/rotational, and posterior control. This is the shared pull-up/dip
convention. A supported or segmentally braced fixture may require only the
reviewed subset, and asymmetric free-load setups make their anti-rotation or
anti-lateral-flexion requirement explicit rather than inheriting the suspended
rule.

`relativeGripWidth` has the shared ordered vocabulary
`narrow|shoulderWidth|medium|wide`. Families may select a reviewed subset, but
the same value cannot change meaning between families.

Row families share `upperArmPath` vocabulary `tucked|scapular|flared` while
admitting only their reviewed subsets. Shoulder-extension row admits
`tucked|scapular`; shoulder-horizontal-abduction row admits only `flared` and
pairs it with an exact `upperArmElevationDegrees: 90` authoring convention.
That numeric value describes canonical position, not a dynamic
shoulder-abduction action or laboratory precision on every repetition.

Row families also share `leverArmConfiguration: linked|independent` for
`machineType: leverRow`. Linked left/right levers are bilateral; every
unilateral lever-row record must use independent arms. Smith rails are not
lever arms and omit the axis.

Family planes are determined only by the declared shoulder basis actions.
Shoulder-extension row is therefore sagittal because its basis action is
`shoulder.extension`; its transverse `scapula.retraction` prime action occurs
at a different joint and must not be used to add a false transverse shoulder
plane. Shoulder-horizontal-abduction row is transverse because its basis action
is `shoulder.horizontalAbduction`; scapular retraction and elbow flexion remain
required actions without contributing their joint planes to the family plane.

Batch-1 families share `elbowMotion: angleHeld|flexes|extends`. `angleHeld`
allows a deliberately maintained soft bend but forbids a material elbow-joint
excursion; it is distinct from `elbowPosture`, which describes the held joint
position. A fly or raise therefore uses `angleHeld`, while a row or future
upright row that dynamically flexes the elbow must use `flexes`.

Distal muscle roles follow the split anatomical taxonomy rather than the old
aggregate arm regions. Reviewed rows and vertical pulls with dynamic elbow
flexion assign `bicepsBrachii`, `brachialis`, and `brachioradialis` as separate
secondaries. A held-elbow reverse fly uses `brachialis` as an elbow stabilizer
without implying dynamic elbow flexion. Incidental implement support may assign
`fingerFlexors` as a hand stabilizer; loaded carry instead assigns them primary
or secondary because the family explicitly resists `hand.fingerExtension`.
`extensorCarpiRadialis` controls the wrist against the flexors' wrist moment in
both cases. Neither policy is a generic `grip` action or permission to infer
pinch, hanging, or dynamic finger closing.

Batch-2 elbow and distal contracts keep joint posture separate from motion.
`forearmOrientation` is a held radioulnar posture; dynamic rotation uses
`forearmMotion` plus explicit start/end orientations. `wristPosture` is present
only when `wristMotion: angleHeld`. `upperArmPosition` is a maintained posture,
not a shoulder prime action. `forearmSupport` describes the actual supporting
surface. The reviewed Batch-2 vocabulary is currently only
`none|bench|table`; adding another support value requires a family-contract
review rather than treating it as pre-approved shared vocabulary. It never
implies torso support.

`handTask: staticImplementHold` creates a hand stability demand without adding
dynamic `hand.fingerFlexion` to the repetition. `resistanceGeometry` names the
reviewed loading mechanism, not merely the equipment. Elbow fixtures distinguish
`lowCableCurl`, `highCablePushdown`, `overheadCableExtension`, and
`gravityLoadedDumbbell`. `overheadCableExtension` identifies the reviewed
overhead task, not a reported pulley geometry, and pairs with
`handleType: unreportedCableInterface` because the source omits the attachment,
anchor, and cable angle. Rotation fixtures use
`rotationalPlateLoadedDumbbell`, while radial/ulnar-deviation fixtures use
`collarOffsetLever` with the hand positioned relative to the collar and shaft.
A conventionally centered dumbbell hold is not interchangeable with either
distal mechanism. Every new elbow/distal `fixedPath` boolean is required and
declares `fixedValue: false`; this preserves the shared external-load meaning
and makes the free-path boundary enforceable without borrowing vertical pull's
body-path `pathConstraint` axis.

`humeralRotation` describes axial rotation at the glenohumeral joint and must
never be inferred from `gripOrientation`. Raise families use
`elevationPath: sagittal|frontal` plus torso-relative
`humerothoracicStartElevationDegrees` and
`humerothoracicEndElevationDegrees`. At-side rotation families instead use one
exact `humerothoracicElevationDegrees: 0`; an elevation path is undefined when
the upper arm is not elevating. `scapular` is not an admitted Batch-1
`elevationPath` value: scaption remains deferred rather than becoming shared
vocabulary through documentation alone.

Every activated Batch-1 family requires `lowerBodyContribution: none` and
forbids spinal motion, hip extension, knee extension, and ankle plantarflexion
as prime actions. An unsupported standing fixture can add a spinal stability
demand without admitting trunk or leg motion as part of the repetition.

Scapular orientation and translation remain separate. Direct elevation
kinematics may justify coupled upward rotation or posterior tilt without
proving protraction or retraction. Likewise, anterior or lateral torso contact
does not automatically pin posterior scapular translation. A scapular action
is authored as prime only when motion evidence or a deliberately constrained
technique supports it; EMG magnitude alone cannot create an action.

Batch-3 scapular isolations apply that evidence rule literally. The reviewed
supine scapular punch admits protraction because the technique prescribes the
loaded scapular excursion while dynamic shoulder and elbow actions are
forbidden. The elevation contract owns upward rotation rather than creating a
duplicate standalone family; its reviewed records retain their exact coupled
actions instead of being rewritten as pure elevation. The exact standing-band
depression fixture is a separate action contract and does not generalize to
dips, press-ups, hangs, or pulldowns. Smaller model-specific scapular
abduction/adduction and winging coordinates remain disclosed three-dimensional
couplings, not relabeled protraction/retraction or tilt. Downward rotation is
intentionally non-standalone, while push-up-plus, overhead shrugs, and other
apparatus or postures still require their own review.

Support and path axes name different mechanical facts. `bodyweightApparatus`
identifies the reviewed hand-support apparatus and `handSupportConstraint`
distinguishes fixed dip bars from independently moving rings. For a suspended
bodyweight exercise, `pathConstraint` describes whether an external mechanism
guides the athlete's body path. `fixedPath` retains its existing external-load
meaning for dumbbells, barbells, rails, and lever machines, so it is used by
the scapular isolations and push press but not overloaded to describe a dip's
body path. These Batch-3 values cover only the activated fixtures; they are not
pre-approved vocabulary for assisted dips, machines, or the deferred
closed-chain vertical-press branch.

`push-press` makes lower-body propulsion explicit rather than hiding it inside
a vertical-press name. `lowerBodyContribution: countermovementPropulsion`
states that the legs deliberately propel the bar; `legDriveDipStyle:
pushPressCountermovement` names the preparatory leg countermovement and is
unrelated to the separate `dip` family. `receivingStrategy:
standingNoRedip` excludes a push-jerk catch, while `footContact: continuous`
records contact through propulsion and lockout without defining stance. These
single admitted values belong only to the reviewed barbell push press; other
implements, receiving strategies, and foot behaviors require their own review.
The record still declares wrist and hand stability and uses the shared loaded-
grip `extensorCarpiRadialis` plus `fingerFlexors` assignments; whole-body power
does not waive the static bar-control contract.

Batch-4 lower-body isolations share one mechanical vocabulary rather than
family-local synonyms. `bodyPosition` names gross posture; `torsoSupport` and
`pelvisSupport` name actual external contact or restraint; and
`pelvisMotion|spineMotion|hipMotion|kneeMotion|ankleMotion|footMotion` say
whether a segment is position-held or supplies the dynamic action. External
support never proves a position-held motion axis by itself. `movingSegment`
identifies the segment whose joint-relative excursion defines the repetition.
`loadInterface` names where resistance contacts the athlete, and `machineType`
names a purpose-built mechanism rather than duplicating the equipment label.
The knee-extension, leg-curl, and calf-raise contracts omit
`resistanceGeometry` because it would be in strict one-to-one correspondence
with their machine type and load interface. Hip extension retains
`resistanceGeometry: limbSegmentGravity`: it has no machine type, and the
unsupported moving segment is the observable source of resistance.
`lowerBodyContribution: isolatedJointMotion` excludes propulsion by another
lower-body joint.

Numeric joint-position axes store canonical reviewed setup targets, not
laboratory precision on every user repetition. When a family has two reviewed
targets, such as 40/90 degrees of hip flexion or 0/90 degrees of knee flexion,
the numeric minimum and maximum do not admit intermediate values by themselves:
reciprocal exercise rules bind each target to its reviewed body position and
mechanism. Knee posture is anatomy-bearing. Rectus femoris changes categorical
role across the two leg-extension fixtures, gastrocnemius changes role across
the two calf-raise fixtures, and the ankle-unreported leg-curl evidence does not
permit gastrocnemius involvement to be invented.

`fixedPath` keeps its established external-load meaning. Lever leg-extension,
leg-curl, and calf-raise machines pin it `true`; the gravity-loaded moving limb
in prone-table hip extension pins it `false`. `kineticChain` remains separate:
leg extensions, leg curls, and hip extension are open chain, while calf raises
are closed chain because the forefoot stays supported as the heel and body
segment move.

Batch-5 lower-body compounds reuse `stanceConfiguration`, `loadPlacement`,
`rangeOfMotion`, `footContact`, `interRepSupport`, and
`lowerBodyContribution` only where the underlying fact is shared. Values stay
family-reviewed: `symmetricBilateral`, `splitSagittal`, and
`leadFootRaisedStart` are different support topologies, while
`thighParallel`, `leadThighParallel`, and the full raised-platform sequence are
different endpoint conventions. The squat and stationary split-squat use the
same `upperBackBarbell` load-placement value. The split-squat source names a
barbell but not a high/low site or hand orientation, so its upper-back placement
and pronated control grip are bounded figure- and mechanics-derived encodings,
not textual-method precision.

`fixedPath` remains an external-load question in Batch 5. Squat,
hip-thrust/bridge, and stationary split-squat require the boolean and pin it
`false`. The bodyweight-only step-up deliberately omits the axis because no
external load path exists; omission must not be interpreted as an unreviewed
machine or rail-guided branch.

The one-record split-squat and step-up contracts keep their boundaries in
required single-value axes rather than always-true exercise rules. Every such
axis is mutation-tested directly. Step-up records Wang et al.'s complete task:
the trail foot returns from platform to floor, the lead foot follows, and the
same lead foot is replaced on the platform before the next repetition. That is
not the continuous gym repetition in which the lead foot stays elevated.

Gross torso instruction and segmental spinal motion remain separate. The
split-squat's `trunkOrientation: erect` records Song et al.'s instructed and
video-checked cue, while `spineMotion: nonstandardized` avoids claiming
unmeasured lumbar immobility. Bilateral squat uses the same spine-motion value
because the reviewed studies measured load- and bracing-sensitive lumbar
alignment rather than one fixed path. Both families still forbid every spinal
prime action: nonstandardized observed motion is not deliberate spinal work.

Squat, stationary split-squat, and step-up author
`ankle.plantarflexion` only because reviewed angular data establish motion from
bottom-position dorsiflexion toward the standing angle. An extensor moment or
calf excitation alone is insufficient. Hip-thrust/bridge instead declares
`ankleMotion: nonstandardized` and forbids ankle prime actions because its
observed motion and negligible variable kinetics do not establish one common
training-defining ankle action. Its pelvic-trunk motion receives the same
honest `nonstandardized` spelling rather than a fabricated position-held claim.

The back- and front-squat rules require the reviewed setup-specific shoulder
control assignment as a minimum: upper-back/pronated requires external
rotators, while anterior clean grip requires anterior deltoid. Exact roster
tests keep the current records from receiving both assignments, but the rule
schema does not claim that the other stabilizer is anatomically forbidden.

Stability demands cover every materially load-bearing or control-defining
region, not every incidental contact. In hip thrust and glute bridge the feet
materially anchor the task, so ankle and foot demands require soleus control.
The pelvis bears the padded barbell; the supinated hands only steady it, so
their contact does not invent wrist, hand, or loaded-grip demands.

Batch-6 lower-body isolations retain the same motion/support distinction. The
side-lying abduction treatment table, both-hands standing-adduction support,
and seated dorsiflexion seat and foot board describe setup and control; none
creates an extra prime action. `hipRotation: neutral`, toes-forward
instructions, and position-held pelvis, spine, and knee axes exclude combined
rotation or trunk-driven repetitions. Each family has one prime action and
forbids the exact 43-action complement.

The pressure-biofeedback abduction record uses `equipment: other`, external
load, and a reviewed 5 lb / 2.5 kg seed. Its 35-to-45-mmHg trunk feedback and
horizontal contact band are part of the condition-matched fixture, not
incidental laboratory metadata. The canonical name and aliases therefore state
the PBU condition; a generic no-feedback side-lying abduction is not silently
routed to this more specific record. The two elastic-band records use
`loadMode: nonComparable`, zero load seeds, and no metric seed; their different
`loadInterface` and `resistanceGeometry` values preserve the ankle-cuffed
lateral anchor versus the board-affixed foot band rather than treating all
bands as one mechanism. All three fixtures pin `fixedPath: false` because no
rail or lever constrains the external load.

Numeric hip-abduction endpoints encode the directly reviewed zero-to-35-degree
fixture, and `hipSagittalPosture: neutral` keeps flexion or extension from
leaking into it. Dorsiflexion instead uses an individualized physical stop and
a self-selected knee posture: a reported cohort mean or per-participant
laboratory measurement is not converted into a universal exercise angle.
Bottom-only sole contact with the board does not make the moving foot closed-
chain.

The adduction sources report the posterior endpoint but not the sagittal
coordinate of the abducted start or its three-dimensional path. The active
record discloses one catalog-authored adaptation: establish that slight
posterior posture before the repetition and hold it while moving strictly in
the frontal plane. `hipSagittalPosture: slightExtensionHeld` prevents an
unmeasured dynamic hip-extension action; it does not claim the source directly
tested the adapted path. `handSupport: bothHandsOnStableExternalSupport`
preserves Jensen's directly reported bilateral setup without over-reading the
less-specific EMG fixture.

Exercise credit remains intentionally narrower than anatomy capability.
Gluteus minimus has an explicitly unvisualized taxonomy region but no
body-model surface. The abduction record still omits it because capability
alone does not establish exercise involvement; no visible region is assigned
as a proxy.
The adduction record does not infer adductor-magnus or pectineus volume from
capability alone. Gracilis is secondary because it can produce the named hip
action while controlling the held knee. Gluteus medius receives stabilizer
credit from its directly measured 18-percent-MVC bilateral excitation and its
hip/pelvis control capability. Serner measured external oblique only, so
assigning the combined `obliques` region explicitly includes an unmeasured
internal-oblique portion of the body-model aggregation. Dorsiflexion does not
infer fibularis-tertius or toe-extensor volume from their shared action.

Hip rotation uses posture-conditioned capabilities rather than unconditional
whole-muscle directions. The 90-degree internal-rotation fixture assigns
gluteus medius and TFL as non-ranked co-primaries, unvisualized gluteus minimus
as a mechanics-derived secondary, and obliques as stabilizers. The 30-degree
external-rotation fixture assigns the unvisualized obturator-internus/gemelli
region as primary, with unvisualized obturator externus, piriformis, and
quadratus femoris as mechanics-derived secondaries. The FOHX protocol reports
no numeric knee angle or exact band force, and its completed trial evaluates a
multi-exercise program rather than the isolated record. No visible hip muscle
receives proxy mover credit.

Batch-7 dynamic-spine families keep direction and setup narrow. The curl-up's
`trunkStartElevationDegrees: 0` and `trunkEndElevationDegrees: 30` are gross
trunk elevation relative to the floor, not segmental lumbar angles. The
torso-twist record uses separate shoulder-height hand grips and bilateral
shoulder pads as the load interface. Its held-pelvis instruction is labeled
`positionHeldCatalogAdaptation` because the source did not measure pelvic
kinematics. The same record prescribes separately logged work in both rotation
directions; right-to-left is disclosed as a mirrored mechanics-and-training
adaptation rather than a source-measured direction. The reviewed MedX extension
fixture is active only at its pinned range, cadence, and machine topology. It
does not authorize arbitrary back-extension machines, and its explicitly
unvisualized lumbar-extensor region remains text-and-analytics visible without
painting a substitute surface.

The anti-movement families make the resisted tendency explicit instead of
inventing a dynamic repetition. Stable forearm plank resists spine extension,
side plank resists aggregated spine lateral flexion, and the feet-together band
Pallof hold resists aggregated spine rotation. Each has empty `primeActions`,
uses the resisted action as its plane basis, and forbids the full 44-action
dynamic complement. Their names and definitions preserve the directly reviewed
support topology, side prescription, and timed hold; unstable surfaces,
suspension, loaded planks, dynamic presses, and moving repetitions require new
review.

Their stability demands cover the complete reviewed support chain rather than
only the trunk. Forearm plank assigns scapular, shoulder, elbow, hip, knee,
ankle, and foot control through serratus, external rotators, triceps, gluteus
maximus, vasti, and soleus. Side plank additionally preserves the directly
measured unheaded deltoid signal, gluteus-medius, rectus-femoris, and
preferred-support-side context while using serratus, triceps, and soleus for
the contacted support chain. Pallof assigns serratus, anterior deltoid,
triceps, finger flexors, extensor carpi radialis, gluteus medius, vasti, and
soleus across the upper- and lower-body base. Extensor carpi radialis provides
wrist counter-control against the finger flexors' wrist-flexion moment. The
Pallof source measured sacral acceleration rather than muscle EMG, so its role
hierarchy is anatomy-and-mechanics-derived and remains explicitly disclosed.

The side-plank `quadratusLumborum` secondary is a mechanics-derived role for
the visible QL region; it is not a proxy for the study's erector-spinae signal.
Both sides are prescribed rather than pretending the direction-aggregated
action or bilateral mesh is side-specific.

`farmer-carry` and `suitcase-carry` share the implement's finger-opening
tendency: finger flexors oppose `hand.fingerExtension`. They remain separate
because suitcase carry additionally resists `spine.lateralFlexion`, uses that
frontal action as its basis, and assigns a core-dominant role policy; farmer
carry stays sagittal and grip-dominant. Both records
use freely held dumbbells, no straps or hooks, continuous forward walking,
neutral forearm orientation, extended held elbows, and a 40-second product
detent. Their 60 lb /
27.5 kg and 50 lb / 22.5 kg seeds are product defaults, not source-derived
universal prescriptions. `loadAccounting: perImplement` means each logged seed
is one implement: either equal farmer-carry dumbbell rather than their combined
pair, or the single suitcase-carry dumbbell. Ordinary gait propulsion remains
`lowerBodyContribution: walkingPropulsion` rather than becoming a set of
training-defining hip, knee, or ankle prime actions; gait-related spinal motion
is honestly `nonstandardized`, not fabricated as absent.
