# Requested pull exercises

Status: Activated in the canonical catalog on 2026-09-22.

## Request

Add the four unsupported names from the requested Pull list: Speed Pull-Up,
Prone TYWs, Single-Arm Bent-Over Row, and KB Row and Rotate.

## Decisions

- `Speed Pull-Up` expands `vertical-pull` with a neutral-grip, strict power
  fixture. The lower body remains still, every repetition reaches straight
  elbows, and the next concentric begins immediately without a bottom pause.
  The source permits neutral or supinated grip; this record deliberately
  narrows to neutral so one catalog record keeps one exact geometry.
- `Prone T-Y-W Holds` owns a new `prone-tyw-hold-sequence` family. The floor
  sequence is T, then Y, then W, with a five-second hold in each position.
  Vivobody records one aggregate 15-second hold because the current duration
  model cannot store three separately timed positions.
- `Single-Arm Bent-Over Row` expands `shoulder-extension-row` with
  `contralateralSupport: handOnBench`. Both feet remain planted, which keeps it
  distinct from the existing hand-and-knee-supported One-Arm Dumbbell Row.
- `Kettlebell Row and Rotate` owns a new `rotational-row` family because the
  strict row family forbids deliberate spinal rotation. The hips and knees
  remain still while the shoulders and upper back turn. The source body's one
  reference to a dumbbell is treated as a copy error because its title, the
  publisher image, the request, and Ruddock et al. identify a kettlebell.

## Evidence boundary

The Boxing Science library anchors the exact requested fixtures. Vigouroux et
al. and Hayashi et al. support the continuous strict pull-up boundary; Cole et
al. plus Ronai's T, Y, and W technique articles support the prone positions;
Saeterbakken et al. support unilateral-row trunk demand; and Ruddock et al.,
Sugaya et al., and the existing shoulder anatomy sources support the combined
row-and-rotation contract. These sources do not establish universal loads,
quantitative muscle rankings, medical outcomes, measured in-app velocity, or
isolated thoracic rotation.

## Rejected aliases and neighbors

`Single-Arm Dumbbell Row` remains owned by the existing hand-and-knee fixture.
`Explosive Pull-Up`, `High Pull-Up`, `Kipping Pull-Up`, and `Row and Rotate`
remain unclaimed because they can describe materially different movements.
Prone TYWs do not enter `reverse-fly`, `scapular-retraction`, or
`suspension-overhead-y-raise`; Kettlebell Row and Rotate does not enter the
strict row or generic spine-rotation families.
