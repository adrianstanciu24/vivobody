# Specification index

This is the routing table for product and engineering specifications. Status
describes the document’s relationship to the current repository, not whether
every future idea in it is shipped. “Last checked” is the date the status and
implementation links were audited against source; it is not a substitute for
runtime verification.

When adding a top-level specification, add it here in the same change. Update a
row when implementation lands, the design is superseded, or its source links
move. Expensive implementation work should also have an active plan under
[engineering/plans/active/](../engineering/plans/active/).

## Active contracts and release artifacts

| Specification | Status | Implementation or source of truth | Last checked |
|---|---|---|---|
| [Exercise Data Contract](exercise-data-contract.md) | Active domain contract | [catalog foundations](catalog/README.md), [catalog generator](../Scripts/catalog.py), [runtime catalog model](../vivobody/Models/Domain/ExerciseCatalog.swift) | 2026-08-31 |
| [Exercise catalog foundation](catalog/README.md) | Active generated-data contract | [catalog sources](catalog/), [catalog generator](../Scripts/catalog.py), [generated runtime catalog](../vivobody/Resources/catalog.json) | 2026-08-31 |
| [Family-first catalog roadmap](catalog/family-roadmap.md) | Complete roadmap; retained as catalog history | [reviewed families](catalog/families/), [proposal history](catalog/proposals/), [generated runtime catalog](../vivobody/Resources/catalog.json) | 2026-08-31 |
| [Free + Pro lifetime unlock](free-with-pro-iap.md) | Implemented product design | [entitlement owner](../vivobody/Store/ProStore.swift), [purchase surface](../vivobody/Store/PaywallSheet.swift), [app state](../vivobody/App/AppState.swift), [widget fallback](../vivobodyWidgets/WidgetChrome.swift) | 2026-08-14 |
| [HealthKit Tier A](healthkit-tier-a.md) | Implemented integration design | [HealthKit boundary](../vivobody/HealthKit/HealthKitWorkoutService.swift), [session fan-out](../vivobody/App/SessionSideEffects.swift), [settings surface](../vivobody/Screens/Me/SettingsScreen.swift) | 2026-08-14 |
| [App Store Connect metadata](appstore-metadata.md) | Release artifact; recheck before submission | [shared version](../Shared.xcconfig), [app metadata](../vivobody/Info.plist), [privacy manifest](../vivobody/PrivacyInfo.xcprivacy), [public website](https://vivobody.app) | 2026-08-14 |
| [Exercise Detail frequency & weekly volume](exercise-detail-frequency-and-volume.md) | Implemented product design | [contribution model](../vivobody/Models/Insights/ExerciseVolumeContribution.swift), [frequency model](../vivobody/Models/Insights/ExerciseFrequency.swift), [hero card](../vivobody/Screens/Library/ExerciseBestHeroCard.swift), [this-week section](../vivobody/Screens/Library/ExerciseWeeklyVolumeSection.swift) | 2026-08-15 |
| [Exercise comparison](exercise-comparison.md) | Implemented product design | [comparison model](../vivobody/Models/Domain/ExerciseComparison.swift), [comparison screen](../vivobody/Screens/Library/ExerciseComparisonScreen.swift), [entry point](../vivobody/Screens/Library/ExerciseDetailScreen.swift), [comparison tints](../vivobody/Models/Domain/MuscleColor.swift) | 2026-08-21 |
| [Exercise substitution](exercise-substitution.md) | Implemented product design | [ranker](../vivobody/Models/Domain/ExerciseSubstitution.swift), [replacement sheet](../vivobody/Screens/ActiveWorkout/ExerciseSubstitutionSheet.swift), [session transaction](../vivobody/App/WorkoutSessionController.swift), [completed execution plan](../engineering/plans/completed/2026-08-22-exercise-substitution.md) | 2026-08-22 |
| [Insights visual instruments](insights-visual-instruments.md) | Implemented product design | [Insights screen](../vivobody/Screens/Insights/InsightsScreen.swift), [completed execution plan](../engineering/plans/completed/2026-08-22-insights-visual-instruments.md) | 2026-08-22 |
| [Strength Routine Builder](strength-routine-builder.md) | Implemented, temporarily hidden | [planner](../vivobody/Models/Domain/StrengthRoutineBuilder.swift), [review screen](../vivobody/Screens/Library/StrengthRoutineBuilderScreen.swift), [atomic batch boundary](../vivobody/Screens/Library/StrengthRoutineTemplateBatch.swift), [completed execution plan](../engineering/plans/completed/2026-08-22-strength-routine-builder.md) | 2026-08-24 |

## Historical and superseded implementation records

These documents retain reasoning and calibration history. Read the newer
contract and current implementation before applying their details.

| Specification | Status | Current implementation or successor | Last checked |
|---|---|---|---|
| [Muscle map as training attention](muscle-attention-simplification.md) | Historical implementation record; persistence details superseded by the family-first model | [set stimulus](../vivobody/Models/Insights/SetStimulus.swift), [muscle development](../vivobody/Models/Insights/MuscleDevelopment.swift), [Exercise Data Contract](exercise-data-contract.md) | 2026-08-14 |
| [Hard-set-equivalent currency](hard-set-currency.md) | Superseded | [Muscle map as training attention](muscle-attention-simplification.md), [current set stimulus](../vivobody/Models/Insights/SetStimulus.swift) | 2026-08-14 |
| [Simplify the muscle development model](simplify-muscle-model.md) | Implemented, then further simplified | [Muscle map as training attention](muscle-attention-simplification.md), [current muscle development](../vivobody/Models/Insights/MuscleDevelopment.swift) | 2026-08-14 |
| [Fix the muscle-development model](muscle-model-fixes.md) | Implemented historical repair record | [muscle development](../vivobody/Models/Insights/MuscleDevelopment.swift), [body renderer](../vivobody/Components/Displays/BodyModelScene.swift), [tests](../vivobodyTests/) | 2026-08-14 |

## Research, not an implementation contract

| Specification | Status | Implementation link | Last checked |
|---|---|---|---|
| [WatchConnectivity research](watchconnectivity-research.md) | Research only; no watch target | None. Start with an execution plan before adding targets or sync ownership. | 2026-08-14 |
| [watchOS architecture research](watchos-architecture-research.md) | Research only; no watch target | None. Revalidate Apple platform facts when work starts. | 2026-08-14 |

## Catalog subdocuments

`specs/catalog/families/` is the reviewed machine-readable source. The
`specs/catalog/proposals/` Markdown files are evidence-backed discovery and
decision history; their own status statements say whether a proposal was
activated, held, merged, or retired. Do not treat proposal prose as runtime
input. The catalog validator and generated resource are the implementation
evidence.
