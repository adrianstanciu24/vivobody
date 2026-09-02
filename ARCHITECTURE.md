# Vivobody architecture

This document maps the stable structure, dependency directions, and named
boundaries of the repository. Source files remain canonical for current model
members, target settings, identifiers, and version numbers.

## Product shape

Vivobody is a local-first SwiftUI application. SwiftData is the canonical
workout store; system integrations mirror or expose that state without becoming
alternate owners. There is no server or account layer.

| Unit | Responsibility | Canonical definition |
|---|---|---|
| App target | UI, SwiftData ownership, analytics, and system-integration orchestration | `vivobody/` and `vivobody.xcodeproj/project.pbxproj` |
| Widget extension | Widgets, Live Activity presentation, and Control Center surfaces | `vivobodyWidgets/` and `vivobody.xcodeproj/project.pbxproj` |
| Shared package | Value types and APIs that both app and widgets compile | `VivoKit/Package.swift` and `VivoKit/Sources/VivoKit/` |
| Tests | Swift Testing suites and launch/UI coverage | `vivobodyTests/` and `vivobodyUITests/` |

The dependency direction is:

```text
vivobody ---------> VivoKit <--------- vivobodyWidgets
   ^                                      |
   |                                      |
tests                              no SwiftData, no app import
```

The widget extension must never import the app target. A type required on both
sides moves into `VivoKit`; app-only behavior stays in the app.

## Application layers

| Area | Owns | Does not own |
|---|---|---|
| `Screens/` | Presentation, bindings, navigation, user intent | Cross-system side-effect fan-out |
| `Components/` | Reusable UI vocabulary, motion, input, and display primitives | Feature persistence policy |
| `Models/Domain/` | SwiftData entities and domain value types | System-framework integration |
| `Models/Insights/` | Pure analytics over session data through `SessionAnalytics` | Per-render store queries or writes |
| `App/` | App shell, persistence bootstrap, session orchestration, entry points, and app-side adapters | Feature screens |
| `HealthKit/` and `Store/` | Narrow system-framework boundaries | General UI or session ownership |

For unfamiliar work, begin with `vivobody/Models/Domain/WorkoutSession.swift`,
`vivobody/Models/Domain/WorkoutTemplate.swift`, `vivobody/App/AppRoot.swift`,
and `vivobody/App/WorkoutSessionController.swift`, then follow the relevant
feature screen.

## Load-bearing flows

### Persistence

`VivobodyStore.schema` is the source of truth for registered SwiftData models.
`VivobodyStore` is also the only container factory used by the app and store
reopen contract tests. The app entry point preserves an explicit in-memory
recovery path if opening the store fails. Before changing a model, read
`vivobody/App/Persistence.swift`, `vivobody/vivobodyApp.swift`, and
`vivobodyTests/PersistenceStoreContractTests.swift`.

Before the first public release, the app deliberately has one current schema
and no `VersionedSchema` or migration plan; breaking changes may reset
development data and intentionally replace the checked-in baseline. At the
release boundary, freeze the then-current model definitions as `SchemaV1`,
retain its store fixture permanently, and route every later shipped schema
change through explicit versioned migration work.

All user mutations stay in the app and save through the error-reporting helper
in `vivobody/App/SaveError.swift`. The active workout is restored from the
canonical store; UI presentation state is not a substitute for session state.

### Workout lifecycle

```text
screen / external action
        |
        v
WorkoutSessionController
        |
        v
SessionSideEffects
   |       |       |       |
widgets  activity  health  notifications
```

`WorkoutSessionController` owns start, restoration, updates, archive, discard,
minimize, and expansion. `SessionSideEffects` is the single fan-out for
lifecycle effects so restoration and normal interaction cannot diverge.

Expanded-workout set completion keeps presentation and persistence ownership
separate: the active card captures immutable tap-time input, a cancelable
coordinator sequences the acknowledgement, the screen prepares PR presentation,
and `WorkoutSessionController` validates and saves the complete mutation before
the screen applies its committed pager route. Active-card files do not query
analytics, write SwiftData, or fan out session side effects.

### External entry points

URLs, Handoff, Spotlight, widgets, Siri, and App Intent mailboxes normalize to
`IncomingAction`. `IncomingActionParser` parses them and the controller's
`handle(_:)` method is the single dispatch point. New sources extend that path
instead of adding screen-specific routing.

### Diagnostics

`vivobody/App/AppDiagnostics.swift` is the unified-logging vocabulary. Storage,
incoming-action, session, snapshot, and HealthKit boundaries emit stable event
kinds and outcomes through it. Associated IDs, names, notes, loads, URLs, and
HealthKit values never enter logs. Semantic scenarios may assert these events
from their captured runtime log; ad-hoc `Logger` instances are structurally
forbidden outside this boundary.

### Widgets and shared state

The app writes versioned Codable snapshots through
`vivobody/App/WidgetSnapshotWriter.swift` into the App Group. Widgets read
those snapshots and render a sane fallback for missing or old versions.
Interactive controls hand intent back to the app rather than opening SwiftData.
Payload-shape changes require coordinated app, widget, fallback, and versioning
work.

### Insights

Insights are pure functions over sessions and are shared through the
fingerprint-keyed `SessionAnalytics` cache. A new insight normally has a model
under `vivobody/Models/Insights/`, a section under
`vivobody/Screens/Insights/`, and deterministic tests under `vivobodyTests/`.

## Named system boundaries

The authoritative import and call-site allowlists live in
`Scripts/check_architecture.py`. At a high level:

| Concern | Boundary |
|---|---|
| HealthKit archive mirror | `vivobody/HealthKit/HealthKitWorkoutService.swift` |
| StoreKit entitlement and purchases | `vivobody/Store/ProStore.swift` |
| App review prompting | `vivobody/App/ReviewRequestController.swift` |
| Notifications | `vivobody/App/RestNotificationController.swift` |
| Live Activity app control | `vivobody/App/WorkoutLiveActivityController.swift` |
| Spotlight indexing and parsing | `vivobody/App/SpotlightIndexer.swift` and `vivobody/App/IncomingAction.swift` |
| Widget snapshot publication | `vivobody/App/WidgetSnapshotWriter.swift` |
| Privacy-safe unified logging | `vivobody/App/AppDiagnostics.swift` |

Do not duplicate the checker’s exact allowlists here. If ownership changes,
change the code and executable rule together, then update this map if the
conceptual boundary changed.

## UI composition

Screens use `Components/Kit/`, `GlassStyle`, and established inputs instead of
creating parallel design vocabularies. The product behavior and interaction
priorities live in [workout-app-principles.md](workout-app-principles.md); the
maintainability and accessibility bar lives in
[engineering/quality.md](engineering/quality.md).

## Launch path

Only work required for first paint belongs on the synchronous launch path.
Catalog reconciliation, active-session restoration, and pending action
consumption are coordinated in `AppRoot`. Non-critical indexing and snapshot
refreshes are deferred or throttled. Any new launch work must state why it is
critical and how often it runs.

## Architecture changes

When a change introduces a target, reverses a dependency, changes persistence
compatibility, or adds a new system boundary:

1. create an execution plan under `engineering/plans/active/`;
2. update source and the structural checks together;
3. update this document without copying volatile counts or versions;
4. record a durable rationale in `engineering/decisions/` when future work
   would otherwise reopen the same choice;
5. validate through [engineering/verification.md](engineering/verification.md).
