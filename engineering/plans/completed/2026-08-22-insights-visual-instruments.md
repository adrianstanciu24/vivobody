# Insights visual instruments

- Status: completed
- Started: 2026-08-22
- Completed: 2026-08-22
- Spec/decision: [Insights visual instruments](../../../specs/insights-visual-instruments.md),
  succeeding the completed [Insights chart system](../completed/2026-08-20-insights-chart-system.md)

## Goal and non-goals

Turn the Insights tab from one long six-section analytics report into four
focused, persistent visual instruments: Shape, Load, Rhythm, and Balance.
Secondary exercise allocation, rep-range history, and the full comparison
roster move behind clear drill-outs. The populated screen should read like a
gauge panel at a glance, while retaining every existing analytics report and
the real-data Pro preview.

Non-goals:

- no analytics, threshold, SwiftData, StoreKit, or entitlement changes;
- no new data-category colors, scores, recommendations, or training claims;
- no changes to widgets, exercise progress, or workout-session behavior.

## Invariants and risks

- `SessionAnalytics.InsightsReports` remains the sole data source. Views may
  prioritize or group its existing reports but may not reinterpret them.
- Free users retain a real-data blurred preview and one persistent purchase
  action. Hidden preview values remain absent from the accessibility tree.
- The mode control must stay reachable while a mode scrolls, preserve the
  large navigation-title behavior, and remain usable at accessibility sizes.
- Existing dormant instruments remain factual and deterministic.
- New Swift files stay below the source-size threshold. Existing oversized
  `SignatureSection.swift` may only shrink.
- The current `--ui-test-insights-showcase` path is too large and makes the
  scenario depend on an unrelated History launch. Replace only that focused
  UI-test fixture; retain the full body-development showcase used elsewhere.
- Rollback is view-only: the existing six section views and analytics reports
  remain independently reusable until verification completes.

## Milestones

- [x] Audit every populated section, semantic tree, locked preview, and current
  verification fixture; record the durable hierarchy contract in the spec.
- [x] Add a persistent four-mode shell with stable, accessible controls and
  top-reset behavior.
- [x] Rebuild Shape around the bloom, two supporting readings, and visual
  drill-out cards for exercise and rep mix.
- [x] Promote the Load verdict and current reading; keep its trend and compact
  driver strip as one instrument.
- [x] Make Rhythm a calendar-led instrument with cadence and weekly-set
  direction, without a second report chapter.
- [x] Focus Balance on the highest-priority tug-of-war beams and move the full
  roster to a drill-out.
- [x] Preserve locked and empty behavior across the new mode shell.
- [x] Replace the oversized populated UI fixture, update semantic scenarios,
  and inspect dark, light, and accessibility evidence for all modes and
  drill-outs.
- [x] Run targeted Insights tests, `Scripts/check.sh`, final diff review, and
  move this plan to completed with evidence.

## Verification

```bash
/usr/bin/python3 Scripts/check_architecture.py
/usr/bin/python3 Scripts/check_naming.py
swiftformat --dryrun vivobody/ vivobodyWidgets/ VivoKit/Sources/
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO test \
  -only-testing:vivobodyTests/TrainingSignatureTests \
  -only-testing:vivobodyTests/TrainingLoadTests \
  -only-testing:vivobodyTests/ExerciseDominanceTests \
  -only-testing:vivobodyTests/IntensityMixTests \
  -only-testing:vivobodyTests/ConsistencyReportTests \
  -only-testing:vivobodyTests/AntagonistBalanceTests
Scripts/check.sh
SCENARIO=insights-showcase Scripts/verify.sh
SCENARIO=insights-push-pull Scripts/verify.sh
SCENARIO=insights-locked Scripts/verify.sh
SCENARIO=insights-empty Scripts/verify.sh
SCENARIO=insights-shape-drillouts Scripts/verify.sh
SCENARIO=insights-accessibility Scripts/verify.sh
```

Manual checks not fully observable by the harness: direct VoiceOver chart
exploration and the free-preview blur under Reduce Transparency. Mode changes
are deliberately instant, so they do not create a separate Reduce Motion path.

## Progress and discoveries

- The prior chart pass successfully removed prose from the four middle
  sections, but it intentionally left the six-section navigation model,
  Signature, and Balance untouched. The remaining problem is hierarchy, not a
  lack of charts.
- The first viewport repeats the signature identity, coverage, cadence, and
  equal-share explanation around one already self-describing bloom. Cadence is
  also present in Consistency.
- Balance can render up to ten qualified rows plus grouping labels and a
  qualification explanation. The pair-relative beams are strong; the
  permanent roster around them is the overload.
- Accessibility captures show inherited section identifiers on multiple child
  nodes. The mode shell will assign identifiers only to their semantic owner.
- The populated scenario currently seeds the much larger body-development
  showcase and waits on unrelated Today/History UI. A focused deterministic
  Insights seed is required before final visual evidence is trustworthy.
- First populated captures exposed two visual-only issues that semantic checks
  could not: mode transitions briefly composited old chart layers, and the
  12-week load axis repeated month labels. Instrument swapping is now instant;
  the load chart requests three month ticks and no longer repeats its hero
  hard-set value in the driver strip.
- The original reset transaction could roll back catalog and session deletes
  together, leaving a stale active workout in direct-launch UI verification.
  The fixture reset now commits session data before refreshing the catalog.
- Light appearance showed that vivid brand orange is a strong chart/fill color
  but does not clear small-text contrast. A semantic `Tint.primaryText`
  endpoint keeps marks vivid and labels AA-readable.
- Accessibility Large exposed horizontal overflow in shared section headers,
  balance labels, and calendar chrome. Headers now stack when required,
  balance rows use wrapped labels, Shape uses visual rails, and chart chrome
  caps independently from the large readings.

## Result and evidence

The Insights tab now presents one focused visual instrument at a time. Shape
leads with the lifetime bloom, Load with the current value and range, Rhythm
with cadence and the calendar, and Balance with three priority tug-of-war
beams. Secondary distributions and the complete comparison roster remain
available through visual drill-outs. No analytics formula, entitlement, or
persistence model changed.

Verification completed on iPhone 17 Pro / iOS 26.5:

- 112 focused analytics tests passed across the six Insights suites.
- `insights-showcase`, `insights-push-pull`, `insights-locked`,
  `insights-empty`, `insights-shape-drillouts`, and `insights-accessibility`
  semantic scenarios passed.
- Dark, light, locked, empty, drill-out, and Accessibility Large screenshots
  and accessibility trees were inspected under `.verify/`.
- `Scripts/check.sh` passed, including architecture, naming, generated data,
  documentation, formatting, source-size, complexity, and generic build
  checks.
