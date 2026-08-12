# Batch 3 — landmine and leg-driven overhead-press review

Status: decision-ready review record. The exact barbell `push-press` task is
ready to activate narrowly as the resolution of the broader
`leg-driven-overhead-press` candidate. `landmine-press` remains an evidence
hold: the first direct kinematic paper tracks the pivoting bar, but still does
not report the human-relative path or upper-body joint kinematics required to
separate this family from incline and vertical pressing.

## Outcome

| Roadmap candidate | Decision | Initial roster |
|---|---|---:|
| `landmine-press` | Defer | 0 |
| `leg-driven-overhead-press` | Resolve to and activate narrowly as `push-press` | 1 |

The decisions are intentionally asymmetric. A push press is distinguished from
the active strict `vertical-press` by directly observed lower-body
countermovement and propulsion. The landmine candidate is distinguished mainly
by path geometry, and the available study does not relate that geometry to the
athlete's torso or joints. Calling both exercises merely “non-strict presses”
would hide the exact fact that is established in one case and missing in the
other.

## Existing vertical-press boundary

The active `vertical-press` contract already supplies the relevant negative
controls:

- `kineticChain: open`;
- a 75–90-degree torso-relative press inclination;
- `lowerBodyContribution: none`;
- a front/scapular humeral and implement path; and
- forbidden hip extension, knee extension, and ankle plantarflexion.

Those constraints are not inconveniences to relax. They are what makes the
strict family strict. The new push-press family should reuse its upper-body
action model but declare the three lower-body propulsion actions explicitly.
The landmine candidate should not enter either family on the strength of the
bar's visible room-space angle.

## Candidate 1: `landmine-press` — defer

### What the new direct paper establishes

Zhao et al. 2026 directly studied a standing unilateral landmine press. Twenty-
four male collegiate athletes used a split stance and pressed the moving end
from near the deltoid under four external loads. The apparatus fixed one end of
an Olympic bar and constrained the moving end to a rotational arc. A 2D vision
system tracked both bar ends and calculated the bar's instantaneous angle
relative to horizontal, angular velocity, tangential velocity, and model-based
power. This is useful direct evidence for all of the following:

- the apparatus is pivot constrained rather than a free barbell path;
- the tested fixture is a unilateral, standing, split-stance task;
- the moving end follows a rotational arc; and
- bar angle must be treated as a changing state, not a single exercise label.

It does **not** establish the family boundary Vivobody needs. The camera model
tracked bar endpoints, not the athlete's shoulder, elbow, scapula, sternum, or
torso frame. The paper does not report a torso-relative start/end hand chord,
glenohumeral actions, scapular actions, or an exercise-specific muscle
hierarchy. Its planar model assumes sagittal-plane bar rotation even though the
method describes a frontal camera view and a split-stance human task. That
assumption is acceptable for the paper's device-comparison purpose; it is not a
substitute for human joint kinematics.

The study also defines the modeled load as bar mass plus plates. Vivobody has
not yet decided whether a user logs total bar-plus-plate mass or only mass added
at the moving sleeve for a landmine fixture. Activating before that decision
would make two physically different entries look comparable under the same
`external` load mode.

### Why static bar angle is the wrong classifier

Three concepts must remain separate:

1. **bar orientation** — the line from the floor pivot to the moving sleeve;
2. **handle path** — the tangent/chord followed by the moving sleeve; and
3. **human-relative press path** — handle travel expressed in a torso frame,
   together with the resulting shoulder and scapular actions.

Only the third can decide whether the app-facing direction is horizontal,
diagonal, or vertical. The same pivoted bar can produce different human-
relative paths when the athlete changes distance from the anchor, stance,
torso lean, kneeling height, or start position. Gravity remains vertical while
the pivot constrains the allowable motion; neither fact makes the family a
vertical press automatically.

The 2026 paper makes the bar geometry measurable but does not complete the
human-relative measurement. This is the same epistemic boundary recorded for
`diagonal-pull`: room-space implement travel cannot stand in for joint and
torso-relative evidence.

### Provisional vocabulary, not activated vocabulary

If the measurement gate is eventually passed, the narrow direct fixture would
most likely need:

- `equipment: barbell` plus a required `barbellConstraint: landminePivot`;
- `fixedPath: true`, because a pivot lever constrains the external load path;
- `bodyPosition: standing` and a reviewed split-stance axis;
- `laterality: unilateral`;
- `scapularTranslation: free`;
- a measured torso-relative path representation, not a copied bench angle;
- a reviewed decision on whether protraction is a prime action or only an
  endpoint/orientation observation; and
- a `loadAccounting` value that says exactly what mass the user records.

Do not add those values to `families/README.md` yet. A proposal must not turn
unmeasured vocabulary into pre-approved surface area.

### Activation gate

Resume `landmine-press` only when one direct fixture supplies all of the
following under a declared execution standard:

1. synchronized athlete and handle tracking with sternum/torso coordinates;
2. torso-relative hand start and end coordinates or a signed path chord with
   uncertainty;
3. shoulder elevation components and elbow excursion;
4. scapular kinematics or an explicit narrower action policy that does not
   infer scapular motion from serratus/trapezius EMG;
5. repeatability across realistic athlete-to-pivot distances; and
6. one load-accounting convention for catalog entry and comparison.

The initial family may then stay limited to the studied standing unilateral
fixture. Half-kneeling, tall-kneeling, bilateral two-hand, rotational,
explosive, and Viking-press variants need separate evidence rather than being
smuggled in as stance values.

### Evidence metadata — keep proposal-only while deferred

Do not register this source in `evidence.json` while no anatomy profile,
family, or exercise references it; the unused-evidence validator would reject
it.

| Proposed ID | Source | Identifier | Exact scope |
|---|---|---|---|
| `zhao-2026-landmine-press-kinematics` | Rui Zhao et al., “Landmine Press Kinematics Measured with an Enhanced YOLOv8 Model and Mathematical Modeling,” *Sensors* 26(4):1161 | DOI `10.3390/s26041161`; PMID `41755100`; PMC `PMC12944738` | Direct bar-end tracking and device comparison in a standing unilateral split-stance landmine press; no human joint, scapular, torso-frame, or muscle-role measurements. |

## Candidate 2: `leg-driven-overhead-press` → `push-press`

### Why the final family name is narrower

`leg-driven-overhead-press` is a useful discovery handle but a poor final
contract name. It also describes push jerks, split jerks, thrusters, and some
strongman presses. The reviewed evidence directly supports one exact task:
the barbell push press from a front rack, using one lower-body
countermovement/propulsion phase, continuous foot contact, and no second dip to
receive the bar.

The final family ID should therefore be `push-press`. It names the reviewed
task and prevents a broad “leg-driven” label from pre-authorizing unreviewed
receiving strategies.

### Direct evidence and limits

Chiu and Salem 2006 instrumented eleven trained men and women while they
performed free-weight and flywheel front squats, lunges, and push presses. Its
joint-kinetics analysis directly reports push-press impulse requirements at the
knee, hip, and ankle and identifies knee-extensor, hip-extensor, and ankle-
plantarflexor demand. This is the joint-resolved load-bearing source for the
three lower-body prime actions. It does not establish a categorical muscle
ranking: the `quads`, `gluteMax`, and `calves` assignments still combine those
joint results with the independently reviewed capability map.

Lake et al. 2014 tested 17 resistance-trained men across 10–90% of push-press
1RM on a force platform. The paper describes a front-rack start, a lower-body
countermovement, rapid hip/knee/ankle extension, and overhead arm lockout. It
found a mechanical demand comparable with the loaded jump squat and explicitly
frames the task as a combination of lower-body power, upper-body pressing, and
trunk strength.

Soriano et al. 2024 tested 18 resistance-trained men performing push press,
push jerk, and split jerk at 60, 75, and 90% of exercise 1RM. Its methods define
the push press as shoulder flexion and elbow extension concurrent with full
hip, knee, and ankle extension while the feet retain ground contact. Unlike the
two jerks, the push press has no descent into a receiving quarter squat and no
foot displacement. Force-time data directly establish a dip and propulsion
phase and quantify the task across loads.

Lake and Soriano do not report joint-resolved lower-limb moments,
exercise-specific lower-limb EMG, scapular kinematics, or a complete upper-body
EMG panel. Chiu supplies the missing joint kinetics, but none of the three
supplies a complete muscle hierarchy or scapular measurement. The contract
therefore uses Lake and Soriano for task identity, system propulsion, modality,
and the strict/jerk boundary; Chiu for lower-limb joint demands; and the
independently reviewed capability map plus active vertical-press evidence for
the categorical roster. That adaptation is explicit; it is not presented as
push-press-specific muscle ranking data.

### Activation-ready fixed contract

```json
{
  "id": "push-press",
  "name": "Push Press",
  "fixed": {
    "mechanic": "compound",
    "pattern": "push",
    "direction": "vertical",
    "planes": ["sagittal", "frontal"]
  },
  "groupPolicy": {
    "default": "shoulders",
    "allowed": ["shoulders"]
  },
  "allowed": {
    "equipment": ["barbell"],
    "modalities": ["power"],
    "trackingModes": ["reps"],
    "loadModes": ["external"],
    "lateralities": ["bilateral"]
  },
  "movementSignature": {
    "planeBasisActions": [
      "shoulder.flexion",
      "shoulder.abduction"
    ],
    "primeActions": [
      "shoulder.flexion",
      "shoulder.abduction",
      "scapula.upwardRotation",
      "scapula.posteriorTilt",
      "elbow.extension",
      "hip.extension",
      "knee.extension",
      "ankle.plantarflexion"
    ]
  }
}
```

`vertical` describes the principal upward bar/body-system direction relative
to the upright athlete. The two shoulder basis actions preserve the existing
front/scapular-path convention; `frontal` is present because of shoulder
abduction, not because lower-body propulsion creates another plane.

Scapular upward rotation and posterior tilt are the one deliberate evidence
transfer from strict pressing. The push-press studies finish in the same front
overhead arm position but did not measure the scapula. The active Ichihashi
military-press source directly measured those actions in a light strict press.
The family should disclose this mechanics transfer and keep the initial path
identical to `vertical-press`; a behind-neck push press is outside scope.

Hip, knee, and ankle flexion occur during the preparatory countermovement, but
the catalog's `primeActions` describe the force-producing upward phase. They
must not be added as concentric prime actions merely because a joint moves in
the opposite direction during the dip.

### Muscle policy

The initial categorical envelope should be narrow and explicit:

| Role | Muscles | Rationale |
|---|---|---|
| Primary | `deltoidAnterior`, `quads`, `gluteMax` | Shoulder-oriented catalog emphasis plus the directly established knee/hip propulsion chain. Multiple primaries acknowledge a whole-body power task; they do not claim equal magnitude. |
| Required secondary | `deltoidLateral`, `supraspinatus`, `triceps`, `serratus`, `trapeziusUpper`, `trapeziusLower`, `calves` | Same front-overhead humeral/scapular/elbow functions as the strict family, plus plantarflexion in the directly described triple-extension drive. |
| Stabilizer | `extensorCarpiRadialis`, `fingerFlexors`, `externalRotators`, `subscapularis`, `abs`, `obliques`, `lowerBack` | Static bar control at the wrist/hand, shoulder control, and force transfer through a torso that is not a dynamic prime mover. |

The initial record should assign only the three primaries, seven required
secondaries, the shared loaded-grip wrist/hand stabilizers, both cuff
stabilizers, and the three trunk stabilizers. The movement signature therefore
declares both wrist and hand stability demands; holding the front-rack bar is
not exempt from the convention used by the other loaded Batch-3 fixtures. In
particular, clavicular pectoralis, hamstrings, and adductors are not admitted
merely because their independent anatomy profiles make a contribution
possible. Adding any of them later requires an exercise-specific role review;
the initial contract should not create permissive surface that its only record
does not exercise.

`groupPolicy.default: shoulders` is a product ownership decision. It keeps the
exercise beside other overhead presses while the involvement list and
`modality: power` make the lower-body contribution visible. The family does
not claim to be a shoulder-only exercise. Restricting allowed group to
`shoulders` also prevents exercise-by-exercise drift until the app has an
explicit full-body or multi-group presentation model.

### Required axes

The one-record activation uses single-value axes rather than always-true
exercise rules:

| Axis | Value | Contract meaning |
|---|---|---|
| `kineticChain` | `open` | The loaded hands and bar move freely relative to the environment. |
| `bodyPosition` | `standing` | The reviewed task begins and finishes standing. |
| `torsoSupport` | `none` | No external surface supports the torso. |
| `scapularTranslation` | `free` | No posterior support limits scapular translation. |
| `pressInclinationDegrees` | `90` | Canonical upright torso-relative overhead press path, not the preparatory dip. |
| `gripOrientation` | `pronated` | Straight front-rack barbell grip. |
| `fixedPath` | `false` with `fixedValue: false` | No rail or lever constrains the bar path. |
| `lowerBodyContribution` | `countermovementPropulsion` | A dip precedes rapid hip/knee/ankle extension that propels the bar-body system. |
| `pressPath` | `frontScapular` | Front-rack to overhead path; behind-neck variants remain out. |
| `legDriveDipStyle` | `pushPressCountermovement` | The reviewed preparatory push-press dip, not a full front-squat repetition. The longer axis name keeps it distinct from a dip exercise family. This is a task-definition class, not a universal angle threshold, and deliberately avoids claiming an unmeasured “shallow” cutoff. |
| `receivingStrategy` | `standingNoRedip` | The athlete presses to lockout without descending under the bar. |
| `footContact` | `continuous` | The feet stay in ground contact through propulsion and lockout. This axis does not overclaim a separately measured foot-position variable. |

`countermovementPropulsion` should become the second reviewed shared value of
`lowerBodyContribution`, alongside `none`. The definition must travel with the
value; a family must still declare the exact hip/knee/ankle prime actions.

`legDriveDipStyle`, `receivingStrategy`, and `footContact` are task-boundary
axes. They
are not redundant prose:

- removing `legDriveDipStyle` admits a thruster with the same concentric joint
  actions;
- removing `receivingStrategy` admits a push jerk; and
- removing `footContact` admits foot-displacement receiving strategies.

No exercise rule is needed because every axis has one admitted value. The
axis-level boolean fixed value should enforce `fixedPath: false` using the
existing Batch-2 mechanism.

### Initial roster and exclusions

| Exercise | Decision | Evidence status |
|---|---|---|
| Barbell Push Press | Activate | Direct joint-kinetics evidence from Chiu 2006 and task, force-time, and load evidence from Lake 2014 and Soriano 2024; upper-body role/scapular details transferred transparently from the active strict press foundation. |
| Dumbbell push press | Defer | Common and mechanically plausible, but not part of either direct task study; independent implements add path and laterality axes. |
| Kettlebell push press | Defer | Bell orientation, rack geometry, and unilateral variants need review. |
| Behind-neck push press | Exclude | Violates `pressPath: frontScapular` and lacks a reviewed shoulder path. |
| Push jerk | Exclude | Adds a receiving dip under the bar. |
| Split jerk | Exclude | Adds a receiving dip, foot displacement, and split stance. |
| Thruster | Exclude | Begins with a full front-squat task rather than the reviewed push-press countermovement. |
| Strongman log/Viking press | Defer | Implement, grip, path constraint, load accounting, and often receiving rules differ. |

The single record is not under-curated. It exactly matches the direct evidence
and exercises every admitted value. Broader equipment coverage would be
speculative padding.

### Recommended defaults

- `modality: power`, because both direct studies quantify propulsion power and
  the task intentionally uses lower-body ballistic drive;
- `trackingMode: reps`;
- `recommended.defaultReps: 1...6`;
- initial `reps: 5`;
- `defaultWeight: 45` and `defaultWeightKg: 20`; and
- `bodyweightFraction: 0` under `loadMode: external`.

The 45 lb / 20 kg seed represents the unloaded standard bar and follows the
catalog's clean imperial/metric detent convention. It is not a prescription
derived from the research participants' 1RM.

## Activation tests

In addition to the generic family/schema/roster tests, activation should pin:

1. `push-press` has exactly one initial record and it is `modality: power`;
2. its upper-body signature equals the active front-path `vertical-press`
   signature before the three lower-body actions are added;
3. hip extension, knee extension, and ankle plantarflexion are all required
   and none remains forbidden;
4. strict `vertical-press` continues to forbid all three lower-body propulsion
   actions and still permits only `lowerBodyContribution: none`;
5. `lowerBodyContribution`, `legDriveDipStyle`, `receivingStrategy`, and
   `footContact`
   are required one-value axes and every roster record uses the exact value;
6. `fixedPath` rejects `true` through its axis-level fixed value;
7. removing `quads`, `gluteMax`, or `calves` fails the matching prime-action or
   muscle requirement;
8. removing one upper-body dynamic contributor or either required loaded-grip
   stabilizer fails the family requirement;
9. a mutation that changes `receivingStrategy` or `footContact` is rejected at
   the axis boundary; and
10. no landmine family file or pre-approved landmine axis vocabulary exists
    while the measurement and load-accounting gates remain open.

## Evidence records to add for `push-press`

| ID | Source metadata | Registry scope |
|---|---|---|
| `chiu-2006-push-press-joint-kinetics` | Loren Z. F. Chiu, George J. Salem, “Comparison of joint kinetics during free weight and flywheel resistance exercise,” *Journal of Strength and Conditioning Research* 20(3):555–562 (2006). DOI `10.1519/R-18245.1`; PMID `16937968`. | Eleven trained men and women performed front squat, lunge, and push press under free-weight and flywheel resistance while instrumented for biomechanical analysis. Direct push-press evidence for knee, hip, and ankle impulse demands and the corresponding extensor/plantarflexor joint functions; not a muscle-ranking, scapular, or upper-body EMG study. |
| `lake-2014-push-press-power` | Jason P. Lake, Peter D. Mundy, Paul Comfort, “Power and impulse applied during push press exercise,” *Journal of Strength and Conditioning Research* 28(9):2552–2559 (2014). DOI `10.1519/JSC.0000000000000438`; PMID `24584046`. | Seventeen trained men performed barbell push presses across 10–90% 1RM on a force platform. Direct evidence for front-rack countermovement propulsion, load-power behavior, and the exercise's lower-body-power plus upper-body/trunk demand; no joint-resolved kinetics or EMG. |
| `soriano-2024-push-press-jerk` | Marcos A. Soriano et al., “Kinetics and Kinematics of the Push Press, Push Jerk, and Split Jerk,” *Journal of Strength and Conditioning Research* 38(8):1359–1365 (2024). DOI `10.1519/JSC.0000000000004810`; PMID `39072653`. | Eighteen trained men performed the three lifts at 60, 75, and 90% 1RM. Direct force-time evidence and methods-level task boundary: push press combines shoulder flexion/elbow extension with full hip/knee/ankle extension while feet remain grounded; jerk variants add a receiving descent and foot displacement. “Kinematics” are system displacement/duration, not joint-angle or scapular measurements. |

Use canonical DOI URLs. All three are load-bearing family/exercise sources. The
scope strings must preserve their measurement limits rather than implying
joint-resolved kinematics from the paper titles.
