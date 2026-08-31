# Default catalog gap closure — August 2026

Status: approved and active as 14 source-bounded records across five existing
families and nine new family owners.

## Decisions

| Catalog ID | Canonical name | Owner |
|---|---|---|
| `bodyweight-floor-squat-100-degrees` | 100° Two-Leg Bodyweight Floor Squat | `bilateral-squat` |
| `bodyweight-supine-glute-bridge-90-degrees` | 90° Bodyweight Supine Glute Bridge | `bodyweight-glute-bridge` |
| `wall-balanced-single-leg-bodyweight-heel-raise` | Wall-Balanced Single-Leg Bodyweight Heel Raise | `ankle-plantarflexion` |
| `hands-elevated-push-up-30-48-cm` | 30.48 cm Hands-Elevated Push-Up | `decline-press` |
| `feet-elevated-push-up-30-48-cm` | 30.48 cm Feet-Elevated Push-Up | `incline-press` |
| `straight-leg-unanchored-sit-up` | Straight-Leg Unanchored Sit-Up | `straight-leg-sit-up` |
| `supine-reverse-crunch` | Supine Reverse Crunch | `supine-pelvic-curl` |
| `bodyweight-lateral-lunge-60-percent-height` | 60%-Height Bodyweight Lateral Lunge | `lateral-lunge` |
| `barbell-hang-power-clean` | Barbell Hang Power Clean | `hang-power-clean` |
| `barbell-power-snatch-from-floor` | Barbell Power Snatch from Floor | `power-snatch` |
| `barbell-push-jerk` | Barbell Push Jerk | `push-jerk` |
| `barbell-thruster` | Barbell Thruster | `thruster` |
| `two-hand-single-dumbbell-pullover` | Two-Hand Single-Dumbbell Pullover | `shoulder-extension-isolation` |
| `ghd-glute-ham-raise` | GHD Glute-Ham Raise | `glute-ham-raise` |

## Product and family boundaries

- Unloaded squat, bridge, heel-raise, sit-up, reverse-crunch, lateral-lunge,
  and GHD fixtures use `nonComparable` load and expose no resistance input.
- Hands-elevated and feet-elevated push-ups remain separate histories inside
  their action-compatible press owners. Their 0.55 and 0.70 bodyweight shares
  are disclosed cohort-average peak-force proxies, not user-specific loads.
- Hang Power Clean, Power Snatch, Push Jerk, and Thruster use ordered phases,
  Power modality, repetitions, and one complete external barbell load.
- The pullover logs its one shared dumbbell once. The GHD is first-class
  equipment, while this unweighted glute-ham-raise fixture remains
  non-comparable so it cannot create false pound-based analytics.
- Straight-Leg Sit-Up and Supine Reverse Crunch remain separate owners: the
  latter owns spinal/pelvic curling without borrowing a dynamic hip-flexion
  prime action.

## Evidence and result

The source contracts register the exact squat, bridge, calf-raise, push-up,
trunk-flexion, lateral-lunge, Olympic-lift, thruster, pullover, and glute-ham
raise evidence used by each fixture. Exercise-specific claims and transferred
anatomy or mechanics are labeled separately in the source scopes.

All 14 records pass duplicate, family-boundary, forbidden-action-complement,
mutation, generated-runtime, search, load-semantics, and routine-equipment
contracts. The active projection contains 96 families, 225 exercises, and 248
registered evidence sources.
