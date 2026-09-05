# Repository Guidelines

Vivobody is a native iOS workout tracker built with SwiftUI and SwiftData, with on-device storage and no third-party runtime libraries.

## Project Structure & Module Organization

`vivobody/` contains `App/`, `Models/`, `Screens/`, `Components/`, `Assets.xcassets/`, and `Resources/`. `vivobodyWidgets/` owns widget surfaces; `VivoKit/` shares app/widget contracts. Tests live in `vivobodyTests/` and `VivoKit/Tests/`. Author exercises in `specs/catalog/families/`; generate `vivobody/Resources/catalog.json` with `Scripts/catalog.py`.

## Build, Test, and Development Commands

Use macOS and Xcode; run commands from the repository root:

```bash
Scripts/check.sh # Required guardrails, contracts, catalog checks, and build
xcodebuild -scheme vivobody -destination 'generic/platform=iOS Simulator' build
swift test --package-path VivoKit # Shared snapshot contracts
swiftformat vivobody/ vivobodyWidgets/ VivoKit/Sources/ # Format Swift
Scripts/verify.sh # Headless Baguette screenshots and accessibility evidence
```

## Coding Style & Naming Conventions

Use four-space indentation, PascalCase types, and lowerCamelCase members without underscores. SwiftFormat owns formatting; `Scripts/check_naming.py` enforces naming; SwiftLint measures complexity. Respect source-size and complexity ratchets. Start Swift files with purpose headers; give reusable components nearby DEBUG galleries.

## Testing Guidelines

Use Swift Testing, `<Feature>Tests.swift` suites, descriptive lowerCamelCase `@Test` functions, and deterministic clocks. Cover changed behavior and failure paths with the smallest relevant suite:

```bash
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:vivobodyTests/TrainingLoadTests
```

Follow [verification requirements](engineering/verification.md), including persistence and snapshot contracts when affected. Keep simulators headless: never open Simulator.app, run XCTest UI tests, or run the full simulator suite. Inspect screenshots and accessibility trees for UI changes; record device-only checks.

## Architecture & Product Boundaries

Read [ARCHITECTURE.md](ARCHITECTURE.md) before data-flow changes and `vivobody/App/Persistence.swift` plus `vivobody/vivobodyApp.swift` before model changes. Only the app writes SwiftData; widgets consume snapshots. Save through `context.saveOrRollback()` and surface errors. `WorkoutSessionController` owns session lifetime; route lifecycle effects through `SessionSideEffects` and external actions through `IncomingActionParser` plus the central handler. Log through `AppDiagnostics` without workout values. Use `SettingsKey`, `WeightFormatter`, and `ScreenKit`/`PanelKit`/`GlassStyle` with 44pt-or-larger controls. Read [product principles](workout-app-principles.md) and [quality guidance](engineering/quality.md) for UX work.

## Commit & Pull Request Guidelines

Recent commits use imperative subjects, such as `Add workout load comparison to workout receipts`. Keep changes focused and preserve unrelated work. PRs should explain the problem, resulting behavior, relevant issue, validation, and manual gaps; include screenshot evidence for UI changes. Review against [the checklist](engineering/code-review.md). Update affected specs and documentation; keep current coordination in `worklog.md` and use [execution plans](engineering/plans/README.md) for risky work.
