# Verification

This is the canonical guide for proving Vivobody changes. Match verification
cost to risk, but always compile before declaring a code change done.

## Default validation

Run from the repository root:

```bash
Scripts/check.sh
```

The command runs the Python guardrail tests, documentation and architecture
checks, generated-catalog parity validation, and a complete simulator build.
The full build log is written to `.verify/check-build.log`. Unexpected warnings
fail the command; the known external AppIntents framework warning is filtered.

For a fast structural loop before compiling:

```bash
/usr/bin/python3 Scripts/check_architecture.py
/usr/bin/python3 Scripts/check_documentation.py
/usr/bin/python3 Scripts/check_source_sizes.py
```

To isolate a compiler failure:

```bash
xcodebuild -scheme vivobody \
  -destination 'generic/platform=iOS Simulator' build
```

## Pre-commit hooks

The checked-in `.pre-commit-config.yaml` moves the fast gates earlier than
`Scripts/check.sh`. Install once per clone:

```bash
brew install pre-commit swiftformat
pre-commit install
```

The commit stage checks file hygiene, formats staged Swift files under
`vivobody/`, `vivobodyWidgets/`, and `VivoKit/Sources/` with SwiftFormat
(matching the `Scripts/check.sh` formatting boundary), and runs the
architecture, source-size, documentation, and catalog-parity guardrails
scoped to the files that can break them. The push stage runs the Python
guardrail suites and the VivoKit snapshot contract tests. Hooks never replace
`Scripts/check.sh`; they surface the same failures earlier. Run the full tree
manually with `pre-commit run --all-files`, adding `--hook-stage pre-push`
for the push stage.

## UI verification with Baguette

For every UI-affecting change, run `Scripts/verify.sh` and inspect both the
screenshot and accessibility tree. The script incrementally builds, reuses a
headless simulator, installs the app, launches deterministic state, and writes
evidence under `.verify/`.

```bash
Scripts/verify.sh
TAB=insights Scripts/verify.sh
CAPTURE_ONLY=1 Scripts/verify.sh
CLEAN_BUILD=1 Scripts/verify.sh
RESET_STATE=0 Scripts/verify.sh
SIMULATOR_NAME='iPhone 16e' Scripts/verify.sh
SIMULATOR_OS=26.2 Scripts/verify.sh
LAUNCH_ARGS='--seed-history' Scripts/verify.sh
SCENARIO=active-restoration Scripts/verify.sh
```

The default launch includes `--ui-test-reset` so onboarding cannot block a
check. `TAB` uses the debug launch route instead of coordinate taps.
`CAPTURE_ONLY=1` records the already running app and is the fastest loop after
manual Baguette interaction.

Each normal capture produces:

- `.verify/<state>.jpg` — visual evidence;
- `.verify/<state>-ui.json` — semantic accessibility tree with frames.

Do not use pixel-perfect snapshot assertions. Animation and system materials
make exact image diffs brittle. Use semantic tree assertions for pass/fail and
review screenshots for layout, hierarchy, clipping, and visual regressions.

`baguette` is required and can be installed with `brew install baguette`.

## Semantic scenarios

Run a checked-in scenario with:

```bash
SCENARIO=<name> Scripts/verify.sh
```

Scenario definitions live in `Scripts/verify_scenarios/`. The runner resolves
controls by accessibility identifier, label, role, or value, then taps the
visible midpoint from the semantic tree. It writes the final screenshot, tree,
runtime log, action trace, and result JSON under
`.verify/scenarios/<name>/`.

Scenario `requiredLogs` and `forbiddenLogs` assertions use literal substrings
from privacy-safe `AppDiagnostics` events. Do not assert Apple framework log
copy, timestamps, private/redacted fields, or user-owned values.

The scenario schema, selector rules, and current scenario catalog are in
[Scripts/verify_scenarios/README.md](../Scripts/verify_scenarios/README.md).
Add stable identifiers only to controls needed for important harness flows;
decorative views do not need identifiers.

## Targeted and full test suites

Run the smallest relevant targeted unit suite by default whenever logic
changes. This gives agents autonomy to prove pure logic and boundary contracts
without paying for every simulator test. Do not run the full simulator suite
unless the user explicitly requests it or the task’s acceptance criteria name
it.

```bash
# Targeted suite, preferred
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:vivobodyTests/TrainingLoadTests

# Current pre-release store reopen contract
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO \
  test -only-testing:vivobodyTests/PersistenceStoreContractTests

# Shared widget payload contracts (host-side, no simulator)
swift test --package-path VivoKit

# Full suite
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Tests use Swift Testing, fixed dates or virtual clocks, and in-memory model
graphs. Follow `vivobodyTests/TrainingLoadTests.swift` for the prevailing style.

## Evidence by change type

| Change | Required evidence |
|---|---|
| Documentation only | Documentation checks and `Scripts/check.sh` |
| Pure analytics or domain logic | Smallest relevant targeted unit suite, then `Scripts/check.sh` |
| Pre-release persistence shape or container opening | Current-store reopen contract, then `Scripts/check.sh` |
| Post-release persistence shape or migration | Every retained version fixture, then `Scripts/check.sh`; use a migration plan |
| Session lifecycle | Targeted controller/domain tests, build, and a relevant semantic scenario |
| UI layout or interaction | Build plus inspected screenshot and accessibility tree |
| VivoKit snapshot payload or widget decoding | `swift test --package-path VivoKit`, build, and semantic handoff evidence when behavior changes |
| HealthKit, StoreKit, provisioning, or hardware behavior | Build and all observable harness evidence; list remaining device/App Store checks explicitly |

Anything the harness cannot observe remains a manual verification item; do not
substitute an unrelated simulator test merely to produce a green result.

## Manual maintenance scan

Generate the unscheduled maintenance report with:

```bash
/usr/bin/python3 Scripts/quality_scan.py --output .verify/quality-scan.md
```

Documentation paths, architecture boundaries, and source-size growth are also
enforced independently by `Scripts/check.sh`. Stale dates, orphaned screens,
and repeated UI-surface expressions are deliberately report-only heuristics.
Review several manual reports and tune false positives before scheduling it.

The current pre-release store lives in `vivobodyTests/Fixtures/`. Contract tests
always reopen a temporary copy. Before V1, an intentional breaking schema
change may replace this baseline and its checksum because development data is
not yet a compatibility promise. When the first public release establishes
`SchemaV1`, retain that fixture permanently and add newer fixtures rather than
rewriting shipped history. The checksum gate in `Scripts/check.sh` catches
accidental baseline changes in either phase.
