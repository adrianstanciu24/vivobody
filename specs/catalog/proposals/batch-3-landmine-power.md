# Batch 3 — nonstandard press resolution

Status: closed. `landmine-press` is active as one bounded power-test family;
`leg-driven-overhead-press` remains active as `push-press`. These contracts do
not merge because their resistance geometry, lower-body contribution, and
reviewed outcomes differ.

## Decision

| Candidate | Resolution | Active records |
|---|---|---:|
| `landmine-press` | Activate narrow split-stance pivoted-bar power test | 1 |
| `leg-driven-overhead-press` | Active as `push-press` | 1 |

## Landmine fixture

Zhao et al. 2026 directly tested a right-arm standing landmine press in 24
trained male collegiate athletes. The left foot was forward, the right foot
back, both toes faced forward, and the moving sleeve began near the deltoid.
The Olympic bar was fixed at its far end; total bar-plus-plate loads were 20,
25, 30, and 35 kg, with three repetitions per condition. Video and GymAware
measured the moving bar endpoint and power-related outputs.

The active record preserves that exact topology as
`standing-single-arm-landmine-press-power-test`. It is a unilateral
barbell/external-load/power/repetition record with a 20 kg (45 lb) starting
seed, and it instructs users to log total bar plus plates. The opposite side is
logged separately with the stance mirrored.

## Evidence boundary

Zhao et al. did not track the athlete's shoulder, elbow, scapula, torso,
pelvis, or lower limbs. Its simplified sagittal model follows bar endpoints,
not human joint angles. Therefore all of the following are explicit bounded
catalog adaptations rather than direct findings:

- `direction: diagonal` and the sagittal `shoulder.flexion` model;
- `elbow.extension` as the second prime action;
- strict absence of deliberate leg drive;
- mirroring the right-arm protocol to the left side; and
- the deltoid-anterior / triceps / clavicular-pectoralis role hierarchy.

No scapular prime action is claimed. Serratus and upper/lower trapezius are
stabilizers only. A future source may justify a different family, but it may
not broaden this one silently.

## Contract boundary

The active family admits only the reviewed standing, unilateral, split-stance,
single-arm pivoted-bar topology. Half-kneeling, tall-kneeling, bilateral,
two-hand, rotational, squat-to-press, explosive throw, Viking-press, free-bar,
cable, machine, and intentional torso-lean variants remain outside. `push-press`
continues to own deliberate countermovement and triple-extension propulsion;
strict `vertical-press` owns overhead external-load presses without the
landmine pivot.

## Evidence record

- `zhao-2026-landmine-press-kinematics` — Rui Zhao, Rong Cong, Ruijie Zhou,
  Kelong Lin, Jianke Yang, Tongchun Kui, Jiajin Zhang, Ran Wang, Rou Dong, and
  Kaihua Zhang. *Landmine Press Kinematics Measured with an Enhanced YOLOv8
  Model and Mathematical Modeling*. Sensors. 2026;26(4):1161. DOI
  `10.3390/s26041161`; PMID `41755100`; PMCID `PMC12944738`.

## Closure gates

Activation is complete only while tests pin:

1. the exact one-record roster and all classification/load fields;
2. the two-prime / 42-forbidden full action partition;
3. every required role and stability provider;
4. every required axis and its one allowed value;
5. total-bar-plus-plates accounting, three repetitions, and 20 kg seed;
6. source/right-side and adaptation limitations;
7. rejection of lower-body primes, scapular primes, kneeling, rotation,
   bilateral, throw, and Viking-press mutations; and
8. exact generated runtime projection and diagonal-push analytics behavior.
