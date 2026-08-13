# Batch 2 — elbow flexion and extension boundary review

Status: integrated review record. `elbow-flexion` and `elbow-extension` are
activated narrowly on the migrated distal upper-body taxonomy. This document
records the evidence and contract decisions behind the validator-loaded family
JSON.

## Outcome

| Candidate | Decision | Initial roster |
|---|---|---:|
| `elbow-flexion` | Activated narrowly | 3 |
| `elbow-extension` | Activated narrowly | 5 |

The two families add eight exercises, not a Cartesian product of every curl or
triceps-extension variation. Their initial rosters are deliberately made from
exercise-specific research fixtures: one three-orientation cable-curl study,
two single-arm cable-extension studies, and one dumbbell-extension study with
two shoulder positions.

The contracts are coupled at their boundary but not at their role policy.
Elbow flexion requires the new biceps-brachii, brachialis, and brachioradialis
regions. Elbow extension retains the existing aggregate `triceps`, because all
three triceps heads extend the elbow and the scene has only one triceps mesh.
Shoulder position can change triceps length, excitation, and adaptation without
turning one aggregate head into a different categorical prime mover.

## Resolved foundation dependency

Neither family could activate against the pre-Batch-2 `biceps` and `forearms`
aggregates. The completed prerequisite is recorded in the sibling
`batch-2-distal-taxonomy.md` decision:

- remove `biceps|forearms`;
- add `bicepsBrachii`, `brachialis`, `brachioradialis`,
  `forearmPronators`, `supinator`, the four reviewed carpal regions,
  `fingerFlexors`, and `fingerExtensors`;
- replace `hand.grip` with `hand.fingerFlexion|hand.fingerExtension`;
- migrate all active-family references deliberately; and
- lock the resulting 41-muscle, 44-action, 62-mesh-base foundation before any
  elbow records are validator input.

`elbow-flexion` was impossible to express truthfully before that migration:
the former `biceps` region gave the brachialis mesh biceps-brachii-only
shoulder-flexion and supination capabilities, while the former `forearms`
region hid brachioradialis among wrist and finger muscles.

`elbow-extension` could have used `triceps` before the migration, but it landed
afterward as well. Its static implement hold names `fingerFlexors`, not the
retired `forearms` aggregate. Activating the families together also kept the
shared distal axes and forbidden-action template atomic.

## Shared elbow vocabulary

Activation added these spellings to `families/README.md` beside the
distal-family vocabulary. A posture axis never creates a prime action.

| Axis | Values used here | Meaning |
|---|---|---|
| `kineticChain` | `open` | The loaded hand moves rather than remaining fixed to the environment. |
| `bodyPosition` | `standing\|seated\|supine` | Gross reviewed body position. |
| `torsoSupport` | `none\|bench` | External surface directly supporting the torso. A seat alone is not torso support. |
| `scapularTranslation` | `free\|supportConstrained` | Whether posterior support limits scapular translation; it does not name a dynamic scapular action. |
| `forearmSupport` | `none` | No surface supports the forearm in these initial fixtures. The shared distal axis also admits `thigh\|bench\|table\|machinePad` only in families that review them. |
| `upperArmPosition` | `atSide\|flexed90\|overhead` | Torso-relative upper-arm posture held during elbow motion: anatomical side (0 degrees shoulder flexion), 90 degrees sagittal flexion, or overhead (180 degrees). It is not dynamic shoulder flexion. |
| `elbowMotion` | `flexes\|extends` | The family-defining dynamic elbow motion. |
| `forearmMotion` | `angleHeld` | No deliberate radioulnar rotation creates the repetition. |
| `forearmOrientation` | `supinated\|neutral\|pronated` | Radioulnar posture held during elbow motion, independent of implement wording. |
| `wristMotion` | `angleHeld` | Wrist angle does not deliberately create the repetition. |
| `wristPosture` | `neutral` | Reviewed authoring target for the held wrist, not a claim of zero measurement error. |
| `handTask` | `staticImplementHold` | The fingers hold the attachment or dumbbell without dynamic finger closing as the repetition. |
| `handleType` | `straightBar\|rope\|singleCableHandle\|unreportedCableInterface\|dumbbellHandle` | The load-to-hand interface. `unreportedCableInterface` preserves Maeo's missing attachment detail rather than manufacturing a handle from the exercise name. |
| `resistanceGeometry` | `lowCableCurl\|highCablePushdown\|overheadCableExtension\|gravityLoadedDumbbell` | The reviewed way cable tension or gravity opposes the elbow action. It records load geometry, not a guided implement path. `overheadCableExtension` identifies Maeo's 180-degree cable task but is deliberately anchor-agnostic because pulley height and cable angle were not reported. |
| `fixedPath` | boolean, `fixedValue: false` | Existing meaning: rails or a lever machine constrain the external load path. Cable direction is not a fixed path; the axis-level fixed value rejects `true` on every initial elbow record. |
| `lowerBodyContribution` | `none` | Hip, knee, or ankle drive does not create the repetition. |

`upperArmPosition` is categorical on purpose. A single numeric 0-to-180-degree
axis would make every intermediate angle valid even though only 0, 90, and 180
degrees are reviewed here. Future preacher, Bayesian, incline, or kickback
fixtures can extend the enum with an explicitly defined posture instead of
silently entering through a numeric range.

Do not use `gripOrientation` for these records. The reviewed variable is the
forearm's radioulnar posture. Likewise, `forearmOrientation: supinated` plus
`forearmMotion: angleHeld` does not declare `forearm.supination`; a rotating
dumbbell curl remains outside the contract.

## Common action boundary

Both active family files use the same exact template as the sibling distal
proposal after the joint-action migration:

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
hip.flexion, hip.extension, hip.abduction, hip.adduction,
hip.internalRotation, hip.externalRotation,
knee.flexion, knee.extension,
ankle.plantarflexion, ankle.dorsiflexion, ankle.inversion, ankle.eversion,
foot.toeFlexion, foot.toeExtension
```

`elbow-flexion` removes only `elbow.flexion`; `elbow-extension` removes only
`elbow.extension`. A static posture, stabilization demand, or muscle capability
does not remove another action from the forbidden list.

This explicit boundary is intentionally stricter than relying on the admitted
muscle list to reject neighboring movements by accident. It prevents a future
role expansion from silently converting a curl into a row, a triceps extension
into a press, or either family into a wrist/forearm exercise.

## Family 1: `elbow-flexion`

### Fixed contract

- Name: `Elbow Flexion`.
- Definition: a strict open-chain isolation movement in which the elbow flexes
  while the upper arm remains at the side, forearm orientation and neutral
  wrist are held, and the torso, scapulae, and lower body do not create the
  repetition.
- Fixed classification: `mechanic: isolation`, `pattern: null`,
  `direction: null`, `planes: [sagittal]`.
- Plane basis and sole required prime action: `elbow.flexion`.
- Group policy: default and allowed `arms` only.
- Allowed: cable equipment, dynamic strength, reps, external load, bilateral
  laterality.
- Stability demands: `shoulder`, `scapula`, `elbow`, `forearm`, `wrist`,
  `hand`, `spine`, and `pelvis`.
- Recommended default reps: 8 through 15.
- Exact family evidence refs: `holzbaur-2005-upper-extremity`,
  `murray-1995-elbow-forearm-moment-arms`,
  `coratella-2023-curl-handgrips`, and
  `kleiber-2015-elbow-flexion-hand-position`.

The shoulder/scapula/trunk demands are family-level because the initial family
is intentionally the strict standing cable-curl fixture. A future supported or
seated expansion must re-review that universal setup instead of adding one
record under constraints that no longer describe the family.

### Muscle policy

The active contract uses the following exact categorical envelope:

```json
{
  "requirements": [
    { "anyOf": ["brachialis"], "minimumRole": "primary" },
    { "anyOf": ["bicepsBrachii"], "minimumRole": "secondary" },
    { "anyOf": ["brachioradialis"], "minimumRole": "secondary" },
    { "anyOf": ["deltoidAnterior"], "minimumRole": "stabilizer" },
    { "anyOf": ["trapeziusMiddle"], "minimumRole": "stabilizer" },
    { "anyOf": ["fingerFlexors"], "minimumRole": "stabilizer" },
    { "anyOf": ["extensorCarpiRadialis"], "minimumRole": "stabilizer" },
    { "anyOf": ["obliques"], "minimumRole": "stabilizer" }
  ],
  "allowedByRole": {
    "primary": ["brachialis", "bicepsBrachii"],
    "secondary": ["bicepsBrachii", "brachioradialis"],
    "stabilizer": [
      "deltoidAnterior",
      "trapeziusMiddle",
      "fingerFlexors",
      "extensorCarpiRadialis",
      "obliques"
    ]
  }
}
```

Role decisions:

- `brachialis` is primary in all three records. It is the orientation-neutral,
  pure elbow-flexor baseline. This is an anatomy/capability judgment grounded
  by Murray and Holzbaur, not a claim that Coratella measured brachialis; that
  exercise study did not.
- `bicepsBrachii` is primary in the supinated curl and secondary in the neutral
  and pronated curls. Murray directly shows its larger flexion moment arm in
  supination, and Coratella found greater ascending-phase biceps excitation in
  the supinated condition than in either neutral or pronated conditions; the
  study did not establish a neutral-versus-pronated ordering.
- `brachioradialis` remains secondary in all three initial records. Kleiber
  found significantly greater activity in pronation than in neutral or
  supination during slow controlled elbow flexion, while Coratella's loaded
  cable curls found the opposite ordering (supinated greater than neutral and
  pronated). Those tasks differ materially. Promoting brachioradialis to
  primary for one grip would pretend that conflict is settled.
- Anterior deltoid and middle trapezius hold the reviewed no-humeral-flexion,
  no-exaggerated-scapular-elevation setup; they are stabilizers, not hidden
  shoulder/scapular prime actions. `fingerFlexors` represents the static
  implement hold, while `extensorCarpiRadialis` supplies the explicit
  counter-control needed to hold a neutral wrist against the finger flexors'
  wrist-flexion moment. Obliques satisfy strict standing spine/pelvis control.
- Triceps antagonist activity, separate carpal stabilizers, pronators, and
  supinator are not admitted without exercise-specific need. The role list is
  useful, not an attempt to enumerate every nonzero EMG signal.

### Variant axes and encoded rules

All three records author:

```text
kineticChain: open
bodyPosition: standing
torsoSupport: none
scapularTranslation: free
forearmSupport: none
upperArmPosition: atSide
elbowMotion: flexes
forearmMotion: angleHeld
wristMotion: angleHeld
wristPosture: neutral
handTask: staticImplementHold
resistanceGeometry: lowCableCurl
fixedPath: false (axis fixedValue: false)
lowerBodyContribution: none
```

`forearmOrientation` admits `supinated|neutral|pronated`; `handleType` admits
`straightBar|rope`. No relative-grip-width value is authored: Coratella held
inter-hand distance consistent but did not establish a catalog category.
Every listed axis is required.

The active contract encodes these four exact rule IDs. Every rule uses empty `requirePresent` and
`requireAbsent` arrays; fields are already required axes.

| Rule ID | Predicate | Assertions / required involvement |
|---|---|---|
| `rope-curl-requires-neutral-forearm` | `variant.handleType == rope` | `variant.forearmOrientation = neutral` |
| `neutral-curl-requires-rope` | `variant.forearmOrientation == neutral` | `variant.handleType = rope` |
| `supinated-curl-promotes-biceps-brachii` | `variant.forearmOrientation == supinated` | require `bicepsBrachii: primary` |
| `non-supinated-curl-keeps-biceps-brachii-secondary` | `variant.forearmOrientation != supinated` | require `bicepsBrachii: secondary` |

The two handle rules are deliberately bidirectional. They reject both a rope
authored as pronated/supinated and a neutral straight-bar record. Supinated and
pronated remain the two reviewed straight-bar orientations.

### Exact initial roster

`P`, `S`, and `St` below mean primary, secondary, and stabilizer. Every record
uses `additionalPrimeActions: []` and `additionalStabilityDemands: []`.

| Catalog ID | Name and aliases | Orientation / handle | Seed | Roles | Evidence |
|---|---|---|---:|---|---|
| `supinated-straight-bar-cable-curl` | **Supinated Straight-Bar Cable Curl**; `Straight-Bar Cable Curl`, `Cable Biceps Curl` | `supinated`; `straightBar` | 30 lb / 15 kg; 10 reps | brachialis P, bicepsBrachii P, brachioradialis S, deltoidAnterior St, trapeziusMiddle St, fingerFlexors St, extensorCarpiRadialis St, obliques St | Coratella 2023 |
| `neutral-rope-cable-curl` | **Neutral-Grip Rope Cable Curl**; `Cable Rope Hammer Curl`, `Rope Hammer Curl` | `neutral`; `rope` | 30 lb / 15 kg; 10 reps | brachialis P, bicepsBrachii S, brachioradialis S, deltoidAnterior St, trapeziusMiddle St, fingerFlexors St, extensorCarpiRadialis St, obliques St | Coratella 2023; Kleiber 2015 limitation context |
| `pronated-straight-bar-cable-curl` | **Pronated Straight-Bar Cable Curl**; `Reverse-Grip Cable Curl`, `Cable Reverse Curl` | `pronated`; `straightBar` | 20 lb / 10 kg; 10 reps | brachialis P, bicepsBrachii S, brachioradialis S, deltoidAnterior St, trapeziusMiddle St, fingerFlexors St, extensorCarpiRadialis St, obliques St | Coratella 2023; Kleiber 2015 limitation context |

Suggested search priorities are 90, 85, and 75 in table order. Seed weights are
product defaults on clean imperial/metric scrubber detents; they are not the
study participants' 8-RM loads. Every record uses `loadMode: external` and
`bodyweightFraction: 0.0`. The supinated exercise cites only
`coratella-2023-curl-handgrips`; the neutral and pronated records cite both
`coratella-2023-curl-handgrips` and
`kleiber-2015-elbow-flexion-hand-position` so the conflicting task context
remains attached to the affected fixtures.

Use these movement definitions verbatim unless copy review changes wording
without changing mechanics:

- **Supinated Straight-Bar Cable Curl:** “Stand facing a low cable while
  holding a straight bar with both forearms supinated. Keep the upper arms
  parallel to the torso, wrists neutral, and body still; flex the elbows
  through the available range, then lower the bar under control without
  rotating the forearms.”
- **Neutral-Grip Rope Cable Curl:** “Stand facing a low cable while holding the
  rope ends with both forearms neutral. Keep the upper arms parallel to the
  torso, wrists neutral, and body still; flex the elbows through the available
  range, then return under control without rotating the forearms.”
- **Pronated Straight-Bar Cable Curl:** “Stand facing a low cable while holding
  a straight bar with both forearms pronated. Keep the upper arms parallel to
  the torso, wrists neutral, and body still; flex the elbows through the
  available range, then lower the bar under control without rotating the
  forearms.”

## Family 2: `elbow-extension`

### Fixed contract

- Name: `Elbow Extension`.
- Definition: a strict open-chain isolation movement in which the elbow extends
  while a reviewed upper-arm and forearm posture is held and shoulder, wrist,
  torso, and lower-body motion do not create the repetition.
- Fixed classification: `mechanic: isolation`, `pattern: null`,
  `direction: null`, `planes: [sagittal]`.
- Plane basis and sole required prime action: `elbow.extension`.
- Group policy: default and allowed `arms` only.
- Allowed: cable or dumbbell equipment, dynamic strength, reps, external load,
  unilateral laterality.
- Family-level stability demands: `shoulder`, `scapula`, `elbow`, `forearm`,
  `wrist`, and `hand`.
- Recommended default reps: 8 through 20.
- Exact family evidence refs: `holzbaur-2005-upper-extremity`,
  `alves-2018-triceps-shoulder-position`,
  `maeo-2023-overhead-neutral-elbow-extension`, and
  `villalba-2024-pushdown-forearm-position`.

Standing and unsupported seated records add `spine|pelvis` as exercise-level
stability demands. The supine record does not inherit that demand merely to
make its roster look symmetrical.

### Muscle policy

The active contract uses this exact envelope:

```json
{
  "requirements": [
    { "anyOf": ["triceps"], "minimumRole": "primary" },
    { "anyOf": ["fingerFlexors"], "minimumRole": "stabilizer" },
    { "anyOf": ["extensorCarpiRadialis"], "minimumRole": "stabilizer" },
    { "anyOf": ["brachioradialis"], "minimumRole": "stabilizer" },
    { "anyOf": ["externalRotators"], "minimumRole": "stabilizer" },
    {
      "anyOf": ["trapeziusMiddle", "trapeziusLower"],
      "minimumRole": "stabilizer"
    }
  ],
  "allowedByRole": {
    "primary": ["triceps"],
    "secondary": [],
    "stabilizer": [
      "brachioradialis",
      "fingerFlexors",
      "flexorCarpiRadialis",
      "extensorCarpiRadialis",
      "externalRotators",
      "trapeziusMiddle",
      "trapeziusLower",
      "obliques"
    ]
  }
}
```

`triceps` is the sole primary on every record and there is no admitted
secondary. Alves measured long and lateral heads, Maeo imaged the long and
combined lateral/medial regions, and Villalba measured long and lateral heads;
none justifies pretending the one aggregate `triceps` mesh has per-head roles.
The shoulder-position sources justify variants and disclose length/adaptation
differences, not different categorical prime movers.

`fingerFlexors` supplies the universal static hand hold;
`extensorCarpiRadialis` supplies universal neutral-wrist counter-control;
`brachioradialis` supplies explicit control of the held radioulnar posture; and
`externalRotators` stabilizes the held humerus. Brachioradialis is not an
elbow-extension mover here: this is a bounded anatomy/mechanics assignment,
not a result measured by the triceps studies. Overhead positions use lower
trapezius for the elevated scapular posture; at-side and bench-supported
positions use middle trapezius. These scapular assignments are mechanics-based
applications of the independent capability map, not muscles measured in the
triceps trials.

Villalba directly observed greater radial wrist-flexor excitation with the
pronated handle and greater radial wrist-extensor excitation with the supinated
handle. The exact two pushdown records therefore add
`flexorCarpiRadialis` and `extensorCarpiRadialis`, respectively, as wrist
stabilizers. Do not copy that orientation result to the overhead cable or
dumbbell fixtures: handle geometry, arm position, and loading were not the
same. Those records retain the narrower static-hold assignment.

### Exact axis roster

Every record uses `kineticChain: open`, `forearmSupport: none`,
`elbowMotion: extends`, `forearmMotion: angleHeld`,
`wristMotion: angleHeld`, `wristPosture: neutral`,
`handTask: staticImplementHold`, `fixedPath: false` through the boolean axis's
`fixedValue: false`, and
`lowerBodyContribution: none`.
All listed axes and the tabled setup axes are required.

| Catalog ID | Body position | Torso support | Scapular translation | Upper arm | Forearm orientation | Handle | Resistance geometry |
|---|---|---|---|---|---|---|---|
| `single-arm-supinated-cable-triceps-pushdown` | standing | none | free | atSide | supinated | singleCableHandle | highCablePushdown |
| `single-arm-pronated-cable-triceps-pushdown` | standing | none | free | atSide | pronated | singleCableHandle | highCablePushdown |
| `single-arm-overhead-cable-triceps-extension` | standing | none | free | overhead | supinated | unreportedCableInterface | overheadCableExtension |
| `seated-single-arm-overhead-dumbbell-triceps-extension` | seated | none | free | overhead | neutral | dumbbellHandle | gravityLoadedDumbbell |
| `single-arm-lying-dumbbell-triceps-extension` | supine | bench | supportConstrained | flexed90 | neutral | dumbbellHandle | gravityLoadedDumbbell |

The unsupported classification for Alves's seated overhead fixture is an
interpretation of the described/illustrated setup, not a tested backrest
contrast. Likewise, `scapularTranslation` records the external support geometry
rather than a measured scapular trajectory. Those are bounded mechanics
inferences and must remain disclosed in the family definition.

### Encoded rules

The active contract encodes these eleven exact rule IDs. `requirePresent` and `requireAbsent` are empty
on every rule because all referenced axes are required.

| Rule ID | Predicate | Assertions / requirements |
|---|---|---|
| `cable-extension-uses-reviewed-cable-interface` | `equipment == cable` | handleType in `singleCableHandle\|unreportedCableInterface`; resistanceGeometry in `highCablePushdown\|overheadCableExtension` |
| `dumbbell-extension-uses-dumbbell-handle` | `equipment == dumbbell` | handleType dumbbellHandle; resistanceGeometry gravityLoadedDumbbell |
| `standing-extension-uses-reviewed-cable-setups` | `variant.bodyPosition == standing` | equipment cable; torsoSupport none; scapularTranslation free; upperArmPosition in `atSide\|overhead`; forearmOrientation in `supinated\|pronated` |
| `seated-extension-is-unsupported-overhead-dumbbell` | `variant.bodyPosition == seated` | equipment dumbbell; torsoSupport none; scapularTranslation free; upperArmPosition overhead; forearmOrientation neutral |
| `supine-extension-is-supported-flexed90-dumbbell` | `variant.bodyPosition == supine` | equipment dumbbell; torsoSupport bench; scapularTranslation supportConstrained; upperArmPosition flexed90; forearmOrientation neutral |
| `pronated-extension-is-at-side-pushdown` | `variant.forearmOrientation == pronated` | bodyPosition standing; equipment cable; upperArmPosition atSide |
| `overhead-extension-uses-lower-trapezius-stability` | `variant.upperArmPosition == overhead` | resistanceGeometry in `overheadCableExtension\|gravityLoadedDumbbell`; require `trapeziusLower: stabilizer` |
| `at-side-extension-uses-high-cable-resistance` | `variant.upperArmPosition == atSide` | resistanceGeometry highCablePushdown; handleType singleCableHandle |
| `overhead-cable-preserves-unreported-interface` | `variant.resistanceGeometry == overheadCableExtension` | equipment cable; upperArmPosition overhead; handleType unreportedCableInterface |
| `non-overhead-extension-uses-middle-trapezius-stability` | `variant.upperArmPosition != overhead` | require `trapeziusMiddle: stabilizer` |
| `unsupported-extension-requires-trunk-control` | `variant.bodyPosition != supine` | require `obliques: stabilizer`; require additional stability demands `spine|pelvis` |

The equipment, arm-position, and setup rules jointly close the admitted
resistance-geometry cross-product as well as the posture combinations. In particular, the
standing rule alone would allow a pronated overhead extension; rule 6 makes the
pronated value exclusive to the directly reviewed at-side pushdown. The
supinated value remains valid for the at-side and overhead cable records, while
neutral remains the dumbbell posture.

### Exact initial roster

Every record uses `additionalPrimeActions: []`.

| Catalog ID | Name and aliases | Seed | Exact involvement | Added stability | Evidence |
|---|---|---:|---|---|---|
| `single-arm-supinated-cable-triceps-pushdown` | **Single-Arm Supinated Cable Triceps Pushdown**; `Underhand Cable Triceps Pushdown`, `Reverse-Grip Cable Triceps Pushdown` | 15 lb / 7.5 kg; 10 reps | triceps P; brachioradialis, fingerFlexors, extensorCarpiRadialis, externalRotators, trapeziusMiddle, obliques St | spine, pelvis | Villalba 2024; Maeo 2023 |
| `single-arm-pronated-cable-triceps-pushdown` | **Single-Arm Pronated Cable Triceps Pushdown**; `Overhand Cable Triceps Pushdown`, `One-Arm Pronated Cable Triceps Pushdown` | 15 lb / 7.5 kg; 10 reps | triceps P; brachioradialis, fingerFlexors, extensorCarpiRadialis, flexorCarpiRadialis, externalRotators, trapeziusMiddle, obliques St | spine, pelvis | Villalba 2024 |
| `single-arm-overhead-cable-triceps-extension` | **Single-Arm Overhead Cable Triceps Extension**; `One-Arm Overhead Cable Triceps Extension`, `Single-Arm Cable Overhead Triceps Extension` | 10 lb / 5 kg; 10 reps | triceps P; brachioradialis, fingerFlexors, extensorCarpiRadialis, externalRotators, trapeziusLower, obliques St | spine, pelvis | Maeo 2023 |
| `seated-single-arm-overhead-dumbbell-triceps-extension` | **Seated Single-Arm Overhead Dumbbell Triceps Extension**; `Seated One-Arm Dumbbell Triceps Extension`, `One-Arm Overhead Dumbbell Triceps Extension` | 10 lb / 5 kg; 10 reps | triceps P; brachioradialis, fingerFlexors, extensorCarpiRadialis, externalRotators, trapeziusLower, obliques St | spine, pelvis | Alves 2018 |
| `single-arm-lying-dumbbell-triceps-extension` | **Single-Arm Lying Dumbbell Triceps Extension**; `One-Arm Lying Dumbbell Triceps Extension`, `Single-Arm Dumbbell Skull Crusher` | 10 lb / 5 kg; 10 reps | triceps P; brachioradialis, fingerFlexors, extensorCarpiRadialis, externalRotators, trapeziusMiddle St | none | Alves 2018 |

Suggested search priorities are 85, 75, 80, 80, and 75 in table order. Again,
seeds are product defaults, not reconstructed experimental loads. Every record
uses `loadMode: external` and `bodyweightFraction: 0.0`. Exercise evidence refs
are the exact IDs represented by the final table column: the supinated
pushdown cites Villalba and Maeo, the pronated pushdown cites Villalba, the
overhead cable record cites Maeo, and both dumbbell records cite Alves.

Use these movement definitions:

- **Single-Arm Supinated Cable Triceps Pushdown:** “Stand at a high cable and
  hold a single handle with the working forearm supinated. Keep the upper arm
  alongside the torso and the wrist neutral; extend the elbow from about 90
  degrees to straight, then return under control without moving the shoulder
  or rotating the forearm.”
- **Single-Arm Pronated Cable Triceps Pushdown:** “Stand at a high cable and
  hold a single handle with the working forearm pronated. Keep the upper arm
  alongside the torso and the wrist neutral; extend the elbow from about 90
  degrees to straight, then return under control without moving the shoulder
  or rotating the forearm.”
- **Single-Arm Overhead Cable Triceps Extension:** “Stand with one arm held
  overhead and the forearm supinated while a cable opposes elbow extension.
  Keep the upper arm, wrist, torso, and lower body still; extend the elbow from
  about 90 degrees to straight, then return under control.”
- **Seated Single-Arm Overhead Dumbbell Triceps Extension:** “Sit upright
  without back support and hold one dumbbell with a neutral forearm and the
  upper arm overhead. Keep the upper arm and torso still; flex the elbow to
  lower the dumbbell, then extend through the available range without rotating
  the forearm.”
- **Single-Arm Lying Dumbbell Triceps Extension:** “Lie supine on a bench with
  one neutral-grip dumbbell held over the chest and the upper arm at 90 degrees
  of shoulder flexion. Hold the upper arm still, lower the dumbbell by flexing
  the elbow, then extend the elbow through the available range.”

## Neighboring-family boundaries

| Candidate movement | Why it is outside these initial contracts | Owner / unlock |
|---|---|---|
| Row or pulldown | Adds shoulder extension/adduction and reviewed scapular actions to elbow flexion. | Existing compound row or vertical-pull family. |
| Upright row | Adds shoulder abduction and unresolved scapular behavior to elbow flexion. | Deferred `upright-row` review. |
| Cheat curl / clean curl | Trunk or lower-body motion creates the repetition. | Not admitted by strict elbow flexion. |
| Rotating dumbbell curl | Dynamically supinates while flexing the elbow; held orientation cannot encode it. | Future combined-action review, not a silent curl variant. |
| Preacher, incline, Bayesian, concentration, machine, barbell, EZ-bar, and ordinary dumbbell curls | Require reviewed support, upper-arm posture, equipment, semisupinated geometry, or path axes not present in the initial direct fixture. | Potential future `elbow-flexion` expansion. |
| Press or close-grip press | Adds shoulder flexion or horizontal adduction and is compound. | Existing press family or a reviewed emphasis variant. |
| Dip | Adds shoulder extension/scapular depression and closed-chain loading. | Not elbow-extension isolation. |
| Bodyweight triceps extension | Closed-chain loading and whole-body geometry are absent here. | Future contract or reviewed elbow-extension expansion. |
| Triceps kickback | Holds the upper arm behind the torso and therefore needs a reviewed new `upperArmPosition` value. | Potential future `elbow-extension` expansion. |
| JM press / rolling extension | Material shoulder motion or press-like load path breaks the strict held-upper-arm signature. | Separate combined-action review. |
| Shoulder-extension isolation | Holds the elbow angle while the shoulder extends; elbow extension does the opposite. | Existing `shoulder-extension-isolation`. |
| Wrist curl, reverse wrist curl, pronation, or supination drill | Makes a distal joint action the repetition rather than holding posture. | Sibling distal families. |

An overhead upper-arm posture is not a shoulder-flexion repetition. Conversely,
the long head of the aggregate triceps being capable of shoulder extension does
not add `shoulder.extension` to an elbow-extension exercise. Prime actions come
from the reviewed movement signature, not from every capability of every
assigned muscle.

## Evidence interpretation and adversarial findings

The direct evidence is strong enough for these narrow fixtures, but it does not
support several tempting overclaims:

1. **Brachialis was not measured in the direct curl study.** Its universal
   primary role is the explicit anatomy-based contract decision, not an EMG
   result. Keep that disclosure in the family definition.
2. **Brachioradialis grip findings conflict.** Kleiber's controlled 20-degree-
   per-second flexions favored pronation; Coratella's 8-RM cable fixture favored
   supination. Keeping it secondary across the first roster is deliberate, not
   an omission.
3. **Coratella studied ten competitive male bodybuilders and six nonfailure
   repetitions at an 8-RM load.** It directly anchors technique and relative
   excitation for that fixture; it does not establish population-wide numeric
   muscle contribution or hypertrophy.
4. **Villalba used maximum repetitions at the same absolute load, selected from
   the supinated-handle 1RM.** Forearm position and attachment altered
   repetitions and external mechanics. Use it to admit the two handle variants
   and their directly observed carpal stabilization, not to rank long-term
   triceps training value.
5. **Maeo is a training study, not an exercise-role decomposition.** It directly
   compares unilateral standing cable extension at 0 versus 180 degrees of
   shoulder flexion with a supinated wrist and fixed elbow range. It supports
   both cable fixtures and the relevance of posture, but not separate app
   roles for triceps heads. It does not report pulley height, anchor setting,
   cable angle, or attachment, so `overheadCableExtension` must remain an
   anchor-agnostic task label; Villalba alone grounds the high-pulley pushdown.
6. **Alves tested one to two slow maximal repetitions at 40% MVIC and measured
   only long and lateral heads.** It directly anchors the seated-overhead and
   supine-90-degree dumbbell setups, not product seed weights, the medial head,
   or a hypertrophy hierarchy.
7. **Support and scapular axes are bounded mechanics inferences.** They were not
   experimental variables in Alves. If full-text figure review contradicts
   the unsupported seated spelling, activation must stop and correct the
   fixture rather than preserve the proposal.
8. **No triceps-head split is warranted.** The family-defining action is shared
   by all heads, the scene has one triceps mesh, and the product is not claiming
   head-specific visualization. Revisit only when a future contract needs a
   head-specific action or display.
9. **Held forearm control is mechanics-derived.** The triceps studies do not
   measure brachioradialis as a radioulnar stabilizer. Its stabilizer-only role
   follows the reviewed anatomy profile and closes the explicit `forearm`
   stability demand; it must not be described as producing elbow extension.

## Evidence registered at activation

`holzbaur-2005-upper-extremity` already exists, and
`murray-1995-elbow-forearm-moment-arms` is predeclared by the taxonomy
foundation. Register exactly these five additional IDs; all must be cited by a
family or exercise so evidence-coverage validation remains meaningful.

| Evidence ID | Type | Source / identifiers | Exact load-bearing scope |
|---|---|---|---|
| `coratella-2023-curl-handgrips` | `experimentalKineticsEMGStudy` | Coratella et al., “Biceps Brachii and Brachioradialis Excitation in Biceps Curl Exercise: Different Handgrips, Different Synergy”; DOI `10.3390/sports11030064`; PMID `36976950` | Ten competitive male bodybuilders performing strict bilateral standing cable curls: straight bar for supinated/pronated and rope for neutral, six nonfailure reps at 8-RM. Direct fixture and relative biceps/brachioradialis excitation; brachialis unmeasured, EMG not contribution or hypertrophy. |
| `kleiber-2015-elbow-flexion-hand-position` | `experimentalKinematicsEMGStudy` | Kleiber, Kunz & Disselhorst-Klug, “Muscular coordination of biceps brachii and brachioradialis in elbow flexion with respect to hand position”; DOI `10.3389/fphys.2015.00215`; PMID `26300781` | Sixteen participants performing repeated controlled elbow flexion at 20 degrees/second in three forearm positions. Pronated brachioradialis result bounds role policy; loading/task differs from heavy cable curls and conflicts with Coratella's orientation order. |
| `alves-2018-triceps-shoulder-position` | `experimentalKineticsEMGStudy` | Alves, Matta & Oliveira, “Effect of shoulder position on triceps brachii heads activity in dumbbell elbow extension exercises”; DOI `10.23736/S0022-4707.17.06849-9`; PMID `28677940` | Twenty-one trained men performing unilateral seated overhead (shoulder 180 degrees) and supine lying (shoulder 90 degrees) dumbbell extensions at 40% MVIC for one to two slow maximal reps. Direct fixtures; long/lateral heads only, not seed weights or hypertrophy. |
| `maeo-2023-overhead-neutral-elbow-extension` | `experimentalTrainingStudy` | Maeo et al., “Triceps brachii hypertrophy is substantially greater after elbow extension training performed in the overhead versus neutral arm position”; DOI `10.1080/17461391.2022.2100279`; PMID `35819335` | Twenty-one adults, 12 weeks of unilateral standing cable elbow extension with shoulder fixed at 180 versus 0 degrees, elbow 90 to 0 degrees, wrist supinated. Issue year 2023, published online 2022; posture/fixture and aggregate adaptation, not categorical head roles or other grips. Attachment, pulley height, anchor, and cable angle are unreported and stay unreported in the exercise record. |
| `villalba-2024-pushdown-forearm-position` | `experimentalKineticsEMGStudy` | Villalba, Fujita, Iossi Junior & Gomes, “Forearm Position Influences Triceps Brachii Activation During Triceps Push-Down Exercise”; DOI `10.47206/ijsc.v4i1.250`; no PMID | Twenty-two adults performing single-arm pronated/supinated pushdowns with handle or padded strap. Direct handle variants and FCR/ECR stabilization; same-absolute-load/max-repetition design and attachment lever changes limit triceps ranking, with no longitudinal outcome. |

Canonical registry URLs remain `https://doi.org/{doi}`. Use issue year 2023 for
Maeo and preserve the online-2022 split in `scope`, matching the established
issue/online disclosure precedent.

Marcolin's barbell/EZ-bar/dumbbell comparison (DOI
`10.7717/peerj.5165`) and Attarieh's preacher-versus-Bayesian training study
(DOI `10.1002/ejsc.12279`) were reviewed for future expansion. Do not register
or cite them now: their fixtures are deliberately outside the initial roster,
and unused evidence fails validation. Oliveira's standing/incline/preacher
study has no DOI in its PubMed record and is not needed to activate these
families.

## Activation and test gates — completed

1. Complete every atomic foundation gate in
   `batch-2-distal-taxonomy.md`; no removed `biceps|forearms|hand.grip` value
   may survive in active family JSON, exercises, debug fixtures, or Swift
   mappings.
2. Add the shared axes and exact posture-versus-motion distinctions above to
   `families/README.md`. Keep `upperArmPosition` categorical and
   `forearmOrientation` separate from `gripOrientation`.
3. Register the five exact evidence IDs with the limitation scopes above.
   Verify global ID/DOI uniqueness and that every new source is used.
4. Activate exactly two family JSON files and the exact 3+5 roster. The elbow
   portion changes active totals by +2 families and +8 exercises; global Batch
   2 count assertions must include the sibling distal activation rather than
   hard-code an elbow-only total.
5. Add exact family-identity, classification, movement-signature, muscle-role,
   variant, seed, name, alias, evidence, movement-definition, and roster tests.
   The tests must reject extra as well as missing involvement assignments.
6. Cover every admitted enum value. Copy a typed-axis coverage test that
   branches for boolean `fixedPath`; assert `fixedValue: false` and mutate every
   elbow record to `true` to prove the family contract—not a roster snapshot—
   rejects guided paths.
7. Assert that every JSON rule has at least one matching and one contrasting
   record. Create one rejecting mutation per **assertion**, not merely one per
   rule: the standing/seated/supine extension rules each encode several
   independent consequences.
8. Add role mutations proving the supinated curl requires biceps brachii
   primary, both non-supinated curls require it secondary, brachialis remains
   primary on all three, and brachioradialis cannot be promoted under the
   initial policy. Mutate each exact pushdown wrist stabilizer independently.
9. For every forbidden action in each family, inject it as an additional prime
   action and assert rejection. Add explicit cross-family mutations for
   shoulder extension/adduction/retraction (row/pull), shoulder abduction
   (upright row), shoulder flexion/horizontal adduction (press), scapular
   depression/shoulder extension (dip), and the opposite elbow action
   (shoulder-extension isolation versus elbow extension).
10. Prove posture does not become movement: changing
    `forearmMotion: angleHeld` to a dynamic rotation is outside the axis, held
    `forearmOrientation` never adds a forearm prime action, and
    `upperArmPosition: overhead|flexed90` never adds shoulder flexion.
11. Add setup mutations proving pronated overhead cable extension, neutral
    standing extension, supinated dumbbell extension, supported standing curl,
    rope pronated curl, and neutral straight-bar curl all fail. Mutate the low
    curl, high pushdown, overhead cable, and gravity-loaded dumbbell resistance
    geometries independently so cable direction cannot remain prose-only.
12. Retain the positive-weight metric-seed invariant, exact global name/alias
    uniqueness, evidence coverage, foundation capability checks, and the
    existing hard active-family/exercise count signal as global tests evolve.
13. Run `Scripts/catalog.py --check`, the complete catalog Python suite,
    `git diff --check`, and the generic iOS Simulator build before calling the
    activation complete. Simulator test suites remain opt-in under repository
    policy.

## Residual scope

This proposal intentionally leaves familiar exercises out. That is a review
queue, not a claim that they belong to different anatomical families. The next
elbow expansion should be selected by one new boundary at a time: supported
curl posture, semisupinated EZ geometry, combined elbow-flexion/supination,
closed-chain triceps loading, or shoulder-extended kickback posture. Each must
bring an exact source fixture, axis value, negative boundary, rule contrast,
and role review rather than entering as a name-only alias.
