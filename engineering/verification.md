# Verification

This is the canonical guide for proving Vivobody changes. Agents use one
focused Baguette check after implementation and leave broader validation to the
user. Simulator processes stay headless: never open the Simulator app and never
run XCTest UI tests as part of the agent workflow.

## Default agent validation

Choose the smallest relevant scenario from the feature/scenario map and run:

```bash
SCENARIO=<relevant-scenario> Scripts/verify.sh
```

Inspect its screenshot and accessibility tree. Do not add a clean build, a
separate simulator build, `xcodebuild test`, `swift test`, or `Scripts/check.sh`
to routine agent verification. If Baguette cannot observe the changed contract,
state the limitation and leave that evidence to the user.

## Documentation and process tooling

For prose-only changes to Markdown, instructions, plans, or proposal records:

```bash
/usr/bin/python3 Scripts/check_documentation.py
git diff --check
```

Inspect the changed guidance for conflicting rules, stale statuses, valid
commands, and useful task routing. The documentation checker verifies local link
paths, required entry points, spec indexing, and generated inventory parity;
it cannot prove that prose agrees with implemented behavior.

Catalog guidance and proposal changes also run the catalog Python suite, which
checks documented mechanics and roster references as well as authored data:

```bash
/usr/bin/python3 -m unittest discover -s Scripts/tests -p 'test_catalog.py'
```

For changes to the documentation checker, inventory generator, or their hook
routing, also run the focused mutation suite:

```bash
/usr/bin/python3 -m unittest discover -s Scripts/tests -p 'test_check_documentation.py'
```

These documentation-only paths do not require Xcode, a simulator, or
`Scripts/check.sh`. A specification edit describing a future behavior does not
implement it; label proposed behavior explicitly and preserve the request boundary.
If the change also affects app code, catalog JSON/schema, runtime resources,
snapshot/persistence fixtures, scenario JSON or runner behavior, build settings,
or other validation hooks/scripts, use the focused Baguette evidence described
below and report any unobserved contracts as user testing.

The [catalog inventory](../specs/catalog/inventory.md) and
[scenario directory](../Scripts/verify_scenarios/index.md) are generated Markdown.
Refresh them after their JSON inputs change:

```bash
/usr/bin/python3 Scripts/documentation_inventory.py --write
```

Regeneration describes those inputs; it does not replace catalog validation,
scenario execution, or screenshot inspection. Do not regenerate or alter
unrelated inputs merely to hide a pre-existing verification failure.

## Optional read-only structural diagnosis

These checks may diagnose a problem while investigating, but they do not replace
the required focused Baguette check after implementation:

```bash
/usr/bin/python3 Scripts/check_architecture.py
/usr/bin/python3 Scripts/check_documentation.py
/usr/bin/python3 Scripts/check_source_sizes.py
/usr/bin/python3 Scripts/check_complexity.py
```

## Pre-commit hooks

The checked-in `.pre-commit-config.yaml` moves the fast gates earlier than
`Scripts/check.sh`. Install once per clone:

```bash
brew install pre-commit swiftformat swiftlint
pre-commit install
```

The commit stage checks file hygiene, formats staged Swift files under
`vivobody/`, `vivobodyWidgets/`, and `VivoKit/Sources/` with SwiftFormat
(matching the `Scripts/check.sh` formatting boundary), and runs the
architecture, source-size, complexity, documentation, and catalog-parity
guardrails scoped to the files that can break them. The push stage runs the
Python guardrail suites and the VivoKit snapshot contract tests. These hooks do
not expand the agent verification policy; the user may run the full tree with
`pre-commit run --all-files`, adding `--hook-stage pre-push` for the push stage.

## Headless UI verification with Baguette

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
RESET_STATE=0 LAUNCH_ARGS='-debug' TAB=library Scripts/verify.sh
SCENARIO=active-restoration Scripts/verify.sh
```

`-debug` (Debug builds only) adds Lower A (Monday), Upper Push (Tuesday),
Lower B (Thursday), and Upper Pull (Friday), each with five exercises (including one core exercise) and
three sets per exercise. It adds completed workouts on those weekdays from
six calendar months ago through yesterday, with varied reps, logged RIR of 1/0/0 across each exercise’s three sets, and
gradual load progression. Stable fixture IDs prevent duplicates on relaunch;
existing data is preserved and newly elapsed training days are filled in.
Existing dummy templates and sessions receive the core exercise and updated
RIR on the next `-debug` launch; unrelated workouts are unchanged.
The flag takes precedence over the other manual `--seed-*` fixtures.

`-years` (Debug builds only) adds completed history from two calendar years
ago through yesterday. Full Monday–Sunday weeks follow a repeatable mix of
3, 4, and 5 workouts; boundary weeks can be partial. Each workout contains
4–6 catalog exercises with three completed sets, varied reps, logged RIR,
load cycles, and occasional deloads. The weekly mix covers upper and lower
body, pushing, pulling, squatting, hinging, core, and all three movement planes.
This history-only fixture uses its own stable date IDs, preserves existing data,
and fills newly elapsed training days without duplicating its sessions.
It takes precedence over `-debug` and the manual `--seed-*` flags. Previously
seeded history remains additive if switching between fixtures.

```bash
RESET_STATE=0 LAUNCH_ARGS='-years' TAB=history READY_TIMEOUT=120 Scripts/verify.sh
```

For an interactive visual view, use Baguette's local interface and open
`http://127.0.0.1:8421` in a browser:

```bash
baguette serve --host 127.0.0.1 --port 8421
```

This localhost page controls the same headless CoreSimulator process. Do not
open the Simulator app. Use Baguette CLI/scenarios or this local interface for
all automated UI interaction; the `vivobodyUITests` XCTest target is excluded.

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

Start with the [feature/scenario map](../Scripts/verify_scenarios/README.md#choose-evidence-for-the-change)
to select the smallest relevant flow and focused unit suite. The generated
directory lists every scenario and its initial launch options. A normal-state
pass is not evidence for a failure, locked, or accessibility state.

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

## Broader user-run validation

The user may run targeted Swift Testing suites or the broad validator when
deeper logic, persistence, or serialization evidence is needed. Agents do not
run these commands unless the user explicitly requests them.

```bash
# Targeted suite, preferred
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:vivobodyTests/TrainingLoadTests

# SchemaV1 store reopen contract
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO \
  test -only-testing:vivobodyTests/PersistenceStoreContractTests

# Shared widget payload contracts (host-side, no simulator)
swift test --package-path VivoKit

```

Tests use Swift Testing, fixed dates or virtual clocks, and in-memory model
graphs. Follow `vivobodyTests/TrainingLoadTests.swift` for the prevailing style.

## Evidence by change type

| Change | Required evidence |
|---|---|
| Prose-only documentation or instructions | Documentation checker, diff hygiene, and manual guidance review; catalog Python suite when catalog guidance/proposals change; no build |
| Documentation checker, inventory generator, or their hook routing | Prose checks plus `test_check_documentation.py`; no app build |
| Scenario JSON or verification harness | Affected headless scenario with inspected evidence; focused harness tests are user-run |
| Pure analytics or domain logic | Closest semantic Baguette scenario; targeted logic suites are user-run |
| Persistence shape or migration | Closest launch/restoration scenario; store fixtures and migration suites are user-run |
| Session lifecycle | Relevant semantic scenario |
| UI layout or interaction | Inspected Baguette screenshot and accessibility tree |
| VivoKit snapshot payload or widget decoding | Relevant semantic handoff scenario; package tests are user-run |
| HealthKit, StoreKit, provisioning, or hardware behavior | All observable Baguette evidence; list remaining device/App Store checks explicitly |

Anything Baguette cannot observe remains a user-owned manual verification item;
do not substitute an XCTest UI test or unrelated simulator test merely to
produce a green result.

Both appearances are supported. Inspect affected UI in light and dark plus
relevant Dynamic Type, Reduce Motion, and color-differentiation states. Prefer
existing scenario variants; if the chosen scenario does not declare those
settings, capture them explicitly. A filename containing “accessibility” can
test semantic grouping without exercising large text; read its launch and steps.

## Manual maintenance scan

Generate the unscheduled maintenance report with:

```bash
/usr/bin/python3 Scripts/quality_scan.py --output .verify/quality-scan.md
```

Documentation paths, architecture boundaries, source-size growth, and function
complexity are also covered by the user-run `Scripts/check.sh`. Stale dates,
orphaned screens, and repeated UI-surface expressions are deliberately
report-only heuristics.
Review several manual reports and tune false positives before scheduling it.

The SchemaV1 store lives in `vivobodyTests/Fixtures/`. Contract tests reopen a
temporary copy. Retain that fixture permanently and add newer fixtures rather
than rewriting shipped history. The checksum gate in the user-run
`Scripts/check.sh` catches accidental baseline changes.
