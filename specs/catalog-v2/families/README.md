# Catalog-v2 families

This directory contains one reviewed JSON source file per movement family.
Thirty-four reviewed family files are currently active: the three chest
presses, vertical press and pull, both compound row families, nine narrow
shoulder or scapular-action families, dip, push press, eight narrow
elbow/forearm/wrist families, four lower-body isolation families, and four
lower-body compound families. Each uses a coverage batch whose exercises
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
The Batch-1 shoulder families intentionally begin much narrower: 17 exercises
total across seven contracts. `scapular-retraction` and `upright-row` remain
tracked proposals because their dynamic action boundaries are not grounded
well enough for validator-loaded records.

Batch 2 adds fourteen exercises across `elbow-flexion`, `elbow-extension`,
conditioned `forearm-pronation|forearm-supination`, and the four cardinal wrist
actions. Generic `grip` remains deferred: dynamic finger closing, isometric
support, hanging, and pinch are different biomechanical tasks, not variants of
one cardinal joint action.

Batch 3 adds five exercises across `scapular-protraction`,
`scapular-elevation`, `dip`, and `push-press`. Scapular depression and
standalone upward/downward rotation remain evidence holds rather than being
inferred from muscle activity or copied out of a coupled movement. Landmine
press remains deferred until human-relative joint geometry, rather than bar
angle alone, supports a contract. Closed-chain vertical press belongs as a
future branch of `vertical-press`, but that branch remains deferred until
direct dynamic evidence supports its bodyweight-loading and action contract.

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

Every positive `defaultWeight` seed must also declare `defaultWeightKg` on the
2.5 kg grid. The metric value is an independently reviewed clean scrubber
detent, not a raw conversion from pounds. Zero-weight bodyweight, duration, and
non-comparable-resistance records may omit it.

Files here must never be derived from, compared with, or merged with the legacy
exercise roster. `Scripts/catalog_v2.py --check` discovers and validates every
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
trunk set (`abs`, `obliques`, and `lowerBack`) to represent anterior,
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
without implying dynamic elbow flexion. Every currently reviewed loaded-grip
fixture assigns `fingerFlexors` to stabilize the hand and
`extensorCarpiRadialis` to control the wrist against the flexors' wrist moment;
neither role is a generic `grip` action or permission to infer pinch, hanging,
or dynamic finger closing.

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
forbidden. The reviewed single-arm shrug admits elevation plus its measured
coupled upward rotation; it is not rewritten as pure elevation merely to make
the family name simpler. The same one-subject trace contains smaller
model-specific scapular abduction/adduction and winging coordinates. Those are
recorded as three-dimensional coupling, not relabeled as shoulder abduction,
protraction/retraction, or tilt and not promoted to prime actions without a
matching taxonomy action and work attribution. Neither contract pre-approves
depression, standalone rotation, push-up-plus, overhead shrug, or another
apparatus or posture.

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
