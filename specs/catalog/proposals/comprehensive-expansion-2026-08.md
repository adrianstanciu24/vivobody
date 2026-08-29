# Comprehensive exercise expansion — August 2026

Status: approved and active as 20 source-exact records across 16
existing-family additions and four new family owners.

## Decision

| Fixture | Owner |
|---|---|
| Continuous Top-Start Barbell Romanian Deadlift | `romanian-deadlift` |
| Two-Dumbbell Continuous Romanian Deadlift | `romanian-deadlift` |
| Kettlebell Goblet Squat | `bilateral-squat` |
| Smith Machine Upper-Back Squat | `bilateral-squat` |
| Two-Dumbbell Rear-Foot-Elevated Split Squat | `split-stance-squat` |
| Two-Dumbbell Continuous Walking Lunge | `walking-lunge` |
| Upright Bilateral Lever-Machine Leg Extension | `knee-extension` |
| Bilateral Standing Shoulder-Pad Machine Calf Raise | `ankle-plantarflexion` |
| Bilateral Seated Thigh-Pad Machine Calf Raise | `ankle-plantarflexion` |
| Simultaneous Bilateral Dumbbell Lateral Raise | `shoulder-abduction-raise` |
| Standing Bilateral Supinated Dumbbell Curl | `elbow-flexion` |
| Bilateral Dumbbell Hammer Curl | `elbow-flexion` |
| Bilateral Rope Cable Triceps Pushdown | `elbow-extension` |
| High-Pulley Rope Face Pull with Deliberate External Rotation | `externally-rotating-face-pull` |
| Standing Bilateral Barbell Shrug | `scapular-elevation` |
| Seated Handled Lever-Machine Chest Fly | `chest-fly` |
| Supported Cable Ankle-Cuff Hip Extension | `hip-extension` |
| Seated Upper-Arm-Pad Machine Lateral Raise | `upper-arm-pad-shoulder-abduction` |
| Two-Dumbbell Forward Step-Up | `step-up` |
| Kneeling Ab-Wheel Rollout | `kneeling-ab-wheel-rollout` |

The requested generic rope face pull was narrowed to the directly supported
high-pulley fixture. A generic face-pull alias still discovers it, but the
canonical name and contract preserve the pulley height and deliberate external
rotation.

## Boundaries

- Generic Romanian Deadlift and RDL aliases now resolve to the continuous
  top-start barbell fixture; the older floor-touch history retains a qualified
  name and alias.
- Every paired-dumbbell record added by this expansion logs one dumbbell through
  `loadAccounting: perImplement` and repeats that meaning in user-facing setup
  text.
- Machine and cable-stack loads use same-fixture-only accounting where the
  mechanism prevents portable weight comparisons.
- The approximately 38-centimeter dumbbell step-up preserves unreported
  terminal trail-foot contact and descent order instead of borrowing the
  complete 21-centimeter bodyweight sequence.
- Ab Wheel is first-class equipment, but the rollout remains
  `nonComparable`, defaults to zero load, and exposes no resistance input.
- Generic `Goblet Squat` and `Ab Wheel Rollout` searches resolve through the
  canonical names rather than underspecified aliases; the catalog identities
  remain explicitly kettlebell and kneeling fixtures.

## Result

The generated runtime projection contains 82 active families, 196 exercises,
and 219 registered evidence sources. Validation, search, runtime, and UI
evidence are recorded in the
[completed execution plan](../../../engineering/plans/completed/2026-08-29-comprehensive-exercise-catalog-expansion.md).
