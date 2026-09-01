# Vivobody

Vivobody is a native iOS workout tracker built with SwiftUI and SwiftData. It
is dark-themed, gesture-first, and local-first: there is no server, no account
layer, and no third-party runtime dependency. Workouts live on device, and
system integrations mirror that state instead of owning a second copy of it.

The product is pre-1.0 and maintained by one developer.

## What is in the app

- Today, History, Library, Insights, and Me screens under `vivobody/Screens/`.
- An active workout flow with a first-class rest timer, tap-to-complete sets,
  and drag-to-adjust weight and reps.
- A generated exercise catalog projected from `specs/catalog/` by
  `Scripts/catalog.py`.
- Insights computed as pure functions over recorded sessions, including
  training load, consistency, symmetry, and exercise dominance.
- Home Screen widgets, a Live Activity, and a Control Center start control in
  `vivobodyWidgets/`, fed by versioned App Group snapshots.
- HealthKit workout mirroring and a StoreKit lifetime Pro unlock, each behind a
  narrow boundary.

The public marketing site lives in a separate repository, `vivobody.web`.

## Requirements

- macOS with a current Xcode release and an iOS 26 simulator runtime.
- Python 3 at `/usr/bin/python3` for the guardrail scripts.
- Optional tooling: `brew install swiftformat swiftlint pre-commit baguette`.

The Xcode project and `VivoKit/Package.swift` are canonical for deployment
targets and Swift version. `Shared.xcconfig` is canonical for version numbers.

## Getting started

```bash
git clone <this repository>
cd vivobody
open vivobody.xcodeproj
```

Select the `vivobody` scheme and run on an iOS simulator or a device. Install
the Git hooks once per clone so the fast gates run before the full validator:

```bash
brew install pre-commit swiftformat swiftlint
pre-commit install
```

## Validating a change

`Scripts/check.sh` is the canonical non-UI validator. It runs the guardrail
unit tests, the VivoKit snapshot contracts, the persistence baseline checksum,
architecture, naming, size, complexity, formatting, documentation, and catalog
checks, then builds the full app and widget graph.

```bash
Scripts/check.sh                  # full non-UI validation
Scripts/verify.sh                 # headless Baguette visual and semantic evidence
SCENARIO=active-restoration Scripts/verify.sh
baguette serve --host 127.0.0.1 --port 8421 # optional local visual interface
swift test --package-path VivoKit # shared widget payload contracts
```

Simulator processes stay headless: do not open the Simulator app or run the
XCTest UI-test target. Run the smallest relevant targeted unit suite when logic
changes. [engineering/verification.md](engineering/verification.md) has the
exact commands, the risk-to-evidence matrix, and the Baguette scenario format.

## Repository layout

| Path | Contents |
|---|---|
| `vivobody/` | App target: screens, components, domain models, app shell |
| `vivobodyWidgets/` | Widget extension, Live Activity, Control Center control |
| `VivoKit/` | Swift package shared by the app and the widget extension |
| `vivobodyTests/`, `vivobodyUITests/` | Unit suites and legacy/manual UI-test target; agents run unit suites only |
| `Scripts/` | Guardrails, catalog generator, verification harness |
| `specs/` | Product and engineering specifications, exercise catalog source |
| `engineering/` | Verification, quality, review, tech debt, plans, decisions |

## Documentation map

| Topic | Document |
|---|---|
| Working agreement and definition of done | [AGENTS.md](AGENTS.md) |
| Structure, boundaries, and data flow | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Product behavior and interaction priorities | [workout-app-principles.md](workout-app-principles.md) |
| Proving a change | [engineering/verification.md](engineering/verification.md) |
| Maintainability and accessibility bar | [engineering/quality.md](engineering/quality.md) |
| Reviewing a diff | [engineering/code-review.md](engineering/code-review.md) |
| Known compromises | [engineering/tech-debt.md](engineering/tech-debt.md) |
| Specifications | [specs/index.md](specs/index.md) |
