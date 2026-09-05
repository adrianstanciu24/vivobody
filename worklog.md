# Current work

- Status: completed
- Updated: 2026-09-05
- Task: make Movement Coverage, Direct vs. Indirect, and Set-Series Stamina all time.
- Authorized scope and steering: user requested all-time history for all three
  instruments. Apply the scope to aggregation, drill-outs, stamina history/trends,
  visible and accessibility labels, contracts, and tests. Preserve the chart designs.
- Plan/contract: [completed plan](engineering/plans/completed/2026-09-05-insights-training-dimensions.md),
  [Insights contract](specs/insights-visual-instruments.md).
- Progress: removed the three report date cutoffs; stamina compares first/latest
  matched history. Cards, drill-outs, accessibility labels, Exercise Detail, and
  contracts now share all-time scope. The fixture includes a year-old session.
- Next action: none. Actual VoiceOver traversal and speech remain device checks.
- Worktree: began clean at `49f4c39`; this task's edits only.
- Verification: 31 focused Swift tests, `Scripts/check.sh`, and 16 focused headless
  scenarios passed. Inspected light/dark, largest text, drill-outs, and multi-year
  stamina history. Four additional runs passed with Reduce Motion and Differentiate
  Without Color enabled. The corrected Exercise Detail accessibility scenario also
  passed; original simulator settings were restored.
- Follow-up evidence: `.verify/insights-all-time-tests.log`,
  `.verify/insights-all-time-check.log`, and `.verify/insights-all-time/`.
  The completed plan retains original evidence and the device-only gap.
