# Current work

- Status: completed
- Updated: 2026-09-05
- Task: make Insights' secondary mix previews concise and easier to scan.
- Authorized scope and steering: improve the Insights presentation discussed in
  the design review. Compact Exercise mix and Rep mix; keep the main training
  visuals and existing analytics/drill-outs. Exercise Detail is outside this task.
- User job: read the leading exercise and rep range at a glance, then continue
  through the main training instruments or open a full breakdown.
- Plan/contract: [Insights contract](specs/insights-visual-instruments.md). No
  separate plan needed for this localized presentation change. Its explicit
  single-scroll order governs over the design skill's general mode suggestion.
- Progress: previews are about 40% shorter at standard text size (181 to 108pt)
  using slimmer share bars, tighter grouping/padding, and deferred legends.
  Empty previews use concise labels; headers and summaries stack at accessibility
  text sizes. The category and value fonts retain their original sizes.
- Next action: none. Actual VoiceOver traversal and speech remain device checks.
- Worktree: clean at `8abe4fe` before edits; this task's changes only.
- Verification: `Scripts/check.sh` passed on the working tree based on `8abe4fe`.
  Three headless Baguette flows passed: Shape drill-outs, the same flow at largest
  text, and locked Insights. Inspected light/dark, largest text, empty previews,
  and Reduce Motion plus Differentiate Without Color. Preview accessibility
  labels match the baseline and targets exceed 44pt. Evidence, measurements,
  and review notes are in `.verify/insights-preview-refinement/`.
