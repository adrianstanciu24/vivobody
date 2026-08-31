# Current work

Goal: add the exact fourteen evidence-reviewed catalog gaps approved on
2026-08-30 without merging distinct movement or load histories.

Approved fixtures:

- 100-degree two-leg bodyweight floor squat; 90-degree bodyweight supine glute
  bridge; single-leg bodyweight heel raise with light wall balance.
- Exact 30.48-centimeter hands-elevated and feet-elevated push-ups; straight-leg
  unanchored sit-up; reverse curl/reverse crunch; 60%-height lateral lunge.
- Barbell hang power clean, floor-start power snatch, push jerk, and thruster;
  single-dumbbell pullover; glute-ham raise on a GHD.

Progress:

- All fourteen exact fixtures are authored as five existing-family expansions
  plus nine narrow new families; the generated projection is 96 families, 225
  exercises, and 248 evidence sources.
- Duplicate, biomechanics, catalog-boundary, product-semantics, exact-roster,
  mutation, generated-runtime, search, load, and routine-equipment gates pass.
- Three independent read-only reviews found no remaining evidence, ownership,
  mechanics, or deterministic-selection blocker.
- Barbell Thruster is intentionally authored as Power/Reps, keeping it outside
  hypertrophy hard-set and estimated-1RM analytics.
- `Scripts/check.sh`, 436 catalog tests, and 62 focused Swift tests pass.
- Inspected headless Baguette evidence proves `GHR` search, the one-record GHD
  Library filter, unclipped GHD detail anatomy, reps-plus-RIR/no-load GHD
  logging, `Front-Squat-to-Press` search, and weight-plus-reps/no-RIR Thruster
  logging.
- The canonical load-semantics spec now matches bodyweight, Ab Wheel, and GHD
  no-resistance behavior; the independent final diff review has no remaining
  actionable finding.

Next:

- None; ready for handoff.

User steering: add all fourteen approved fixtures; do not substitute adjacent
variants or weaken exact source and load boundaries.
