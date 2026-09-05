# Vivobody

Vivobody is a native iOS workout tracker built with SwiftUI and SwiftData. It
supports light and dark appearances and is gesture-first and local-first:
there is no server, no account layer, and no third-party runtime dependency.
Workouts live on device, and system integrations mirror that state instead of
owning a second copy of it.

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

## How the app fits together

The core journey is to choose a workout on Today, log sets and rest during the
active session, then revisit the completed workout in History. Library owns
exercise discovery and reusable templates. Insights explains patterns across
recorded sessions; Me holds personal context and settings. These are the five
top-level tabs and five is the maximum. Both light and dark appearances are
supported across the app.

| Term | Meaning and governing contract |
|---|---|
| Template | A reusable workout plan. Starting one creates a session; editing a template does not rewrite completed history. |
| Session | One performed workout, either active or archived. Minimizing its UI does not end it. [Lifecycle and ownership](ARCHITECTURE.md#workout-lifecycle) |
| Catalog exercise | A reusable exercise identity and its tracking/mechanics. Bundled entries come from reviewed family JSON; custom entries are user-authored app data. [Exercise contract](specs/exercise-data-contract.md) |
| Exercise snapshot | The exercise facts retained with workout history. Catalog identity and historical performance have different lifetimes. [Identity and instructions](specs/exercise-data-contract.md#identity-and-movement-instructions) |
| Comparable load | Resistance that the app can account for using the exercise's declared load semantics. Bodyweight, assistance, external load, and non-comparable resistance are distinct. [Load semantics](specs/exercise-data-contract.md#load-semantics) |
| Hard sets | Estimated strength-set credit, including effort and muscle-role policy. Muscle attention and balance use this currency; it is not a physiological measurement. [Muscle semantics](specs/exercise-data-contract.md#muscle-roles) |
| Volume load | Accumulated comparable load × reps. Training Load uses it when available in its current/baseline span, with hard sets as fallback. [Measure decision](engineering/decisions/2026-09-03-training-load-measures-volume-load.md) |
| Workout load comparison | One workout versus the average comparable archived workout across normalized set progress. This differs from the rolling Training Load report. [Receipt contract](specs/workout-load-comparison.md) |

Workout logging and history remain free; Pro unlocks analysis and selected
integrations. Read the [entitlement contract](specs/free-with-pro-iap.md) before
changing access. The [routine builder](specs/strength-routine-builder.md) is
implemented but intentionally hidden behind a DEBUG route. Watch documents
are research, not an existing watch app. There is no server or account layer.
Use the [spec index](specs/index.md) to distinguish active behavior from history
and research before extending a feature.

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

Prose-only changes use `/usr/bin/python3 Scripts/check_documentation.py` and
`git diff --check`. Documentation-tooling changes also run their focused Python
tests. See the [scope rules](engineering/verification.md#documentation-and-process-tooling)
before selecting the lighter path.

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
