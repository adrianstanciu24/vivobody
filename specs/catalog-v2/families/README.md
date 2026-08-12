# Catalog-v2 families

This directory contains one reviewed JSON source file per movement family.
Twenty-six reviewed family files are currently active: the three chest presses,
vertical press and pull, both compound row families, nine narrow shoulder or
scapular-action families, dip, push press, and eight narrow
elbow/forearm/wrist families. Each uses a coverage batch whose exercises
collectively exercise every admitted discrete
axis value without generating the Cartesian product. A continuous numeric
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
that an assigned muscle can stabilize every declared region. When the setup
requires one member of a biomechanically valid muscle set rather than one exact
assignment, `requireMuscleRequirements` reuses the family muscle-requirement
shape (`anyOf` plus `minimumRole`) without forcing an arbitrary muscle.

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
