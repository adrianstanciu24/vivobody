# Repository Guidelines

Vivobody is a native SwiftUI/SwiftData workout tracker with on-device storage and no third-party runtime libraries. Start unfamiliar work with the [product overview and domain vocabulary](README.md#how-the-app-fits-together).

## Start with the task

Inspect `git status --short` and [worklog.md](worklog.md) before editing. Preserve unrelated changes. Read only the guidance relevant to the request:

| Task | Read first | Verification |
|---|---|---|
| Understand a feature or change its behavior | [Spec index](specs/index.md), then the active feature contract | Relevant row in the [evidence matrix](engineering/verification.md#evidence-by-change-type) |
| UI, navigation, appearance, or copy | [Product principles](workout-app-principles.md), [quality](engineering/quality.md), active feature spec | [Feature/scenario map](Scripts/verify_scenarios/README.md#choose-evidence-for-the-change); inspect light, dark, and relevant accessibility states |
| Add or review a bundled exercise or family | [Repository catalog skill](.agents/skills/vivobody-add-exercise/SKILL.md), [catalog foundation](specs/catalog/README.md) | Skill's catalog gates and relevant Library/detail scenario |
| Custom exercises, templates, or exercise selection | [Exercise contract](specs/exercise-data-contract.md), applicable spec in the index | Focused domain suite and relevant Library scenario |
| Persistence, session lifetime, or integrations | [Architecture](ARCHITECTURE.md), applicable feature spec | Boundary contracts in the evidence matrix |
| Docs, instructions, or process tooling | [Documentation maintenance](engineering/quality.md#documentation-maintenance), [workflow and handoffs](engineering/plans/README.md) | [Documentation and tooling checks](engineering/verification.md#documentation-and-process-tooling) |
| Review a change | Request, relevant contract/plan, [review checklist](engineering/code-review.md) | Assess the existing evidence; report gaps within the review's scope |

Current task instructions set the authorized scope. Active specs define feature behavior; product principles define shared UX constraints; architecture defines ownership. Historical plans, proposals, and design notes explain past choices. If current guides conflict, resolve the affected rule explicitly rather than silently choosing one. Executable checks prove only the contracts they check.

## Action boundaries

A review or investigation is read-only unless fixes are requested. A plan request authorizes planning, including a plan file when useful, and ends before implementation. An implementation request authorizes completing that scope and its verification; do not ask again for already-authorized steps. Follow [workflow and handoff guidance](engineering/plans/README.md) for active work and durable decisions.

## Project Structure & Module Organization

`vivobody/` contains `App/`, `Models/`, `Screens/`, `Components/`, `Assets.xcassets/`, and `Resources/`. `vivobodyWidgets/` owns widget surfaces; `VivoKit/` shares app/widget contracts. Tests live in `vivobodyTests/` and `VivoKit/Tests/`. Author exercises in `specs/catalog/families/`; generate `vivobody/Resources/catalog.json` with `Scripts/catalog.py`.

## Build, Test, and Development Commands

Use macOS and Xcode; run commands from the repository root:

```bash
Scripts/check.sh # Required for app, data, build, and runtime-contract changes
/usr/bin/python3 Scripts/check_documentation.py # Prose-only validation; see verification guide
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

Read [ARCHITECTURE.md](ARCHITECTURE.md) before data-flow changes and `vivobody/App/Persistence.swift` plus `vivobody/vivobodyApp.swift` before model changes. Only the app writes SwiftData; widgets consume snapshots. Save through `context.saveOrRollback()` and surface errors. `WorkoutSessionController` owns session lifetime; route lifecycle effects through `SessionSideEffects` and external actions through `IncomingActionParser` plus the central handler. Log through `AppDiagnostics` without workout values. Use `SettingsKey`, `WeightFormatter`, and `ScreenKit`/`PanelKit`/`GlassStyle` with 44pt-or-larger controls. Both light and dark appearances are supported; the app has a maximum of five top-level tabs.

## Commit & Pull Request Guidelines

Recent commits use imperative subjects, such as `Add workout load comparison to workout receipts`. Keep changes focused and preserve unrelated work. PRs should explain the problem, resulting behavior, relevant issue, validation, and manual gaps; include screenshot evidence for UI changes. Review against [the checklist](engineering/code-review.md). Update affected specs and documentation; keep current coordination in `worklog.md` and use [execution plans](engineering/plans/README.md) for risky work.
