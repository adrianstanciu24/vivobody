# vivobody

Starter instructions for AI coding agents working in this repository. Keep this file current as the project evolves.

## Canonical CLI Validation Commands

- Install repo-managed developer tools: `brew bundle --file Brewfile`
- Format Swift code in place: `./scripts/format-swift.sh`
- Run Swift style validation: `./scripts/lint-swift.sh`
- List project settings and schemes: `xcodebuild -list -project vivobody.xcodeproj`
- Build the main app scheme: `xcodebuild -project vivobody.xcodeproj -scheme vivobody -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Run all tests for the main scheme: `xcodebuild -project vivobody.xcodeproj -scheme vivobody -destination 'platform=iOS Simulator,name=iPhone 17' test`
- Run only unit tests: `xcodebuild -project vivobody.xcodeproj -scheme vivobody -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:vivobodyTests test`
- Run only UI tests: `xcodebuild -project vivobody.xcodeproj -scheme vivobody -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:vivobodyUITests test`

These are the source-of-truth command lines for reproducible validation and final reported results.
Use simulator builds/tests for routine validation unless a task explicitly requires a physical device.

## Tool Selection Rules

Do not guess which tool family to use. Follow these rules exactly.

### Required project skills

- Always use these 4 existing project skills when working in this repository so the implementation follows stronger Swift, UI, data, and testing practices:
  - `swiftui-pro` for SwiftUI views, state flow, navigation, and previews.
  - `swiftdata-pro` for `SwiftData` models, queries, persistence, and container usage.
  - `swift-testing-pro` for unit tests, UI tests, and `Testing` framework coverage.
  - `swift-concurrency-pro` for `async/await`, actor isolation, `@MainActor`, and sendability concerns.
- Before starting any non-trivial Swift task, invoke every relevant skill from this list.
- If a change touches multiple areas, use all applicable skills instead of picking only one.

### Xcode MCP bootstrap

- Before any Xcode MCP action, call `XcodeListWindows` and use the returned `tabIdentifier` for all Xcode MCP calls.
- In this repository, the current Xcode project is `vivobody.xcodeproj`.

### Use Xcode MCP tools for project-aware iOS work

- Use `BuildProject` for quick IDE-style compile checks during iteration. Do not use it as the only final validation proof when a canonical `xcodebuild` command exists above.
- Use `RunAllTests` for quick full test-plan runs during iteration. For final reported validation, also run the matching canonical `xcodebuild` command above.
- Use `RunSomeTests` together with `GetTestList` when only specific tests should run during development.
- Use `XcodeRefreshCodeIssuesInFile` for compiler issues in one file.
- Use `XcodeListNavigatorIssues` or `GetBuildLog` to inspect structured Xcode build/test issues.
- Use `RenderPreview` after changing SwiftUI views when preview validation is relevant.
- Use `ExecuteSnippet` for small Swift experiments in project context.
- Use `DocumentationSearch` for Apple framework API lookups.
- Use `XcodeRead`, `XcodeUpdate`, `XcodeWrite`, `XcodeLS`, `XcodeGlob`, `XcodeGrep`, `XcodeMV`, `XcodeMakeDir`, and `XcodeRM` only for files and folders that are part of the Xcode project structure.

### Use regular repo tools for filesystem / repo work

- Use `Read`, `ApplyPatch`, `LS`, `Glob`, and `Grep` for repository files outside Xcode project awareness.
- Use regular file tools for `AGENTS.md`, `Brewfile`, shell scripts, lint/format config files, `.plist` inspection outside navigator workflows, and any future backend or infra files.
- Use `Grep` and `Glob` instead of shell `grep` / `find` for repo-wide searches.
- Use `TodoWrite` for any non-trivial task.

### Use shell commands only for explicit command-line workflows

- Use `Execute` with `xcodebuild ...` for final validation runs, reproducible simulator-targeted test/build commands, and any result that should be easy to match in CI.
- Use `Execute` for `./scripts/format-swift.sh` and `./scripts/lint-swift.sh`. Do not use Xcode MCP tools for formatting or linting.
- Use `Execute` for `git status`, `git diff`, commits, and other git workflows.
- Use `Execute` only when the action is not better served by an existing structured tool.

### Default choices in this repo

- Editing Swift or test source inside the app project: prefer Xcode MCP file tools.
- Editing repository-level instructions such as `AGENTS.md`: use regular file tools.
- Debugging compile failures: use `BuildProject` first, then `XcodeRefreshCodeIssuesInFile` / `GetBuildLog`.
- Checking SwiftUI view changes: use `RenderPreview` first, then simulator tests if needed.
- Final completion validation: run the appropriate `xcodebuild` command via `Execute`.

## Project Layout

- `vivobody/` — app source
- `vivobody/vivobodyApp.swift` — app entry point and `SwiftData` container setup
- `vivobody/ContentView.swift` — current root UI
- `vivobody/Item.swift` — current `SwiftData` model
- `vivobodyTests/` — unit tests using the Swift `Testing` framework
- `vivobodyUITests/` — UI tests using `XCTest`

## Architecture Overview

- The app currently uses `SwiftUI` for UI and `SwiftData` for persistence.
- `vivobodyApp` owns the shared model container and injects it into the view hierarchy.
- Keep persistence concerns in models / data-facing code and keep views focused on presentation and user interaction.

## iOS Conventions

- Prefer `SwiftUI` patterns already present in the codebase over introducing UIKit.
- Prefer `async/await` for new asynchronous work.
- Keep UI-affecting code on the main actor when needed.
- Preserve and update `#Preview` blocks when editing SwiftUI views.
- Match the existing Swift style and keep changes local to the feature or bug being worked on.
- Run `./scripts/format-swift.sh` after Swift source edits before final validation.
- Fix `./scripts/lint-swift.sh` failures instead of suppressing them unless the task explicitly requires a rule change.
- Do not introduce new package dependencies unless the task requires it.

## Style Tooling

- Swift formatting is enforced with `SwiftFormat` using `.swiftformat`.
- Swift linting is enforced with `SwiftLint` using `.swiftlint.yml`.
- Tool installation is repo-managed via `Brewfile`.
- Agents should not invent ad-hoc formatting commands; use the repo scripts only.
- If `swiftformat` or `swiftlint` is missing, run `brew bundle --file Brewfile` before editing more code.
- Do not modify `.swiftformat`, `.swiftlint.yml`, `.swift-version`, `Brewfile`, or `scripts/format-swift.sh` / `scripts/lint-swift.sh` unless the task explicitly asks for style-tooling changes.

## Required Agent Workflow For Swift Changes

When a task changes any `.swift` file, follow this exact order:

1. Edit code using Xcode MCP file tools when the file is inside the Xcode project.
2. Run `./scripts/format-swift.sh` with `Execute`.
3. Run `./scripts/lint-swift.sh` with `Execute`.
4. Run the smallest relevant Xcode validation while iterating:
   - `BuildProject` for compile checks
   - `RenderPreview` for SwiftUI view changes
   - `RunSomeTests` for targeted tests
5. Before reporting completion, run the final canonical CLI validation with `Execute`:
   - usually `xcodebuild -project vivobody.xcodeproj -scheme vivobody -destination 'platform=iOS Simulator,name=iPhone 17' test`

Do not skip formatting or linting after Swift edits.
Do not use Xcode MCP as the final reported validation when a canonical CLI command exists.

## Validation Expectations

- After Swift code changes, run `./scripts/format-swift.sh`, then `./scripts/lint-swift.sh`, then the smallest relevant Xcode validation, then the full scheme tests before finishing significant work.
- Use Xcode MCP for fast iterative checks while developing.
- Use the canonical `xcodebuild` commands from `Canonical CLI Validation Commands` for the final reported validation result.
- For UI-only changes, prefer checking previews and the relevant UI tests when available.
- For model or persistence changes, add or update tests to cover the behavior.
- Do not claim a fix without objective validation.

## Safety / Guardrails

- Do not change bundle identifiers, signing settings, team settings, or entitlements unless explicitly asked.
- Avoid editing `Info.plist` unless the task requires it.
- Keep Xcode project file changes minimal and intentional.
- Do not touch generated user-specific Xcode files under `xcuserdata/`.

## Git Workflow

- Keep diffs tightly scoped.
- Prefer small, reviewable commits.
- Before any commit, review `git status`, `git diff --cached`, and check for secrets or unintended project file changes.

## Updating This File

- Add new architecture, tooling, or validation rules here as they become real project conventions.
- Prefer concise, copy-pasteable commands and repository-specific guidance over generic advice.
