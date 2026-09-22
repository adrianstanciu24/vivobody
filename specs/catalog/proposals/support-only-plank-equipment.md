# Support-only equipment in plank holds

Status: owner decision required before catalog activation

## Requested fixtures

Two requested Boxing Science core-endurance fixtures are evidence-backed but cannot yet be represented truthfully by the active product contract:

- **Hands-Elevated Dumbbell Plank** (`Plank Holds w/ Hands Elevated`): a straight-arm high plank with each hand supported on a dumbbell and the feet wider than the hips. The dumbbells raise the hands; their mass is not the exercise resistance.
- **Medicine-Ball Single-Arm Plank Hold** (`Single-Arm ISO Hold`): a high-plank hold with one hand supported on a medicine ball, the other hand clear of the floor, and a small controlled turn toward the ball. The ball is a support surface; its mass is not the exercise resistance.

The exact fixture source is `boxing-science-exercise-library`. The single-arm demonstration is also available from Boxing Science at <https://www.youtube.com/watch?v=J6_DE2uSwpw>.

## Product blocker

The current runtime derives resistance tracking from `loadMode` and `equipment`. A `nonComparable` exercise with `dumbbell` or `medicineBall` equipment presents a **Resistance** input. That would invite users to log the implement mass even though the implement only changes the support geometry. Labeling either exercise `bodyweight` would avoid the input but would make equipment filtering false.

## Decision requested

Approve a shared per-exercise capability, tentatively `tracksResistance: false`, that can suppress the resistance field while preserving truthful `dumbbell` or `medicineBall` equipment classification.

If approved, activation should include:

1. the schema and runtime projection for the new capability;
2. logging UI behavior that hides resistance for these records;
3. persistent exercise, template, workout-set, and widget snapshot semantics so an old session cannot be reinterpreted when catalog metadata changes;
4. duplication, default resolution, import/normalization, migration behavior, and `ExercisePerformanceSignature` identity for the new field;
5. the two exact family contracts and mutation tests;
6. Library/detail and active-workout scenarios proving correct equipment filtering and no resistance input.

Until that decision, neither fixture is emitted into the runtime catalog. This avoids both false equipment metadata and misleading workout logging.
