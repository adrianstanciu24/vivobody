# Insights chart system

- Status: completed
- Started: 2026-08-20
- Completed: 2026-08-20
- Spec/decision: user-requested Insights redesign — charts carry the story,
  text steps back, dormant placeholders replace empty-state prose

## Goal and non-goals

Rebuild the four middle Insights sections (training load, strength
composition, rep ranges, consistency) around one bold Swift Charts graphic
each, styled from a shared kit so the sections stay consistent with each
other and with their own empty states. The graph explains; copy shrinks to
headers, axes, and one micro-legend row.

Non-goals:

- `SignatureSection` (petal hero) and `SymmetrySection` (training balance)
  stay untouched.
- No model changes. `SessionAnalytics` reports and their thresholds are the
  source of truth and remain as-is; this is a view-layer rework.
- No new colors, type roles, or spacing tokens. Orange is `Tint.primary`;
  secondary elements step down through `Ink`.

## Chart rules (the contract every Insights chart follows)

1. Chart-first anatomy: `SectionHeader` (title + one trailing status word or
   timeframe) → one chart → at most one micro-legend row. No body paragraphs
   under a chart; explanation moves into axes, legends, and the header
   trailing.
2. One orange per chart: `Tint.primary` marks the primary series or dominant
   element only. Never two accents in one chart.
3. Swift Charts for all data graphics: `LineMark`/`AreaMark` for trends,
   stacked `BarMark` for composition and weekly sets. Custom drawing remains
   only for the six-month heatmap (a calendar grid, not a chart) and the two
   keeper sections.
4. Shared axis chrome from one helper: hairline `Surface.edge` gridlines,
   `Typography.metricMicro` labels in `Ink.tertiary`, max 4 X / 3 Y ticks,
   no axis titles.
5. Two canvas heights only: `.hero` (180pt) for a section's main chart,
   `.compact` (56pt) for sparkline-style reads.
6. Dormant state = the same chart, undrawn. No data renders a placeholder at
   the exact canvas size and chrome of the live chart: ghost gridlines,
   dotted baseline, real qualification progress encoded as filled slots or
   segments, and the next slot breathing. One micro-legend allowed
   ("2/6 SETS · 9/28 DAYS"). No titles, no paragraphs. This replaces
   `InsightBuildingCard` in all four sections.
7. One building vocabulary: header trailing status + `BuildingSignalDot`,
   plus the dormant canvas. Delete the per-section bespoke building panels
   (baseline-progress panel, rhythm-taking-shape panel, trend-building
   footer).
8. Motion rules: only the next slot breathes; all motion freezes under
   Reduce Motion; real data never animates on scroll. Motion must never
   masquerade as progress (existing `DormantChart` rule).
9. Accessibility stays first-class: live charts keep Swift Charts' per-point
   VoiceOver representation; dormant placeholders get one consolidated label
   stating what is required.

## Section-by-section

- Training load: orange rolling-7-day line + soft orange recent-range band +
  verdict-colored endpoint. Verdict word ("Below/Within/Above range") moves
  to the header trailing. Keep one slim `StatStrip` with the three driver
  numbers (hard sets, sessions, 1–5 rep sets) under the chart. Cut the
  status headline and paragraph, the segment gauge, and the baseline panel;
  baseline days/weeks progress becomes the dormant canvas.
- Strength composition: one 100% stacked horizontal `BarMark` for exercise
  allocation (rank 1 orange, remaining ranks gray steps) with a micro-legend
  naming the top lifts and percentages; exercise type becomes a second
  stacked `BarMark` (compound orange, isolation gray). Classification
  coverage collapses to one micro-legend token ("86% CLASSIFIED"). Cut the
  custom `GeometryReader` strips and the caption paragraphs.
- Rep ranges: the 12-week stacked `BarMark` returns, slimmer — dominant zone
  per week in orange, other zones gray steps. Migration verdict ("Lower-rep
  shift") moves to the header trailing. Cut the hero percentage, sample
  copy, legend columns, and trend-footer metrics and requirement sentences.
  The file header currently documents the chart's deliberate removal; update
  it to record why the slimmer chart returns.
- Consistency: the heatmap is promoted to the section's single card. The
  weekly-sets sparkline stays as a bold orange compact `AreaMark` above it.
  One slim `StatStrip` (workouts/wk, days trained, avg RIR) replaces both
  existing strips; the week streak moves to the header trailing. Cut the
  recent-rhythm prose card and the RIR coverage ladder.

## Invariants and risks

- Reworked section files may only shrink (source-size ratchet); new files
  stay under the 600-line threshold.
- `LockedInsightPreview` blurs real sections for the free tier; dormant
  canvases must render deterministically under that blur.
- Fixed chart heights keep the `LazyVStack` free of layout jumps.
- Tension to resolve in copy: `IntensityMixSection`'s header says the
  12-week chart was removed for duplicating reads. The returning chart is
  deliberately slimmer and owns the trend read; the text that duplicated it
  is what gets cut this time.
- Placeholder slots encode only real logged evidence. Never invent sample
  data to make an empty chart look alive.

## Milestones

- [x] Add `Screens/Insights/InsightChartKit.swift` (axis style, canvas
  heights, micro-legend row) and extend `Components/Displays/DormantChart.swift`
  with a general slots canvas; DEBUG gallery covering empty, partial,
  populated, and accessibility-type states. Done 2026-08-20:
  `InsightChartCanvas` (hero 180 / compact 56), `InsightChartAxis`
  (dates/values/counts), `InsightChartLegend` (line/fill swatches),
  `DormantSlotsCanvas` (slots + optional span track, consolidated
  accessibility label); `DormantChartCard`/`DormantTrendSlots` refactored
  onto shared ghost chrome with identical output. Gallery:
  `InsightChartKitGallery.swift`. Evidence: `Scripts/check.sh` passed
  (guardrails + full build, no unexpected warnings). No app-UI change yet —
  the kit is unwired, so screenshot evidence starts at milestone 2.
- [x] Rework `TrainingLoadSection` (chart-first, verdict to header, slim
  driver StatStrip, dormant canvas). Done 2026-08-20: header trailing now
  carries the verdict ("within range") or "baseline building"/"waiting for
  sets" with the breathing dot; the card is legend → orange line + range
  band + verdict endpoint → hairline → StatStrip (hard sets / sessions /
  1–5 rep sets). Status headline, context paragraph, segment gauge,
  baseline panel, and driver chip list removed; axes now come from
  `InsightChartAxis`. Empty state is `DormantSlotsCanvas` (3 week slots +
  28-day span track) at hero height. Evidence: `Scripts/check.sh` passed;
  `.verify/insights.jpg` + `insights-ui.json` (TAB=insights,
  `--seed-showcase --pro`) show the chart-first section with no prose.
  Note: the section's dormant state is unreachable via the seeded app
  because zero qualifying load points collapses to the whole-screen empty
  state first; the dormant canvas is exercised through the DEBUG gallery.
- [x] Rework `ExerciseDominanceSection` (Swift Charts stacked bars, coverage
  to legend token). Done 2026-08-20: allocation and exercise type are now
  stacked horizontal `BarMark`s at compact canvas height (rank 1 / compound
  in orange, rest gray steps); the custom `GeometryReader` strips, coverage
  bar, set-count column, confidence chip, and both caption paragraphs are
  gone. Classification coverage is a header token ("100% CLASSIFIED" /
  "early read"). Empty state is `DormantSlotsCanvas` (6 set slots).
  `InsightChartLegend` gained a `ViewThatFits` vertical fallback for
  accessibility type sizes. Evidence: `Scripts/check.sh` passed;
  `.verify/insights.jpg` + `insights-ui.json` (TAB=insights,
  `--seed-showcase --pro`) show both stacked bars with legend rows and no
  prose.
- [x] Rework `IntensityMixSection` (12-week stacked bars return, verdict to
  header, header comment updated). Done 2026-08-20: the 12-week stacked
  `BarMark` is back at hero height with the shared axis chrome; the
  migration verdict ("higher-rep shift" etc.) is the header trailing and
  "trend building"/"waiting for rep sets" carry the breathing dot. Cut:
  hero percentage, sample copy, mix bar, zone-legend columns, and the
  whole trend-summary chip (metrics, footers, requirement sentences).
  Empty state is `DormantSlotsCanvas` (6 rep-tracked-set slots). Header
  comment now records why the chart returns. Interpretation decision:
  "dominant zone in orange" is section-level (the existing `accentZone`
  logic), not per-week — orange keeps one meaning across all weeks; the
  current partial week is dimmed to 55% instead of dropped. Evidence:
  `Scripts/check.sh` passed; `.verify/insights.jpg` + `insights-ui.json`
  show the verdict in the header and the bold stacked bars.
- [x] Rework `ConsistencySection` (heatmap promoted, one StatStrip, streak
  to header). Done 2026-08-20: single card — StatStrip (workouts/wk, days
  trained, avg RIR) → weekly-sets sparkline (compact canvas, legend
  trailing carries the "RIR 0/198 sets" coverage token) → heatmap → daily
  legend. Week streak moved to the header trailing ("18-week streak");
  "N/4 workouts" + breathing dot while the rhythm settles. Cut: the
  recent-rhythm prose card, the rhythm-taking-shape panel, the RIR
  coverage ladder, the streak chip, and the second StatStrip. Empty state
  is `DormantSlotsCanvas` (4 workout slots). Heatmap grid stays custom
  (calendar, not a chart) per the plan. Evidence: `Scripts/check.sh`
  passed; `.verify/insights.jpg` + `insights-ui.json` confirm header
  streak, one strip, sparkline with RIR token, and heatmap legend.
- [x] Retire `InsightBuildingCard` and its gallery once all four sections
  use the dormant canvas; fold the beacon idea into the canvas if wanted.
  Done 2026-08-20: both files deleted. One surprise usage remained in the
  keeper petal section — its "no signature yet" state rendered the text
  card under the empty bloom. The petal chart itself is untouched; the
  prose card became one centered micro-legend line ("waiting for the
  first muscle-mapped set"), with the header's "first signal" + breathing
  dot carrying the in-progress cue. The beacon was not folded into the
  canvas: the breathing next slot plus the header's `BuildingSignalDot`
  are the two sanctioned motion cues, and a third breathing element would
  break the one-building-vocabulary rule. `SignatureSection.swift` shrank
  and its source-size allowance was ratcheted down (890 → 887). Evidence:
  `Scripts/check.sh` passed with the files removed (synchronized project
  folders, no pbxproj edits needed).
- [x] Verify: `Scripts/check.sh`, targeted insight unit suites, and
  `Scripts/verify.sh` screenshot plus accessibility-tree evidence for
  populated and fresh-install Insights. Done 2026-08-20: 65 targeted
  insight tests passed (ConsistencyReportTests, SessionInsightsTests,
  ExerciseProgressInsightsTests). Final captures: `.verify/insights-populated.jpg`
  (+ `-ui.json`, `--seed-showcase --pro`) and `.verify/insights-locked.jpg`
  (free-tier blur over the reworked sections, purchase control intact).
  Fresh-install capture shows a persistent "Building your training
  signals" spinner — confirmed pre-existing by re-capturing on the
  stashed pre-change build (identical result); the empty-store gating in
  `InsightsScreen`/`SessionAnalytics` is untouched by this work and the
  reachability of `emptyState` on a zero-session archive is a separate
  follow-up. `Scripts/check.sh` passed as the final gate.

## Verification

```bash
/usr/bin/python3 Scripts/check_architecture.py
/usr/bin/python3 Scripts/check_naming.py
swiftformat --dryrun vivobody/
Scripts/check.sh
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -parallel-testing-enabled NO \
  test -only-testing:vivobodyTests/ConsistencyReportTests \
  -only-testing:vivobodyTests/SessionInsightsTests \
  -only-testing:vivobodyTests/ExerciseProgressInsightsTests
Scripts/verify.sh
```

Manual checks: scroll the Insights tab in both populated and empty states at
default and accessibility type sizes; confirm dormant motion freezes under
Reduce Motion; confirm the locked free-tier blur still reads as frozen
content.

## Progress and discoveries

- `DormantChart.swift` (Components/Displays) already implements the
  placeholder-with-motion idea — breathing slot dots, dotted baseline, ghost
  axis — but only the Library strength-trend card uses it. `BuildingSignalDot`
  (ScreenKit) is the shared breathing cue for header statuses.
- `InsightBuildingCard` is used by exactly the four sections in scope plus
  its DEBUG gallery, so it can be retired cleanly after the rework.
- `Tint.inProgress` aliases `Tint.primary`, so building states already share
  the brand orange; no token changes needed.
- Training-load drivers stay as one slim StatStrip (user decision).
- The 12-week stacked bar chart returns for rep ranges (user decision),
  overriding the removal recorded in the section header.

## Result

All seven milestones completed in one session. The four middle Insights
sections now follow the nine chart rules: header (title + trailing
status) → one Swift Charts instrument → at most one micro-legend row,
with `Tint.primary` reserved for the primary series or dominant zone and
gray steps for everything else. `InsightChartKit` owns the two canvas
heights, the shared axis chrome, and the responsive legend;
`DormantSlotsCanvas` gives every section an empty state with the same
geometry as its live chart, real progress as slots/span, and one
breathing next-slot for motion. `InsightBuildingCard` and its gallery
are retired; the petal and balance sections are functionally untouched
(the petal's no-signature prose card became a one-line legend). The four
reworked sections shrank from roughly 1,900 to ~1,060 lines total.

Evidence:

- 65 targeted insight unit tests passed; models were not changed.
- `Scripts/check.sh` passed after each milestone and as the final gate.
- `.verify/insights-populated.jpg` / `-ui.json`: chart-first sections,
  verdicts and streak in headers, no prose under charts.
- `.verify/insights-locked.jpg`: free-tier blur intact over the new
  sections.
- `.verify/insights-empty.jpg`: fresh-install capture (see milestone 7
  note — pre-existing spinner behavior, verified against the pre-change
  build via stash).

Manual verification still owed (Baguette cannot observe these): dormant
slot breathing motion, and its freeze under Reduce Motion; both are
previewable in `InsightChartKitGallery` and `DormantChart` previews.
