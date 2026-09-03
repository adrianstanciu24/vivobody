# Current work

Goal: present Insights as one ordered scroll: Shape, Load, Rhythm, then Balance,
with no segmented mode bar.

Progress:

- Replaced the four-mode shell with one lazy vertical instrument panel and preserved all
  existing analytics, scopes, Shape drill-outs, and the focused Balance roster.
- Passed dark, light, locked, and Accessibility Large visual inspection plus
  the showcase, push/pull, locked, accessibility, and drill-out scenarios.
- The full generic build, catalog parity, architecture, naming, documentation,
  source-size, complexity, and changed-file formatting checks pass.
- Added the seven-day 6–12 rep-set count beside Sessions and 1–5 reps in the
  centered Training load driver strip; its focused model test and headless
  semantic scenario pass, with the rendered three-column strip inspected.
- Widened the Rep ranges weekly stacks and inset the plot so its newest date
  label remains fully visible.
- Added a hairline separator between the Training rhythm daily heatmap and
  weekly-set trend.
- Centered the Last workout metrics in a 30/40/30 column layout so Volume has
  room for its wider value and unit.

Next: user visual review. `Scripts/check.sh` stops only at the pre-existing
trailing whitespace in the user-owned `vivobodyApp.swift` change.

User steering: remove the segment bar and keep the order Shape, Load, Rhythm,
Balance on one screen. Use a centered 30/40/30 layout for the Last workout
metrics. Preserve unrelated work.

# Queued: Training Load measures volume load

Plan: `engineering/plans/active/2026-09-03-training-load-volume-load.md`.
Decision (proposed):
`engineering/decisions/2026-09-03-training-load-measures-volume-load.md`.

Progress: analysis done, plan and decision written, no code changed yet.

Next: commit the in-flight Insights work above first, then start milestone 1
(session volume load on `AnalyticsSessionReplay`).

User steering: load belongs in Training Load only. The muscle map, 3D body,
and `SetStimulus` keep hard sets and are out of scope.
