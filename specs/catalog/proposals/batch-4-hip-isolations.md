# Batch 4 — hip isolation review

Status: resolved. `hip-extension` and `hip-flexion` are active after the
reviewed 52-region lower-body taxonomy migration. The hip-flexion decision
does not revive the earlier position-held-pelvis proposal. It activates the
narrower Okubo active-straight-leg-raise topology and preserves pelvic and
spinal motion as `nonstandardized`.

## Outcome

| Candidate | Decision | Initial roster |
|---|---|---:|
| `hip-extension` | Active | 1 |
| `hip-flexion` | Active | 1 |

This review intentionally does not use bridge, thrust, hinge, sit-up, hanging
leg-raise, or knee-raise records to make the two narrow families appear more
complete. Those tasks change which segment moves, add another prime joint or
trunk action, or introduce loading that the isolation evidence does not
resolve.

## Resolved taxonomy dependency

The pre-Batch-4 aggregates could not express the reviewed hip roles. The
activation decision uses the migrated 52-region taxonomy and these exact
IDs:

| Exact region | Relevant capability and policy |
|---|---|
| `gluteMax` | Produces hip extension and is the primary target in the reviewed bent-knee fixture. |
| `medialHamstrings` | Produces hip extension and knee flexion; it can receive secondary hip-extension credit. |
| `bicepsFemoris` | Produces knee flexion only in the catalog because the body-model mesh does not distinguish its biarticular long head from its monoarticular short head. |
| `iliopsoas` | Produces hip flexion; the one visible region combines iliacus and psoas even though their task-specific functions are not identical. |
| `rectusFemoris` | Produces hip flexion and knee extension. |
| `sartorius` | Produces hip flexion, abduction, and external rotation plus knee flexion. |
| `adductorLongusBrevis` | Produces hip adduction only in the current foundation. Its modeled sagittal moment reverses as hip flexion deepens, so flexion remains deliberately under-credited until a reviewed hip-position condition exists. |
| `pectineus` | Produces hip adduction only in the current foundation. Its modeled sagittal moment approaches or crosses zero near deep flexion, so unbounded hip-flexion capability would be too permissive. |

`adductorMagnus` is not given hip extension or flexion. Its one scene mesh
cannot distinguish action-changing fiber regions. `bicepsFemoris` likewise
cannot inherit long-head hip extension without also falsely assigning it to
the short head represented by the same mesh. Those are deliberate visible-
taxonomy under-credits, not reasons to restore the retired aggregates.

## Lower-body isolation vocabulary

Both contracts use the lower-body spellings agreed with the knee/ankle
isolation review, while preserving the different facts established by their
sources:

| Axis | Hip extension | Hip flexion | Meaning |
|---|---|---|---|
| `kineticChain` | `open` | `open` | The distal limb is free rather than fixed to the environment. |
| `bodyPosition` | `prone` | `supine` | Whole-body posture. |
| `torsoSupport` | `table` | `table` | Actual external torso support. |
| `pelvisSupport` | `table` | `table` | Actual external pelvis support; this does not itself prove zero pelvic motion. |
| `pelvisMotion` | `positionHeld` | `nonstandardized` | The extension technique holds the pelvis; the ASLR source does not establish a zero-motion pelvis. |
| `spineMotion` | `positionHeld` | `nonstandardized` | The extension technique holds the spine; the ASLR source does not establish a zero-motion spine. |
| `hipMotion` | `extends` | `flexes` | The dynamic family action. |
| `rangeOfMotion` | numeric reviewed endpoints | `activeEndRange` | Only the extension source supports universal numeric authoring targets. |
| `kneeMotion` | `positionHeld` | `positionHeld` | Knee posture is held while the hip moves. |
| `kneePosture` | reviewed 90-degree value | `extended` | The directly reviewed working-knee posture. |
| `movingSegment` | `thigh` | `thigh` | Pelvis-relative femoral motion defines the repetition. |
| `loadInterface` | `none` | `none` | No external resistance implement contacts the athlete. |
| `resistanceGeometry` | `limbSegmentGravity` | `limbSegmentGravity` | The unsupported limb segment supplies resistance. |
| `fixedPath` | `false` | `false` | No rail or lever constrains an external load path. |
| `lowerBodyContribution` | `isolatedJointMotion` | `isolatedJointMotion` | Another lower-body joint does not propel the repetition. |

Support and motion are deliberately separate facts. A torso or pelvis resting
on a table does not automatically prove that the pelvis and spine remained
still. The extension source supports its position-held technique boundary;
the hip-flexion contract instead records both motions as nonstandardized.

## Family 1: `hip-extension`

### Contract boundary

The active family is a strict unilateral open-chain task in which the femur
extends relative to the supported pelvis. The knee remains at 90 degrees,
and the pelvis and spine remain position-held. Its only prime and plane-basis
action is `hip.extension`; every other current action is forbidden. It uses
`mechanic: isolation`, `pattern: null`, `direction: null`, and
`planes: [sagittal]`.

This excludes:

- a bridge or hip thrust, in which the pelvis moves relative to planted feet;
- a hinge or back extension, in which the pelvis and/or trunk moves relative
  to the femur;
- a quadruped kickback, whose support and trunk-control demands were not
  tested in the active evidence;
- a straight-knee prone extension, which materially changes hamstring length
  and contribution;
- standing cable, band, and multi-hip-machine extensions, whose support and
  resistance geometries are not reviewed here; and
- combined abduction, external rotation, knee motion, or lumbar extension.

### Direct evidence and role policy

Jeon et al. studied sixteen healthy men performing conventional prone hip
extension, prone-table hip extension, and prone-table hip extension with the
knee flexed 90 degrees. Surface EMG covered gluteus maximus, biceps femoris,
semitendinosus, and erector spinae; electromagnetic tracking measured pelvic
rotation and anterior tilt. The bent-knee prone-table condition produced the
greatest gluteus-maximus amplitude and lower hamstring and erector-spinae
amplitudes than the straight-knee table condition. The comparison supports a
glute-max-emphasis contract; lower amplitude is not absence, so the medial
hamstrings remain secondary rather than being deleted.

The exact active role envelope is:

```json
{
  "requirements": [
    { "anyOf": ["gluteMax"], "minimumRole": "primary" },
    { "anyOf": ["medialHamstrings"], "minimumRole": "secondary" },
    { "anyOf": ["bicepsFemoris"], "minimumRole": "stabilizer" },
    { "anyOf": ["lumbarExtensors"], "minimumRole": "stabilizer" }
  ],
  "allowedByRole": {
    "primary": ["gluteMax"],
    "secondary": ["medialHamstrings"],
    "stabilizer": ["bicepsFemoris", "lumbarExtensors"]
  }
}
```

The source measured a biceps-femoris site but did not solve the body model's
long-head/short-head collision. The active record therefore does not pretend
the shared visible `bicepsFemoris` region can receive dynamic hip-extension
credit. Its stabilizer assignment is limited to the real knee-flexion
capability used to hold the 90-degree knee posture. This still under-credits
the long head's hip-extension contribution in the 3D model and volume
analytics, and the contract says so explicitly.

That stabilizer is evidence-required rather than a validator patch. The
assigned movers already cover hip, pelvis, and knee stability; biceps femoris
is retained because it was directly measured and the conservative visible
region can truthfully receive held-knee control without being mislabeled as a
dynamic hip extensor. `lumbarExtensors` is likewise the directly measured provider
for the otherwise uncovered spine demand.

The study measured erector spinae and used an abdominal drawing-in maneuver
monitored through a pressure biofeedback unit, but it did not measure a
specific abdominal muscle and acknowledged that correct abdominal activation
was not confirmed by ultrasound. `lumbarExtensors` therefore represents the
measured posterior spine-control role; no arbitrary `abs` or `obliques`
assignment is fabricated from the generic cue.

### Exact initial roster

| Catalog ID | Name and aliases | Geometry | Load semantics | Roles |
|---|---|---|---|---|
| `prone-table-bent-knee-hip-extension` | **Prone Table Bent-Knee Hip Extension**; `Prone Table Hip Extension`, `Bent-Knee Prone Hip Extension` | prone table, unilateral, knee 90 degrees, hip 30 degrees flexion to 5 degrees extension | bodyweight equipment, `nonComparable`, zero authored fraction; 10 reps | gluteMax P, medialHamstrings S, bicepsFemoris St, lumbarExtensors St |

The 30-degree start and 5-degree extension endpoint are the reviewed authoring
targets, not a promise of laboratory precision in user repetitions. The
fixture has no external weight seed. Encoding a guessed fraction of total
bodyweight would make the limb's mass and hip moment arm look comparable to a
push-up-style supported-body fraction, so the active record remains explicitly
`nonComparable`.

The one-record roster is intentional. It tests the foundation's hip action,
the posture-bearing knee angle, supported-versus-held distinction, complete
forbidden-action boundary, non-comparable limb-gravity load, and the visible
biceps-femoris taxonomy limitation without inventing an equipment survey.

### Exact active evidence ID

`jeon-2016-prone-table-hip-extension`

- Source type: `experimentalKinematicsEMGStudy`
- Title: *Comparison of gluteus maximus and hamstring electromyographic
  activity and lumbopelvic motion during three different prone hip extension
  exercises in healthy volunteers*
- Authors: In-Cheol Jeon; Ui-Jae Hwang; Sung-Hoon Jung; Oh-Yun Kwon
- Year: 2016
- DOI: `10.1016/j.ptsp.2016.03.004`
- PMID: `27583647`
- URL: `https://doi.org/10.1016/j.ptsp.2016.03.004`
- Scope: Sixteen healthy men performed conventional prone, prone-table, and
  90-degree-knee-flexed prone-table hip extension. Surface EMG measured
  gluteus maximus, biceps femoris, semitendinosus, and erector spinae while
  electromagnetic tracking measured pelvic rotation and anterior tilt. The
  study directly supports the one reviewed bent-knee fixture and relative
  categorical roles, not other apparatus, external loading, bilateral
  variants, or a zero-pelvic-motion claim.

## Family 2: `hip-flexion`

### Contract boundary

The active family is a unilateral supine active straight-leg raise from the
table-supported start to the participant's active end range. The working knee
remains extended, and no external implement is used. Its only prime and
plane-basis action is `hip.flexion`; every other current action is forbidden.
It uses `mechanic: isolation`, `pattern: null`, `direction: null`, and
`planes: [sagittal]`.

This is deliberately not the previously proposed position-held-pelvis family.
Okubo et al. measured the moving hip and segmented the repetition through
concentric, end-range, and eccentric phases, but did not establish a universal
numeric endpoint, a standardized cadence or end-range duration, or zero
pelvic and spinal motion. The active contract therefore records
`pelvisMotion: nonstandardized` and `spineMotion: nonstandardized`. Those
values preserve uncertainty; they do not promote either region to a deliberate
prime action.

This excludes:

- sit-ups and V-ups, which deliberately add spinal or trunk motion;
- hanging and captain-chair raises, whose suspended support and pelvic demands
  are different;
- knee raises, which change the reviewed rectus-femoris length condition;
- standing marches, which add stance-leg and balance demands;
- loaded, cable, and machine flexion, whose load and restraint geometries were
  not studied; and
- any record with an authored numeric endpoint, cadence, or hold duration.

### Direct evidence and role policy

Okubo et al. collected fine-wire psoas-major EMG plus surface EMG from rectus
femoris, rectus abdominis, external oblique, and a combined internal-oblique/
transversus-abdominis site during active straight-leg raises to end range.
The analysis covered concentric, end-range, and eccentric phases in data from
nine healthy men. Psoas-major activation was greatest late in the concentric
phase, at end range, and early in the eccentric phase, and exceeded rectus
femoris at the high-flexion portion of the task. The abdominal panel was also
active around the late concentric and end-range portions. This supports the
narrow topology and a conservative categorical role hierarchy; it does not
turn surface or fine-wire amplitude into numeric volume shares.

The exact active role envelope is:

```json
{
  "requirements": [
    { "anyOf": ["iliopsoas"], "minimumRole": "primary" },
    { "anyOf": ["rectusFemoris"], "minimumRole": "secondary" },
    { "anyOf": ["abs"], "minimumRole": "stabilizer" },
    { "anyOf": ["obliques"], "minimumRole": "stabilizer" }
  ],
  "allowedByRole": {
    "primary": ["iliopsoas"],
    "secondary": ["rectusFemoris"],
    "stabilizer": ["abs", "obliques"]
  }
}
```

The body model's visible `iliopsoas` region combines psoas major and iliacus.
Okubo directly measured psoas major, not iliacus; the primary label therefore
means the combined visible region carries the directly supported psoas role,
not that the study separately ranked both constituent muscles. The anatomy
foundation independently supports both constituents as hip flexors.

Rectus femoris remains secondary rather than absent. Abs and obliques receive
stabilizer-only credit, which conservatively covers the declared spine and
pelvis demands without labeling their measured activity as deliberate spinal
motion. Iliopsoas and rectus femoris cover hip and knee stability. No
additional provider is needed for the exact `hip|pelvis|knee|spine` envelope.

Tensor fasciae latae, sartorius, and the adductor regions are excluded. Okubo
did not measure them, and general anatomical hip-flexion capability is not a
license to add them to this exact exercise. The exclusion also avoids
fabricating a posture condition for position-sensitive adductor function.

### Exact initial roster

| Catalog ID | Name and aliases | Geometry | Load semantics | Roles |
|---|---|---|---|---|
| `bodyweight-active-straight-leg-raise` | **Bodyweight Active Straight-Leg Raise**; `Active Straight-Leg Raise`, `Supine Straight-Leg Raise` | unilateral, supine table support, extended working knee, participant-specific active end range | bodyweight equipment, `nonComparable`, zero authored fraction; 10 reps | iliopsoas P, rectusFemoris S, abs St, obliques St |

The repetition reaches active end range and returns under control. It does not
publish a degree endpoint, cadence, pause, or hold duration. The fixture has
no external weight seed. Encoding a guessed fraction of total bodyweight
would make the limb's mass and moment arm look comparable to a supported-body
fraction, so the record remains explicitly `nonComparable`.

The one-record roster is intentional. It activates only the exact primary
source topology and does not treat every exercise commonly called a leg raise
as equivalent.

### Exact active evidence ID

`okubo-2021-end-range-active-straight-leg-raise`

- Source type: `experimentalKinematicsEMGStudy`
- Title: *Differential activation of psoas major and rectus femoris during
  active straight leg raise to end range*
- Authors: Yu Okubo; Koji Kaneoka; Kiyotaka Hasebe; Naoto Matsunaga;
  Atsushi Imai; Paul W. Hodges
- Year: 2021
- DOI: `10.1016/j.jelekin.2021.102588`
- PMID: `34455371`
- URL: `https://doi.org/10.1016/j.jelekin.2021.102588`
- Scope: Fine-wire psoas-major and surface rectus-femoris and abdominal EMG,
  synchronized with hip kinematics, characterized concentric, end-range, and
  eccentric phases of the unilateral active straight-leg raise to active end
  range. The analyzable data were from nine healthy men. The source supports
  this bodyweight topology and the categorical role envelope, not iliacus as
  a separately measured site, a numeric universal endpoint, a standardized
  cadence or end-range duration, an external load, or zero pelvis/spine
  movement.

The earlier Lewis, Hu, Yamane, and Elia studies remain useful adverse context
for position sensitivity, loading, and pelvic behavior. They are not needed
to broaden the active family and should not be registered merely because they
were reviewed.

## Activation checks

Activation of both families should add tests that prove:

1. each exact one-record roster and global name/alias uniqueness;
2. each complete 43-action forbidden complement;
3. every admitted enum and boolean value is covered;
4. the hip-extension numeric start, endpoint, and knee-posture values are
   pinned exactly, while hip-flexion has no numeric endpoint, cadence, or hold
   duration to mutate;
5. every required muscle-role assignment fails independently when removed or
   weakened;
6. changing pelvis or spine motion, knee posture, resistance geometry, load
   semantics, laterality, or support fails validation;
7. bridge/thrust, hinge, straight-knee hip extension, loaded leg raises, knee
   raises, and deliberately trunk-driven mutations cannot enter through the
   active vocabularies;
8. `bicepsFemoris` cannot be promoted to a dynamic hip-extensor role;
9. `tensorFasciaeLatae`, `sartorius`, and all adductor regions cannot enter the
   exact hip-flexion roster; and
10. the hip-flexion contract keeps both `pelvisMotion` and `spineMotion`
    `nonstandardized` and cannot be silently strengthened to `positionHeld`.
