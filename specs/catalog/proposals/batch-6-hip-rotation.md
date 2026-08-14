# Batch 6 — hip-rotation foundation review

Status: complete. The posture-conditioned anatomy migration and both narrow
exercise contracts are active. `hip-internal-rotation` uses the Lahuerta-Martín
seated 90-degree flywheel fixture; `hip-external-rotation` uses the FOHX supine
30-degree therapist-held band fixture.

## Outcome

| Candidate | Resolution | Exercises |
|---|---|---:|
| `hip-internal-rotation` | Activate one exact 90-degree fixture | 1 |
| `hip-external-rotation` | Activate one exact 30-degree fixture | 1 |

The resolution is intentionally narrower than the discovery labels. Neither
family authorizes a generic seated, standing, side-lying, cable, machine,
self-anchored-band, gait, pivoting, or combined-motion exercise. The catalog now
contains 48 real families and 124 reviewed exercises. The foundation contains
58 muscle regions, 60 trainable mesh bases, and 44 joint actions, and the
evidence registry contains 140 sources.

## Why the migration had to be atomic

Hip-rotation direction cannot be assigned from a muscle name alone. Delp et al.
showed that the modeled moment direction changes with hip-flexion posture and,
for several muscles, by compartment. The former foundation therefore could not
truthfully activate either family: TFL was the only internal-rotation producer,
whole gluteus maximus carried unconditional external rotation, and gluteus
minimus and the deep short rotators had no exact taxonomy identities.

The completed migration adds three posture conditions:

- `atNeutralHipFlexion` is constrained to `hipFlexionDegrees: 0` and is used
  only for the retained neutral-position gluteus-maximus external-rotation
  capability.
- `atThirtyDegreeHipFlexion` is constrained to `hipFlexionDegrees: 30` and is
  used by the active FOHX external-rotation family.
- `atNinetyDegreeHipFlexion` is constrained to `hipFlexionDegrees: 90` and is
  used by the active Lahuerta-Martín internal-rotation family.

The migration also adds five explicitly unvisualized exact regions:
`gluteMin`, `piriformis`, `obturatorInternusGemelli`, `obturatorExternus`, and
`quadratusFemoris`. No BodyModel.scn surface is claimed for them and no visible
region paints in their place. Obturator internus and the gemelli share one
region because the exercise evidence and Ito torque model report their
conjoined tendon together; the other short rotators remain separate. A blanket
`deepHipRotators` aggregate was rejected because these muscles do not share one
rotation direction across hip posture.

The final capability policy is posture-specific:

- `gluteMax` retains external rotation only at neutral hip flexion; its unsplit
  region receives no mover role in either active Batch-6 rotation exercise.
- `gluteMed` and `gluteMin` produce internal rotation at 90 degrees.
- `piriformis` produces external rotation at 30 degrees and internal rotation
  at 90 degrees.
- `obturatorInternusGemelli`, `obturatorExternus`, and `quadratusFemoris`
  produce external rotation at 30 degrees.
- TFL retains the condition-matched internal-rotation capability needed by the
  90-degree fixture.

These capabilities prove eligibility, not exercise involvement. Every active
role remains separately justified by the exact fixture review.

## Evidence synthesis and limits

### Position and anatomy evidence

Delp et al. measured rotation moment arms for eighteen compartments across
gluteus maximus, medius, and minimus plus iliopsoas, piriformis, quadratus
femoris, obturator internus, and obturator externus at 0, 20, 45, 60, and 90
degrees in four cadaveric specimens. It directly supports conditioned action
directions and the rejection of whole-region aggregation. It did not measure
either gemellus and does not establish exercise recruitment, role categories,
or contribution magnitudes.

Beck et al. supports gluteus minimus as a distinct anatomical region with
abduction, capsular-stabilization, and position- and fiber-dependent rotation
functions. It does not establish exercise-specific involvement or a role
ranking.

Peduzzi de Castro et al. measured maximal isometric internal- and
external-rotation force and surface EMG at 0, 45, and 90 degrees. It supports
posture-sensitive recruitment and gluteus-medius and TFL participation in a
condition-matched 90-degree internal-rotation effort. It does not supply the
dynamic flywheel topology, resolve net torque direction for an unsplit muscle,
measure deep rotators, or establish a numeric cross-muscle role ranking.

Ito et al. estimated PCSA-scaled external-rotation torque for piriformis,
obturator internus, the obturator-internus/gemelli conjoined tendon, and
obturator externus from 0 through 105 degrees. It supports position-matched
deep-rotator capability and relative mechanical capacity at 30 degrees, not
neural recruitment or an exercise role by itself. Quadratus femoris was
explicitly excluded and receives no ranking from this source.

Vaarbakken et al. measured quadratus-femoris and obturator-externus wire paths
and moment arms in three mobilized cadaver hips. Internal rotation lengthened
both muscles, supporting a possible external-rotation action, while the study
also emphasizes their other position-dependent functions. It does not measure
exercise recruitment, rank quadratus femoris in the active band fixture, or
license an undifferentiated deep-rotator aggregate.

### Exercise evidence

Lahuerta-Martín et al. supplies the exact dynamic internal-rotation fixture and
its force, power, and velocity measurement context. It measured no muscle
activity. Delp and Peduzzi de Castro therefore establish the condition-matched
role envelope; the family does not pretend that the flywheel study ranked its
muscles.

The 2017 FOHX protocol supplies the exact external-rotation topology and
progression. It does not measure deep-muscle recruitment, exact elastic force,
or the effect of this exercise in isolation. The 2020 trial confirms delivery
of the four-week, 12-session multi-exercise program and reports outcomes at 12
weeks. It supports program implementation and trainability only. It does not
establish an isolated causal outcome, individual-muscle recruitment, a role
hierarchy, or treatment advice for the general catalog user.

Previously reviewed alternatives remain outside the active roster. Hirano's
standing MRI task is not an open-chain isolation and does not authorize a
standing rotation family. Chen's seated band repetition omitted a numeric hip
and knee posture and a reproducible anchor geometry, and its surface EMG did
not measure the deep rotators. Morimoto's side-lying task was unloaded. Yeum's
program does not isolate a reproducible position-matched external-rotation
fixture. These sources are not registered because no active capability,
family, or exercise cites them.

## Active `hip-internal-rotation` contract

The single record is `seated-flywheel-hip-internal-rotation`. It preserves the
reported topology rather than generalizing the exercise name:

- unilateral open-chain rotation on a hydraulic treatment table set 75 cm
  above the floor;
- both hips and knees held at 90 degrees, both feet suspended, hands crossed
  over the opposite shoulders, and pelvis neutral;
- bilateral ASIS belts holding the pelvis and spine, plus a distal-femur belt
  preventing non-rotational hip motion;
- ankle brace and carabiner connected to the Conic Power Move cable;
- horizontally wall-fixed flywheel 7 cm above the floor, 7.5-cm mean diameter,
  460-g attached load, 15-cm axis distance, upper-middle sliding-frame
  position, and cable length matched to maximum active hip-rotation range;
- an as-fast-as-possible concentric phase followed by a return that counteracts
  generated flywheel inertia; and
- seven high-intensity work repetitions after the source's two ten-repetition
  progressive warm-up sets and three progressive repetitions.

The exercise uses `nonComparable` load semantics. The device load and geometry
are setup metadata, not a user-entered comparable weight.

`gluteMed` and `tensorFasciaeLatae` are non-ranked co-primaries. Delp found all
measured gluteus-medius compartments internally directed at 90 degrees, and
Peduzzi de Castro measured both regions during a condition-matched effort
without establishing a cross-muscle hierarchy. Unvisualized `gluteMin` is a
mechanics-derived secondary. `obliques` receive mechanics-derived stabilizer
credit for the held spine and pelvis under flywheel torque, not measured EMG or
rotation volume. Whole gluteus maximus receives no mover credit because its
unsplit fibers do not share one direction at this posture. Piriformis has a
conditioned 90-degree internal-rotation capability but receives no exercise
role: Delp reported a 14 ± 7 mm internal-rotation moment arm at 90 degrees,
compared with 26–42 mm across the gluteus-minimus compartments, and no reviewed
condition-matched source measured piriformis recruitment in this fixture.

## Active `hip-external-rotation` contract

The single record is
`therapist-held-supine-band-hip-external-rotation`. It preserves the FOHX
topology:

- unilateral open-chain rotation while supine on a treatment table;
- both hips held at 30 degrees over a wedge and both knees flexed over that
  wedge; the source does not report a numeric knee angle;
- pelvis and spine supported and position-held;
- the working knee stabilized against the support by a therapist;
- an elastic band attached at the working ankle and held by the therapist so
  it opposes external rotation; no environmental or self-anchor is inferred;
- movement from neutral to the middle of the participant's available
  external-rotation range; no unsupported numeric endpoint is invented; and
- approximately 10-to-12-RM resistance for three sets of ten.

The record uses `nonComparable` load semantics. `obturatorInternusGemelli` is
primary because the position-matched Ito model gives its conjoined tendon the
strongest reviewed mechanical case. `obturatorExternus` and `piriformis` are
mechanics-derived secondaries. `quadratusFemoris` is also secondary, supported
for external-rotation direction by Delp and Vaarbakken but not ranked by Ito,
which excluded it. `obliques` and `medialHamstrings` receive mechanics-derived
stabilizer credit for the held spine, pelvis, and flexed knee. All four mover
regions are unvisualized; no visible proxy receives mover volume or 3D paint.

Whole gluteus maximus, gluteus medius, and sartorius remain unassigned because
an anatomy-level capability does not establish exercise emphasis and their
unsplit or multi-action anatomy does not justify a categorical role in this
fixture.

## Validation closure

The completed tests pin the migration as one contract:

- exactly 58 taxonomy IDs and 60 trainable mesh bases;
- the exact unvisualized-region set and empty `meshBaseNames` for every such
  region;
- all three hip-flexion condition-to-variant constraints;
- neutral-only gluteus-maximus external rotation, 90-degree gluteus-medius and
  gluteus-minimus internal rotation, posture-opposed piriformis actions, and
  30-degree-only short-rotator external rotation;
- exact one-record family rosters, complete forbidden-action complements,
  fixed one-value or fixed-number axes, condition-matched exercise values,
  muscle-role rosters, source limitations, and direct mutation failures; and
- runtime projection parity at 48 families and 124 exercises with all 140
  evidence records referenced by active foundation or family claims.

The two former Batch-6 holds are closed. Future hip-rotation fixtures require
their own posture, topology, and role review; they do not inherit either active
family merely because their display name contains “hip rotation.”
