# Scapular-retraction family proposal

Status: **deferred after evidence review**. This document records a candidate
boundary and the evidence needed to activate it. It is not validator input.

## Decision

Do not activate `scapular-retraction` in Batch 1.

Scapular retraction is a distinct anatomical action, but the available named
exercises do not yet form a clean family whose loaded repetition is retraction
alone. Direct three-dimensional measurements show that common retraction
exercises also produce varying combinations of scapular external rotation,
upward rotation, posterior tilt, clavicular retraction, and sometimes
depression. The combination changes with humeral elevation, humeral rotation,
and elbow posture. That is evidence against flattening all of those exercises
into a permissive one-action contract.

Kara et al. instructed movement from protraction to full retraction under
elastic resistance at several shoulder-abduction angles, but analyzed the
isometric phase for its trapezius comparison. Fennell et al. directly sampled
middle trapezius and rhomboid major with fine-wire EMG, but used maximal static
contractions and did not measure scapular kinematics. Neither result turns a
band pull-apart, reverse fly, face pull, row, or prone T into an isolated
dynamic retraction exercise.

The deferral is therefore a boundary decision, not a claim that retraction is
not trainable.

## Candidate contract if the boundary is later unlocked

```json
{
  "id": "scapular-retraction",
  "fixed": {
    "mechanic": "isolation",
    "pattern": null,
    "direction": null,
    "planes": ["transverse"]
  },
  "movementSignature": {
    "planeBasisActions": ["scapula.retraction"],
    "primeActions": ["scapula.retraction"],
    "forbiddenPrimeActions": [
      "scapula.elevation",
      "scapula.depression",
      "scapula.protraction",
      "scapula.upwardRotation",
      "scapula.downwardRotation",
      "scapula.anteriorTilt",
      "scapula.posteriorTilt",
      "shoulder.flexion",
      "shoulder.extension",
      "shoulder.abduction",
      "shoulder.adduction",
      "shoulder.horizontalAdduction",
      "shoulder.horizontalAbduction",
      "shoulder.internalRotation",
      "shoulder.externalRotation",
      "elbow.flexion",
      "elbow.extension"
    ],
    "stabilityDemands": ["scapula", "shoulder"]
  }
}
```

The strict candidate would use middle trapezius as the only admitted primary.
Rhomboids would be secondary when the reviewed setup meaningfully recruits
them, because their downward-rotation and elevation capabilities make them
more than interchangeable copies of middle trapezius. Lower trapezius could be
an optional secondary only where the setup does not simultaneously promote
depression, upward rotation, or posterior tilt to an unacknowledged prime
action. A shoulder-capable stabilizer would remain required for the declared
shoulder demand.

This is intentionally narrower than the retraction actions currently declared
inside row and vertical-pull families. In those compound families, retraction
is one component of a multi-joint pull. Here it would have to be the exercise's
training-defining dynamic action.

## Shared axes required before activation

A future contract must explicitly author:

- `kineticChain`: initially `open` only;
- `bodyPosition`: such as `standing` or `prone`, only when directly reviewed;
- `torsoSupport`: `none|bench`, retaining the existing external-support
  meaning;
- `scapularTranslation`: `free` for the initial candidate; anterior or lateral
  torso contact must not be equated with a pinned posterior scapula;
- `humerothoracicElevationDegrees`: the thorax-relative upper-arm position,
  not a declaration of dynamic shoulder abduction;
- `elevationPath`: absent when elevation is zero and otherwise a reviewed
  sagittal, scapular, or frontal position descriptor;
- `humeralRotation`: `neutral|internal|external`, independent of hand grip;
- `elbowMotion`: `angleHeld`; dynamic elbow flexion would cross into a row;
- `elbowPosture`: `nearExtended|flexed`, because elbow posture changes the
  retractor recruitment balance even when the angle is held;
- the torso-relative resistance origin or line of pull; and
- `lowerBodyContribution`: `none`.

The current family schema can encode those typed axes and their cross-field
rules. No schema extension is required. Activation would nevertheless need an
exact axis vocabulary shared with the other Batch-1 contracts before a family
file is authored.

## Starter roster gate

No exercise currently clears all of the following conditions:

1. dynamic scapular retraction is directly measured or unambiguously
   prescribed through a loaded range;
2. elbow angle is held, so the exercise is not a row;
3. the humerus does not dynamically horizontally abduct, extend, rotate, or
   elevate to create the repetition;
4. depression, elevation, upward/downward rotation, and tilt are either shown
   not to define the repetition or are modeled honestly as additional prime
   actions; and
5. the resistance geometry can be authored without inferring it from the
   exercise name.

A standing elastic or cable scapular retraction with the upper arms at the
side and elbows held flexed is the most plausible first fixture. It remains a
proposal until its coupled scapular motion and resistance geometry are reviewed
against direct evidence. A second record must add a real mechanical contrast,
not merely rename the same task with another elastic implement.

## Explicit exclusions and ownership

| Exercise or setup | Why it is outside | Owner |
|---|---|---|
| Bent-elbow cable, machine, dumbbell, barbell, or bodyweight row | Dynamic elbow flexion plus shoulder extension or horizontal abduction | Active row families |
| Reverse fly or band pull-apart | Dynamic shoulder horizontal abduction | `reverse-fly` candidate |
| Face pull with external rotation | Rowing plus deliberate shoulder external rotation | Future coupled contract, not retraction |
| Prone T or horizontal-abduction raise | Dynamic shoulder horizontal abduction, often with position-dependent scapular coupling | `reverse-fly` candidate |
| Y raise or 120-degree high retraction | Shoulder elevation and directly observed upward rotation/posterior tilt | Raise or coupled scapular contract |
| Low row with deliberate depression | Retraction plus defining scapular depression | Future depression/row boundary |
| Static shoulder-blade squeeze | Isometric task, not the proposed dynamic-strength contract | Possible future isometric family |

The family must also forbid deliberate shoulder external rotation so the
Fennell external-rotation posture cannot silently become a retraction exercise
with two prime actions. Its EMG comparison informs muscle-policy judgment; it
does not define the starter movement.

## Evidence reviewed

### Existing registry entries

- `kara-2021-scapular-retraction-abduction-angle` — DOI
  `10.4085/1062-6050-0053.21`. Elastic-resistance tasks at 0, 45, 90, and 120
  degrees of shoulder abduction; the analyzed isometric phase supports
  angle-dependent trapezius recruitment but not a universal dynamic role map.
- `fennell-2016-shoulder-retractor-row` — DOI `10.3138/ptc.2014-83`.
  Fine-wire middle-trapezius/rhomboid evidence from analyzable data in eight
  participants. It shows coactivation and an elbow-posture effect but does not
  measure scapular motion.
- `seth-2019-shoulder-work`, `gaffney-2014-trapezius-subdivisions`, and
  `werthel-2019-trapezius-transfer` retain their existing capability-profile
  roles. They support anatomy, not the existence of a clean exercise family.

### Reviewed but not registered while deferred

- Proposed ID `oyama-2010-scapular-retraction-kinematics` — Oyama S, Myers JB,
  Wassinger CA, Lephart SM, *Three-dimensional scapular and clavicular
  kinematics and scapular muscle activity during retraction exercises*, DOI
  `10.2519/jospt.2010.3018`, PMID `20195020`. This is the load-bearing reason
  for deferral: six retraction exercises produced position-dependent coupled
  scapular and clavicular motion rather than one invariant retraction-only
  signature.

Do not add the Oyama entry to `evidence.json` until an active capability,
family, or exercise cites it; unused evidence is intentionally rejected.

## Activation tests required later

If the candidate is unlocked, its family suite must include:

- exact signature, forbidden-action, role-policy, axis, rule-ID, and roster
  assertions;
- one matching and one contrasting exercise for every JSON rule;
- one mutation for every assertion inside compound rules;
- mutations adding shoulder horizontal abduction, shoulder extension, elbow
  flexion, external rotation, depression, upward rotation, and posterior tilt;
- a role mutation proving middle trapezius remains primary and that rhomboids
  cannot replace it merely because both can retract;
- exact enum coverage and numeric endpoint coverage;
- global catalog-ID, name, and alias uniqueness; and
- negative fixtures proving that a reverse fly, active row, face pull, prone T,
  and depression-biased low row cannot validate as scapular retraction.

Until both an honest roster and those boundary fixtures exist, the correct
catalog outcome is no active `scapular-retraction` family.
