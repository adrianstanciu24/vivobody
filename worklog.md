# Current work

- Status: completed
- Updated: 2026-09-07
- Task: remove in-app purchases and unlock all existing app functionality.
- Authorized scope and steering: paid-upfront app; remove Insights, Exercise
  Detail, template, widget, and Apple Health purchase gates.
- Plan/contract: [paid-app contract](specs/paid-app.md),
  [completed plan and evidence](engineering/plans/completed/2026-09-07-paid-app.md).
- Progress: removed purchase service, UI, product configuration, entitlement
  preferences, and all Pro gates. Updated active specs and release metadata;
  replaced locked scenarios with unrestricted-access checks.
- Next action: none for repository implementation. Select the upfront price in
  App Store Connect as separate release work.
- Worktree: based on `43cf909`; preserved existing Codex recorder changes in
  `.gitignore`, `AGENTS.md`, `Scripts/check.sh`, `engineering/verification.md`,
  `.codex/`, recorder scripts/tests, and observability documentation. Replaced
  the prior completed-task handoff in this file per workflow guidance.
- Verification: `Scripts/check.sh`, 18 focused app tests, five VivoKit snapshot
  tests, 11 scenario-runner tests, and 13 headless UI scenarios passed. Inspected
  screenshots and accessibility trees across dark, light, and large text. Logs
  are `.verify/paid-app-*.log`; scenario evidence is `.verify/scenarios/`.
  Physical-device VoiceOver, HealthKit, and installed widget checks remain manual.
