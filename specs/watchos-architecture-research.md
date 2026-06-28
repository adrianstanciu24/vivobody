# watchOS App Architecture Research (2025-2026)

Research summary for building a watchOS app for a workout/fitness application.
Sources: Apple Developer Documentation, WWDC 2023/2025/2026 sessions, TN3157,
and expert practitioner write-ups. Current state: watchOS 26 shipped (Xcode 26),
watchOS 27 in beta (Xcode 27).

---

## 1. App Architecture

### The single-target model (the modern standard)

Since **Xcode 14 (2022)**, new watchOS apps use a **single-target architecture**.
Historically watchOS apps were "dual-target": a WatchKit App target (containing
only resources/storyboards) plus a WatchKit Extension target (containing all
code). The single-target model collapses these into one watchOS app target that
holds both code and resources, eliminating confusion about where to embed a
resource or apply an entitlement.

Key facts (from TN3157):
- **Single-target watchOS apps work on watchOS 7 and later.**
- At the code level, converting dual-target to single-target replaces
  `WKExtension` / `WKExtensionDelegate` with `WKApplication` /
  `WKApplicationDelegate`.
- WatchKit storyboards were **deprecated in watchOS 7 (2020)**. Xcode 14
  removed the ability to create new WatchKit storyboards. **SwiftUI is the
  only supported path for new UI.**
- **ClockKit complications were deprecated in watchOS 10 (2023)**; the
  replacement is **WidgetKit complications** (which also support the Smart
  Stack).

### Distribution models

Three options when creating a project (from "Setting up a watchOS project"):
1. **Watch-only App** - no companion iOS app; installs and runs independently.
2. **Watch App with New Companion iOS App** - creates both targets together.
3. **Watch app for Existing iOS App** - adds a watchOS target to an existing
   iOS project (the relevant path for vivobody).

### Terminology (TN3157)
- **Dependent** app relies on its companion iOS app to function.
- **Independent** app works when the paired iPhone isn't nearby or the iOS app
  isn't installed. It may or may not have a companion iOS app.
- **Watch-only** app has no companion iOS app.

Apple's strong recommendation: **build independent watchOS apps**. Users expect
Apple Watch apps to "just work" without the iPhone present.

### App entry point (SwiftUI lifecycle)

Use the SwiftUI `App` protocol with `@main`. No storyboards, no
`WKExtensionDelegate` unless needed.

```swift
import SwiftUI
import WatchKit

@main
struct VivobodyWatchApp: App {
    // Optional: connect an app delegate for events SwiftUI doesn't handle
    // (workout recovery, extended runtime sessions, remote notifications, etc.)
    @WKApplicationDelegateAdaptor var appDelegate: WatchAppDelegate

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }
}
```

Use `@WKApplicationDelegateAdaptor` (not `@UIApplicationDelegateAdaptor`) to
attach a `WKApplicationDelegate`. You need an app delegate to handle:
- Life-cycle events not covered by `scenePhase`
- `userInfo` dictionaries from handoff or complications
- Remote Now Playing activity
- **Workout configurations and recovery** (relevant for a fitness app)
- **Extended runtime sessions**
- Registration of remote notifications

### Key Info.plist keys
- `WKWatchKitApp` - Boolean indicating the bundle is a watchOS app.
- `WKAppBundleIdentifier` - bundle ID of the watchOS app.
- `WKCompanionAppBundleIdentifier` - bundle ID of the companion iOS app.
- `WKRunsIndependentlyOfCompanionApp` - whether the watch app installs/runs
  independently of the iOS app.
- `WKWatchOnly` - whether the app is watch-only.
- `WKBackgroundModes` - services requiring background execution
  (e.g., `workout-processing`, `audio`).
- `WKExtensionDelegateClassName` - (legacy dual-target only) extension delegate.

---

## 2. SwiftUI on watchOS

### What's available / how it differs from iOS

SwiftUI on watchOS is now the **primary and recommended UI framework**; it gives
"considerably more freedom, power, and control than user interfaces laid out in
a storyboard." `List` supports features `WKInterfaceTable` never did: platter
style, swipe actions, and row reordering.

Available SwiftUI components and patterns on watchOS (watchOS 10+ design):
- **`NavigationStack`** - hierarchical navigation (push/pop a path array). Use a
  large title on the root; no title on subsequent views where a back button is
  present. Keep hierarchies shallow.
- **`NavigationSplitView`** - toggles between a source list and detail views.
  On watchOS only one column shows at a time; selecting an item animates to the
  detail. Combine with `.listStyle(.carousel)`.
- **`TabView`** - on watchOS this is a **set of pages scrolled with the Digital
  Crown**, not a bottom tab bar. `.tabViewStyle(.verticalPage)` produces vertical
  pagination with a page indicator next to the Digital Crown. This is the
  signature watchOS navigation idiom.
- **`List`** with swipe actions, reordering, `.listStyle(.carousel)`.
- **`ScrollView`** - vertical scrolling is emphasized over horizontal; the
  Digital Crown drives precise scrolling.
- **`Picker`** - system control that already supports the Digital Crown.
- **Toolbars** - place up to 2 top buttons (leading/trailing) and up to 3 bottom
  buttons. The center bottom button can be made larger/prominent. Scrolling
  toolbar buttons (`ToolbarItemPlacement.primaryAction`) reveal on scroll-up.
- **`containerBackground(_:for:)`** - for full-color/gradient backgrounds inside
  `NavigationSplitView`, `NavigationStack`, or `TabView`, pass `.navigation` or
  `.tabView` placement. Plain views can use `.background(...)`.
- **`Material`** - vibrant fills on controls/list cells; full-screen thin
  material on sheets/full-screen covers; blur behind the nav bar.
- **Hierarchical foreground styles** - `.primary`, `.secondary`, `.tertiary`,
  `.quaternary` for typographic hierarchy over color backgrounds.
- **`matchedGeometryEffect`** - animate a persistent element's size/position
  between tabs (continuity across pages).
- **`Button` styles** - `.borderedProminent` to make a button prominent.

### watchOS-specific UI considerations
- **Glanceability is the core principle.** Design for a 1-2 second glance.
  Limit each vertical-page view to roughly one screen of information.
- **Digital Crown first.** Emphasize vertical scrolling; use system controls
  that already support the Crown (e.g., `Picker`).
- **Full-screen color** conveys branding/emotion/state at a glance (e.g., Timer
  turns orange when done).
- **No bottom tab bar.** Navigation is via `TabView` vertical pages,
  `NavigationSplitView`, or `NavigationStack` - never a UIKit-style tab bar.
- **No `NavigationLink(value:)` + `.navigationDestination` reliability caveat**
  is an iOS/SwiftData gotcha; on watchOS the path-array `NavigationStack(path:)`
  form is well-supported.
- **Screen is small** (~242-282px wide depending on model); large tap targets,
  minimal chrome.
- **watchOS 26 SwiftUI changes** (from release notes): `ControlSize` conforms to
  `Comparable`; `NavigationLink`s produce a single view (perf improvement in
  lazy `List`); `buttonSizing(_:)` modifier for flexible buttons;
  `buttonBorderShape(_:)` now affects bordered buttons in apps adopting the new
  design. Known issue: `toolbarForegroundStyle` no longer tints toolbar labels
  on watchOS (workaround: tint the label directly).

### Liquid Glass (watchOS 26 / 27)
Apple's new unified platform design language "elevates the content people care
about most." New design refinements improve consistency, readability, and
accessibility, and introduce ways for apps to adapt across devices/screen sizes.
Build with the latest SwiftUI APIs for system materials, tab views, split views.

---

## 3. App Lifecycle

### Foreground-first runtime model
watchOS apps **primarily run in the foreground** to limit system resource impact.
Background execution is allowed only for a limited set of cases. This is
fundamentally different from iOS - there is no iOS-style general background
execution. **A recognized session type is the contract that keeps an app
running through wrist-drop.**

### Background execution options (from "Background execution")
1. **Background notifications** - `UNUserNotificationCenterDelegate` for local/
   remote notifications; `PKPushRegistryDelegate` (PushKit) for complication
   push updates.
2. **Background refresh tasks** - scheduled, a few seconds of execution. Handle
   via `.backgroundTask(_:action:)` SwiftUI scene modifier OR app delegate's
   `handle(_:)`. Always call
   `setTaskCompletedWithSnapshot(_:)` when done. Task types:
   `WKApplicationRefreshBackgroundTask`, `WKURLSessionRefreshBackgroundTask`,
   `WKWatchConnectivityRefreshBackgroundTask`, `WKSnapshotRefreshBackgroundTask`,
   `WKBluetoothAlertRefreshBackgroundTask`, `WKIntentDidRunRefreshBackgroundTask`,
   `WKRelevantShortcutRefreshBackgroundTask`.
3. **Background sessions** (run until the session ends; require a
   `WKBackgroundModes` capability):
   - **`HKWorkoutSession`** - workouts continue in background. Requires the
     **Workout processing** background mode. Add **Audio** mode if you play
     audio/haptics during the workout.
   - **`AVAudioSession`** - extended background audio. Requires Audio mode.
   - **`CLLocationManager`** with `allowsBackgroundLocationUpdates` - continuous
     background location. Requires Location updates mode.
4. **Extended runtime sessions** (`WKExtendedRuntimeSession`) - additional time
   after the user stops interacting. Session types: **self care, mindfulness,
   physical therapy, smart alarm.** Lets the app keep talking to Bluetooth,
   process data, or play sounds/haptics after the screen turns off. Most run
   the app as frontmost; some run in background. Choose by intended use, not by
   features.

### Workout session lifecycle (critical for a fitness app)
`HKWorkoutSession` is a six-state machine:
`notStarted -> prepared -> running -> (paused -> running)* -> stopped -> ended`

- Transitions reported via `HKWorkoutSessionDelegate.workoutSession(_:didChangeTo:from:date:)`.
- **`prepare()`** warms sensors (heart rate, motion, GPS). Apple recommends a
  3-second countdown UI between `prepare()` and `startActivity(_:)`.
- **`startActivity(with: Date)`** -> `.running`. Official start time.
- **`pause()` / `resume()`** -> `.paused` / `.running`. Can repeat.
- **`stopActivity(with: Date)`** -> `.stopped` (transient; finalize metrics here;
  cannot resume).
- **`end()`** -> `.ended` (terminal).

**Runtime contract**: while the session is in `.prepared`, `.running`, `.paused`,
or `.stopped`, the app keeps running; the screen wakes on wrist-raise; sensors
stream continuously. Transitioning to `.ended` releases the contract and lets
the OS suspend the app.

**Common failures to avoid:**
- Skipping `prepare()` -> first 5-10s of heart-rate data unreliable/missing.
- Calling `end()` directly from `.running` (skip `.stopped`) -> missing summary
  statistics. Always `stopActivity` first, wait for delegate `.stopped`, then
  `end()`.
- Inferring state from method calls instead of the delegate -> miss
  system-driven transitions (auto-pause, auto-end on watch removal, errors).

**Crash recovery**: if the app crashes mid-workout, the system calls the app
delegate's `handleActiveWorkoutRecovery()` on relaunch. Call
`healthStore.recoverActiveWorkoutSession(completion:)`, then re-attach the
builder's delegate and data source ASAP.

### Snapshots
`WKSnapshotRefreshBackgroundTask` updates the UI in preparation for a snapshot
(the static image shown in the app switcher / on raise). Provide a timely,
accurate snapshot.

### Complications / widgets (watchOS 10+)
ClockKit is deprecated; use **WidgetKit complications**. Widgets also appear in
the **Smart Stack**. If your widget provides relevance cues, it appears when
needed. Live Activities from the iOS app automatically appear at the top of the
Smart Stack on a connected Apple Watch.

---

## 4. Xcode Project Setup - Adding a watchOS target to an existing iOS app

Steps (from Apple's "Setting up a watchOS project"):

1. Select the project in the Project navigator.
2. Click the **"Add a target"** button in the Project editor.
3. Select the **watchOS** tab.
4. Select the **App** icon and click Next.
5. In the project option sheet, enter a name for the watchOS app, and select
   **"Watch app for Existing iOS App."** Make sure to select the correct iOS app
   in the pull-down menu, and click Finish.

### Bundle ID rule
The watchOS app's bundle ID must be a child of the iOS app's bundle ID.
For vivobody: iOS bundle ID is `astanciu.vivobody.app`, so the watchOS app bundle
ID should be `astanciu.vivobody.app.watchkitapp` (or similar `.watch` suffix).
`WKCompanionAppBundleIdentifier` in the watch app's Info.plist must be set to the
iOS app's bundle ID.

### Capabilities to add for a workout app
- **HealthKit** (enable, request read/share authorization for workout types,
  heart rate, active energy, distance, activity summary).
- **Background Modes** -> **Workout processing** (and **Audio** if playing
  audio/haptics during the workout).
- The watch app is embedded as embedded content of the iOS app target
  (General > Frameworks, Libraries, and Embedded Content) so it ships together.

### Sharing code between iOS and watchOS
SwiftUI and WidgetKit are cross-platform. You can share SwiftUI views and widgets
between targets by adding the same source files to both targets (target
membership), using `#if os(watchOS)` / `#if os(iOS)` guards where behavior
differs. Domain models (e.g., workout templates) can be shared the same way.

---

## 5. Compatibility

### Current versions
- **watchOS 26** shipped (requires Xcode 26 SDK). Apple Watch Series 11 is the
  latest hardware (Sept 2025). watchOS 27 is in beta (Xcode 27, WWDC 2026).
- The vivobody project uses Xcode 17 / iOS 26.5 per AGENTS.md, so the matching
  watchOS SDK is watchOS 26.x.

### Minimum watchOS version recommendations
- **Single-target architecture requires watchOS 7+** (the practical floor).
- **watchOS 10** is the modern baseline: introduces the redesigned SwiftUI UI
  (vertical-page `TabView`, `NavigationSplitView`, `containerBackground`,
  carousel lists), WidgetKit complications replacing ClockKit, and the
  **mirrored workout session APIs** (the key feature for a paired iOS+Watch
  workout app, watchOS 10 / iOS 17+). **Recommend watchOS 10 as the minimum
  deployment target** for a new workout app.
- **watchOS 11** (2024) added health/fitness insights and personalization.
- **watchOS 26** brought `HKWorkoutSession` to iPhone (iOS 26+) for
  cross-device workouts, workout zones (heart rate / cycling power zones),
  Workout Buddy (Apple Intelligence-powered audio coaching on AirPods),
  Liquid Glass design.
- **watchOS 27 (beta)** adds Foundation Models framework on-watch (glanceable
  summaries, workout feedback, smart replies), Vision framework on watchOS
  (image understanding, barcode reading), and HealthKit workout zones API.

### Device families
- **Apple Watch Series 4-11** (40/41/42/45/46mm cases). Series 7+ recalibrate
  battery capacity on watchOS 26.
- **Apple Watch Ultra / Ultra 2** (49mm) - has an **Action button** (register
  actions via App Intents) and supports the **double-tap gesture** (customize
  your app's response via `.onTapGesture` / the dedicated API).
- **Apple Watch SE / SE 2** (40/44mm) - lower-cost; lacks some sensors (e.g.,
  ECG, blood oxygen). watchOS 26 supports SE 2.
- watchOS 26 dropped support for some older models; check the SDK deployment
  target against the devices you want to support.

### Recommendation for vivobody
Set the watchOS deployment target to **watchOS 10** to get mirrored workout
sessions and the modern SwiftUI design system while still covering the vast
majority of active Apple Watches. Target the 45/46/49mm large-case displays as
the primary design size.

---

## 6. Key Frameworks

### WatchKit
- Still provides `WKApplication` / `WKApplicationDelegate` (single-target) and
  `WKInterfaceDevice` for haptics.
- `WKApplicationDelegate` handles life-cycle events, workout recovery
  (`handleActiveWorkoutRecovery()`), extended runtime sessions, remote
  notifications, and `userInfo` from handoff/complications.
- Storyboards (`WKInterfaceController`, `WKInterfaceTable`) are deprecated;
  use SwiftUI. `WKHostingController` can host SwiftUI inside legacy
  interface controllers for incremental migration (not needed for new apps).
- `WKNotificationScene` + `WKUserNotificationHostingController` for custom
  long-look notification interfaces.

### WatchConnectivity
- Two-way communication between an iOS app and its paired watchOS app
  (`WCSession` + `WCSessionDelegate`). Available watchOS 2.0+.
- Three transfer methods:
  1. **`updateApplicationContext(_:)`** - latest state; replaces previous; good
     for "current state" sync (e.g., the current workout template).
  2. **`transferUserInfo(_:)`** - queued, guaranteed delivery, background.
  3. **`sendMessage(_:replyHandler:)`** - live, only when both apps are active.
  Plus `transferFile(_:metadata:)` for files.
- **For workout apps on watchOS 10+/iOS 17+, prefer HealthKit's mirrored
  workout session APIs** (`session.startMirroringToCompanionDevice()`,
  `session.sendToRemoteWorkoutSession(data:)`,
  `workoutSession(_:didReceiveDataFromRemoteWorkoutSession:)`). These assume
  much of the sync responsibility and let the two devices exchange live data
  during a workout without manually juggling WatchConnectivity. WatchConnectivity
  remains useful for non-workout data sync (e.g., pushing template lists).

### HealthKit on watchOS (the core framework for a fitness app)
- **`HKWorkoutSession`** - the workout state machine (see Lifecycle). Keeps the
  app running in the background through wrist-drop. Requires Workout processing
  background mode.
- **`HKWorkoutConfiguration`** - `activityType` (e.g.,
  `.traditionalStrengthTraining`, `.running`, `.functionalStrengthTraining`) and
  `locationType` (`.indoor`/`.outdoor`). Drives sensor optimization and
  calorimetry.
- **`HKLiveWorkoutBuilder`** (watchOS 5+; iOS 26+ on iPhone) - accumulates
  samples/events incrementally; `finishWorkout()` saves the `HKWorkout` to
  HealthKit. Pair with `HKLiveWorkoutDataSource` to auto-collect Apple Watch
  sensor data (heart rate, active energy, distance, etc.).
- **`HKLiveWorkoutBuilderDelegate`** - `workoutBuilder(_:didCollectDataOf:)` for
  new samples (update UI with `statistics(for:)`), `workoutBuilderDidCollectEvent(_:)`
  for events (e.g., laps).
- **Authorization**: request share for `workoutType()`; read for `heartRate`,
  `activeEnergyBurned`, `distanceWalkingRunning`, `activitySummaryType`,
  `activityMoveMode`. Set up HealthKit per "Setting up HealthKit."
- **Mirrored sessions** (watchOS 10+/iOS 17+): Apple Watch is primary (sensors),
  iPhone is mirrored. `healthStore.startWatchApp(toHandle: configuration)` on
  iPhone launches the Watch app and calls the Watch app delegate's
  `handle(_ workoutConfiguration:)`. The user can end on either device.
- **New in watchOS 26/iOS 26**: `HKWorkoutSession` on iPhone; workout zones
  (heart rate / cycling power zones) via "Accessing workout zone data."
- **Background data**: fitness apps can receive HealthKit data in the
  background and access real-time heart rate, gyroscope, route map data, and the
  all-day accelerometer.
- **Best practices**: clearly indicate an active workout; auto-save or provide
  explicit save/discard; give clear feedback on save; coordinate companion app
  (don't retroactively create a Watch session if the user didn't start one on
  Watch); always call `finishWorkout()` to persist data.

### Sound and Haptics
- **`WKInterfaceDevice.current().play(_:)`** with `WKHapticType`
  (`.click`, `.success`, `.failure`, `.warning`, `.directionUp`, etc.) - the
  classic WatchKit haptics API. **No effect when the app is in the
  background/inactive, EXCEPT for apps with an active workout session** (key for
  a fitness app - rest-timer haptics fire during a workout). Don't call in rapid
  succession (100ms minimum, battery cost).
- **Core Haptics** is also available on watchOS for richer, pattern-based
  haptics.
- **Background audio**: `AVAudioPlayer` for short clips during workouts;
  `AVAudioSession` + the Audio background mode for long-form background audio.
- **Workout Buddy** (watchOS 26): Apple Intelligence-powered audio coaching
  announcements on AirPods (H1+) - system feature, not a direct API, but worth
  knowing the platform direction for fitness audio.

### SceneKit
- Available on watchOS for 3D content, but **rarely used** and not relevant to a
  workout/fitness app. watchOS emphasizes 2D glanceable SwiftUI content. Skip
  unless you have a specific 3D visualization need.

### Other relevant frameworks
- **WidgetKit** - complications + Smart Stack widgets (cross-platform with iOS).
- **App Intents** - register actions for Siri and the Action button (Apple Watch
  Ultra); expose app capabilities to Apple Intelligence.
- **Foundation Models** (watchOS 27) - on-device LLM for glanceable summaries,
  workout feedback, smart replies.
- **Vision** (watchOS 27) - on-device image understanding.

---

## Practical Guidance: Starting the vivobody watchOS app

### Recommended architecture
1. **Add a watchOS target** ("Watch app for Existing iOS App") to the existing
   vivobody Xcode project. Bundle ID `astanciu.vivobody.app.watchkitapp`.
2. **Single-target, SwiftUI lifecycle** with `@main` `App` +
   `@WKApplicationDelegateAdaptor` for a `WKApplicationDelegate` that handles
   workout recovery and incoming workout configurations.
3. **Deployment target: watchOS 10** (for mirrored sessions + modern SwiftUI).
4. **Capabilities**: HealthKit + Background Modes (Workout processing, Audio).
5. **Workout model**: Apple Watch is the sensor primary; use
   `HKWorkoutSession` + `HKLiveWorkoutBuilder` + `HKLiveWorkoutDataSource`.
   Mirror to iPhone with `startMirroringToCompanionDevice()` so the existing iOS
   app can display live stats and control rest timers bidirectionally.
6. **UI shape**: vertical-page `TabView` for the in-workout screens (metrics,
   current exercise, rest timer), `NavigationStack` for browsing templates, full
   black/dark backgrounds to match the iOS app's dark theme, `containerBackground`
   for color accents. Glanceable, Digital-Crown-driven.
7. **Shared code**: put domain models and any pure-SwiftUI reusable views in
   files with target membership on both iOS and watchOS; use `#if os(watchOS)`
   guards for platform-specific pieces. Keep the watch feature set minimal
   (start/track/end workout + rest timer + heart rate) and leave catalog
   management/history on iPhone.
8. **Haptics**: use `WKInterfaceDevice.current().play(.success/.warning/...)`
   for set-complete and rest-timer cues; these fire during an active workout
   session even in the background.
9. **Lifecycle discipline**: always `prepare()` with a countdown, drive UI from
  `HKWorkoutSessionDelegate` state, `stopActivity` -> wait for `.stopped` ->
   `end()` -> `finishWorkout()`.

### Key code pattern (start a mirrored workout)
```swift
// iPhone side
let configuration = HKWorkoutConfiguration()
configuration.activityType = .traditionalStrengthTraining
configuration.locationType = .indoor
try await healthStore.startWatchApp(toHandle: configuration)

// Watch app delegate
func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
    Task { await WorkoutManager.shared.startWorkout(with: workoutConfiguration) }
}

// WorkoutManager (watch)
func startWorkout(with config: HKWorkoutConfiguration) async throws {
    let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
    let builder = session.associatedWorkoutBuilder()
    session.delegate = self
    builder.delegate = self
    builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                 workoutConfiguration: config)
    try await session.startMirroringToCompanionDevice()
    session.prepare()              // warm sensors + show 3-2-1 countdown
    // user taps Start:
    session.startActivity(with: .now)
    try await builder.beginCollection(at: .now)
    self.session = session; self.builder = builder
}
```

### Sources
- Apple: Setting up a watchOS project; Building a watchOS app; Background
  execution; Running workout sessions; Creating an intuitive and effective UI in
  watchOS 10; TN3157; watchOS 26 Release Notes; What's new in watchOS 27.
- WWDC: "Build a productivity app for Apple Watch" (2022); "Design and build
  apps for watchOS 10" (2023); "Track workouts with HealthKit on iOS and
  iPadOS" (2025, session 322); "Deliver workout insights with HealthKit workout
  zones" (2026).
- Practitioner: Blake Crosley, "HealthKit Workout Lifecycle" (2026); Teng
  (Sasquatch Studio), "Building a Workout App for Apple Watch" (2025) - mirrored
  sessions walkthrough incl. the session.end() ordering fix.
