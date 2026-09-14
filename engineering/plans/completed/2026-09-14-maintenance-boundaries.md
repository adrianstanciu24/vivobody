# Maintenance boundaries

- Status: Complete
- Date: 2026-09-14

## Scope completed

- Aligned agent verification guidance with the focused Baguette-only policy.
- Removed the obsolete technical-debt ledger and its tooling assumptions.
- Froze SwiftData SchemaV1 behind `VivobodyMigrationPlan` and added an
  architecture guardrail for that boundary.
- Split every grandfathered high-complexity function and retired the baseline.

## Evidence

- Architecture, documentation, source-size, naming, complexity, and diff-hygiene
  diagnostics passed. Complexity reports zero functions above the limit and
  zero allowances.
- `insights-hard-sets`, `widget-start-handoff`, and `start-complete-rest`
  Baguette scenarios passed; their screenshots and accessibility trees were
  inspected.
- `insights-showcase` and `insights-dimensions-building` compiled and rendered
  but exposed unrelated stale fixture assertions. Their expected labels were
  intentionally left unchanged.
- Persistence fixture and broader analytics suites remain user-run evidence.
