# Comprehensive exercise catalog expansion

## Outcome

- Status: completed
- Started: 2026-08-29
- Completed: 2026-08-29
- Governing contracts: [catalog foundation](../../../specs/catalog/README.md),
  [exercise data contract](../../../specs/exercise-data-contract.md), and
  [exercise-addition workflow](../../../.agents/skills/vivobody-add-exercise/SKILL.md)

Added all twenty owner-approved exercise fixtures from the 2026-08-29 catalog
audit. Every active record has source-bounded mechanics, a stable history
identity, explicit load semantics, mutation coverage, generated runtime output,
and inspected Library/detail evidence.

## Goal and non-goals

The expansion closes identified lower-body, arm, shoulder, chest, core, and
machine-fixture gaps without merging mechanically different histories. It does
not restore Conditioning or Mobility, redesign workout screens, claim portable
machine-load equivalence, create quantitative muscle rankings, or generalize a
reviewed fixture into neighboring variants.

## Delivered fixtures

### Existing-family additions

- Continuous Top-Start Barbell Romanian Deadlift
- Two-Dumbbell Continuous Romanian Deadlift
- Kettlebell Goblet Squat
- Smith Machine Upper-Back Squat
- Two-Dumbbell Rear-Foot-Elevated Split Squat
- Upright Bilateral Lever-Machine Leg Extension
- Bilateral Standing Shoulder-Pad Machine Calf Raise
- Bilateral Seated Thigh-Pad Machine Calf Raise
- Simultaneous Bilateral Dumbbell Lateral Raise
- Standing Bilateral Supinated Dumbbell Curl
- Bilateral Dumbbell Hammer Curl
- Bilateral Rope Cable Triceps Pushdown
- Standing Bilateral Barbell Shrug
- Seated Handled Lever-Machine Chest Fly
- Supported Cable Ankle-Cuff Hip Extension
- Two-Dumbbell Forward Step-Up

### New family owners

- `walking-lunge`: Two-Dumbbell Continuous Walking Lunge
- `externally-rotating-face-pull`: High-Pulley Rope Face Pull with Deliberate
  External Rotation
- `upper-arm-pad-shoulder-abduction`: Seated Upper-Arm-Pad Machine Lateral Raise
- `kneeling-ab-wheel-rollout`: Kneeling Ab-Wheel Rollout

## Resolved contracts

- `specs/catalog/` remains canonical; `Scripts/catalog.py` generated the runtime
  projection with digest `096e6f51c01e`.
- Paired-dumbbell fixtures added or materially revised here record one dumbbell
  through `loadAccounting: perImplement` and say so in setup text.
- Smith, selectorized-machine, and cable-stack loads compare only within the
  same catalog fixture when mechanisms prevent portable comparisons.
- The step-up pins the sourced platform height and leaves unreported terminal
  trail-foot contact and descent order unclaimed.
- Ab Wheel is first-class equipment. Kneeling rollout remains
  `nonComparable`, defaults to zero load, and exposes no resistance input.
- Generic Goblet Squat and Ab Wheel Rollout searches work through canonical-name
  token matching rather than underspecified aliases.
- New coupled-action families retain negative boundaries against their closest
  row, raise, isolation, plank, and lunge neighbors.

## Milestones

- [x] Complete independent evidence, family-boundary, and product-semantics
      packets for all twenty exact fixtures.
- [x] Resolve the step-up geometry and ab-wheel equipment/load representation.
- [x] Integrate shared semantics and existing-family expansions with mutation
      coverage.
- [x] Add four new family contracts and cross-family negative tests.
- [x] Register only evidence referenced by active claims and update catalog
      documentation/counts.
- [x] Regenerate runtime output and pass catalog validation and targeted tests.
- [x] Complete independent post-draft reviews and repair concrete failures.
- [x] Pass `Scripts/check.sh` and inspect representative Library, detail, and
      active-workout screenshot and accessibility evidence.
- [x] Review the final diff and record the results.

## Verification

- `python3 Scripts/catalog.py --check`: passed; 58 muscles, 60 mesh bases,
  44 joint actions, 219 evidence sources, 83 contracts including the synthetic
  validation fixture, digest `096e6f51c01e`.
- `python3 -m unittest Scripts.tests.test_catalog`: 424 tests passed.
- `BiomechanicsDomainTests`, `CatalogBiomechanicsTests`, and
  `ExerciseSearchTests`: 51 targeted Swift tests passed; the final alias-only
  adjustment was followed by a 22-test `ExerciseSearchTests` pass.
- `Scripts/check.sh`: passed, including architecture, documentation, naming,
  source-size, complexity, formatting, generated-data, snapshot, and build
  gates.
- `catalog-comprehensive-expansion`, `catalog-machine-expansion`,
  `catalog-cable-expansion`, `catalog-ab-wheel-expansion`, and
  `active-ab-wheel-no-load`: passed with inspected screenshots and
  accessibility trees under `.verify/scenarios/`.
- `git diff --check`: passed.

## Review record

Three independent read-only reviews covered biomechanics/evidence,
family/taxonomy/load boundaries, and lifter-facing product semantics. Their
corrections narrowed source claims and aliases, made same-fixture and
per-implement loads explicit, removed unsupported muscle ownership, and fixed
stale axis descriptions. All three final reviews reported no blockers.

The final generated projection contains 82 production families, 196 exercises,
and 219 registered evidence sources. No hardware-specific integration changed;
the simulator evidence covers the new user-visible catalog and logging
semantics.
