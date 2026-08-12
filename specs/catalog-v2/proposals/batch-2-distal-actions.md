# Batch 2 — distal forearm, wrist, and grip contract discovery

Status: integrated review record. The six anatomical rotation/wrist families
are activated narrowly after the arm/forearm taxonomy migration and acceptance
of the disclosed source-to-product adaptation. The generic `grip` candidate is
rejected as presently named and remains deferred.

## Outcome

| Candidate | Verdict | Initial roster |
|---|---|---:|
| `forearm-pronation` | Activated narrowly | 1 |
| `forearm-supination` | Activated narrowly | 1 |
| `wrist-flexion` | Activated narrowly | 1 |
| `wrist-extension` | Activated narrowly | 1 |
| `wrist-radial-deviation` | Activated narrowly | 1 |
| `wrist-ulnar-deviation` | Activated narrowly | 1 |
| `grip` | Do not activate | 0 |

The resulting distal activation is deliberately only six exercises. It
covers every admitted equipment and geometry value without treating every
familiar forearm drill as already reviewed.

## Resolved foundation dependency: aggregate forearm shortcut removed

These contracts could not activate against the pre-Batch-2 `biceps` and
`forearms` regions. That `forearms` aggregate claimed pronation, all four wrist
actions, and grip, while `biceps` combined biceps brachii and brachialis despite
only the former supinating the forearm. The completed foundation migration
removed that representation before any family became validator input.

The foundation migration replaces the two aggregate IDs with these eleven
regions, taking the taxonomy from 32 to 41 muscles:

| New muscle ID | Mesh ownership | Required dynamic capabilities |
|---|---|---|
| `bicepsBrachii` | `Biceps` | shoulder flexion, elbow flexion, forearm supination |
| `brachialis` | `Brachialis` | elbow flexion |
| `brachioradialis` | `Brachioradialis` | elbow flexion; forearm pronation from supination toward neutral; forearm supination from pronation toward neutral |
| `forearmPronators` | unvisualized pronator teres + pronator quadratus | forearm pronation |
| `supinator` | unvisualized | forearm supination |
| `flexorCarpiRadialis` | `Flexor_Carpi_Radialis` | wrist flexion, wrist radial deviation |
| `flexorCarpiUlnaris` | `Flexor_Carpi_Ulnaris` | wrist flexion, wrist ulnar deviation |
| `extensorCarpiRadialis` | `Extensor_Carpi_Radialis_Longus`, `Extensor_Carpi_Radialis_Brevis` | wrist extension, wrist radial deviation |
| `extensorCarpiUlnaris` | `Extensor_Carpi_Ulnaris` | wrist extension, wrist ulnar deviation |
| `fingerFlexors` | `Flexor_Digitorum_Superficialis`, `Flexor_Digitorum_Profundus` | wrist flexion, hand finger flexion |
| `fingerExtensors` | `Extensor_Digitorum_Communis` | wrist extension, hand finger extension |

Wrist muscles stabilize `wrist`, finger muscles stabilize `hand`, and the
elbow-crossing arm muscles stabilize `elbow` where anatomically appropriate.
Those stabilization capabilities are necessary for the categorical roles
below; they do not add a prime action.

`hand.grip` must be retired from `joint-actions.json`. Grip is a task outcome,
not a single cardinal-plane joint rotation: a static support grip has no
dynamic hand action, a gripper closes the finger joints, and a plate pinch has
thumb and intrinsic-hand demands that the taxonomy does not represent. Add
instead:

```json
{
  "id": "hand.fingerFlexion",
  "region": "hand",
  "plane": "sagittal",
  "displayName": "Finger flexion"
},
{
  "id": "hand.fingerExtension",
  "region": "hand",
  "plane": "sagittal",
  "displayName": "Finger extension"
}
```

The two new actions describe dynamic joint motion. An isometric implement hold
is represented by `handTask: staticImplementHold`, a `hand` stability demand,
and `fingerFlexors` as a stabilizer, not by adding finger flexion as a prime
action.

The foundation also adds `fromSupinatedPosition` for
`forearm.pronation` and `fromPronatedPosition` for
`forearm.supination`. They describe rotation only from the named side toward
neutral. Bremer 2006 and Boland 2008 make the conditions load-bearing: they
preserve brachioradialis's observed return-to-neutral moment without falsely
making it an unconditional full-range pronator or supinator.

## Shared distal vocabulary

The following spellings are shared with the elbow-family proposal and should
be documented in `families/README.md` during activation.

| Axis | Values | Meaning |
|---|---|---|
| `kineticChain` | `open` | The implement/hand segment moves rather than remaining fixed to the environment. |
| `bodyPosition` | `seated\|standing` | Gross body position used by the reviewed fixture. |
| `forearmSupport` | `none\|thigh\|bench\|table\|machinePad` | Surface supporting the forearm. Admit only the subset a family actually uses. This is not torso support. |
| `elbowMotion` | `angleHeld\|flexes\|extends` | Dynamic elbow action; distal families use only `angleHeld`. |
| `elbowPosture` | `flexed\|extended` | Canonical elbow posture held through the repetition. |
| `forearmMotion` | `angleHeld\|pronates\|supinates` | Dynamic radioulnar action, independent of hand contact or grip. |
| `forearmOrientation` | `supinated\|neutral\|pronated` | A posture held while another joint moves. It must not describe a dynamic rotation exercise. |
| `forearmStartOrientation` | `supinated\|neutral\|pronated` | Starting posture for a dynamic radioulnar rotation. |
| `forearmEndOrientation` | `supinated\|neutral\|pronated` | Concentric endpoint for a dynamic radioulnar rotation. |
| `wristMotion` | `angleHeld\|flexes\|extends\|radiallyDeviates\|ulnarlyDeviates` | Dynamic wrist action; it must agree with the family signature. |
| `wristPosture` | `neutral` | Wrist posture held when `wristMotion` is `angleHeld`; neutral is a reviewed authoring target, not claimed zero measurement error. |
| `handTask` | `staticImplementHold` | The fingers hold the implement without deliberate opening/closing as the repetition. |
| `resistanceGeometry` | `centeredBar\|rotationalPlateLoadedDumbbell\|collarOffsetLever` | How resistance produces the reviewed joint torque. `rotationalPlateLoadedDumbbell` records Szymanski's plate-loaded dumbbell rotated about the forearm axis without inventing a one-ended load. `collarOffsetLever` records the separately described deviation fixture, where the hand grips above or below the bottom collar and the dumbbell shaft points behind or ahead to create a wrist lever. The mechanisms must not collapse into a generic `offsetLever`; only the deviation source explicitly reports collar-relative offset. Deferred band fixtures do not pre-authorize `bandAnchor`. |
| `fixedPath` | `false` (`fixedValue: false`) | Existing external-load meaning: no rail or machine lever constrains the implement path. The boolean invariant is validator-enforced by the axis-level fixed value, without inventing an always-true exercise rule or overloading vertical pull's body-path `pathConstraint` vocabulary. |
| `lowerBodyContribution` | `none` | Hip, knee, or ankle drive does not create the repetition. |

Do not reuse `gripOrientation` for forearm posture. In the current catalog that
axis describes a hand/implement relationship, while pronation and supination
are radioulnar joint states. Keeping the concepts separate is especially
important once a future grip family owns finger motion.

`forearmStartOrientation` and `forearmEndOrientation` are required only in the
two rotation families. `forearmOrientation` is required only when the forearm
is held still in an elbow or wrist family. Likewise, `wristPosture` is required
only where `wristMotion` is `angleHeld`; a wrist-motion family uses its
signature and motion axis rather than inventing approximate endpoint angles.
The reviewed sources do not justify universal numeric range thresholds.

### Exact initial axis matrix

Every listed axis is required in the family where a value appears. An em dash
means the axis is absent from that family rather than optional on an exercise.
All six also pin `kineticChain: open`, `handTask: staticImplementHold`,
`fixedPath: false` through `fixedValue: false`, and
`lowerBodyContribution: none`.

| Family | bodyPosition | forearmSupport | elbowMotion / posture | forearmMotion | held forearmOrientation | start → end | wristMotion | wristPosture | resistanceGeometry |
|---|---|---|---|---|---|---|---|---|---|
| `forearm-pronation` | seated | table | angleHeld / flexed | pronates | — | supinated → neutral | angleHeld | neutral | rotationalPlateLoadedDumbbell |
| `forearm-supination` | seated | table | angleHeld / flexed | supinates | — | pronated → neutral | angleHeld | neutral | rotationalPlateLoadedDumbbell |
| `wrist-flexion` | seated | bench | angleHeld / flexed | angleHeld | supinated | — | flexes | — | centeredBar |
| `wrist-extension` | seated | bench | angleHeld / flexed | angleHeld | pronated | — | extends | — | centeredBar |
| `wrist-radial-deviation` | standing | none | angleHeld / extended | angleHeld | neutral | — | radiallyDeviates | — | collarOffsetLever |
| `wrist-ulnar-deviation` | standing | none | angleHeld / extended | angleHeld | neutral | — | ulnarlyDeviates | — | collarOffsetLever |

Each initial family has only single-value axes and one roster record, so none
needs an `exerciseRules` entry. The constraints belong in the axis
`allowedValues`; an always-true rule would violate the established contrasting-
fixture test convention.

All six use `groupPolicy.default: arms`, allow only that group, and set
`modality: dynamicStrength`, `trackingMode: reps`, `loadMode: external`, and
`recommended.defaultReps: 8...15`. Rotation and deviation allow only
`equipment: dumbbell` with `laterality: unilateral`; flexion and extension
allow only `equipment: barbell` with `laterality: bilateral`. Those are exact
initial classifications, not a claim that cable, band, or unilateral wrist-
curl variants are biomechanically impossible. All six initial records use
`aliases: []` so the migration does not inherit ambiguous legacy names.

## Common action boundary

Activation expanded one auditable forbidden-action template into every family
JSON. It starts with these actions:

```text
scapula.elevation, scapula.depression, scapula.protraction,
scapula.retraction, scapula.upwardRotation, scapula.downwardRotation,
scapula.anteriorTilt, scapula.posteriorTilt,
shoulder.flexion, shoulder.extension, shoulder.abduction,
shoulder.adduction, shoulder.horizontalAdduction,
shoulder.horizontalAbduction, shoulder.internalRotation,
shoulder.externalRotation,
elbow.flexion, elbow.extension,
forearm.pronation, forearm.supination,
wrist.flexion, wrist.extension, wrist.radialDeviation,
wrist.ulnarDeviation,
hand.fingerFlexion, hand.fingerExtension,
spine.flexion, spine.extension, spine.lateralFlexion, spine.rotation,
hip.extension, knee.extension, ankle.plantarflexion
```

Each family removes only its own required prime action from that list. This
makes the boundary declarative: rotation cannot become a curl, a wrist curl
cannot add finger closing, and a standing deviation cannot silently become a
whole-body lever movement merely because an assigned muscle list happens to
reject the extra action today.

Because `forbiddenPrimeActions` stores bare action IDs, a conditioned family
cannot also forbid the unconditioned spelling of its own action. The generic
validator hardening in the activation gate below closes that representational
hole: an exercise may not redeclare a family action with broader or different
condition semantics.

All seven candidates are isolation mechanics with `pattern: null` and
`direction: null`. The app-facing plane comes solely from the basis action:
transverse for radioulnar rotation, sagittal for wrist flexion/extension, and
frontal for radial/ulnar deviation.

## Source-to-product adaptation disclosed

Szymanski 2004 is a direct 12-week isotonic training source, but its detailed
10RM assessments used neoprene wraps: the forearms were secured to the bench
for wrist curls, the upper arm was held against the torso for rotation, and the
entire arm was held against the side for deviation. The six product fixtures
retain the reported joint posture, external support, direction, and prohibition
on proximal motion, but do not turn laboratory restraint straps into catalog
equipment. Their unstrapped coaching is therefore a disclosed mechanics-based
product adaptation, not a claim that the exact free setup was studied. This is
the one activation judgment common to all six records; if the project requires
literal apparatus identity, the honest outcome is to defer this batch rather
than invent an `armRestraint` axis users cannot normally satisfy.

Removing those straps transfers the held proximal-joint work to the athlete.
The active contracts therefore declare `shoulder|scapula|elbow|forearm|wrist|
hand` stability on all six fixtures rather than preserving only the distal
demands from the laboratory apparatus. `externalRotators` and
`trapeziusMiddle` stabilize the unsupported shoulder and scapula;
`brachioradialis` supplies elbow/forearm stability where it is not already a
secondary rotator. Wrist flexion also retains `fingerExtensors` as a hand/wrist
stabilizer opposing the static bar hold. These are anatomy-map applications to
the disclosed unstrapped product fixture, not muscles measured by Szymanski or
evidence that proximal motion creates the repetition. The exact policies below
include them so the proposal and activated JSON do not describe different
exercises.

The same paper's ulnar-deviation paragraph repeats the radial-deviator list
(`FCR`, `ECRL`, `ECRB`) verbatim. That conflicts with the movement direction,
with its own surrounding protocol, and with direct tendon-moment-arm evidence.
Treat it as a textual error, not as role evidence. Ulnar roles below come from
Garland, Nichols, and Forman; Szymanski supports only the loaded exercise
fixture and training response.

## Family 1: `forearm-pronation`

### Contract

- Fixed: isolation, no pattern/direction, `planes: ["transverse"]`.
- Basis action: `forearm.pronation`.
- Required prime action:
  `{ "action": "forearm.pronation", "condition": "fromSupinatedPosition" }`.
- Stability demands: `shoulder`, `scapula`, `elbow`, `forearm`, `wrist`,
  `hand`.
- Allowed equipment: dumbbell; unilateral; dynamic strength; reps; external
  load.
- Muscle requirements:
  - `forearmPronators` at `primary`;
  - `brachioradialis` at `secondary` for its reviewed, conditioned
    return-to-neutral contribution;
  - `extensorCarpiRadialis` at `stabilizer` for the held wrist; and
  - `fingerFlexors`, `externalRotators`, and `trapeziusMiddle` at
    `stabilizer` for implement contact and the unstrapped proximal setup.
- `allowedByRole` is exact: primary `forearmPronators`; secondary
  `brachioradialis`; stabilizers
  `extensorCarpiRadialis|fingerFlexors|externalRotators|trapeziusMiddle`.

Fukunaga observed high pronator-teres and flexor-digitorum-superficialis EMG in
its full-range band fixture. That does not make `fingerFlexors` a pronation
synergist: they cannot produce radioulnar pronation and remain a hand-contact
stabilizer. More importantly, that fixture crossed neutral, so it is evidence
for pronator involvement but is deliberately not copied into this narrower
conditioned family roster.

### Axes and initial roster

The exact single-value setup uses `kineticChain: open`,
`bodyPosition: seated`, `forearmSupport: table`,
`elbowMotion: angleHeld`,
`elbowPosture: flexed`, `forearmMotion: pronates`,
`forearmStartOrientation: supinated`, `forearmEndOrientation: neutral`,
`wristMotion: angleHeld`, `wristPosture: neutral`,
`handTask: staticImplementHold`,
`resistanceGeometry: rotationalPlateLoadedDumbbell`, `fixedPath: false` through
the boolean axis's `fixedValue: false`, and `lowerBodyContribution: none`.
Single-value axes pin
the fixture without an always-true exercise rule.

| ID | Name | Load seed | Reps | Priority | Evidence |
|---|---|---:|---:|---:|---|
| `seated-dumbbell-forearm-pronation` | Seated Dumbbell Forearm Pronation | 5 lb / 2.5 kg | 10 | 80 | Szymanski 2004; Haugstvedt 2001 |

The dumbbell must be authored as Szymanski's plate-loaded rotational implement
in both its variant and movement definition. The source does not say that it
was loaded at only one end, so a generic or one-ended offset claim would be an
invention. The definition must also stop the concentric phase at
neutral; extending past neutral would outgrow the conditioned prime action and
would require reopening the family contract.

## Family 2: `forearm-supination`

### Contract

- Fixed: isolation, no pattern/direction, `planes: ["transverse"]`.
- Basis action: `forearm.supination`.
- Required prime action:
  `{ "action": "forearm.supination", "condition": "fromPronatedPosition" }`.
- Stability demands: `shoulder`, `scapula`, `elbow`, `forearm`, `wrist`,
  `hand`.
- Allowed equipment: dumbbell; unilateral; dynamic strength; reps; external.
- Muscle requirements and exact roles:
  - `supinator` at `primary`;
  - `bicepsBrachii` at `primary`;
  - `brachioradialis` at `secondary` for its reviewed, conditioned
    return-to-neutral contribution;
  - `extensorCarpiRadialis` at `stabilizer`; and
  - `fingerFlexors`, `externalRotators`, and `trapeziusMiddle` at
    `stabilizer`.
- `allowedByRole` is exact: primary `supinator|bicepsBrachii`; secondary
  `brachioradialis`; stabilizer
  `extensorCarpiRadialis|fingerFlexors|externalRotators|trapeziusMiddle`.

The dual-primary choice is deliberate. Haugstvedt found both biceps and
supinator capable throughout rotation, with biceps torque strongly dependent
on forearm position, and the newer torque-stepped EMG pilot found the supinator
more active at low torque while biceps recruitment rose much more with load.
A universal primary/secondary ordering would therefore imply precision the
evidence does not support. `brachioradialis` is secondary rather than primary:
Bremer and Boland support the conditioned return-to-neutral moment but not an
unconditional supination role or a co-equal training emphasis.

### Axes and initial roster

The exact single-value setup is seated, table-supported, open-chain, elbow
flexed with its angle held, `forearmMotion: supinates`,
`forearmStartOrientation: pronated`, `forearmEndOrientation: neutral`, wrist
held neutral, static implement hold, plate-loaded rotational-dumbbell
resistance, `fixedPath: false` through the axis-level fixed value, and no
lower-body contribution. Single-value axes enforce the setup without an
always-true exercise rule. The movement definition must stop at neutral so the
fixture remains inside `fromPronatedPosition`.

| ID | Name | Load seed | Reps | Priority | Evidence |
|---|---|---:|---:|---:|---|
| `seated-dumbbell-forearm-supination` | Seated Dumbbell Forearm Supination | 5 lb / 2.5 kg | 10 | 80 | Szymanski 2004; Haugstvedt 2001; Murray 1995 |

## Family 3: `wrist-flexion`

### Contract

- Fixed: isolation, no pattern/direction, `planes: ["sagittal"]`.
- Basis and required prime action: `wrist.flexion`.
- Stability demands: `shoulder`, `scapula`, `elbow`, `forearm`, `wrist`,
  `hand`.
- Allowed: barbell, bilateral, dynamic strength, reps, external load.
- Both `flexorCarpiRadialis` and `flexorCarpiUlnaris` are required primary
  movers. `extensorCarpiRadialis` and `extensorCarpiUlnaris` are required
  wrist stabilizers, `fingerFlexors` is required at secondary, and
  `fingerExtensors|brachioradialis|externalRotators|trapeziusMiddle` are
  required stabilizers for the unstrapped hand and proximal setup.
- The exact `allowedByRole` mirrors those assignments: primary
  `flexorCarpiRadialis|flexorCarpiUlnaris`, secondary `fingerFlexors`, and
  stabilizer
  `extensorCarpiRadialis|extensorCarpiUlnaris|fingerExtensors|brachioradialis|
  externalRotators|trapeziusMiddle`. FDS/FDP cross the
  wrist and Forman treats FDS as one of the dynamic wrist flexors, so reducing
  it to a hand-contact stabilizer would be false. Secondary records its wrist
  moment without adding `hand.fingerFlexion`: the reviewed fixture keeps the
  fingers closed statically around the bar rather than opening and closing
  them as the repetition.

Forman's dynamic study found much higher extensor/flexor co-contraction ratios
during flexion than extension, supporting the extensor stabilizer role without
turning extension into an additional prime action.

### Axes and initial roster

The setup is seated and bench-supported, open-chain, elbow angle held in a
flexed posture, forearm held supinated, `forearmMotion: angleHeld`,
`wristMotion: flexes`, static implement hold, centered bar,
`fixedPath: false` through the axis-level fixed value, and no lower-body contribution. It does not author
`wristPosture`, because the wrist
moves rather than holding neutral.

| ID | Name | Load seed | Reps | Priority | Evidence |
|---|---|---:|---:|---:|---|
| `seated-barbell-wrist-curl` | Seated Barbell Wrist Curl | 20 lb / 10 kg | 10 | 88 | Szymanski 2004; Forman 2020; Garland 2018 |

Finger-curl finishes, behind-the-back curls, cable curls, and wrist rollers are
not name variants. They change hand action, support, or alternating mechanics
and remain deferred.

## Family 4: `wrist-extension`

### Contract

- Fixed: isolation, no pattern/direction, `planes: ["sagittal"]`.
- Basis and required prime action: `wrist.extension`.
- Stability demands: `shoulder`, `scapula`, `elbow`, `forearm`, `wrist`,
  `hand`.
- Allowed: barbell, bilateral, dynamic strength, reps, external load.
- Both `extensorCarpiRadialis` and `extensorCarpiUlnaris` are required primary
  movers, and `fingerExtensors` is required at secondary.
  `flexorCarpiRadialis`, `flexorCarpiUlnaris`, and `fingerFlexors` are required
  stabilizers. `brachioradialis|externalRotators|trapeziusMiddle` are also
  required stabilizers for the unstrapped proximal setup. The exact
  `allowedByRole` uses those six stabilizer spellings. EDC crosses
  the wrist and Forman treats it as one of the dynamic wrist extensors, so it
  cannot honestly be capped at stabilizer. Secondary records that contribution
  without adding `hand.fingerExtension`; the fingers do not deliberately open
  as the repetition. The flexors must not be described as extension
  synergists.

### Axes and initial roster

The setup matches wrist flexion except that the forearm is held pronated and
`wristMotion` is `extends`. This exact posture is directly documented in the
reviewed barbell protocol.

| ID | Name | Load seed | Reps | Priority | Evidence |
|---|---|---:|---:|---:|---|
| `seated-barbell-reverse-wrist-curl` | Seated Barbell Reverse Wrist Curl | 10 lb / 5 kg | 10 | 85 | Szymanski 2004; Forman 2020; Garland 2018 |

Reverse curls with dynamic elbow flexion belong to `elbow-flexion`, not this
family. Finger extension against elastic resistance also has a different basis
action and remains outside this contract.

## Family 5: `wrist-radial-deviation`

### Contract

- Fixed: isolation, no pattern/direction, `planes: ["frontal"]`.
- Basis and required prime action: `wrist.radialDeviation`.
- Stability demands: `shoulder`, `scapula`, `elbow`, `forearm`, `wrist`,
  `hand`.
- Allowed: dumbbell, unilateral, dynamic strength, reps, external load.
- `flexorCarpiRadialis` and `extensorCarpiRadialis` are both required primary
  movers. `flexorCarpiUlnaris` and `extensorCarpiUlnaris` are admitted wrist
  stabilizers; `fingerFlexors|brachioradialis|externalRotators|
  trapeziusMiddle` are required stabilizers for the implement and unstrapped
  proximal setup.
- `allowedByRole` is exact: primary
  `flexorCarpiRadialis|extensorCarpiRadialis`; no secondaries; stabilizer
  `flexorCarpiUlnaris|extensorCarpiUlnaris|fingerFlexors|brachioradialis|
  externalRotators|trapeziusMiddle`. The initial record authors all six;
  the two opposing carpal muscles are admitted but not hard family
  requirements.

The dual-primary role follows the independent radial moment arms, not an EMG
ranking. The dynamic robot evidence shows substantial direction- and
phase-dependent co-contraction and does not justify reducing radial deviation
to only the flexor or only the extensor side.

### Axes and initial roster

The exact setup is standing, unsupported, open-chain, elbow extended and held,
forearm held neutral, `wristMotion: radiallyDeviates`, static implement hold,
collar-offset lever resistance, `fixedPath: false` through the axis-level fixed value, and no lower-body
contribution.

| ID | Name | Load seed | Reps | Priority | Evidence |
|---|---|---:|---:|---:|---|
| `standing-dumbbell-wrist-radial-deviation` | Standing Dumbbell Radial Deviation | 5 lb / 2.5 kg | 10 | 75 | Szymanski 2004; Forman 2020; Garland 2018 |

The movement definition must identify the thumb-side endpoint, grip below the
bottom collar, and forward-pointing dumbbell shaft. Hammer curls, forearm
rotation, and the coupled dart-thrower's motion are excluded.

## Family 6: `wrist-ulnar-deviation`

### Contract

- Fixed: isolation, no pattern/direction, `planes: ["frontal"]`.
- Basis and required prime action: `wrist.ulnarDeviation`.
- Stability demands: `shoulder`, `scapula`, `elbow`, `forearm`, `wrist`,
  `hand`.
- Allowed equipment: dumbbell; unilateral; dynamic strength; reps; external
  load.
- `flexorCarpiUlnaris` and `extensorCarpiUlnaris` are required primary movers.
  `flexorCarpiRadialis` and `extensorCarpiRadialis` are admitted wrist
  stabilizers; `fingerFlexors|brachioradialis|externalRotators|
  trapeziusMiddle` are required stabilizers for hand contact and the
  unstrapped proximal setup.
- `allowedByRole` is exact: primary
  `flexorCarpiUlnaris|extensorCarpiUlnaris`; no secondaries; stabilizer
  `flexorCarpiRadialis|extensorCarpiRadialis|fingerFlexors|brachioradialis|
  externalRotators|trapeziusMiddle`. The initial record authors all six;
  the two opposing carpal muscles are admitted but not hard family
  requirements.

Fukunaga directly found a band exercise selectively elevated FCU relative to
the measured FDS and pronator teres. ECU was not measured, so that study cannot
erase its independently established ulnar-deviation moment arm. The study's
fixture held both arms at shoulder height, however, creating bilateral static
shoulder/scapular demands that are absent from the reviewed dumbbell fixture.
It remains role evidence rather than being silently simplified into a one-arm
distal-only band record.

### Axes and initial roster

The exact record is open-chain with an extended held elbow, neutral held forearm,
`wristMotion: ulnarlyDeviates`, static hand contact,
`fixedPath: false` through the axis-level fixed value, and no lower-body contribution. It is standing,
unsupported, and uses
`resistanceGeometry: collarOffsetLever`. Single-value axes pin the fixture without
an always-true exercise rule.

| ID | Name | Load seed | Reps | Priority | Evidence |
|---|---|---:|---:|---:|---|
| `standing-dumbbell-wrist-ulnar-deviation` | Standing Dumbbell Ulnar Deviation | 5 lb / 2.5 kg | 10 | 75 | Szymanski 2004; Forman 2020; Garland 2018 |

## Why generic `grip` remains deferred

The candidate should not be activated merely by renaming `hand.grip`.

| Common label | Mechanical reality | Ownership decision |
|---|---|---|
| Hand-gripper closing / crush repetitions | Dynamic multi-joint finger flexion against a closing implement | Future `finger-flexion-grip` candidate after direct fixture review |
| Static dynamometer squeeze | Isometric assessment, normally not a catalog exercise | Exclude |
| Plate pinch | Thumb opposition/adduction plus finger forces; not represented by the current muscle taxonomy | Defer pending intrinsic/thumb taxonomy |
| Farmer support grip | Isometric hand demand while locomotion/carry is the exercise | Grip remains a stabilizer inside a future carry family |
| Barbell/dumbbell support grip | Isometric hand demand while another joint action is the exercise | Keep `fingerFlexors` as a stabilizer in the owning family |
| Dead hang / hangboard | Isometric finger/hand demand plus a closed-chain shoulder complex and bodyweight load | Separate hanging review; not a crush-grip variant |
| Wrist roller | Alternating wrist motion, implement winding, and repeated hand repositioning | Separate compound/conditioning review |

A future `finger-flexion-grip` contract would likely use
`hand.fingerFlexion` as its sagittal basis action, `fingerFlexors` as primary,
and `extensorCarpiRadialis` as a wrist stabilizer. It also needs an explicit
`handGripper` equipment value rather than hiding the implement under `other`.
It stays deferred until a primary loaded dynamic source establishes the exact
gripper fixture, hand/wrist posture, tracking semantics, and role envelope.
Osawa 2026 now supplies a genuinely dynamic loading task (a 30 kg grip trainer,
3 sets of 30), but it does not report the implement's closure geometry,
forearm/wrist posture, closure endpoint, or per-muscle role panel; its MMG site
is explicitly a composite superficial flexor-pronator signal. It therefore
resolves “does a loaded repeated-grip fixture exist?” but not the fields needed
for a testable family contract. The simultaneous handgrip study remains useful
for wrist-extensor stabilization only. Predeclare the future evidence ID
`osawa-2026-repetitive-grip-mmg` (`10.3390/app16157379`) here, but do not
register an unused source until the family is activation-ready.

## Explicit exclusions and later expansion

| Exercise or setup | Reason it is not in the initial roster |
|---|---|
| Combined pronation/supination repetition | Two opposite concentric emphases cannot belong to both one-action families as one record; author direction-specific exercises. |
| Full-range band pronation | Fukunaga's seated, thigh-supported fixture moves through the entire available pronation range and crosses neutral. It cannot enter the initial `fromSupinatedPosition` contract without replacing its conditioned signature and re-reviewing brachioradialis roles. |
| Bilateral band ulnar deviation | Fukunaga holds both arms at shoulder height with elbows extended. Activation requires explicit shoulder/scapular stability demands and reviewed stabilizers; it is not the unsupported unilateral fixture drafted initially. |
| Unspecified dumbbell rotation | The admitted fixture names Szymanski's plate-loaded dumbbell and its start/end geometry. A conventional fixed dumbbell or a claimed one-ended load needs its own review; the source does not make either equivalent. |
| Hammer/club/mace rotation | Different implement and torque distribution; review before adding equipment vocabulary. |
| Cable pronation/supination | Plausible, but no exercise-specific source reviewed in this gate. |
| Dumbbell wrist curl/reverse wrist curl | Plausible unilateral variants; the initial directly documented roster is barbell and bilateral. |
| Behind-the-back wrist curl | Unsupported shoulder/elbow posture and different excursion boundary. |
| Finger-assisted wrist curl | Adds `hand.fingerFlexion` and therefore crosses into the future hand family. |
| Cable wrist curls | Different resistance geometry and attachment; defer rather than infer from the barbell fixture. |
| Wrist roller | Alternating multi-action task, not one wrist family. |
| Coupled flexion-ulnar or extension-radial “dart throw” | Natural coupling does not make a two-component path a cardinal one-action family. |
| Gyroball | Multidirectional reactive/isometric task with non-comparable resistance. |
| Therapeutic manual resistance | Load cannot be compared and the partner/clinician interface is outside the first roster. |

Li's kinematic study directly shows that wrist flexion/extension and
radial/ulnar deviation can couple, especially extension with radial deviation
and flexion with ulnar deviation. That is a warning against claiming perfectly
isolated biological motion, not permission to add a second prime action to the
strict fixtures. The catalog records the coached dominant action; a future
combined-path family must declare both basis actions and both cardinal planes.

## Evidence registered at activation

Register only sources cited by an activated anatomy profile, family, or
exercise. The proposed stable IDs are:

| Evidence ID | Primary source | DOI / PMID | Load-bearing use and limitation |
|---|---|---|---|
| `haugstvedt-2001-forearm-rotation-moment-forces` | Haugstvedt, Berger & Berglund, “A mechanical study of the moment-forces of the supinators and pronators of the forearm” | `10.1080/000164701317269076`; `11817880` | Cadaveric torque across rotation for biceps, supinator, PT, and both PQ heads; supports capability/position dependence, not exercise EMG. |
| `murray-1995-elbow-forearm-moment-arms` | Murray, Delp & Buchanan, “Variation of muscle moment arms with elbow and forearm position” | `10.1016/0021-9290(94)00114-J`; `7775488` | Position-dependent biceps, brachialis, brachioradialis, PT, and triceps moment arms; two specimens plus model, not a role ranking. |
| `bremer-2006-forearm-rotator-moment-arms` | Bremer et al., “Moment arms of forearm rotators” | `10.1016/j.clinbiomech.2006.03.002`; `16678316` | Load-bearing source for unconditional prime rotators and brachioradialis's direction change around neutral. |
| `boland-2008-brachioradialis-function` | Boland, Spigelman & Uhl, “The function of brachioradialis” | `10.1016/j.jhsa.2008.07.019`; `19084189` | Bounds brachioradialis as a secondary conditioned rotator rather than a full-range prime mover. |
| `gordon-2004-forearm-rotation-emg` | Gordon et al., “Electromyographic activity and strength during maximum isometric pronation and supination efforts in healthy adults” | `10.1016/S0736-0266(03)00115-3`; `14656682` | Fine-wire separation of PT/PQ and supinator/biceps; isometric and not the dumbbell fixture. |
| `szymanski-2004-wrist-forearm-training` | Szymanski et al., “Effect of 12 weeks of wrist and forearm training on high school baseball players” | `10.1519/13703.1`; `15320673` | Direct barbell wrist, plate-loaded rotational-dumbbell, and collar-offset deviation fixtures plus 8–12-rep training; adolescent male program and no exercise EMG. Its plate-squeeze result does not support a generic grip family. |
| `fukunaga-2023-flexor-pronator-exercises` | Fukunaga et al., “Flexor-Pronator Mass Training Exercises Selectively Activate Forearm Musculature” | `10.26603/001c.68073`; `36793573` | Direct band protocols in ten men: seated, thigh-supported full-range pronation and bilateral ulnar deviation with arms held at shoulder height. Used for muscle-role evidence only; neither setup is simplified into the initial roster. PT/FDS/FCU panel only, so absent muscles cannot be ranked as inactive. |
| `garland-2018-wrist-tendon-moment-arms` | Garland, Shah & Kedgley, “Wrist tendon moment arms: Quantification by imaging and experimental techniques” | `10.1016/j.jbiomech.2017.12.024`; `29306550` | FCR, FCU, ECRL/B, ECU, APL moment-arm geometry in ten cadaveric limbs; method differences require categorical rather than numeric use. |
| `nichols-2015-wrist-muscle-moment-arms` | Nichols et al., “Wrist salvage procedures alter moment arms of the primary wrist muscles” | `10.1016/j.clinbiomech.2015.03.015`; `25843482` | Independent confirmation of the five prime carpal motors across both wrist degrees of freedom. |
| `an-1983-index-finger-moment-arms` | An et al., “Tendon excursion and moment arm of index finger muscles” | `10.1016/0021-9290(83)90074-X`; `6619158` | Direct extrinsic finger flexor/extensor actions; foundation support rather than exercise-role ranking. |
| `mirakhorlo-2018-hand-wrist-model` | Mirakhorlo et al., “A musculoskeletal model of the hand and wrist: model definition and evaluation” | `10.1080/10255842.2018.1490952`; `30257101` | Hand-wrist model supporting both finger actions and the wrist moments of extrinsic finger muscles. |
| `ferrer-uris-2023-finger-dead-hangs` | Ferrer-Uris et al., “Exploring forearm muscle coordination and training applications of various grip positions during maximal isometric finger dead-hangs in rock climbers” | `10.7717/peerj.15464`; `37304875` | Loaded FDS/FDP/EDC evidence for the split finger profiles; a closed-chain isometric hang, not a grip-family fixture. |
| `delp-1996-wrist-isometric-moments` | Delp, Grierson & Buchanan, “Maximum isometric moments generated by the wrist muscles in flexion-extension and radial-ulnar deviation” | `10.1016/0021-9290(96)00029-2`; `8884484` | Joint moment envelopes across wrist angles in ten men; supports programming/position bounds, not individual-muscle roles. |
| `forman-2020-dynamic-wrist-flexion-extension` | Forman et al., “Characterizing forearm muscle activity in young adults during dynamic wrist flexion-extension movement using a wrist robot” | `10.1016/j.jbiomech.2020.109908` | Direct dynamic flexion/extension EMG and phase-dependent co-contraction in 12 men; robot handle is not the barbell fixture. |
| `forman-2020-dynamic-wrist-deviation` | Forman et al., “Characterizing forearm muscle activity in university-aged males during dynamic radial-ulnar deviation of the wrist using a wrist robot” | `10.1016/j.jbiomech.2020.109897` | Direct dynamic deviation EMG in 12 men; supports multi-muscle/co-contraction policy, not free-weight equivalence. |
| `forman-2019-handgrip-wrist-force` | Forman et al., “The influence of simultaneous handgrip and wrist force on forearm muscle activity” | `10.1016/j.jelekin.2019.02.004`; `30822679` | Isometric combined grip/wrist forces and persistent wrist-extensor activity; supports stabilizer semantics only, not dynamic grip activation. |
| `li-2005-wrist-motion-coupling` | Li et al., “Coupling between wrist flexion-extension and radial-ulnar deviation” | `10.1016/j.clinbiomech.2004.10.002`; `15621323` | Dynamic kinematic coupling in ten men; defines a boundary warning rather than adding coupled actions to strict records. |

The 2026 four-person forearm-rotation EMG pilot may be registered as
`kondi-2026-forearm-rotation-emg` (`10.7759/cureus.101255`, PMID `41674760`)
only if the dual-primary supination rationale cites it in the activated family.
Its small sample and isometric protocol must be explicit in `scope`; it is
corroboration, not the sole basis for the taxonomy or fixture.

`holzbaur-2005-upper-extremity` already exists and remains useful as a broad
upper-extremity geometry challenge, but it cannot preserve the old aggregate
muscle IDs after the split. Every new muscle profile needs a source that
actually covers its specific action.

## Activation and test gate — completed

Activation is one coordinated migration, not seven independent edits:

1. Replace `biceps` and `forearms` with the eleven exact taxonomy IDs, update
   mesh ownership, unvisualized reasons, validator constants, README count,
   and every active family reference.
2. Replace `hand.grip` with `hand.fingerFlexion` and
   `hand.fingerExtension`; update muscle profiles and action tests.
3. Register only the evidence IDs actually cited by the migrated profiles and
   the six activated families.
4. Document the shared distal axes and the posture-versus-motion distinction.
5. Harden `validate_exercise`: when a family declares a conditioned prime
   action, an exercise must not add the same action without a condition (or
   with a different condition). This prevents a partial-range family from
   silently broadening itself through `additionalPrimeActions` and also
   protects the existing conditioned shoulder-extension families.
6. Add the six family JSON files and six exact exercises. Each family has an
   empty `exerciseRules` array because every initial axis is single-valued. Do
   not add a
   `grip.json` placeholder.
7. Update every existing family that currently uses aggregate `biceps` or
   `forearms` by biomechanical role, not a global string replacement. For
   example, an implement-hold stabilizer normally maps to `fingerFlexors`,
   while an elbow-flexion secondary may require one or more of
   `bicepsBrachii|brachialis|brachioradialis` according to that family's
   reviewed posture.
8. Update exact family/exercise inventory tests in the same change.

The test gate requires:

- exact taxonomy count, mesh ownership, new action set, and zero references to
  retired `biceps|forearms|hand.grip` in validator-loaded sources;
- exact fixed classification, basis action, prime action, forbidden set,
  roles, and roster for all six families;
- every admitted enum/numeric/boolean axis value observed by the roster;
- exact empty `exerciseRules` arrays; setup mutations reject through
  single-value axis constraints rather than invented always-true rules;
- for each family, mutation to every forbidden prime action rejects;
- rotation start/end reversal rejects, held `forearmOrientation` is absent
  from rotation records, and adding the same rotation action unconditioned or
  under a different condition rejects;
- wrist records reject dynamic forearm motion, while rotation records reject
  dynamic wrist motion;
- changing a rotation record's `rotationalPlateLoadedDumbbell` or a deviation
  record's `collarOffsetLever` to `centeredBar` rejects, and swapping the two
  dumbbell mechanisms also rejects;
- demoting either required radial/ulnar or flexion/extension primary mover
  rejects, preserving the two-sided wrist contract;
- in rotation/deviation families, promoting `fingerFlexors` from stabilizer to
  secondary rejects because it cannot produce the declared prime action; in
  `wrist-flexion`, where its anatomy profile truthfully can produce the action,
  demoting it from required secondary to stabilizer rejects by family role
  policy rather than by a false incapability claim;
- positive external seeds require exact metric detents; and
- global catalog ID/name/alias/evidence uniqueness and evidence-use coverage
  remain exact-count guarded.

The grip deferral also needs a negative registry assertion: no real family may
use ID `grip`, no validator-loaded action may use `hand.grip`, and no exercise
may add `hand.fingerFlexion` as an extra prime action inside one of the six
distal families.
