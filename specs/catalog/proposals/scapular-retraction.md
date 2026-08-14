# Scapular-retraction family proposal

Status: **resolved and activated**. The active contract is
`families/scapular-retraction.json`.

## Decision

Activate one exact dynamic fixture: McCabe et al.'s standing unilateral
Theraband scapular retraction with the shoulder held at 80 degrees of flexion
and the elbow extended.

This resolves the earlier hold without turning rows, reverse flies, pull-aparts,
face pulls, or prone raises into scapular-isolation exercises. McCabe et al.
unambiguously prescribed a loaded retraction range, held the elbow angle, and
used a reproducible elastic-resistance protocol. The paper measured EMG rather
than three-dimensional scapular kinematics, so the contract pins its exact
posture, anchor, resistance, and cadence instead of generalizing to other
named retraction tasks.

Cools et al.'s Biodex work remains supplemental role evidence only. Its
apparatus performed reciprocal concentric protraction and retraction, so it
cannot define a one-action retraction exercise or replace the McCabe fixture.

## Active boundary

The family fixes:

- `mechanic: isolation`, with no pattern or push/pull direction;
- transverse classification from `scapula.retraction`;
- `scapula.retraction` as its only prime and plane-basis action;
- every other current action as forbidden; and
- open-chain control demands at the scapula, shoulder, elbow, wrist, hand,
  spine, and pelvis.

The working shoulder is held near 80 degrees of forward flexion, the elbow is
extended, and the thumb-up forearm remains neutral. These are maintained
postures, not dynamic shoulder-flexion, elbow-extension, or forearm actions.
The band is just taut at the start and runs to the low anterior anchor shown in
the source figure. Retraction stretches the band while the glenohumeral and
elbow angles remain materially fixed.

The source used five repetitions at subject-adjusted moderate effort, a
four-second cadence split evenly between concentric and eccentric phases, and
five seconds between repetitions. All are pinned. The elastic load is
`nonComparable`: no pound or kilogram value is invented from band color or
subjective effort.

## Muscle-policy judgment

McCabe et al. reported the following mean activity during the exact retraction
task:

| Region | Mean EMG |
|---|---:|
| Upper trapezius | 62% MVIC |
| Middle trapezius | 50% MVIC |
| Lower trapezius | 51% MVIC |
| Serratus anterior | 26% MVIC |

EMG magnitude does not create an anatomical action. Middle trapezius is the
sole primary because retraction is its defining capability. Lower trapezius is
secondary: it can retract, but its broader depression, upward-rotation, and
posterior-tilt capabilities make it less specific to the one-action boundary.
Upper trapezius and serratus are stabilizers because neither produces
retraction in the foundation; their measured activity is co-contraction during
this task.

Rhomboids are anatomically capable retractors, but McCabe did not measure them
in this fixture. Fennell's static fine-wire comparison and Cools's reciprocal
machine protocol do not justify assigning rhomboid volume to this exact band
record. Rhomboids therefore remain excluded until a directly reviewed dynamic
fixture measures or otherwise establishes their role.

External rotators, triceps, extensor carpi radialis, finger flexors, and the
trunk regions are mechanics-derived stabilizers for the held shoulder, elbow,
grip, and standing posture. They receive no mover credit.

## Initial roster

| Exercise | Evidence boundary |
|---|---|
| Standing Band Scapular Retraction | Exact McCabe unilateral Theraband fixture at 80 degrees of flexion; five reps, 2-second concentric/eccentric phases, five-second inter-rep rest |

The one-record roster is intentional. A second record must add a directly
reviewed mechanical contrast, not merely use a cable or a different exercise
name.

## Explicit exclusions and ownership

| Exercise or setup | Why it is outside | Owner |
|---|---|---|
| Bent-elbow row | Dynamic elbow flexion plus shoulder extension or horizontal abduction | Active row family |
| Reverse fly or band pull-apart | Dynamic shoulder horizontal abduction | `reverse-fly` |
| Face pull | Rowing plus deliberate shoulder external rotation | Future coupled contract |
| Prone T or high retraction raise | Dynamic humeral elevation/horizontal abduction and measured 3-D scapular coupling | Raise or reverse-fly owner |
| Low row with depression | Retraction plus defining depression | Row/depression boundary |
| Static shoulder-blade squeeze | Isometric rather than the reviewed dynamic task | Possible future isometric owner |
| Biodex reciprocal protraction/retraction | Both directions are concentrically loaded | Supplemental evidence only |

Oyama et al. remain adverse boundary evidence: their prone retraction exercises
produced position-dependent external rotation, upward rotation, posterior tilt,
clavicular retraction, and depression. Those tasks do not invalidate the exact
McCabe prescription, but they prevent generalization to free-arm prone raises.

## Evidence payload

The active family expects these shared evidence entries:

- `mccabe-2007-below-90-scapular-exercises` — McCabe RA, Orishimo KF,
  McHugh MP, Nicholas SJ, *Surface Electromyographic Analysis of the Lower
  Trapezius Muscle During Exercises Performed Below Ninety Degrees of Shoulder
  Elevation in Healthy Subjects*, *North American Journal of Sports Physical
  Therapy* 2(1):34-43, 2007; PMID `21522201`; PMCID `PMC2953285`; no DOI;
  canonical URL `https://pmc.ncbi.nlm.nih.gov/articles/PMC2953285/`.
- `cools-2004-isokinetic-scapular-rotators` — Cools AM, Witvrouw EE,
  Declercq GA, Vanderstraeten GG, Cambier DC, *Evaluation of isokinetic force
  production and associated muscle activity in the scapular rotators during a
  protraction-retraction movement in overhead athletes with impingement
  symptoms*, *British Journal of Sports Medicine* 38(1):64-68, 2004; DOI
  `10.1136/bjsm.2003.004952`; PMID `14751949`; PMCID `PMC1724756`.

The McCabe scope must say that action membership comes from the prescribed
loaded range, not from EMG. The Cools scope must state that both protraction and
retraction were concentrically loaded and that the source is supplemental role
evidence rather than the active exercise fixture.

## Required integration tests

The integration suite should pin:

1. the exact signature, full forbidden complement, role policy, axes, and
   one-record roster;
2. middle trapezius as the only primary and lower trapezius as the required
   secondary;
3. upper trapezius and serratus as stabilizers rather than movers;
4. exclusion of rhomboids from the exact record;
5. the 80-degree shoulder posture, low anterior anchor, just-taut start,
   moderate five-rep effort, 2+2-second cadence, and five-second rest;
6. `nonComparable` load with zero weight seeds;
7. mutations adding shoulder horizontal abduction, shoulder extension, elbow
   flexion, external rotation, depression, upward rotation, or posterior tilt;
8. negative reverse-fly, row, face-pull, prone-T, and reciprocal-machine
   fixtures; and
9. runtime projection of the new family and exercise.
