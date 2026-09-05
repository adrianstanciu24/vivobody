# Insights training dimensions

- Status: completed 2026-09-05
- Authorized: implementation requested 2026-09-05.

## Outcome

Show where training moves, which muscles receive direct versus indirect work,
and how reps hold across equal-load sets. Charts lead; explanations and full
rosters live in drill-outs. Keep the existing ordered Insights scroll and Pro
boundaries. Exercise Detail also shows its own stamina series and trend.

## Contracts and invariants

These describe the initial implementation. The all-time follow-up below supersedes
the original date windows and pattern-change baseline.

- Follow [Insights](../../../specs/insights-visual-instruments.md),
  [architecture](../../../ARCHITECTURE.md), and [verification](../../verification.md).
- Movement Coverage uses 28-day hard-set equivalents, splitting each exercise's
  credit equally across unique authored planes. Unknown classification and
  family coverage remain explicit. Project reviewed produced, resisted, and
  yielding actions without changing authored biomechanics.
- Direct/indirect work retains SetStimulus pricing and snapshotted primary 1.0 /
  secondary 0.5 roles. Stabilizers receive no volume. Catalog examples are
  descriptive primary-target examples, never prescriptions.
- Stamina requires archived dynamic-strength rep series with at least three
  consecutive completed positive-rep sets at identical logged weight. Invalid,
  incomplete, or changed-weight sets break a run. Higher logged RIR relative to
  an earlier rated set flags a held-back series and excludes it from aggregate
  retention. Unlogged RIR remains unknown. Trends compare the same exercise,
  load semantics, weight, and series length.
- No SwiftData schema, logging, rest timer, widget, or active-workout changes.

## Milestones

1. Project family/action metadata; add snapshot family identity and pure reports.
2. Integrate cached reports and visual sections, drill-outs, and exercise detail.
3. Add deterministic logic tests and focused UI fixtures/scenarios.
4. Run canonical gate, focused Swift tests, and inspect light/dark/accessibility
   evidence. Update active specs and complete this plan.

## Risks and recovery

Miscounted multiplane credit, treating resisted actions as produced, indirect
credit presented as literal sets, and unmatched stamina trends are the main
semantic risks. Deterministic tests cover these boundaries. All new data is
derived; rollback is removal of these changes and regeneration of catalog.json
from the unchanged family sources. Keep unrelated work intact.

## Evidence

All four milestones completed. The report remains Shape → Load → Rhythm →
Balance: coverage follows Shape, stamina follows Load, and muscle roles follow
Balance. Exercise Detail reuses the same stamina instrument after Effort and
before Recent sessions. Explanations and full rosters live in drill-outs.

| Check | Result and evidence |
| --- | --- |
| Canonical gate | `Scripts/check.sh` passed after the final Swift changes; `.verify/insights-check-final.log` and `.verify/check-build.log`. |
| Focused Swift tests | 113 tests across nine suites passed; `.verify/insights-tests.log`. Suites: `MovementCoverageTests`, `MuscleDirectnessTests`, `SetSeriesStaminaTests`, `CatalogMovementMetadataTests`, `CatalogBiomechanicsTests`, `BiomechanicsDomainTests`, `SessionAnalyticsConcurrencyTests`, `ExerciseDetailReadModelTests`, and `DebugSeedRoutingTests`. |
| Catalog projection | 441 Python catalog tests passed with `python3 -m unittest discover -s Scripts/tests -p 'test_catalog*'`; `.verify/insights-catalog-tests.log`. Removing the two new generated metadata keys produces the exact pre-change catalog records. |
| Headless UI | All 21 new scenarios and the existing `insights-showcase` passed on iPhone 17 Pro, iOS 26.5. Results, screenshots, and accessibility trees are in `.verify/scenarios/`. |
| Accessibility settings | The three entry instruments and held-back drill-out passed with both Reduce Motion and Differentiate Without Color enabled through iOS Settings. Setting-state trees, four scenario results, and settled screenshots are in `.verify/insights-accessibility-settings/`. Original settings were restored. |

The focused Swift run used `xcodebuild -scheme vivobody -destination
'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO test`
with an `-only-testing:vivobodyTests/<Suite>` argument for each suite above.
Scenario commands and variants are indexed in
[the scenario map](../../../Scripts/verify_scenarios/README.md).

Inspected settled light/dark screenshots, largest Dynamic Type, plane gaps,
primary exercise examples, the matched-load trend, held-back series, building
states, Pro locks, and Library navigation to Exercise Detail. Large-text review
led to stacked metric layouts and more room for rep annotations; trend endpoints
remain readable. The three entry links expose button traits and numeric summaries
in the accessibility tree. Shape, labels, and position carry meaning alongside
color; stamina does not animate a required interpretation.

The existing catalog count assertions were stale before this work: baseline
`49f4c39` already contained 231 records in 97 families. Updated those assertions
to the verified baseline. Authored exercises and family mechanics are unchanged.

No data migration is required. Missing family/plane metadata and unrated effort
remain explicit; held-back series cannot create a pattern or matched-load trend.
Actual VoiceOver traversal and speech remain a physical-device check. Headless
evidence covers exposed semantics, frames, navigation, and accessibility states.
No implementation work remains.

## Follow-up: all-time history

The user subsequently requested all three instruments show all time. Movement
Coverage and Direct vs. Indirect now include every qualifying completed workout
through the report date. Plane/action gaps, muscle totals, sources, and empty-state
copy use the same scope. Future and live sessions remain excluded.

Stamina retains all qualifying archived series for pattern averages, exercise
drill-outs, and Exercise Detail. Pattern changes compare first and latest dates
at each matching prescription, averaging runs that share an endpoint timestamp
before averaging the matched differences. One timestamp cannot create a trend.
The higher-RIR, weight, modality, and matching eligibility gates still apply.

The three cards and their accessibility summaries say “All time.” Stamina date
labels show years when needed. The verification fixture now includes a workout
370 days old; the stamina card asserts eight push series at 70% retention.

Follow-up validation: 31 tests in `MovementCoverageTests`, `MuscleDirectnessTests`,
and `SetSeriesStaminaTests` passed, including two-year-old coverage, role credit,
matched trends, and cached Exercise Detail history. `Scripts/check.sh` passed after
the final source and scenario updates. Sixteen focused headless scenarios passed
with light/dark, largest text, plane gaps, muscle examples, stamina history,
Exercise Detail, and building-state evidence.

Logs: `.verify/insights-all-time-tests.log`, `.verify/insights-all-time-check.log`.
Scenario results and settled screenshots: `.verify/insights-all-time/`.

The three entry instruments and the Insights stamina history also passed with
Reduce Motion and Differentiate Without Color enabled. Largest-text screenshots
keep both endpoint years readable. The Exercise Detail accessibility scenario
now asserts the rep trace before scrolling to the history chart; the corrected
scenario passed. Additional results, setting-state evidence, and screenshots are
in `.verify/insights-all-time/accessibility-settings/`. Original simulator settings
were restored. Actual VoiceOver traversal and speech remain device checks.
