# Semantic verification scenarios

Run a scenario through the normal build, simulator, and installation path:

```bash
SCENARIO=active-restoration Scripts/verify.sh
```

Each JSON file declares an initial `launch`, ordered `steps`, and final
`required` / `forbidden` accessibility selectors. Outputs land in
`.verify/scenarios/<name>/` as a screenshot, UI tree, runtime log, action trace,
and result JSON. Screenshots are evidence for review; the pass/fail decision is
made from accessibility semantics and any declared diagnostic-log contracts.

## Choose evidence for the change

Use this map to pick a starting flow, then read its JSON before running it.
Run the smallest relevant unit suite when logic changes. These are entry points,
not a request to run every linked scenario or suite. The
[complete generated directory](index.md) lists every scenario and its initial
launch arguments, including fixture, entitlement, appearance, and text-size flags.

| Feature | Starting flows | Additional states to consider | Focused logic suites |
|---|---|---|---|
| Today and start/resume | [today-actions](today-actions.json), [today-up-next](today-up-next.json) | Empty, scheduled, active, and restored states in `today-actions`; [journal semantic grouping](today-journal-accessibility.json) | [TodayUpNextPresentationTests](../../vivobodyTests/TodayUpNextPresentationTests.swift), [UpNextTests](../../vivobodyTests/UpNextTests.swift) |
| Active sets and rest | [start-complete-rest](start-complete-rest.json), [superset completion](active-superset-completion.json) | [Restoration](active-completion-restoration.json), [zero-set recovery](active-zero-set-recovery.json), `active-*` tracking variants in the directory; save-failure paths are unit contracts | [ActiveSetCompletionTests](../../vivobodyTests/ActiveSetCompletionTests.swift), [WorkoutSessionArchiveFailureTests](../../vivobodyTests/WorkoutSessionArchiveFailureTests.swift) |
| Active exercise replacement | [replacement](replace-active-exercise.json), [substitution sheet](exercise-substitution-sheet.json) | [Blocked replacement](replace-active-exercise-blocked.json) | [WorkoutExerciseReplacementTests](../../vivobodyTests/WorkoutExerciseReplacementTests.swift), [ExerciseSubstitutionTests](../../vivobodyTests/ExerciseSubstitutionTests.swift) |
| Receipts and archive | [receipt parity](receipt-metric-parity.json), [archive-to-history](archive-to-history.json) | Live summary in [dark](receipt-live-summary.json), [light](receipt-live-summary-light.json), and [Accessibility XXXL](receipt-live-summary-accessibility.json) | [WorkoutReceiptMetricTests](../../vivobodyTests/WorkoutReceiptMetricTests.swift), [SessionInsightsTests](../../vivobodyTests/SessionInsightsTests.swift) |
| Workout load comparison | [History placement](workout-load-comparison.json) | Live summary in [dark](workout-load-comparison-live.json), [light](workout-load-comparison-live-light.json), and [Accessibility XXXL](workout-load-comparison-live-accessibility.json); unavailable/partial load in model tests | [WorkoutLoadComparisonTests](../../vivobodyTests/WorkoutLoadComparisonTests.swift) |
| Library, picker, and catalog edits | [Library filters](library-training-role-filters.json), [picker filters](exercise-picker-training-role-filters.json), [custom exercise](custom-exercise-type.json) | [Assistance editor](custom-exercise-assistance.json); choose the relevant `catalog-*` fixture from the directory | [ExerciseCatalogBrowserTests](../../vivobodyTests/ExerciseCatalogBrowserTests.swift), [CatalogMutationBoundaryTests](../../vivobodyTests/CatalogMutationBoundaryTests.swift); `test_catalog.py` for authored JSON |
| Exercise detail | [hero](exercise-detail-hero.json), [weekly volume](exercise-detail-weekly-volume.json) | [Locked](exercise-detail-weekly-volume-locked.json), [dormant chart](exercise-detail-dormant-chart.json), [single session](exercise-detail-single-session-point.json); `exercise-execution-*` tracking variants | [ExerciseDetailReadModelTests](../../vivobodyTests/ExerciseDetailReadModelTests.swift), [ExerciseVolumeContributionTests](../../vivobodyTests/ExerciseVolumeContributionTests.swift), [ExerciseDetailChartPresentationTests](../../vivobodyTests/ExerciseDetailChartPresentationTests.swift) |
| Exercise comparison | [comparison](exercise-comparison.json), [picker](exercise-comparison-picker-filters.json) | [Locked](exercise-comparison-locked.json), [hidden during workout](exercise-comparison-active-workout-hidden.json), picker [light](exercise-comparison-picker-filters-light.json) and [large text](exercise-comparison-picker-filters-accessibility.json) | [ExerciseComparisonTests](../../vivobodyTests/ExerciseComparisonTests.swift), [ExerciseSearchTests](../../vivobodyTests/ExerciseSearchTests.swift) |
| Insights | [showcase](insights-showcase.json), [load drivers](insights-load-rep-drivers.json), [Shape details](insights-shape-drillouts.json) | [Empty](insights-empty.json), [locked](insights-locked.json), [hard-set fallback](insights-hard-sets.json), [large text](insights-accessibility.json) | [TrainingLoadTests](../../vivobodyTests/TrainingLoadTests.swift), [TrainingSignatureTests](../../vivobodyTests/TrainingSignatureTests.swift), [AntagonistBalanceTests](../../vivobodyTests/AntagonistBalanceTests.swift); choose the changed instrument's suite |
| Insights training dimensions | [Movement coverage](insights-movement-coverage.json), [muscle roles](insights-muscle-directness.json), [stamina](insights-stamina.json) | Matching `-light` and `-accessibility` variants; [family gaps](insights-movement-gaps.json), [primary examples](insights-muscle-primary.json), [matched series](insights-stamina-series.json), [held back](insights-stamina-held-back.json), [building](insights-dimensions-building.json), [locked](insights-dimensions-locked.json); [Exercise Detail](exercise-detail-stamina.json) and its variants | [MovementCoverageTests](../../vivobodyTests/MovementCoverageTests.swift), [MuscleDirectnessTests](../../vivobodyTests/MuscleDirectnessTests.swift), [SetSeriesStaminaTests](../../vivobodyTests/SetSeriesStaminaTests.swift), [CatalogMovementMetadataTests](../../vivobodyTests/CatalogMovementMetadataTests.swift) |
| Routine builder (DEBUG only) | [build](strength-routine-builder.json), [review](strength-routine-builder-review.json) | [Public entry hidden](strength-routine-builder-hidden.json), [insufficient catalog](strength-routine-builder-insufficient-catalog.json), [template cap](strength-routine-builder-template-cap.json), [picker contract](strength-routine-picker-contract.json) | [StrengthRoutineBuilderTests](../../vivobodyTests/StrengthRoutineBuilderTests.swift), [StrengthRoutineSaveTests](../../vivobodyTests/StrengthRoutineSaveTests.swift) |
| Me and settings | [Me showcase](me-showcase.json), [preferences](settings-preferences.json) | Device-only feedback, permissions, purchases, and system handoffs remain separate checks | [MePresentationTests](../../vivobodyTests/MePresentationTests.swift), [SettingsInteractionPolicyTests](../../vivobodyTests/SettingsInteractionPolicyTests.swift), [ProStatusTests](../../vivobodyTests/ProStatusTests.swift) |
| External actions and widgets | [deep link](deep-link-insights.json), [widget start](widget-start-handoff.json) | Missing/old/malformed snapshot payloads in shared contract tests; real widget presentation on device when affected | [WidgetSnapshotCodecTests](../../VivoKit/Tests/VivoKitTests/WidgetSnapshotCodecTests.swift); `swift test --package-path VivoKit` |

For changed UI, inspect light and dark appearances and relevant accessibility
states even when there is no named variant in this table. Read the launch
arguments and steps: a semantic accessibility test does not automatically test
large text or VoiceOver behavior on a device. Use the launch options in
[verification.md](../../engineering/verification.md#headless-ui-verification-with-baguette)
for additional captures. Do not use a default Today capture as proof of an
unrelated feature change.

When adding or changing a scenario, regenerate `index.md` with
`/usr/bin/python3 Scripts/documentation_inventory.py --write` from the root.
Update this curated map when the recommended starting flow or evidence changes.
The documentation checker rejects a stale generated directory.

## Runtime log assertions

Scenarios may also declare `requiredLogs` and `forbiddenLogs` as arrays of
literal substrings. These assertions read the captured unified `runtime.log`
and are reserved for stable privacy-safe `AppDiagnostics` events, not Apple
framework chatter or user-owned values.

## Launch

- `reset`: adds `--ui-test-reset` when true.
- `tab`: adds `--verify-tab <tab>`.
- `arguments`: additional deterministic debug launch arguments. Pass
  `--static-body` on any scenario that lands on a screen with the 3D body
  model: the idle turntable starves the simulator's accessibility bridge
  (polls return skeleton trees) and makes screenshots nondeterministic.

## Steps

- `wait`: poll until at least one visible element matches a selector.
- `waitAbsent`: poll until no visible element matches a selector.
- `tap`: require one visible match and tap its on-screen midpoint.
- `scrollTo`: swipe in the declared direction until its semantic `selector`
  becomes visible; coordinates are derived from the application frame.
- `swipe`: perform `count` blind swipes in the declared `direction` with no
  selector. Use it to nudge content clear of the tab bar before tapping a
  row that `scrollTo` leaves half-covered at the screen edge.
- `assert`: poll `required` and `forbidden` selector arrays together.
- `relaunch`: terminate and launch again with a new launch object. State is
  preserved unless `reset` is true.
- `openURL`: open a URL through `simctl` and let the app's real deep-link path
  handle it.

## Selectors

Selectors can combine exact `identifier`, `label`, `role`, and `value` fields.
Text fields also accept `identifierContains`, `labelContains`, `valueContains`,
and their `*Regex` counterparts. `visible` defaults to true; visibility requires
the element frame to intersect the application frame. `enabled` is optional.

Tap selectors must resolve to exactly one visible element. Required selectors
may match one or more elements. Ambiguous taps and malformed selectors fail
with candidate paths and semantic values in `actions.log`.

## Today action contract

`today-actions` exercises the pinned start/active states and both chooser
hierarchies in one deterministic run. Its Today taps are intentional uniqueness
assertions: an accidental second matching action makes the scenario fail before
interaction. The existing `start-complete-rest` flow chooses the featured plan
and proves the scheduled start through set completion.

- Empty, unscheduled Today exposes one generic `Start Workout`, with no
  scheduled or active action and no empty Consistency / Last workout journal.
- A due template keeps the same single `Start Workout` action. Its chooser
  features `Start Today's Plan` first, then Fresh, Repeat, and other saved
  templates without duplicating the featured plan.
- An active workout wins over a simultaneously due template and exposes one
  `Resume Workout` action, with no start action present;
  the final relaunch also proves that restored state keeps the same hierarchy.

`today-journal-accessibility` scrolls a fixed history seed to the compact
Consistency journal and requires one exact two-week overview plus its detail
drill-out. It forbids the former per-day `Rest` / `Trained` values so the
fourteen visual dots cannot silently return as fourteen VoiceOver stops.

`insights-load-rep-drivers` scrolls the showcase history to Training load and
requires the centered seven-day Sessions, 1–5 reps, and 6–12 reps driver cells.
