# Batch 4 — hip isolation review

Status: mixed outcome. `hip-extension` is active after the reviewed 52-region
lower-body taxonomy migration. `hip-flexion` remains an evidence hold: the
available studies establish muscle activity and load sensitivity,
but no reviewed condition-matched source proves the proposed dynamic
femur-relative-to-position-held-pelvis isolation contract.

## Outcome

| Candidate | Decision | Initial roster |
|---|---|---:|
| `hip-extension` | Active | 1 |
| `hip-flexion` | Defer | 0 |

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

## Shared lower-body isolation vocabulary

The hip-extension contract uses the lower-body spellings agreed with the
knee/ankle isolation review:

| Axis | Active value | Meaning |
|---|---|---|
| `kineticChain` | `open` | The distal limb is free rather than fixed to the environment. |
| `bodyPosition` | `prone` | Whole-body posture. |
| `torsoSupport` | `table` | Actual external torso support. |
| `pelvisSupport` | `table` | Actual external pelvis support; this does not itself prove zero pelvic motion. |
| `pelvisMotion` | `positionHeld` | The pelvis does not deliberately create the repetition. |
| `spineMotion` | `positionHeld` | The spine does not deliberately create the repetition. |
| `hipMotion` | `extends` | The dynamic family action. |
| `kneeMotion` | `positionHeld` | Knee posture is held while the hip moves. |
| `kneeFlexionDegrees` | `90` | Reviewed bent-knee posture. |
| `movingSegment` | `thigh` | Pelvis-relative femoral motion defines the repetition. |
| `loadInterface` | `none` | No external resistance implement contacts the athlete. |
| `resistanceGeometry` | `limbSegmentGravity` | The unsupported limb segment supplies resistance. |
| `fixedPath` | `false` | No rail or lever constrains an external load path. |
| `lowerBodyContribution` | `isolatedJointMotion` | Another lower-body joint does not propel the repetition. |

Support and motion are deliberately separate facts. A torso or pelvis resting
on a table does not automatically prove that the pelvis and spine remained
still; the position-held axes state the reviewed technique boundary.

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
    { "anyOf": ["lowerBack"], "minimumRole": "stabilizer" }
  ],
  "allowedByRole": {
    "primary": ["gluteMax"],
    "secondary": ["medialHamstrings"],
    "stabilizer": ["bicepsFemoris", "lowerBack"]
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
dynamic hip extensor. `lowerBack` is likewise the directly measured provider
for the otherwise uncovered spine demand.

The study measured erector spinae and used an abdominal drawing-in maneuver
monitored through a pressure biofeedback unit, but it did not measure a
specific abdominal muscle and acknowledged that correct abdominal activation
was not confirmed by ultrasound. `lowerBack` therefore represents the
measured posterior spine-control role; no arbitrary `abs` or `obliques`
assignment is fabricated from the generic cue.

### Exact initial roster

| Catalog ID | Name and aliases | Geometry | Load semantics | Roles |
|---|---|---|---|---|
| `prone-table-bent-knee-hip-extension` | **Prone Table Bent-Knee Hip Extension**; `Prone Table Hip Extension`, `Bent-Knee Prone Hip Extension` | prone table, unilateral, knee 90 degrees, hip 30 degrees flexion to 5 degrees extension | bodyweight equipment, `nonComparable`, zero authored fraction; 10 reps | gluteMax P, medialHamstrings S, bicepsFemoris St, lowerBack St |

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

## Family 2: `hip-flexion` — deferred

### Proposed boundary

The candidate family would require the femur to flex relative to a
position-held pelvis while the spine and knee posture remain held. The family
would be open-chain, sagittal, isolation work with `hip.flexion` as its only
prime action. It would exclude sit-ups and V-ups (spine/trunk motion), hanging
or captain-chair leg raises (suspended support and different pelvic demand),
standing marches (stance-leg and balance demands), knee raises (different
rectus-femoris length), and machine or cable fixtures whose exact pelvis
restraint and resistance geometry have not been reviewed.

That is the contract the catalog wants. The current primary studies do not yet
prove it.

### What the primary studies establish

Lewis et al. modeled prone hip extension and supine straight-leg hip flexion
across joint angles and compared predictions with static midpoint EMG in five
subjects. In the supine task, iliopsoas activity exceeded rectus femoris and
tensor fasciae latae. The study supports anatomy and position-sensitive load,
but the experimental validation is a static hold rather than the proposed
dynamic repetition.

Hu et al. used fine-wire psoas and iliacus EMG plus surface rectus-femoris and
adductor-longus EMG during unilateral active straight-leg raises, with and
without a subject-specific ankle load that increased the leg's static hip
moment by 50 percent. All four muscles increased activity with load. Psoas was
also active during the contralateral raise, however, supporting a bilateral
spinal-stabilization interpretation; the paper also states that initial trunk
position was not controlled and frontal deviations of the raised leg were not
recorded.

Yamane et al. directly measured psoas and iliacus with fine-wire electrodes
and rectus femoris, sartorius, adductor longus, and tensor fasciae latae with
surface electrodes during straight-leg raises to 30, 45, and 60 degrees. At
60 degrees, psoas and iliacus activity was significantly greater than at the
shallower angles. This is strong range-dependent muscle evidence. Its
limitations explicitly say anterior/posterior pelvic movement was not limited,
muscle activity with hip motion alone was not recorded, and participants with
less than 60 degrees of passive range were excluded.

Elia et al. videotaped bilateral supine hip flexion and found that clinicians
experienced in stabilization training could reduce pelvic movement when
trying to cocontract trunk muscles. No participant eliminated pelvic movement.
The study verifies that pelvic motion is a load-bearing boundary, but it did
not measure the hip-flexor role panel needed to activate a family.

Taken together, these sources prove that a straight-leg raise is not a free
synonym for isolated hip flexion. Good hip-flexor EMG does not prove that the
femur moved relative to a held pelvis, and a stabilization instruction does
not prove zero pelvic motion.

### Activation gate

Do not create `families/hip-flexion.json` until a reviewed condition-matched
primary source, or a defensible combination of sources on the same fixture,
establishes all of the following:

1. dynamic femoral flexion relative to the pelvis, with sagittal pelvic and
   spinal motion measured or externally constrained and verified;
2. the exact knee posture and hip range used by the fixture;
3. enough individual-muscle evidence to assign `iliopsoas`, `rectusFemoris`,
   and any admitted `sartorius|tensorFasciaeLatae` roles without using the
   retired aggregate; admitting `adductorLongusBrevis` or `pectineus` as a
   flexor additionally requires a reviewed hip-position condition in the
   central action vocabulary;
4. an implement/support/resistance geometry that maps to a real exercise a
   user can reproduce; and
5. honest load semantics—a measured external load or reviewed bodyweight
   fraction, not a guessed fraction of total body mass.

The first likely fixture is a unilateral supine straight-leg raise to a
reviewed deep-flexion endpoint with an externally stabilized pelvis and a
measured ankle-cuff load. That is a search target, not pre-approved roster
content.

### Reviewed hold evidence metadata

These sources are documented here for the next evidence pass. They should not
be registered merely because they were reviewed: the evidence validator
rejects registry entries unused by active anatomy or family contracts.

#### `lewis-2009-hip-strengthening-forces`

- Source type: `peerReviewedMusculoskeletalModelAndEMGStudy`
- Title: *Effect of position and alteration in synergist muscle force
  contribution on hip forces when performing hip strengthening exercises*
- Authors: Cara L. Lewis; Shirley A. Sahrmann; Daniel W. Moran
- Year: 2009
- DOI: `10.1016/j.clinbiomech.2008.09.006`
- PMID: `19028000`
- URL: `https://doi.org/10.1016/j.clinbiomech.2008.09.006`

#### `hu-2011-weighted-active-straight-leg-raise`

- Source type: `intramuscularEMGAndKinematicStudy`
- Title: *Is the psoas a hip flexor in the active straight leg raise?*
- Authors: Hai Hu; Onno G. Meijer; Jaap H. van Dieën; Paul W. Hodges;
  Sjoerd M. Bruijn; Rob L. Strijers; Prabath W. B. Nanayakkara; Barend J.
  van Royen; Wen Hua Wu; Chun Xia
- Year: 2011 (published online 2010)
- DOI: `10.1007/s00586-010-1508-5`
- PMID: `20625774`
- URL: `https://doi.org/10.1007/s00586-010-1508-5`

#### `yamane-2019-straight-leg-raise-hip-flexors`

- Source type: `intramuscularEMGStudy`
- Title: *Understanding the Muscle Activity Pattern of the Hip Flexors during
  Straight Leg Raising in Healthy Subjects*
- Authors: Masahiro Yamane; Mitsuhiro Aoki; Yuji Sasaki; Hayato Kawaji
- Year: 2019
- DOI: `10.2490/prm.20190007`
- PMID: `32789254`
- URL: `https://doi.org/10.2490/prm.20190007`

#### `elia-1996-dynamic-pelvic-stabilization-hip-flexion`

- Source type: `kinematicTechniqueStudy`
- Title: *Dynamic pelvic stabilization during hip flexion: a comparison
  study*
- Authors: D. S. Elia; R. W. Bohannon; D. Cameron; R. C. Albro
- Year: 1996
- DOI: `10.2519/jospt.1996.24.1.30`
- PMID: `8807539`
- URL: `https://doi.org/10.2519/jospt.1996.24.1.30`

## Activation checks

Activation of `hip-extension` should add tests that prove:

1. the exact one-record roster and global name/alias uniqueness;
2. the complete 43-action forbidden complement;
3. every admitted enum and boolean value is covered;
4. numeric start, endpoint, and knee-posture values are pinned exactly;
5. every required muscle-role assignment fails independently when removed or
   weakened;
6. changing pelvis or spine motion, knee posture, resistance geometry, load
   semantics, laterality, or support fails validation;
7. bridge/thrust, hinge, straight-knee, and externally loaded mutations cannot
   enter through the active vocabulary;
8. `bicepsFemoris` cannot be promoted to a dynamic hip-extensor role; and
9. `hip-flexion` remains absent until its evidence gate is deliberately
   resolved.
