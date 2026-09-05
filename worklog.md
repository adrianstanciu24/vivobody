# Current work

- Status: completed
- Updated: 2026-09-05
- Task: implement the five approved documentation and agent-workflow improvements.
- Authorized scope and steering: docs and process tooling; support light and
  dark appearances and a maximum of five top-level tabs. Preserve app behavior.
- Plan/contract: [task guide](AGENTS.md), [verification](engineering/verification.md),
  and [handoff format](engineering/plans/README.md). No separate execution plan
  needed for this bounded documentation/tooling change.
- Progress: all five improvements completed: current product principles,
  task/domain routing, catalog history and generated inventories, feature-based
  verification with a prose-only path, and explicit handoffs/action boundaries.
  Prior receipt steering is retained in its active spec.
- Next action: none; replace this completed handoff when a new task starts.
- Worktree at verification: documentation/tooling edits based on `7a87186`,
  before commit; began clean. App code, runtime data, and scenario JSON are unchanged.
- Verification: working-tree documentation and inventory checks passed;
  `test_check_documentation.py` passed 10 tests and `test_quality_scan.py`
  passed 3 tests. Pre-commit configuration and documentation hook, catalog
  skill validation, Markdown path/heading inspection, and `git diff --check`
  passed. Command/output evidence is local at
  `.verify/docs-process-validation.log`. No app build or UI run is required
  for this documentation-tooling scope under the revised verification policy.
- Publish verification: catalog documentation assertions now read the generated
  inventory. The full guardrail and VivoKit snapshot pre-push hooks passed.
  Catalog-guidance changes explicitly require the catalog Python suite.
