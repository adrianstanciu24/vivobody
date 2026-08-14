# Diagnostics and entropy control

- Status: completed
- Started: 2026-08-14
- Spec/decision: user-requested harness-engineering follow-up

## Goal and non-goals

Add privacy-safe semantic diagnostics to the app's load-bearing boundaries,
make selected events assertable from the runtime logs already captured by the
Baguette scenario harness, prevent oversized source files from growing, and
provide a deterministic manual maintenance report.

This work does not add analytics, transmit logs, log user-owned workout data,
immediately split every existing large file, or schedule unattended scans.

## Invariants and risks

- Diagnostic events contain stable event kinds and outcomes, never workout or
  exercise names, notes, weights, URLs, UUIDs, or HealthKit sample values.
- Existing boundary owners remain intact; logging observes transitions without
  creating another side-effect owner.
- The size check is a ratchet: current debt is recorded, new debt and growth
  fail, and reduced files must tighten their allowance.
- Heuristic orphan and UI-duplication findings remain report-only until manual
  scans demonstrate that they are reliable.

## Milestones

- [x] Add centralized diagnostics and boundary events.
- [x] Add required/forbidden runtime-log assertions to semantic scenarios.
- [x] Add and test the source-size ratchet.
- [x] Add and test the manual quality report.
- [x] Document correction routing and run focused plus canonical verification.

## Verification

```bash
/usr/bin/python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
/usr/bin/python3 Scripts/check_source_sizes.py
/usr/bin/python3 Scripts/quality_scan.py --output .verify/quality-scan.md
SCENARIO=deep-link-insights Scripts/verify.sh
SCENARIO=archive-to-history Scripts/verify.sh
Scripts/check.sh
```

## Progress and discoveries

- `verify_scenario.py` already starts a filtered unified-log stream before app
  launch and preserves it as `runtime.log`, so declarative assertions could be
  added without creating a second capture path.
- Fourteen production Swift files currently exceed 600 physical lines. The
  largest are existing Library and input surfaces, so a baseline ratchet is
  appropriate while an immediate hard cap is not.

## Result

- `AppDiagnostics` now owns privacy-safe storage, incoming-action, session,
  snapshot, and HealthKit events; a structural rule rejects direct `Logger`
  creation elsewhere.
- Semantic scenarios support literal required/forbidden runtime-log contracts.
  Deep-link routing, archive-to-history, and active restoration passed with
  their expected events and without an in-memory storage fallback.
- The 600-line ratchet records fourteen existing allowances, rejects new or
  growing oversized files, and requires baseline tightening after reductions.
- The unscheduled manual report aggregates enforced checks and reports stale
  knowledge, orphaned screens, and repeated UI surface expressions. Its first
  run identified the already-known orphaned `TemplateDetailScreen` candidate.
- All Python guardrail tests and `Scripts/check.sh` pass; the latter includes
  VivoKit contracts, fixture integrity, catalog validation, and the complete
  simulator build with no unexpected warnings.
