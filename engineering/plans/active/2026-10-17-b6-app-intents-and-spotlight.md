# B6. App Intents and Spotlight

Status: Implemented on 2026-10-17. Device tests are open. Parent plan:[native SwiftUI adoption](2026-10-17-native-swiftui-adoption.md), issues 18 and 19.

## Decisions

- Spotlight: `IndexedEntity` replaces the CoreSpotlight items for templates
  and catalog exercises.
- Live Activity: Complete Set runs in the background. The app stays closed.
- Start Workout (widget, control, Siri) still opens the app. It uses
  `supportedModes = .foreground(.immediate)` in place of the deprecated
  `openAppWhenRun`.

## API facts

Checked against the iOS 27.0 SDK interface. All APIs are available on iOS 26.1.

- `AppDependencyManager.shared.add(dependency:)` takes a `Sendable` value.
  `@Dependency` reads it in an intent or a query. Register in `App.init`.
  A missing registration can crash, so never run an intent that reads a
  dependency in a process that did not register it.
- `supportedModes: IntentModes` (iOS 26). `.foreground(.immediate)` opens the
  app before `perform()`. `.background` does not open the app.
- `LiveActivityIntent` (iOS 17). `perform()` runs in the app process, which the
  system can launch in the background. The widget extension never runs it.
- Entity queries for app-target intents run in the app process. The query can
  read SwiftData through a `ModelContainer` dependency.
- `IndexedEntity` (iOS 18) with `CSSearchableIndex.indexAppEntities(_:)` and
  `deleteAppEntities(identifiedBy:ofType:)`. A Spotlight tap runs the matching
  `OpenIntent`. It does not reliably arrive as `CSSearchableItemActionType`.
- `AppIntent.perform()` is not main-actor isolated. VivoKit has no default
  isolation. Mark `perform()` `@MainActor` where it calls app code.

## Design

### Process boundary

| Code | Target | Runs in |
|---|---|---|
| `StartTodaysWorkoutIntent`, `CompleteActiveSetIntent`, `WorkoutIntentActions` | VivoKit (app and widget link it) | App process only |
| `AppIntentRouter`, dependency registration | App | App process |
| Template and exercise entities, queries, open intents, `StartTemplateWorkoutIntent` | App | App process |
| Widget, control, Live Activity views | Widget extension | Extension; builds intent values only |

The widget extension registers no dependency and gains no write path. It only
constructs intent values for `Button(intent:)` and `ControlWidgetButton`.

### VivoKit

- `WorkoutIntentActions`: a `Sendable` struct with two
  `@MainActor @Sendable () async -> Void` closures, `startTodaysWorkout` and
  `completeActiveSet`. No SwiftData types.
- `StartTodaysWorkoutIntent`: `.foreground(.immediate)`. `perform()` calls
  `actions.startTodaysWorkout()`.
- `CompleteActiveSetIntent`: `LiveActivityIntent`, `.background`. `perform()`
  calls `actions.completeActiveSet()`.
- Remove the three mailbox keys and `templatesSnapshotKey` from `WidgetShared`.

### App

- `VivobodyApp` creates `AppState` with the other dependencies, so one
  `AppState` exists per process even when no scene connects. `AppRoot` takes it
  as a parameter. `App.init` registers `WorkoutIntentActions`, the
  `AppIntentRouter`, and the `ModelContainer`.
- `AppIntentRouter` (`@MainActor`, app target) is the only entry point for App
  Intents. It routes to `WorkoutSessionController.handle(_:)`.
  - Foreground actions (start today, start template, open template, open
    exercise) wait until `AppRoot` calls `attach()` from the place where it used
    to drain the mailboxes. Before that, the router holds them in memory in
    arrival order. This keeps the old launch order: restore, then act.
  - Background Complete Set does not wait for a scene. If the controller has no
    context, the router gives it `container.mainContext` and restores the active
    workout. It then completes the set without presenting the workout. If the
    app is not active, it schedules the rest notification, as scene deactivation
    does.
- `IncomingActionParser` loses the three mailbox parsers. The URL, Handoff, and
  legacy Spotlight parsers stay. `AppRoot.consumeIncomingActions()` becomes
  `router.attach()`.
- DEBUG: the `widgetStartRequest` launch step sends `.startTodaysWorkout`
  through the router. `DebugStoreResetter` and `DebugSeedRoutingTests` stop
  using mailbox keys.

### Templates and exercises

- `WorkoutTemplateEntity` and a new `ExerciseEntity` are `IndexedEntity`
  values with the same title, description, keywords, and ranking hint as the
  current searchable items.
- The queries read SwiftData through the `ModelContainer` dependency on the
  main actor. The template snapshot in the App Group and `TemplateEntitySnapshot`
  are deleted.
- `OpenWorkoutTemplateIntent` (starts the template, the current Spotlight
  behavior) and `OpenExerciseIntent` (shows the exercise detail) are
  `OpenIntent`s that call the router.
- `SpotlightIndexer` keeps its role and API names for callers, but indexes
  entities with `indexAppEntities` and removes them with `deleteAppEntities`.
  `SpotlightIndexStore` builds entity values on its `ModelActor`.
- The launch fingerprint gains an entity version. The first launch after the
  update deletes the two legacy CoreSpotlight domains and indexes entities.
- The `CSSearchableItemActionType` handler stays for taps on legacy items.

## Changes after review

Two reviewers checked the first version. These changes fix their findings:

- Background Complete Set waits for its side effects before `perform()`
  returns: `SessionSideEffects.flushExternalPresentation` writes the widget
  snapshot at once, flushes the Live Activity, and waits for the rest
  notification request.
- Live Activity content has `staleDate` set to the rest end. When the content
  is stale, the Lock Screen and Dynamic Island show Complete again, so the user
  can log the next set with the app closed. A Complete tap during rest ends the
  rest early (as Skip does in the app), then completes the set. An elapsed rest
  ends without the "rest complete" cue.
- `handle(.completeActiveSet)` completes without presenting the workout. The
  router calls it, so all external actions use the central handler.
- `CompleteActiveSetIntent.isDiscoverable` is `false`. It does not show in
  Shortcuts.
- `AppRoot` removes the retired App Group keys (`WidgetShared.retiredKeys`) at
  launch. One of them held template names.
- `SpotlightIndexer` runs all index operations in one serial queue. Launch
  maintenance prepares its payload inside that queue, so a change made during
  the reindex is not lost. `reindexAll` also deletes the legacy domains.
## Steps

1. Intents and router: VivoKit intents, `AppIntentRouter`, app wiring,
   background completion, mailbox removal, DEBUG seed and test updates.
2. Entities and Spotlight: entity queries on SwiftData, `IndexedEntity`, open
   intents, indexer rewrite, template snapshot removal,
   `Scripts/check_architecture.py` boundary.
3. Documentation: ARCHITECTURE.md "External entry points" and integration
   ownership rows; the parent plan progress.
4. Review with independent reviewers. Fix findings.

## Checks

- Build the app scheme (it builds the widget extension and VivoKit).
- `/usr/bin/python3 Scripts/check_architecture.py`.
- Baguette: `widget-start-handoff`, `deep-link-insights`.
- Documentation: `/usr/bin/python3 Scripts/check_documentation.py` and
  `git diff --check`.

## User tests on a device

- Cold launch and warm launch from the Up Next widget, the Control Center
  control, the Action Button, and Siri ("Start my workout in vivobody").
- Live Activity Complete: app closed, app suspended, and app open. The set
  completes, rest starts, the Live Activity updates, and the app stays closed.
  When the rest ends, Complete shows again on the Lock Screen and in the
  Dynamic Island, and the next tap logs the next set.- Siri and Shortcuts template parameter: the list shows current templates
  after a rename or delete, with the app closed.
- Spotlight: search a template and an exercise. A template tap starts it; an
  exercise tap shows its detail. Old results do not appear twice.
