# Vivobody

Vivobody is a native SwiftUI and SwiftData workout tracker for iOS. It stores all data on the device and has no third-party runtime libraries.

## Commands
- Open: `open vivobody.xcodeproj` (schemes: `vivobody`, `vivobodyWidgets`, `VivoKit`)
- Build: `xcodebuild -scheme vivobody -destination 'generic/platform=iOS Simulator' build`
- Format: `swiftformat vivobody/ vivobodyWidgets/ VivoKit/Sources/`
- UI check: `SCENARIO=<name> Scripts/verify.sh` (scenarios are in `Scripts/verify_scenarios/`)

## Stack and tools
- Swift 6, SwiftUI, SwiftData, WidgetKit, ActivityKit.
- Xcode 27.2 and iOS 27.2 simulators. Always use the latest Xcode and simulator version; update this line when a new version ships.
- SwiftFormat and pre-commit. Baguette (`brew install baguette`) for headless UI checks.

## Layout
- `vivobody/` – app: `App/` (state, persistence, session), `Models/`, `Screens/`, `Components/`
- `vivobodyWidgets/` – widgets, Live Activity, and controls
- `VivoKit/` – contracts shared by the app and widgets
- `Scripts/` – `verify.sh`, the scenario runner, and the architecture and naming guardrails

## Boundaries
- Always: save through `context.saveOrRollback()` and surface errors. Log through `AppDiagnostics`, without workout values.
- Always: support light and dark appearance. Make controls 44pt or larger.
- Always: route session lifetime through `WorkoutSessionController`, and external actions through `IncomingActionParser`.
- Ask first: new dependencies, SwiftData schema changes, a sixth top-level tab.
- Never: write SwiftData from widgets (they read snapshots).
- Never: write tests (unit, UI, or snapshot).

## Verification
We do not write tests. Verify once, when the change is complete, not after each edit:
- Logic, model, or persistence change with no visible effect: run an incremental build only.
- UI, navigation, or interaction change: run one relevant scenario with `SCENARIO=<name> Scripts/verify.sh`. It also builds, so do not build first. Inspect its screenshot and accessibility tree.
- Do not use `CLEAN_BUILD=1` unless the build cache is broken.
- The commit hooks run formatting and the guardrails. The push hook runs the VivoKit tests.

## Git
- Commit format: imperative subject, for example `Add workout load comparison to workout receipts`.
- PR: explain the problem and the new behavior, list the checks you ran, and add screenshots for UI changes.

## More docs (read when relevant)
- `workout-app-principles.md` – product and UX rules
- `Scripts/verify_scenarios/README.md` – scenario format and which scenario to run
- `.agents/skills/typesafe-ai/SKILL.md` – AI features with TypeSafe
