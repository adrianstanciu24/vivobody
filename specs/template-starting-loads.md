# Template starting loads

Status: Active product contract.

Templates own exercise order, set count, target repetitions or duration, and
supersets. A remembered starting load is a reference to recorded work, not a
progression recommendation. Completing a workout never rewrites a template.

## Load choices

- New uniform template exercises default to **Use last workout**. Compatible
  completed history supplies the starting loads. Matching requires exercise
  identity and the exact performance signature; unrelated variants never share
  loads. The template's set count and targets remain unchanged.
- Loads map in stable set order. If the template has more sets than the latest
  completed instance, repeat that instance's final load. Ignore additional
  historical sets beyond the template's set count.
- Without compatible history, use the explicitly entered first-workout load.
  Zero can be intentionally entered; it is distinct from an unset starting load.
  Creating an exercise without history requires entering a first-workout load
  before committing. Catalog weights do not prefill new template exercises.
- **Fixed load** always uses the saved weight. Explicit per-set programming is
  fixed and retains each row's repetitions, duration, and weight.
- Exercises without a resistance input omit these controls and load references.
  Assistance, added bodyweight load, and non-comparable resistance retain their
  existing semantics. Last used is the logged setting, not an effective load.

## Presentation and startup

Template editor rows use the same resolution as workout startup. Show target
structure followed by **Last used**, **Fixed**, or **Starting load**. Last used
includes its date. Mixed loads are listed in set order, with up to five entries
and an explicit remaining-set count. Template detail is an identity-only
overview: each row shows a quiet muscle-group caption and headline-weight
exercise name, without set targets or load references. Selecting the row opens
the exercise editor where its programming and resolved load live. The Today
preview shows target structure but no load reference.

The exercise editor groups load policy and input under the load mode's direct
label, such as **Weight**. With no compatible history, it says that no previous
weight was found and presents a full-width, required **Set first workout
weight** control. The commit button summarizes targets in words, such as **3
sets · 10 reps**, rather than showing detached multiplication shorthand.
Programmatically created plans may remain unset; starting one surfaces an error
identifying the exercise to configure instead of creating a workout with an
invented weight.

Workout inputs retain target reps and duration. Per-set planned-load snapshots
capture the resolved starting load, preserving accurate comparison against the
session's starting plan. Historical sessions are never rewritten.

## Persistence and existing templates

SchemaV2 adds the load policy and explicit starting-load state. The lightweight
SchemaV1 migration preserves saved loads and marks existing templates **Fixed
load**; users switch individual uniform exercises to **Use last workout** in
the editor. Explicit per-set plans stay fixed. Frozen SchemaV1 models and the
original persistence fixture remain retained.

## Verification

The focused `template-starting-loads` scenario covers editing the policy,
preview/startup agreement, preserved target reps, and relaunch persistence.
Matching light and accessibility captures inspect the editor and preview.
The `template-first-load` scenario checks explicit entry without compatible history.
The `template-starting-loads-today` scenario checks that Today and template
detail omit the load reference; the `template-starting-loads-detail` scenario
covers the direct exercise editor where the reference remains visible.
Migration and load-resolution boundary suites are user-run under the repository
verification policy.

Implementation: [resolution](../vivobody/Models/Domain/TemplateLoadResolution.swift),
[editor](../vivobody/Screens/Library/ConfigureExerciseSheet.swift),
[startup](../vivobody/App/WorkoutSessionController.swift), and
[persistence](../vivobody/App/Persistence.swift).
