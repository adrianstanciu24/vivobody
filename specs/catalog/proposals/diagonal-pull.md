# Diagonal-pull contract discovery

Status: deferred after a failed public-source activation gate; deliberately
**not activated**. There is no
`families/diagonal-pull.json` yet, and this document is not validator input.

## Discovery outcome

Keep `diagonal-pull` as a candidate family, but do not activate it merely
because commercial equipment is sold as a “high row.” The defensible initial
scope is much narrower:

- a seated, open-chain, externally loaded, purpose-built lever high row;
- handles that begin above and anterior to the head;
- a guided high-to-low path with a meaningful torso-relative horizontal
  component;
- shoulder adduction plus conditioned shoulder extension;
- scapular retraction and elbow flexion; and
- no deliberate trunk or lower-body propulsion.

The app-facing name should be **Diagonal High Row**, not simply “Diagonal
Pull.” The broader phrase also describes rotational and cable diagonal
patterns with different muscle recruitment and ownership. A direction word is
not a biomechanical contract.

The important finding is that this candidate is **not distinguished from
`vertical-pull` by joint actions**. The active vertical family already fixes
the same shoulder, scapular, and elbow components. Geometry must carry the
boundary. Until the catalog can prove that geometry, two separate families
would differ only because an author typed `vertical` in one record and
`diagonal` in another.

There is also a real possibility that the familiar commercial fixture does
not belong in a diagonal family at all. Hammer's current first-party page calls
its high row “more horizontal” than a front pulldown and markets an upper-back
emphasis. Marketing copy cannot assign muscle roles, but that adverse geometry
description cannot be ignored. If human-path review places the fixture in the
horizontal band, or fails to show meaningful shoulder adduction, route it to
the appropriate row family and retire this proposal.

## Public-source activation audit: no-go

A model-specific review could identify the candidate as the current Hammer
Strength Plate Loaded Iso-Lateral High Row, SKU `IL-HR`, but could not recover
the calibrated human-relative geometry or joint kinematics required by this
contract. Public material is sufficient to keep the candidate alive, not to
activate it.

| Reviewed artifact | What it establishes | What it cannot establish |
|---|---|---|
| Current first-party `IL-HR` page and paired start/end photographs | Fixed overhand grip, independent arms, adjustable seat/thigh pad, anterior chest support, unilateral support handle, and a qualitative high-to-low guided pull. | A calibrated torso-relative chord, signed sagittal direction, humeral corridor, glenohumeral actions, scapular motion, or repeatability across seat settings and body sizes. The photographs are oblique, uncalibrated 2D projections without anatomical landmarks or a declared tolerance. |
| 2023 `ILHR & IL-HR` parts manual | The current component set, including separate movement arms, chest pad, saddle, thigh pads, bearings, bumpers, and seat adjustment. | Orthographic movement-arm dimensions, start/end coordinates, full travel, serial-specific geometry, or tolerances. |
| Jones's 1993 high-row patent | A historical embodiment with qualitative downward/slightly-forward travel, independent forward-converging lever planes, support provisions, and selected apparatus dimensions. | A documented cross-reference to the current `IL-HR`, a terminal lever angle, a complete hand chord, or human joint/scapular kinematics. Patent geometry must not be silently inherited by the retail revision. |
| Embedded `IL-HR` marketing 3D viewer | A model-specific asset identifier exists. | During the 2026-08-11 audit the provider reported the asset inactive. Even an accessible illustrative mesh would not establish an articulated, accuracy-rated human-relative endpoint path. |
| Closest human studies | Pull-up, pulldown, and row research shows that grip, torso angle, humeral path, and shoulder-abduction angle materially affect kinematics or recruitment. | No reviewed study directly measures the commercial overhead-start lever high row. None supplies this proposal's signed torso-relative chord, `upperArmPath`, scapular action, or muscle hierarchy. |

The activation attempt therefore fails the model-geometry, cross-family-band,
and human-kinematics gates. Do not add a family JSON, migrate neighboring
pull/row axes, reserve aliases, or register candidate-only evidence yet. The
next acceptable unlock is either:

1. a calibrated physical measurement of a serial-numbered `IL-HR`, followed by
   the same protocol on the neighboring pull/row fixtures; or
2. manufacturer-supplied dimensioned CAD or kinematic endpoints explicitly
   tied to that revision, plus separate human tracking for joint and scapular
   actions.

The physical route must record the model and serial label, movement-arm part
numbers, seat and thigh-pad positions, chest-pad contact, participant or
surrogate dimensions, torso-frame construction, hand/sternum landmarks,
bilateral and unilateral trials, and uncertainty. Several body sizes and
realistic settings are needed to determine whether one canonical proxy is
honest or whether the observed distributions overlap neighboring families.
The [diagonal-pull measurement protocol](diagonal-pull-measurement-protocol.md)
is the tracked capture and acceptance protocol for that work.

## Provisional family boundary

The candidate should own one reviewed lever-high-row mechanism, not every
exercise whose implement happens to travel obliquely in the room.

Room-space travel is especially misleading. A landmine or T-bar handle may
arc diagonally relative to the floor while the upper arm still performs a
torso-relative horizontal shoulder-extension row. Conversely, a seated lever
can travel through an arc while the relative hand path is meaningfully between
a row and a pulldown.

Family membership should therefore require all of the following:

1. an elevated and anterior hand position at the eccentric start;
2. a high-to-low relative hand path that is neither horizontal nor
   vertical under the shared catalog convention;
3. meaningful shoulder adduction and extension from the flexed start;
4. dynamic elbow flexion;
5. a reviewed lever path rather than membership inferred from a product name;
   and
6. strict execution without hip, knee, or trunk propulsion.

The initial contract should be machine-only. Cable, landmine, free-weight,
and kneeling variants create too many unreviewed combinations of path,
support, and trunk contribution. Adding weak fixtures only to exercise more
axis values would make the contract look broader than the evidence.

## Why joint actions do not separate the family

The proposed component model is intentionally identical to the active
`vertical-pull` model:

| Component | `vertical-pull` | Candidate `diagonal-pull` |
|---|---|---|
| Shoulder basis | Extension from a flexed start + adduction | Extension from a flexed start + adduction |
| Scapula | Retraction | Provisionally retraction |
| Elbow | Flexion | Flexion |
| Shoulder planes | Sagittal + frontal | Sagittal + frontal |
| App direction | Vertical | Diagonal |

That equality is a feature of the component model, not a reason to invent a
different action. A commercial high row may change the relative amount and
timing of extension and adduction without introducing a new anatomical plane.
`diagonal` is a push/pull direction; there is still no oblique anatomical
plane.

This also means the action signature cannot validate the direction. The
activation tests must acknowledge the shared action model explicitly and then
prove the path-geometry difference independently.

## Provisional classification

The classification below is a review target, not validator-ready JSON:

```json
{
  "id": "diagonal-pull",
  "name": "Diagonal High Row",
  "fixed": {
    "mechanic": "compound",
    "pattern": "pull",
    "direction": "diagonal",
    "planes": ["sagittal", "frontal"]
  },
  "groupPolicy": {
    "default": "back",
    "allowed": ["back"]
  },
  "allowed": {
    "equipment": ["machine"],
    "modalities": ["dynamicStrength"],
    "trackingModes": ["reps"],
    "loadModes": ["external"],
    "lateralities": ["bilateral", "unilateral"]
  },
  "movementSignature": {
    "planeBasisActions": [
      "shoulder.extension",
      "shoulder.adduction"
    ],
    "primeActions": [
      {
        "action": "shoulder.extension",
        "condition": "fromFlexedPosition"
      },
      "shoulder.adduction",
      "scapula.retraction",
      "elbow.flexion"
    ],
    "forbiddenPrimeActions": [
      "shoulder.flexion",
      "shoulder.abduction",
      "shoulder.horizontalAdduction",
      "shoulder.horizontalAbduction",
      "shoulder.internalRotation",
      "shoulder.externalRotation",
      "scapula.protraction",
      "scapula.depression",
      "scapula.elevation",
      "scapula.upwardRotation",
      "scapula.downwardRotation",
      "scapula.anteriorTilt",
      "scapula.posteriorTilt",
      "elbow.extension",
      "spine.flexion",
      "spine.extension",
      "spine.lateralFlexion",
      "spine.rotation",
      "hip.flexion",
      "hip.extension",
      "knee.flexion",
      "knee.extension",
      "ankle.plantarflexion"
    ],
    "stabilityDemands": [
      "shoulder",
      "scapula",
      "wrist",
      "hand"
    ]
  },
  "recommended": {
    "defaultReps": {
      "minimum": 5,
      "maximum": 15
    }
  }
}
```

`shoulder.internalRotation` is forbidden as a **dynamic prime action**. A
pronated grip does not establish dynamic glenohumeral internal rotation.
Keeping the action out also prevents generic diagonal
extension-adduction-internal-rotation patterns from entering through the word
“diagonal.”

`forbiddenPrimeActions` is a flat action-ID list. Under the catalog convention
it constrains the canonical concentric signature; it cannot encode a separate
eccentric phase. The observation that protraction may occur during the return
is therefore non-normative and creates no phase-specific exception.
`scapula.protraction` remains forbidden as an authored prime action. This also
exposes a separate hardening question for `vertical-pull`, which requires
retraction but does not currently forbid a future record from also authoring
protraction.

Scapular retraction remains provisional until the canonical machine path is
reviewed with human kinematics. It is mechanically plausible and consistent
with the intended retractor involvement, but neither apparatus geometry, a
product name, nor a list of target muscles proves joint motion. If the reviewed
path does not contain meaningful dynamic retraction, remove the action and
replace the dynamic-retractor requirement rather than inheriting both from
neighboring families. The `scapula` stability demand remains: that branch must
require at least one scapula-capable muscle at `minimumRole: stabilizer`
(for example a reviewed trapezius, rhomboid, serratus, or pectoralis-minor
assignment). It must also remove retractor-only muscles from mover roles and
change the required back-primary set to muscles capable of the remaining
shoulder actions, provisionally `lats|teresMajor`. It may remove the demand only
if review separately establishes that scapular control is not part of the
exercise contract; removing the action and requirement alone is invalid.

## The geometry contract required before activation

Introduce a shared geometry definition analogous to
`pressInclinationDegrees`, but do not erase the direction of the horizontal
component.

At the canonical start and end, express the working-hand position relative to
the upper sternum in a torso coordinate frame whose superior-inferior and
anterior-posterior axes are fixed from the canonical start posture. For a
bilateral exercise use the midpoint of the two hands; for a unilateral
exercise use the working hand. Subtract the start relative position from the
end relative position to obtain the concentric relative-displacement chord.

`pullInclinationDegrees` is the magnitude of that chord's inclination in the
torso sagittal projection. Zero degrees is parallel to the torso's
anterior-posterior axis; 90 degrees is parallel to its superior-inferior axis.
For a curved lever use the start-to-end chord rather than one instantaneous
tangent. A separate `sagittalPathDirection: anterior|posterior|neutral` records
the sign of the anterior-posterior component so that a downward-forward path
cannot validate as the mirror image of a downward-rearward path.

Relative displacement accommodates either kinetic chain without claiming that
the hands literally move toward the torso. It subtracts torso translation from
an open-chain implement path and describes torso motion relative to fixed hands
in a closed-chain pull. A materially rotating torso is outside this strict
measurement convention unless a later axis represents that rotation.

The metric is a catalog authoring convention, not a biological threshold and
not a claim that the joint follows a straight line. It deliberately leaves
mediolateral lever-plane orientation and humeral corridor to separate axes.
The existing `pullPath` axis should carry the reviewed categorical endpoint
corridor (`overheadToAnteriorUpperTorso` for this candidate), because an angle
alone cannot distinguish an upper-chest high row from an overhead-to-hip
movement. The measurement fixture still records exact anatomical landmarks;
they do not need two additional exercise axes.

Do **not** assign a diagonal range yet. Values such as 30–60 degrees are
plausible-looking but are not supplied by any reviewed source. Before
activation:

1. identify one physical high-row model and document seat height, pad settings,
   anatomical alignment, endpoint landmarks, athlete or fixture dimensions,
   coordinate-frame construction, and measurement tolerance;
2. measure the candidate bilateral and unilateral use of that same mechanism;
3. measure a canonical pull-up plus representative pulldown and horizontal-row
   boundary fixtures under the same definition;
4. decide whether the observed values support non-overlapping direction bands;
5. put each reviewed direction band in that family's
   `pullInclinationDegrees.minimum` and `.maximum`, then assert the complete
   family-to-band map in one exact test, following the existing press-family
   precedent; and
6. either author a defensible value or reviewed family-level proxy for every
   affected active exercise—adding a required exercise axis cannot be justified
   by measuring only a representative subset.

The bilateral and unilateral executions use the same physical mechanism, but
that does not prove equal **torso-relative** chords: unilateral bracing or
rotation can change the human-relative result. Measure them separately. Give
the records the same canonical value only if they agree within a declared
tolerance; otherwise either retain two truthful values inside a reviewed
family range or reject unilateral co-ownership. The initial family's numeric
bounds use `minimum == maximum` only if the canonical values are genuinely
equivalent. Tests should assert the complete pull-family band map and mutations
just outside each family range without manufacturing endpoint values.

The patent itself treats a close-grip pull-up with rearward torso travel as a
high-row analogue. A canonical pull-up is therefore a mandatory boundary
fixture, not a generic vertical example. If its torso-relative chord overlaps
the proposed high-row band, that is evidence against activating the split.

If that work cannot produce a stable distinction, do not activate the family.
Keep the candidate deferred rather than merging it into `vertical-pull` with a
false vertical direction.

## Provisional narrow variant vocabulary

The first contract should admit only discrete values exercised by the initial
roster. Each family keeps its continuous direction bounds on its own numeric
axis, with one central exact-map test. Bilateral and unilateral records carry
their separately reviewed canonical values, which may be equal within the
measurement tolerance; neither may be assigned an artificial endpoint merely
to make a coverage test pass.

| Axis | Provisional values | Reason |
|---|---|---|
| `kineticChain` | `open` | The external lever moves relative to the seated athlete. |
| `bodyPosition` | `seated` | The reviewed mechanism is seated. |
| `lowerBodySupport` | `thighPad` | The adjustable pad restrains the athlete against the external load's reaction force. |
| `torsoSupport` | `machinePad` | The candidate IL-HR parts manual includes an anterior row chest pad; the exact measured unit must confirm the same setup. |
| `scapularTranslation` | `free` | An anterior chest pad supports the torso without pinning the posterior scapulae. |
| `gripOrientation` | `pronated` | The current IL-HR page specifies a fixed overhand grip. |
| `pullPath` | `overheadToAnteriorUpperTorso` | Reuses the pull-family categorical path axis to pin the reviewed elevated start and anterior upper-torso finish. |
| `upperArmPath` | `scapular` **provisional** | Reuses the row-family humeral corridor. The patent's outward elbows do not by themselves establish the value; human kinematics must confirm it is neither tucked nor flared. |
| `pullInclinationDegrees` | reviewed numeric value(s) **TBD** | Measure bilateral and unilateral use separately; collapse to one canonical value only if they agree within the declared tolerance. |
| `sagittalPathDirection` | **TBD after measurement** | Preserves whether the relative hand chord moves anteriorly, posteriorly, or has no material AP component. |
| `pathConstraint` | `leverGuided` | Reuses the pull-family mechanism vocabulary and pins the only admitted path constraint through a single-value enum. |
| `machineType` | `leverRow` | Reuses the row-mechanism vocabulary; endpoint and path axes carry the family geometry. |
| `leverArmConfiguration` | `independent` | Supports bilateral or one-arm execution without implying linked arms. |
| `leverPlaneOrientation` | **TBD after model-specific measurement** | The patent's approximately 25-degree forward-converging lever planes belong to its historical embodiment and cannot be inherited by the current `IL-HR`. |
| `lowerBodyContribution` | `none` | No hip, knee, or ankle drive. |
| `interRepSupport` | `none` | The working load does not reset on an external support. |
| `contralateralSupport` | `none|stabilizingHandle` | The reviewed unilateral setup lets the nonworking hand anchor on the machine. |

Do not add `relativeGripWidth` merely to copy neighboring families. The
patent's forward-converging lever planes and inwardly angled handles support
approach toward the midline, but that geometry does not map onto the catalog's
categorical shoulder-width scale. Add the axis only when a canonical endpoint
and value are documented.

### Why these path axes

The four path concepts answer different questions:

- `pathConstraint` says **how** the body or implement path is constrained. This
  candidate uses the existing single-value `leverGuided` enum; no boolean
  `fixedPath` and no `fixedValue` schema extension are needed.
- `pullPath` says **where** the canonical hand path starts and finishes relative
  to the head and torso. Replace vertical pull's mixed
  `frontScapular` value with the shared
  `overheadToAnteriorUpperTorso` endpoint value.
- `upperArmPath` says **where the humerus travels** (`tucked|scapular|flared`).
  It is reused from the row families because the patent's outward-elbow claim
  is exactly the kind of geometry this axis must review.
- `pullInclinationDegrees` plus `sagittalPathDirection` says **which app-facing
  direction** the torso-relative chord occupies.

At activation, migrate both active row families from `fixedPath` to the shared
pull `pathConstraint` enum (`free|leverGuided|railGuided`) while retaining
`assistancePlatformGuided` in vertical pull. Press families keep `fixedPath`;
their contract only distinguishes free versus guided external load and has no
guided-body branch. This yields one path-constraint vocabulary across pull
families without pretending every family must admit every value.

`lowerBodySupport: thighPad` also requires a deliberate shared-definition
migration. The existing wording focuses on contact that changes effective
bodyweight loading even though active `vertical-pull` already uses `thighPad`
as restraint against an external load. Broaden the one shared definition to
cover lower-body contact that materially changes either effective bodyweight
loading **or resistance-force restraint**, then update the README and every
affected contract test in the same activation change. Do not create a
diagonal-only synonym for the same physical pad.

### Provisional exercise rules

With the two-record roster, only two conditional rules are honest:

1. `bilateral-uses-no-contralateral-support`: bilateral laterality requires
   `variant.contralateralSupport == none`.
2. `unilateral-uses-reviewed-stabilizing-handle`: unilateral laterality
   requires `variant.contralateralSupport == stabilizingHandle`.

Each has a real match and contrast. Every other property is a required
single-value axis or the measured geometry value.
The second rule may activate only after one model-specific fixture confirms
that the measured path, chest pad, thigh restraint, independent arm, and
support handle coexist; otherwise defer the unilateral record rather than
combining features from different revisions.

Both active row families currently make `machineType: leverRow` imply
`contralateralSupport: none` through their local
`lever-row-is-supported-seated` rules. Those rules do **not** need relaxing:
they truthfully constrain those families' reviewed fixtures. Activation must
clarify in `families/README.md` that `leverRow` names a mechanism, not a global
no-support invariant; this candidate's documented support handle is governed
by its own family rule.

The supported unilateral fixture intentionally adds no `pelvis` demand. The
chest pad, thigh restraint, seat, and contralateral handle externally constrain
the anti-rotation task under this narrow setup. That is not a claim of zero
pelvic activity. A one-arm execution without the pad or support handle is a
different branch and must review both `pelvis`/`spine` demands and trunk-muscle
requirements rather than inheriting this omission.

## Provisional muscle policy

This is a provisional mechanics judgment, not a conservative evidence-backed
ranking. The reviewed component evidence is already too adverse to encode
sole-primary `lats` as the only legal answer:

| Role | Provisional muscles | Meaning and limitation |
|---|---|---|
| Required back primary | At least one of `lats`, `rhomboids`, or `trapeziusMiddle` | Keeps the product in the back group while allowing the measured humeral/scapular emphasis to decide the lead contributor. |
| Required contributor | `lats`, at least secondary | Shoulder-adduction/extension anatomy supports involvement, but no condition-matched high-row evidence establishes sole-primary status. |
| Required secondary | `teresMajor`, `bicepsBrachii`, `brachialis`, `brachioradialis` | Adduction/extension synergy plus the three separately represented elbow flexors. |
| Required retractor | At least one of `trapeziusMiddle`, `trapeziusLower`, or `rhomboids`, at least secondary | Required only if human kinematic review retains scapular retraction. |
| Optional co-primary or secondary | `pectoralisMajorSternocostal` | Loaded coronal adduction classifies its sternal compartments as co-prime with lat compartments; the condition-mismatched high-row path decides whether the catalog authors primary or secondary. |
| Optional secondary | `deltoidPosterior` and remaining allowed retractors | Plausible path- and position-dependent contribution; none of these is promoted to manufacture a difference from vertical pull. |
| Required stabilizer | `fingerFlexors`, `extensorCarpiRadialis` | Explicit static hand and wrist control without recreating the retired aggregate. |
| Optional stabilizer | `externalRotators`, `subscapularis`, `supraspinatus`, `trapeziusUpper`, `serratus`, `pectoralisMinor` | Exercise-specific shoulder/scapular control; no cuff assignment is copied automatically from a sibling family. |

The initial chest-supported fixture does not require a family-level `spine`
demand or a trunk-stabilizer assignment. That is a setup decision, not a claim
that the trunk is inactive. If model-specific review does not confirm the
anterior pad, the unsupported branch must instead add `spine` and require at
least one reviewed trunk stabilizer; only that branch may add `abs`, `obliques`,
or `lowerBack` to `allowedByRole.stabilizer`, together with the matching
exercise-level `additionalStabilityDemands`. It cannot reuse this policy
unchanged.

Provisional policy shape:

```json
{
  "requirements": [
    {
      "anyOf": [
        "lats",
        "rhomboids",
        "trapeziusMiddle"
      ],
      "minimumRole": "primary"
    },
    {"anyOf": ["lats"], "minimumRole": "secondary"},
    {"anyOf": ["teresMajor"], "minimumRole": "secondary"},
    {"anyOf": ["bicepsBrachii"], "minimumRole": "secondary"},
    {"anyOf": ["brachialis"], "minimumRole": "secondary"},
    {"anyOf": ["brachioradialis"], "minimumRole": "secondary"},
    {
      "anyOf": [
        "trapeziusMiddle",
        "trapeziusLower",
        "rhomboids"
      ],
      "minimumRole": "secondary"
    },
    {"anyOf": ["fingerFlexors"], "minimumRole": "stabilizer"},
    {"anyOf": ["extensorCarpiRadialis"], "minimumRole": "stabilizer"}
  ],
  "allowedByRole": {
    "primary": [
      "lats",
      "rhomboids",
      "trapeziusMiddle",
      "pectoralisMajorSternocostal"
    ],
    "secondary": [
      "lats",
      "teresMajor",
      "bicepsBrachii",
      "brachialis",
      "brachioradialis",
      "trapeziusMiddle",
      "trapeziusLower",
      "rhomboids",
      "deltoidPosterior",
      "pectoralisMajorSternocostal"
    ],
    "stabilizer": [
      "fingerFlexors",
      "extensorCarpiRadialis",
      "externalRotators",
      "subscapularis",
      "supraspinatus",
      "trapeziusUpper",
      "serratus",
      "pectoralisMinor"
    ]
  }
}
```

This allowed-role surface is illustrative, not permission to encode unresolved
roles at activation. Condition-matched evidence must decide whether
`rhomboids`, `trapeziusMiddle`, or `pectoralisMajorSternocostal` may be primary
on the admitted fixture. Component capability or manufacturer emphasis alone
cannot settle that hierarchy.

Reed et al. found mean maximal-load excitation of 103% MVC for latissimus, 81%
for rhomboid major, and 76% for teres major during isometric adduction at 30,
60, and 90 degrees of shoulder abduction in the scapular plane, all well above
the measured cuff values. Wickham and Brown found latissimus compartments
L1–L6 and sternal-head pectoralis compartments P3–P6 activated together,
significantly earlier than the other segments, and more than 100 ms before
movement onset; both sets were classified as prime movers. The later
onset group—clavicular pectoralis P1/P2 plus deltoid D7—activated about 86 ms
before movement onset and was classified as synergistic. These studies support
the **adduction component**,
not the complete lever-high-row exercise. They make sole-primary lats less
secure and make sternocostal-pec involvement an explicit activation decision,
but they do not by themselves justify either a primary or secondary high-row
assignment and do not turn a mechanics-derived roster into directly tested
exercise variants.

Ekholm et al. provide the opposite kind of warning: their pulley-resisted
diagonal shoulder patterns included an extension-adduction-internal-rotation
condition that strongly activated sternocostal pectoralis major. That movement
is not the proposed high row—it deliberately adds internal rotation and lacks
the same elbow/support geometry—but it proves that the words “diagonal,”
“extension,” and “adduction” do not by themselves guarantee a lat-dominant
exercise.

## Scapular policy

Do not infer `scapula.depression` or `scapula.downwardRotation` from downward
handle travel. The active vertical-pull review already rejected that shortcut,
and loaded-adduction kinematics show task-specific orientation with substantial
individual variability.

Provisionally forbid depression, elevation, upward/downward rotation, and
anterior/posterior tilt as **authored prime actions** under the catalog's
canonical-concentric convention, as shown in the classification draft. This is
not a claim that no angular scapular motion occurs; the schema has no separate
eccentric-action channel. The flat prohibition prevents a future exercise from
silently adding an unreviewed action through `additionalPrimeActions`.
Admitting one later requires evidence and a family-contract edit. The initial
contract must not claim a scapular angular direction merely because the hands
finish lower.

## Candidate initial roster

If the gates pass, only two catalog entries are needed for the narrow initial
roster:

| Candidate exercise | Laterality | Reviewed setup purpose | Evidence status |
|---|---|---|---|
| Lever High Row Machine | Bilateral | Candidate seated IL-HR setup: anterior chest pad, fixed overhand grip, independent levers, thigh restraint, and a guided path whose direction remains unmeasured. | Apparatus features are documented, but path geometry, humeral actions, scapular action, and roles remain activation blockers. |
| Single-Arm Lever High Row Machine | Unilateral | Same physical unit and lever mechanism using one independent arm plus the documented contralateral stabilizing handle; measure its torso-relative path separately. | One-arm operation is documented; geometric equivalence, every setup feature on the measured unit, and muscle-role deltas still require review. |

Plate-loaded versus selectorized resistance is not automatically a separate
exercise. If both machines reproduce the same reviewed relative path and
support geometry, they can map to the same catalog movement. If they do not,
the shared marketing name does not make them variants of one contract.

Candidate aliases, subject to the cross-family cleanup below:

| Canonical exercise | Candidate aliases |
|---|---|
| Lever High Row Machine | `Machine High Row`, `Iso-Lateral High Row` |
| Single-Arm Lever High Row Machine | `Single-Arm Machine High Row`, `One-Arm Machine High Row` |

Do not add bare `High Row`. It is already used in research and gyms for
shoulder-height, diagonal, suspension, cable, and rehabilitation movements
with different signatures.

## Naming conflict in the active catalog

The active `shoulder-horizontal-abduction-row` family correctly explains that
“High Row” is ambiguous, but its aliases currently include:

- `Wide-Grip Barbell High Row`;
- `Chest-Supported Dumbbell High Row`;
- `Wide-Grip Cable High Row`; and
- `Chest-Supported Machine High Row`.

The last alias is especially likely to be interpreted as this candidate's
commercial diagonal machine. Before activation, remove those broad aliases or
qualify each with `Rear-Delt` or `Shoulder-Height`. Reserve `Machine High Row`
and its one-arm forms for the diagonal family while keeping bare `High Row`
unowned. Because the catalog is pre-production, semantic clarity is more
valuable than preserving these newly authored aliases.

Whole-family normalized identity validation and exact alias-set tests must be
updated in the same activation change.

## Ownership and exclusions

| Candidate | Decision | Reason |
|---|---|---|
| Reviewed IL-HR lever high row | Candidate owner only if gates pass | Elevated-start guided mechanism; product name alone does not establish diagonal ownership. |
| One-arm use of the same independent lever | Candidate owner with disclosure | Same reviewed path; the support-handle setup must be explicit. |
| Front cable or lever lat pulldown | Exclude | Vertical relative path; active `vertical-pull`. |
| Tucked torso-height lever row | Exclude | Horizontal shoulder-extension path; active `shoulder-extension-row`. |
| Flared 90-degree rear-delt high row | Exclude | Transverse horizontal-abduction path; active `shoulder-horizontal-abduction-row`. |
| 60-degree flared cable row | Defer outside this family | Mixed extension/horizontal-abduction issue, not proof of extension/adduction diagonal ownership. |
| Diverging commercial high-row machine | Defer | The shared name does not prove the same humeral components or mediolateral path. |
| High-row machine with different support or restraint geometry | Defer | A shared product name does not make different pad, arm-path, or reaction-force geometry equivalent. |
| Unsupported high-row setup | Defer | The initial fixture is chest-supported; removing the pad changes trunk control and may change the authored path. |
| Seated or kneeling diagonal cable row | Defer | Free path, line-of-pull, pelvis, and trunk combinations are unreviewed. |
| D.Y. row, T-bar, or landmine high row | Defer | An overhead pivot or room-space diagonal arc does not establish this torso-relative path. |
| Straight-arm pulldown or machine pullover | Exclude | No dynamic elbow-flexion signature. |
| Face pull | Exclude | Adds horizontal abduction and often deliberate external rotation. |
| Extension-adduction-internal-rotation diagonal | Exclude | Dynamic internal rotation is forbidden and the muscle emphasis can differ. |
| Upright row | Exclude | Shoulder abduction/elevation rather than the proposed signature. |
| Kipping or momentum high row | Exclude | Trunk, hip, or lower-body propulsion is part of the repetition. |

## Evidence limitations

- No peer-reviewed study found in this review directly tests the commercial
  overhead-start lever-high-row exercise.
- Youdas' “high row” is a suspension row ending in 90-degree shoulder
  horizontal abduction. It belongs to the active shoulder-height-row family.
- Kara's 120-degree “high row” is an elastic scapular-retraction condition,
  not a condition-matched heavy lever high row.
- The original high-row patent is useful for handle position, a
  downward/slightly-forward path, forward-converging lever-plane orientation,
  inwardly angled handles, support provisions, and alternate one-arm
  operation. That geometry supports the hands approaching the midplane, but it
  does not map that approach onto `relativeGripWidth`, prove that a current
  IL-HR revision reproduces the exact geometry, or turn inventor muscle claims
  into experimental evidence.
- Manufacturer pages are useful for identifying actual mechanisms and for
  proving that different products called “High Row” are heterogeneous. The
  Nautilus page explicitly documents divergence; the Hammer page does **not**
  document convergence. Their target-muscle copy is marketing, not a
  primary/secondary oracle.
- Reed and Wickham support shoulder-adduction muscle behavior, not the whole
  compound exercise.
- Ekholm studies different resisted diagonal shoulder patterns and is used only
  to reject an invalid inference from action labels to muscle emphasis.
- The exact back-primary and sternocostal-pec roles are therefore explicit
  equipment-specific mechanics judgments. Activation may accept those
  disclosed limitations, but must not describe them as directly measured
  high-row evidence.

## Evidence reviewed

- [Prinold and Bull (2016), *Scapula kinematics of pull-up techniques:
  Avoiding impingement risk with training changes*](https://doi.org/10.1016/j.jsams.2015.08.002):
  direct 3D pull-up measurements show grip-dependent humerothoracic,
  glenohumeral, and scapulothoracic kinematics plus substantial between-person
  variation. This is a boundary-method precedent, not transferable high-row
  kinematics.
- [Lorenzetti et al. (2017), *Pulling Exercises for Strength Training and
  Rehabilitation: Movements and Loading
  Conditions*](https://doi.org/10.3390/jfmk2030033): compares pulling setups
  with 3D motion capture, including an exercise named a 45-degree lat
  pulldown. That label describes its setup; it is not this contract's signed
  torso-relative start/end hand chord and cannot supply a numeric direction
  band.
- [Vasconcelos et al. (2023), *Effect Of Different Grip Position And
  Shoulder-Abduction Angle On Muscle Strength And Activation During The Seated
  Cable Row*](https://doi.org/10.47206/ijsc.v3i1.190): recruitment shifts as
  the tested humeral-abduction angle moves from the narrow corridor toward 60
  and 90 degrees. That makes `upperArmPath` contract-defining rather than a
  value that can be inferred safely from a product photograph.
- [Reed, Halaki, and Ginn (2010), *The rotator cuff muscles are activated at
  low levels during shoulder adduction: an experimental
  study*](https://doi.org/10.1016/S1836-9553(10)70009-6): 15 healthy adults
  performed isometric adduction at 30, 60, and 90 degrees of shoulder
  abduction in the scapular plane and at four loads. At maximal load,
  latissimus averaged 103% MVC, rhomboid major 81%, and teres major 76%, versus
  3% supraspinatus and 27% each for infraspinatus and subscapularis. This is
  direct adverse evidence against treating rhomboids as merely incidental, but
  it still supports only the adduction component.
- [Wickham and Brown (2012), *The function of neuromuscular compartments in
  human shoulder muscles*](https://doi.org/10.1152/jn.00049.2011): 16 men
  performed a 40-degree ballistic coronal-plane adduction. Latissimus L1–L6
  and sternal-head pectoralis P3–P6 activated together, significantly earlier
  than the other compartments and more than 100 ms before movement onset; both
  were classified as prime movers. The later-onset synergist group—clavicular
  pectoralis P1/P2 and deltoid D7—activated about 86 ms before movement onset.
  The paper is in the January
  2012 issue of *Journal of Neurophysiology* 107(1):336–345 and was published
  online October 5, 2011; register it as 2012 and preserve that split in the
  evidence scope.
- [Ackland et al. (2008), *Moment arms of the muscles crossing the anatomical
  shoulder*](https://doi.org/10.1111/j.1469-7580.2008.00965.x): independent
  anatomical capability evidence for latissimus, teres major, pectoralis
  major, deltoid, and cuff actions; it does not classify a high-row machine.
- [Holzbaur, Murray, and Delp (2005), *A model of the upper extremity for
  simulating musculoskeletal surgery and analyzing neuromuscular
  control*](https://doi.org/10.1007/s10439-005-3320-7): upper-extremity
  musculotendon geometry supporting the capability map, not exercise roles.
- [Lee et al. (2025), *Scapular kinematics and task specificity: The effect of
  load direction*](https://doi.org/10.1016/j.jbiomech.2025.112932): loaded
  shoulder-adduction kinematics caution against inferring scapular angular
  change from arm or handle travel.
- [Ekholm et al. (1978), *Shoulder muscle EMG and resisting moment during
  diagonal exercise movements resisted by
  weight-and-pulley-circuit*](https://pubmed.ncbi.nlm.nih.gov/715388/): four
  resisted diagonal shoulder patterns produced different recruitment. The
  extension-adduction-internal-rotation result is a boundary warning, not
  high-row evidence.
- [Gary A. Jones (1993), US5273505A, *High row exercise
  machine*](https://patents.google.com/patent/US5273505A/en): documents handles
  above and in front of the exerciser, a downward/slightly-forward pull,
  forward-converging independent lever planes, thigh restraint, chest-support
  provisions, slightly outward elbow travel, and bilateral or alternate
  one-arm operation. Its close-grip-pull-up analogy is a boundary warning. It
  does not experimentally validate joint actions or muscle roles.
- [Hammer Strength, *Plate Loaded Iso-Lateral High
  Row*](https://shop.lifefitness.com/products/hammer-strength-iso-lateral-high-row):
  current first-party independent-arm, fixed-overhand-grip, adjustable
  seat/thigh-pad, and one-arm support-handle documentation. The page calls the
  motion more horizontal than a front pulldown and emphasizes rhomboids,
  trapezius, and rear deltoid before lats, so it is adverse evidence against
  assuming diagonal geometry or sole-primary lats. Its muscle-target copy is
  not used to assign roles.
- [Life Fitness (2023), *ISO-LATERAL Parts Manual — High Row — ILHR &
  IL-HR*](https://www.lftechsupport.com/c/document_library/get_file?p_l_id=1691375&folderId=1627127&name=DLFE-123712.pdf):
  the current first-party parts drawing includes the anterior torso pad on the
  IL-HR. It establishes the component's presence, not a measured hand path or
  human scapular motion.
- [Nautilus, *Leverage High
  Row*](https://www.corehandf.com/products/nautilus-leverage-high-row): a
  first-party example of a diverging product with independent arms and an
  adjustable chest pad using the same common name. The page does not document
  a foot platform or lower-body restraint. It establishes product
  heterogeneity, not family equivalence.

The patent, current retail page, and current parts manual are separate pieces
of provenance. Together they identify a plausible fixture, but they do not
prove that every patent path detail survives on every current serial revision.
The activation measurement must record one physical model rather than
assembling a contract from whichever feature appears in each source.

## Evidence-registry impact

Do not add any source to `evidence.json` during discovery; unused registered
evidence correctly fails validation.

Two registerable component sources are reserved for activation:

- `reed-2010-shoulder-adduction-emg`
- `wickham-2012-shoulder-adduction-compartments`

The current evidence model already accepts optional `pmid`, and 33 registered
sources use it. The actual blocker is that `doi` remains mandatory
for every source and `url` must equal `https://doi.org/{doi}`. It therefore
cannot represent Ekholm's PMID-only paper or the high-row patent even though
each has a stable reviewed identifier. Because the patent would be
load-bearing geometry evidence, activation must either:

1. make `doi` optional when an approved alternative identifier is present,
   retain the existing `pmid` field, add a precise patent-publication field,
   and validate the canonical URL for each identifier type; or
2. obtain equivalent DOI-backed or directly measured geometry and keep the
   non-registerable sources contextual only.

Do not weaken identity validation to permit arbitrary URLs.

## Activation gates

The family is ready for activation only after all of these are settled:

1. **Model-specific geometry:** measure one identified physical unit with the
   documented seat/pad/alignment protocol, exact endpoint landmarks, signed AP
   direction, inclination, and tolerance. Measure bilateral and unilateral
   execution separately; share a canonical value only if the results agree
   within tolerance. Both must satisfy the same reviewed categorical
   `pullPath` to remain in one family.
2. **Family-local bands:** measure the canonical pull-up, representative
   pulldown, shoulder-extension row, and shoulder-height row under the same
   convention. Put each reviewed range in that family's
   `pullInclinationDegrees` axis and assert the complete family-to-band map in
   one exact test, matching the press precedent. The initial diagonal axis uses
   `minimum == maximum` only if every admitted canonical fixture value is
   equivalent within tolerance; otherwise its bounds must be the truthful
   reviewed range. If the pull-up or IL-HR overlaps a neighboring band, reject
   the proposed split.
3. **Cross-family path migration:** add a defensible per-exercise inclination
   or documented setup proxy **and** its reviewed `sagittalPathDirection` to
   `vertical-pull.json`,
   `shoulder-extension-row.json`, and
   `shoulder-horizontal-abduction-row.json`. Migrate the two row families from
   `fixedPath` to shared pull `pathConstraint` values
   `free|leverGuided|railGuided`; vertical pull keeps its existing
   `assistancePlatformGuided` branch. Rename vertical pull's `pullPath` value
   from `frontScapular` to `overheadToAnteriorUpperTorso`, narrow its
   description to endpoint-corridor semantics, and move the former humeral
   meaning into shared `upperArmPath` values reviewed per vertical-pull record.
   `sagittalPathDirection` is a shared pull/row axis, not a candidate-only
   escape hatch. This candidate also uses `upperArmPath`. Update the proposal
   records, `families/README.md`, exact-roster tests, and mutations in the same
   change.
   Measuring one representative does not justify invented values for every
   existing record.
4. **Apparatus review:** on that same unit verify the chest pad, thigh
   restraint, fixed overhand grip, independent arms, support handle, endpoint
   landmarks, and lever-plane orientation. Patent and retail features are not
   substitutes for this identity check.
5. **Human kinematic review:** separately establish `upperArmPath`, meaningful
   shoulder adduction, conditioned extension, and any scapular retraction.
   Apparatus geometry cannot establish glenohumeral or scapular action by
   itself. If retraction is removed, retain `scapula` and activate the explicit
   stabilizer-requirement branch. If the movement proves horizontal, flared, or
   lacks meaningful adduction, route it to an existing row family and retire
   this candidate.
6. **Scope:** keep the initial contract to the one reviewed lever mechanism
   and its bilateral/unilateral executions. Cable, unsupported, differently
   restrained, diverging, landmine, D.Y.-row, and free-weight branches stay
   deferred.
7. **Muscle policy:** use condition-matched evidence to approve the exact
   back-primary and sternocostal-pec role surface; geometry and component
   capability alone are insufficient. Register the two component studies as
   context, note Wickham's October 2011 online/January 2012 issue split in its
   scope, and keep cuff roles optional absent condition-matched evidence.
8. **Evidence identifiers:** decide how load-bearing non-DOI primary sources
   are represented or replaced.
9. **Support vocabulary:** broaden the shared `lowerBodySupport` definition in
   both catalog READMEs and all four active families that declare it
   (`horizontal-press`, `vertical-pull`, `shoulder-extension-row`, and
   `shoulder-horizontal-abduction-row`) so `thighPad` honestly covers
   resistance-force restraint as well as effective-bodyweight changes.
10. **Lever-row support semantics:** keep the two sibling families' local
    `contralateralSupport: none` rules, add this candidate's documented
    unilateral handle rule, and state in `families/README.md` that `leverRow`
    itself implies neither choice.
11. **Names and aliases:** remove or qualify the active rear-delt family's
    broad `High Row` aliases, reserve machine-high-row names here, and validate
    global normalized uniqueness.
12. **Contract encoding:** add `families/diagonal-pull.json` only after gates
    1–11, with exactly the reviewed roster, two explicit laterality/support
    rules, and no speculative axis values.
13. **Tests:** require exact classification and planes; deliberate equality of
    the vertical/diagonal component actions but different measured geometry;
    one exact pull-family band map and just-outside mutations; signed path,
    exact `pullPath`, `upperArmPath`, and single-value
    `pathConstraint: leverGuided`; typed discrete-axis coverage; exact roster
    and alias sets; global identity uniqueness; independent-only lever
    admission with both bilateral and unilateral use; and a match, contrast,
    and per-assertion mutation for each of the two JSON rules.
    Boundary fixtures must cover a canonical pull-up/pulldown, tucked
    horizontal row, shoulder-height rear-delt row, face pull, internal-rotation
    diagonal, and the measured valid fixture. A straight-arm pulldown is a
    contract-level mutation removing fixed `elbow.flexion`, not an
    exercise-level variant the current schema can encode.
    Port vertical-pull and row coverage tests to branch on axis `valueType`:
    enum axes require exact admitted-value coverage, while continuous direction
    bands must not force authors to invent records at numeric minima/maxima.
    Explicitly load the new family in the unit-test fixture and include it in
    exact family/evidence/identity sets; the command-line validator's directory
    discovery does not make those test lists automatic.
14. **Phase semantics:** assert the flat prime/forbidden action lists only as
    the canonical concentric signature; do not promise an eccentric mutation
    or phase condition the schema cannot encode.
15. **Historical runtime boundary:** this discovery itself did not cut the
    catalog into Swift. The later atomic cutover is now complete: runtime uses
    the final 52-region taxonomy, `familyID`, diagonal direction, multi-plane
    snapshots, deterministic family compilation, and matching editor surfaces.

The public-source geometry review is complete and failed. The correct next
action is the tracked physical/CAD measurement protocol, not family activation.
