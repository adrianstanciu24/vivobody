# Batch 6 — hip-rotation foundation review

Status: evidence hold. Neither `hip-internal-rotation` nor
`hip-external-rotation` is activated by this review. No family contract should
be created until its foundation and exercise-specific gates below are resolved
atomically.

## Outcome

| Candidate | Decision | Initial roster |
|---|---|---:|
| `hip-internal-rotation` | Defer | 0 |
| `hip-external-rotation` | Defer | 0 |

This is not a conclusion that either action lacks trainable exercises. It is a
decision not to turn a position-dependent hip-muscle system into an
unconditional catalog claim. The current foundation can name both joint
actions, but it cannot yet describe the muscles that produce them truthfully
at the postures used by the reviewed exercises.

## Current foundation audit

The active taxonomy and anatomy profiles expose the following rotation
capabilities:

| Direction | Current producer | Problem for a family contract |
|---|---|---|
| Internal rotation | `tensorFasciaeLatae` | It is the sole producer, so the validator would force TFL to carry the family even though the reviewed exercise evidence shows a broader, posture-dependent strategy. |
| External rotation | `gluteMax` | Its capability is currently unconditional, but experimentally measured anterior compartments change toward internal rotation as hip flexion deepens. |
| External rotation | `sartorius` | Its anatomical capability does not establish it as the training emphasis or a prime mover in either reviewed rotation fixture. |

The one visible `gluteMed` mesh deliberately has only `hip.abduction`. That is
correct at an unrestricted foundation level: its anterior and posterior paths
can have opposite rotation moment directions. Gluteus minimus, piriformis,
obturators, gemelli, and quadratus femoris have no taxonomy regions or scene
meshes. A family must not solve those omissions by promoting the muscles that
happen to be visible.

`BodyModel.scn` was checked directly. It contains `Gluteus_Medius`,
`Gluteus_Maximus`, and `Tensor_Fascia_Latae` surfaces, but no gluteus-minimus,
piriformis, obturator, gemellus, or quadratus-femoris surface. Any new region
for those structures must therefore declare `meshBaseNames: []` and an honest
`unvisualizedReason`.

## What the position evidence actually says

### Delp et al.: rotation direction changes with hip flexion

Delp et al. measured rotation moment arms at 0, 20, 45, 60, and 90 degrees of
hip flexion in four cadaveric specimens and compared the measurements with a
three-dimensional model. The compartment results rule out several tempting
shortcuts:

- At zero degrees, only the anterior gluteus-medius compartment had a small
  internal-rotation moment arm. The other three compartments were external
  rotators. At 90 degrees, all four measured compartments were internal
  rotators.
- At zero degrees, the anterior gluteus-minimus compartment was an internal
  rotator while its middle and posterior compartments were external rotators.
  At 90 degrees, all three measured compartments were internal rotators.
- Every measured gluteus-maximus compartment was an external rotator at zero
  degrees. With flexion, anterior/superior compartments changed toward or
  across zero into internal rotation while the posterior/inferior compartments
  retained external-rotation moment arms.
- Piriformis changed from external rotation at zero degrees to internal
  rotation at 90 degrees.
- Obturator internus, obturator externus, and quadratus femoris retained
  external-rotation moment arms throughout the tested 0-to-90-degree range.

Those data support exact posture conditions. They do not support giving the
unsplit gluteus medius or maximus the union of every compartment's action.

### Peduzzi de Castro et al.: excitation is not action direction

Twenty-one participants performed maximal isometric internal- and
external-rotation efforts at 0, 45, and 90 degrees of hip flexion. Gluteus
medius, TFL, and upper gluteus maximus had substantially greater excitation
during internal rotation than external rotation at every posture. Lower
gluteus maximus followed that pattern at 90 degrees. External-rotation force
was greater at zero degrees but lower at 90 degrees.

This is direct evidence that posture changes both force and recruitment. It is
also adverse evidence against reading an EMG signal as proof of an individual
muscle's torque direction. The authors explicitly frame frontal-plane hip
stabilization as a source of synergy. The study can support an isometric
posture fixture and conservative inclusion, but it cannot by itself rank
primary versus secondary movers or activate a dynamic repetition.

### Hirano et al.: neutral-position adductor evidence is not an isolation

Hirano et al. found that pectineus, adductor longus, and adductor brevis
shortened during passive internal rotation from neutral in all eight dissected
limbs. In eight living participants, MRI T2 values increased more after the
study's internal-rotation condition than its external-rotation condition.

The live task was not an open-chain hip-rotation isolation. Participants stood
on the right leg and deliberately rotated the pelvis while the left leg took a
loaded forward or backward step. The authors also state that MRI T2 shows
activity but cannot determine the torque contributed at the joint. The source
therefore supports a candidate neutral-position capability for
`pectineus` and `adductorLongusBrevis`; it does not anchor a catalog exercise
or a categorical mover hierarchy.

### Deep external rotators cannot remain invisible to the contract

Ito et al. used fifteen fresh-frozen hips to estimate external-rotation torque
from physiological cross-sectional area and measured muscle-string geometry
from 0 to 105 degrees of hip flexion. The conjoined tendon of obturator
internus plus both gemelli had the greatest external-rotation torque from 0 to
45 degrees. Obturator externus increased with flexion and had the greatest
external-rotation torque from 75 through 105 degrees. Piriformis changed to an
internal-rotation torque between 75 and 90 degrees.

This result agrees with Delp's direction changes and makes a seated
90-degree external-rotation family especially dependent on obturator externus
and the conjoined tendon. A policy containing only visible `gluteMax`,
`gluteMed`, and `sartorius` would omit the structures with the strongest
position-matched mechanical case.

### The available dynamic external-rotation fixture does not solve anatomy

Chen et al. tested a seated, elastic-band hip external-rotation repetition to
30 degrees over two seconds in thirty women with patellofemoral pain. It is a
useful dynamic geometry anchor, but the text does not give a numeric seated hip
or knee angle or the band's anchor location. Its EMG panel contained gluteus
medius, vastus lateralis, and vastus medialis only. It contained none of the
deep external rotators and no gluteus maximus.

Gluteus-medius excitation during that task cannot be promoted to dynamic
external-rotation credit. The photographed posture appears near 90 degrees,
where Delp's four measured gluteus-medius compartments all had
internal-rotation moment arms, but the missing numeric posture prevents an
exact condition match. Either way, the signal is compatible with hip
stabilization or co-contraction, not proof that the unsplit region produced
the external-rotation moment. The quadriceps signal is likewise relevant to
held-knee stabilization, not a prime hip action.

Morimoto et al. provide a second dynamic boundary, not an activation escape.
Their knee-extended, side-lying external rotation at neutral hip flexion had
low mean excitation: approximately 7% MVC for piriformis, 5-to-6% for the two
gluteus-maximus sites, and 7% for gluteus medius. No external resistance was
applied. It demonstrates the movement and directly measures piriformis, but it
does not establish a useful loaded strength fixture or a defensible external
load seed.

## Candidate 1: `hip-internal-rotation` — deferred

### Truthful narrow boundary

The clearest prospective contract is a unilateral open-chain isolation with
the hip and knee held at 90 degrees, the femur rotating internally relative to
a position-held pelvis, and the lower leg moving outward. Hip flexion,
abduction, adduction, and spine or pelvis rotation do not create the
repetition. The family would use a conditioned `hip.internalRotation` as its
only prime and plane-basis action and `planes: [transverse]`.

This boundary excludes:

- gait, pivots, stepping, and standing pelvic-rotation drills;
- femoral-internal-rotation control during squats or landings;
- prone or standing rotations whose hip-flexion posture changes the available
  muscle actions;
- combined flexion, adduction, or abduction drills; and
- passive mobility work.

### Why it cannot activate now

At 90 degrees, the anatomy case is materially better than the current
foundation: every measured gluteus-medius and gluteus-minimus compartment has
an internal-rotation moment arm, and the isometric study directly shows TFL
and gluteal recruitment. But the reviewed condition-matched study is
isometric. No reviewed primary source dynamically tests the proposed seated
repetition while resolving its resistance geometry, motion range, and mover
roles.

An isometric-only family is a possible separate resolution, not a shortcut.
It would need the complete experimental setup, a reproducible user-facing
resistance interface, an admitted `isometricStrength` tracking policy, and a
role policy that does not rank movers by raw cross-muscle EMG. Those product
and source-detail gates were not resolved here.

Activating now would require one of two unsupported choices:

1. make TFL the sole primary because it is the only currently encoded
   producer; or
2. treat whole-muscle EMG as a numeric action-direction oracle and assign
   gluteus maximus despite its opposing fiber moment arms.

Neither is acceptable. No `families/hip-internal-rotation.json` should exist
yet.

### Neutral-position alternative remains outside the family

Hirano's adductor evidence makes a neutral-position branch worth future
review. It does not make the standing step-and-pelvis-rotation task an
isolation exercise. A neutral branch needs its own open-chain dynamic source
before `pectineus` or `adductorLongusBrevis` can receive an exercise role.

## Candidate 2: `hip-external-rotation` — deferred

### Truthful narrow boundary

The best prospective dynamic contract is a unilateral seated open-chain band
isolation with hip and knee held at 90 degrees, the femur rotating externally
relative to a position-held pelvis, and the lower leg moving inward. The knee,
pelvis, and spine do not deliberately create the repetition. The family would
use conditioned `hip.externalRotation` as its only prime and plane-basis
action and `planes: [transverse]`.

This is not a clamshell contract. Clamshell geometry combines a changing thigh
position with rotation and is routinely described and measured as both hip
abduction and external rotation. It must not be used to fill a pure-rotation
roster without its own action review.

### Why it cannot activate now

Chen supplies a real dynamic band fixture, but its EMG panel omits the
position-matched prime structures. At 90 degrees, Ito supports obturator
externus and the obturator-internus/gemelli conjoined tendon; those structures
do not exist in the taxonomy. Piriformis must not be substituted because it
changes to internal rotation in deep flexion. Whole `gluteMax` must not be
assigned from its current unconditional profile because its compartments do
not share one rotation direction at 90 degrees.

No `families/hip-external-rotation.json` should exist until the missing deep
rotator representation and the stale glute-max capability are fixed together.

## Proposed atomic foundation migration

The following is a proposal, not an activated edit. It must be reviewed with
the app's product policy for unvisualized muscles before implementation.

### 1. Add exact posture conditions

Add these centrally to `joint-actions.json`:

```json
{
  "id": "atNeutralHipFlexion",
  "displayName": "At neutral hip flexion",
  "definition": "Hip flexion is held at the anatomical-neutral, nominal zero-degree posture while the hip rotation action is produced.",
  "appliesTo": [
    "hip.internalRotation",
    "hip.externalRotation"
  ]
}
```

```json
{
  "id": "atNinetyDegreeHipFlexion",
  "displayName": "At 90 degrees of hip flexion",
  "definition": "Hip flexion is held at the nominal 90-degree posture while the hip rotation action is produced.",
  "appliesTo": [
    "hip.internalRotation",
    "hip.externalRotation"
  ]
}
```

These are held-posture conditions, not starting-side conditions like
`fromPronatedPosition`. A future family must carry the same condition in its
prime action and separately pin `hipFlexionDegrees` to the matching numeric
value.

### 2. Correct existing visible-region capabilities

- Replace `gluteMax`'s unconditional `hip.externalRotation` with
  `{ "action": "hip.externalRotation", "condition":
  "atNeutralHipFlexion" }`. Retain unconditional `hip.extension`.
- Add `{ "action": "hip.internalRotation", "condition":
  "atNinetyDegreeHipFlexion" }` to `gluteMed`. Retain unconditional
  `hip.abduction`.
- Keep TFL's unconditional internal-rotation capability only if the Arnold
  model is rechecked over the full range represented by that spelling. Even
  then, a family role remains posture-specific rather than automatic.
- Consider the Hirano-supported neutral-position internal-rotation capability
  for `pectineus` and `adductorLongusBrevis`. Do not add it unconditionally,
  and do not treat the standing MRI task as exercise-family evidence.

This deliberately leaves whole `gluteMax` without a 90-degree rotation action.
Its anterior and posterior regions do not share one direction there. Muscle
excitation can still be discussed as stabilization without granting false
dynamic credit.

### 3. Add action-compatible unvisualized regions

Three regions are the smallest useful taxonomy expansion:

```json
{
  "id": "gluteMin",
  "displayName": "Glute Min",
  "anatomicalName": "Gluteus Minimus",
  "group": "legs",
  "meshBaseNames": [],
  "unvisualizedReason": "BodyModel.scn has no gluteus-minimus surface mesh."
}
```

Its profile may produce unconditional `hip.abduction` and conditioned
90-degree `hip.internalRotation`, while stabilizing the hip and pelvis. It
must not receive unconditional internal or external rotation.

```json
{
  "id": "piriformis",
  "displayName": "Piriformis",
  "anatomicalName": "Piriformis",
  "group": "legs",
  "meshBaseNames": [],
  "unvisualizedReason": "BodyModel.scn has no piriformis surface mesh."
}
```

Its profile may produce conditioned external rotation at neutral hip flexion
and conditioned internal rotation at 90 degrees while stabilizing the hip. It
must not receive unconditional rotation.

```json
{
  "id": "deepHipExternalRotators",
  "displayName": "Deep Hip External Rotators",
  "anatomicalName": "Obturator Internus and Externus, Gemelli, and Quadratus Femoris",
  "group": "legs",
  "meshBaseNames": [],
  "unvisualizedReason": "BodyModel.scn has no obturator, gemellus, or quadratus-femoris surface meshes."
}
```

This aggregate may produce conditioned `hip.externalRotation` at neutral and
at 90 degrees and stabilize the hip because every included structure retains
that direction at both reviewed endpoints. Do not make the capability
unconditional: the reviewed evidence does not license every future hip posture
outside that range. Piriformis is deliberately excluded from the aggregate
because its direction reverses. This is not the blanket `deepRotators` union
rejected by the roadmap.

If product semantics require obturator externus to receive a different role
from the conjoined tendon at 90 degrees, split the aggregate before activation
rather than after users have accumulated muscle-volume history. The evidence
supports that split; the product decision determines whether it is useful.

### 4. Revalidate every affected contract

The migration changes the meaning of an existing producer. Re-run the entire
family set and explicitly assert that no active family currently relies on
unconditioned glute-max external rotation. The anatomy coverage tests must pin
the new muscle IDs, new count, empty-mesh reasons, condition usage, and the
absence of redundant conditional/unconditional action pairs.

## Activation gates

### Shared gates

1. Approve the exact action-condition names and numeric meanings.
2. Decide whether unvisualized gluteus minimus, piriformis, and the
   action-compatible deep-external-rotator aggregate are acceptable product
   regions.
3. Implement taxonomy, anatomy profiles, evidence registration, validator
   tripwires, README counts, Swift cutover tracking, and tests atomically.
4. Replace the stale unconditional `gluteMax -> hip.externalRotation`
   capability and prove that no active family regresses.
5. Require each rotation family to pin `hipFlexionDegrees` to the posture in
   its conditioned prime action.
6. Forbid every non-family prime action, including hip flexion, extension,
   abduction, adduction, knee motion, and pelvis/spine rotation.

### Internal-rotation-only gates

7. Obtain a primary dynamic study of a strict open-chain hip-internal-rotation
   repetition at a declared hip-flexion posture. The source must make the
   resistance attachment and direction, motion range, knee posture, pelvis
   control, and moving segment auditable.
8. Resolve mover hierarchy without comparing raw EMG magnitudes across
   muscles. At minimum, distinguish dynamic production from frontal-plane hip
   stabilization and explain any glute-max excitation without granting the
   unsplit region a false action.
9. If the neutral branch is admitted, use an isolation-specific source; do not
   convert Hirano's loaded step and intentional pelvis rotation into an
   open-chain record.

### External-rotation-only gates

10. Decode and pin the exact hip angle, knee angle, elastic-band anchor, and
    lower-leg attachment in the Chen fixture, or obtain a source that reports
    them textually. A generic `seated` plus `band` spelling is not a posture or
    resistance-geometry contract.
11. Decide whether the initial 90-degree family uses a single
    `deepHipExternalRotators` role or separately represents obturator externus
    and the conjoined tendon. The decision must reflect Ito's position-specific
    torque result.
12. Treat `gluteMed` and the measured quadriceps as stabilizers at most in the
    seated 90-degree fixture unless new action-direction evidence supports a
    dynamic role. Do not infer prime status from their excitation.
13. Keep clamshells, prone combined-extension rotations, and unloaded
    side-lying rotation outside the initial roster unless separately reviewed.

## Proposed tests when the foundation activates

- The exact muscle-ID set and count include every approved unvisualized
  region; each has an empty mesh list and a nonempty reason.
- `gluteMax` can satisfy neutral-position external rotation but cannot satisfy
  unconditioned or 90-degree external rotation.
- `gluteMed` and `gluteMin` can satisfy 90-degree internal rotation but cannot
  satisfy an unconditioned rotation action.
- `piriformis` satisfies opposite directions only under their matching
  posture conditions.
- `deepHipExternalRotators` satisfies conditioned external rotation at both
  reviewed postures but satisfies neither unconditioned external rotation nor
  internal rotation.
- Changing a family's conditioned prime action to its bare action ID fails.
- Changing the numeric hip-flexion axis while leaving the condition unchanged
  fails a cross-field rule, and changing both requires an explicit reviewed
  contract edit rather than passing a loose range test.
- Every exercise rule has matching and contrasting fixtures, and each
  assertion in a compound rule has its own mutation.
- The full forbidden-action complement is mutated one action at a time.
- No hip-rotation family exists while any activation gate remains unresolved.

## Evidence records to register only with activation

These IDs are predeclared to prevent collisions. Do not register them while
both families are held because unused evidence fails catalog validation.

### `delp-1999-hip-rotation-moment-arms`

- Source type: `cadavericMomentArmStudy`
- Title: *Variation of rotation moment arms with hip flexion*
- Authors: Scott L. Delp; William E. Hess; David S. Hungerford; Lynne C. Jones
- Year: 1999
- DOI: `10.1016/s0021-9290(99)00032-9`
- PMID: `10327003`
- URL: `https://doi.org/10.1016/s0021-9290(99)00032-9`
- Scope: Rotation moment arms for eighteen compartments across gluteus
  maximus, medius, and minimus plus iliopsoas, piriformis, quadratus femoris,
  and both obturators at 0, 20, 45, 60, and 90 degrees of hip flexion in four
  cadaveric specimens, with comparison to a three-dimensional model. It
  supports posture-conditioned action capabilities and adverse aggregate
  boundaries, not exercise-specific roles or contribution magnitudes.

### `peduzzi-de-castro-2021-hip-rotation-isometric`

- Source type: `experimentalIsometricEMGStudy`
- Title: *Activation of the gluteus maximus, gluteus medius and tensor fascia
  lata muscles during hip internal and external rotation exercises at three
  hip flexion postures*
- Authors: Marcelo Peduzzi de Castro; Heiliane de Brito Fontana; Marina Costa
  Fóes; Gilmar Moraes Santos; Caroline Ruschel; Helio Roesler
- Year: 2021
- DOI: `10.1016/j.jbmt.2021.05.011`
- PMID: `34391276`
- URL: `https://doi.org/10.1016/j.jbmt.2021.05.011`
- Scope: Maximal isometric internal- and external-rotation force plus surface
  EMG of upper/lower gluteus maximus, gluteus medius, and TFL in 21
  participants at 0, 45, and 90 degrees of hip flexion. It supports
  posture-sensitive recruitment and an isometric fixture, not a dynamic
  repetition, deep-rotator policy, or cross-muscle role ranking.

### `hirano-2025-hip-adductor-internal-rotation`

- Source type: `experimentalImagingStudy`
- Title: *Toward a Better Understanding of Hip Adductor Function: Internal
  Rotation Capability Revealed by Anatomical and MRI Evaluation*
- Authors: Kazuhiro Hirano; Kazuo Kinoshita; Atsushi Senoo; Masaru Watanabe
- Year: 2025
- DOI: `10.3390/jfmk10030354`
- PMID: `40981053`
- URL: `https://doi.org/10.3390/jfmk10030354`
- Scope: Passive neutral-position rotation anatomy in eight limbs and
  pre/post-exercise MRI T2 of pectineus and combined adductor longus/brevis in
  eight healthy adults. The live task used a loaded contralateral step and
  intentional standing pelvis rotation. It supports a candidate
  neutral-position capability, not an open-chain isolation, joint-torque
  magnitude, or categorical mover role.

### `ito-2025-short-hip-external-rotator-torque`

- Source type: `biomechanicalCadaverStudy`
- Title: *Comparison of External Rotation Torque of Short External Rotator
  Muscles in Hip Flexion Position*
- Authors: Yoshiaki Ito; Daisuke Suzuki; Fumiya Kizawa; Arata Kanaizumi;
  Toshihito Hiraiwa; Takashi Tamura; Yoshiharu Kawaguchi; Satoshi Nagoya
- Year: 2025
- DOI: `10.1002/jor.70005`
- PMID: `40524428`
- URL: `https://doi.org/10.1002/jor.70005`
- Scope: PCSA-scaled muscle-string external-rotation torque for piriformis,
  obturator internus, the obturator-internus/gemelli conjoined tendon, and
  obturator externus in fifteen fresh-frozen hips from 0 through 105 degrees
  of flexion. It supports position-specific deep-rotator capability and
  relative mechanical capacity, not neural recruitment or an exercise role by
  itself.

### `chen-2018-seated-band-hip-external-rotation`

- Source type: `experimentalKinematicsEMGStudy`
- Title: *Electromyographic analysis of hip and knee muscles during specific
  exercise movements in females with patellofemoral pain syndrome: An
  observational study*
- Authors: Shuya Chen; Wen-Dien Chang; Jhih-Yun Wu; Yi-Chin Fong
- Year: 2018
- DOI: `10.1097/md.0000000000011424`
- PMID: `29995792`
- URL: `https://doi.org/10.1097/md.0000000000011424`
- Scope: Thirty women with patellofemoral pain performed a seated elastic-band
  hip external-rotation repetition to 30 degrees over two seconds while an
  electronic goniometer and surface EMG measured gluteus medius, vastus
  lateralis, and vastus medialis. It anchors dynamic motion and measured
  stabilizers, but does not textually report the seated hip/knee angles or band
  anchor, omits every deep external rotator and gluteus maximus, and cannot
  establish the prime-mover contract.

### `morimoto-2018-piriformis-hip-movements`

- Source type: `intramuscularEMGStudy`
- Title: *Piriformis electromyography activity during prone and side-lying hip
  joint movement*
- Authors: Yasuhiro Morimoto; Tomoki Oshikawa; Atsushi Imai; Yu Okubo; Koji
  Kaneoka
- Year: 2018
- DOI: `10.1589/jpts.30.154`
- PMID: `29410588`
- URL: `https://doi.org/10.1589/jpts.30.154`
- Scope: Fine-wire piriformis EMG, a twelve-muscle surface panel, and
  three-dimensional marker motion during seven unloaded hip movements in
  eleven healthy men. The exact knee-extended side-lying neutral-flexion
  external rotation condition directly demonstrates the movement but produced
  low excitation and supplies neither external loading nor a strength seed.

### `beck-2000-gluteus-minimus`

- Source type: `biomechanicalCadaverStudy`
- Title: *The anatomy and function of the gluteus minimus muscle*
- Authors: Martin Beck; John B. Sledge; Emmanuel Gautier; Claudio F. Dora;
  Reinhold Ganz
- Year: 2000
- DOI: `10.1302/0301-620x.82b3.10356`
- PMID: `10813169`
- URL: `https://doi.org/10.1302/0301-620x.82b3.10356`
- Scope: Dissection of sixteen fresh-cadaver hips plus a plastic-bone
  mechanical model describing gluteus-minimus attachments, capsular
  stabilization, abduction, and position- and fiber-dependent rotation. It
  supports a distinct unvisualized region and rejects unconditional aggregate
  rotation, not exercise-specific involvement.

## Decision summary

The foundation changes are supportable enough to specify, but they are not a
license to activate either family in isolation from the shared migration.
Internal rotation still lacks a reviewed dynamic isolation fixture. External
rotation has a dynamic fixture, but the muscles with the strongest
position-matched mechanical case are absent from the taxonomy. Keeping both
families held is therefore the conservative result that preserves the purpose
of family contracts: biomechanics mistakes should be unrepresentable, not
merely documented after the fact.
