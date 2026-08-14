# Batch 3 — dip and closed-chain vertical-press resolution

Status: closed. `dip` remains active as its own family. Closed-chain vertical
press is active as one strict wall-supported handstand push-up record inside
`vertical-press`; there is no parallel `closed-chain-vertical-press` family.

## Decision

| Candidate | Resolution | Active records |
|---|---|---:|
| `dip` | Active standalone family | 2 |
| `closed-chain-vertical-press` | Active branch inside `vertical-press` | 1 |

## Exact closed-chain fixture

Li et al. 2026 directly specify a strict wall-supported handstand push-up test
in male collegiate gymnasts:

- an inversion stand 10 cm from the wall;
- hand supports 20 cm wider than shoulder breadth;
- a 15 cm head-contact sponge;
- gentle feet-only wall contact;
- bottom contact between head and sponge;
- full elbow and shoulder extension at the top;
- no waist collapse and no bent legs; and
- maximum valid repetitions over 40 seconds.

The source also states that inverted push-up loading is difficult to quantify.
The active record therefore uses `bodyweight`, `reps`, and `nonComparable`, not
an invented body-mass fraction or external load. Five repetitions are merely
the editable product seed, not the source prescription.

## Action and role policy

Li et al. did not measure joint, scapular, or muscle actions. The branch reuses
the already reviewed `vertical-press` signature—shoulder flexion and abduction,
scapular upward rotation and posterior tilt, and elbow extension—as a clearly
labelled mechanics transfer. It also reuses the existing primary/secondary
mover hierarchy. This is why the record belongs in `vertical-press` rather
than creating a duplicate family ID.

Kinoshita et al. 2022 measured static upper/middle/lower trapezius, serratus,
anterior/middle deltoid, infraspinatus, and latissimus activity across
progressive handstand positions. It supports the inverted stability context
only; it does not establish dynamic handstand-push-up roles or rankings.
Wrist/hand, trunk, pelvis, hip, knee, ankle, and foot providers are stabilizers
and earn no mover volume.

## Boundary

The active branch admits only the strict wall-supported, inversion-stand,
head-target repetition. Pike, freestanding, parallettes, deficit, kipping,
waist-collapsed, bent-knee, wall-propelled, and handstand-walk variants remain
outside. `dip` remains distinct because its concentric action begins behind
neutral at the shoulder and uses a different support/loading topology.

## Resolved foundation condition: sternocostal flexion from extension

The earlier dip activation gap remains closed through the narrowly conditioned
`fromExtendedPosition` capability. Regional dip EMG and separately measured
extended-bottom-to-neutral motion form a triangulated basis, not a direct
negative-angle moment-arm result. Both dip records preserve sternocostal mover
credit, closing the prior user-visible zero-credit gap without granting broad
sternocostal flexion to neutral-start presses such as this handstand branch.

## Evidence records

- `li-2026-wall-handstand-push-up-test` — Aojie Li, Jing Tang, Kaiqi Zheng,
  Jingyi Chen, Guangshun Wang, and Daoguang Feng. DOI
  `10.1016/j.jesf.2026.200456`; PMID `41732289`; PMCID `PMC12925195`.
- `kinoshita-2022-progressive-handstand-emg` — Kazuaki Kinoshita, Yuichi
  Hoshino, Naoko Yokota, Masashi Hashimoto, Yuichiro Nishizawa, and Noriyuki
  Kida. DOI `10.3233/IES-210169`.

## Closure gates

Tests pin the exact bodyweight record, the unchanged family prime signature,
all eight fixture-only axes, both equipment-branch rules, every required
stability provider, non-comparable load semantics, source limitations, no
standalone family ID, rejection of excluded topologies, runtime projection,
vertical-push analytics classification, and mover-versus-stabilizer volume.
