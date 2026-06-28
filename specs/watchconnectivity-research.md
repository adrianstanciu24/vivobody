# WatchConnectivity Research: iPhone-to-Apple Watch Sync

Research summary for adding a watchOS companion app to vivobody. Sources: Apple
Developer documentation (WatchConnectivity, WCSession, WCSessionDelegate, sample
code "Transferring data with Watch Connectivity"), WWDC21 session "There and back
again: Data transfer on Apple Watch" (session 10003), WWDC26 watchOS guide, and
Apple Developer Forums. All findings are current as of watchOS 11/12 and Xcode 16/17.

---

## 1. WatchConnectivity Framework Overview

WatchConnectivity is Apple's framework for **two-way communication between an iOS
app and its paired watchOS app**. It abstracts away the underlying Bluetooth/Wi-Fi
transport and exposes high-level APIs that fall into two categories:

- **Background transfers** (fire-and-forget, system-managed, delivered
  opportunistically when power/network conditions are good). These continue after
  the sending app is suspended or terminated.
- **Interactive (live) messaging** (real-time, requires both apps reachable).

The central object is `WCSession`, a singleton (`WCSession.default`). Both the iOS
app and the watchOS app must independently create, configure (assign a delegate),
and activate their own session. A connection is only established once **both**
sessions report `.activated`.

> Important framing (WWDC21): WatchConnectivity is specifically for communication
> between a phone and a *paired* Watch. It does **not** support Family Setup
> (watches without a paired iPhone). For Family Setup, use iCloud/CloudKit or
> direct URLSession-to-server communication instead.

### Key session properties (valid only while `activationState == .activated`)

| Property | Platform | Meaning |
|---|---|---|
| `isPaired` | iOS | iPhone has a paired Apple Watch |
| `isWatchAppInstalled` | iOS | The paired/active Watch has your watch app installed |
| `isCompanionAppInstalled` | watchOS | The paired iPhone has your iOS app installed |
| `isReachable` | both | Counterpart app is available for *live* messaging right now |
| `isComplicationEnabled` | iOS | Your complication is active on the current watch face |
| `activationState` | both | Always valid: `.notActivated` / `.inactive` / `.activated` |
| `hasContentPending` | both | More queued content waiting to be delivered after activation |
| `watchDirectoryURL` | iOS | Per-watch storage directory (useful with multiple watches) |

---

## 2. Session Activation & Pairing

### Setup pattern (shared iOS + watchOS)

```swift
import WatchConnectivity

final class ConnectivityCoordinator: NSObject, WCSessionDelegate {
    static let shared = ConnectivityCoordinator()
    private let session: WCSession

    private override init() {
        session = WCSession.default
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return } // check before any use
        session.delegate = self
        session.activate()
    }

    // REQUIRED on both platforms
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // Only initiate transfers once activationState == .activated
    }

    // REQUIRED on iOS only (multiple-watch support)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Auto Switch: finish delivering in-flight data, then deactivate
    }
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate to connect to the newly active watch
        session.activate()
    }
}
```

Activate the session **as early as possible** in the app lifecycle (WWDC21
recommendation). On the watch, do it in the app delegate / `@main` App init. On
iOS, do it in `applicationDidFinishLaunching` or the `App` struct init.

```swift
// watchOS app entry point
@main
struct vivobodyWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchExtensionDelegate.self) var delegate
    init() { ConnectivityCoordinator.shared.activate() }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

### Multiple Apple Watches (iOS 9.3+)
An iPhone can pair with more than one Watch. With Auto Switch enabled, only one
watch communicates at a time. When the user switches watches, the iOS session goes
`inactive` (finish delivering received data) then `deactivated` (call `activate()`
again to connect to the new watch). You cannot start new transfers while inactive
or deactivated.

---

## 3. Communication Methods

All dictionary-based methods require **property-list encodable** values only
(`String`, `Number`, `Date`, `Data`, `Array`, `Dictionary`). Encode custom structs
to `Data` (JSON or PropertyList) before sending.

### Comparison at a glance

| Method | Reachable required? | Guaranteed delivery? | Delivery order | Background OK? |
|---|---|---|---|---|
| `updateApplicationContext` | No | Yes (latest only) | Coalesced; only newest kept | Yes |
| `transferUserInfo` | No | Yes (all queued) | Sequential (FIFO) | Yes |
| `transferFile` | No | Yes (all queued) | Sequential (FIFO) | Yes |
| `sendMessage` / `sendMessageData` | **Yes** | No (fails if unreachable) | Sequential | Interactive only |
| `transferCurrentComplicationUserInfo` | No | Yes (budget-limited) | Prioritized over userInfo | Yes (iOS -> watch) |

### 3a. Application Context (latest state sharing)

Sends a single `[String: Any]` dictionary representing *current* app state. If you
update it multiple times before the counterpart wakes, **only the latest** is
delivered (previous in-flight values are replaced). Best for "what is the current
state" data: logged-in status, current workout in progress, today's plan summary,
unit preferences.

```swift
// SEND (either side)
func pushAppState(_ context: [String: Any]) {
    guard session.activationState == .activated else { return }
    do { try session.updateApplicationContext(context) }
    catch { /* handle WCError */ }
}

// RECEIVE (either side)
func session(_ session: WCSession,
             didReceiveApplicationContext applicationContext: [String: Any]) {
    // Also available any time via session.receivedApplicationContext
    DispatchQueue.main.async { /* update UI / persist */ }
}
```

When to use for vivobody: push the user's current settings (weight unit, theme),
the active/last workout summary, and the Today plan to the watch so it can render
immediately on launch without waiting for a fetch.

### 3b. UserInfo Transfer (queued dictionary, guaranteed)

Each dictionary is **queued and delivered in order**, all of them, even if the
counterpart is unreachable or the sending app is suspended. Returns a
`WCSessionUserInfoTransfer` you can use to cancel. Best for discrete events that
must all arrive: "a new workout session was completed", "a set was logged".

```swift
// SEND
func sendCompletedSession(_ payload: [String: Any]) {
    guard session.activationState == .activated else { return }
    let transfer = session.transferUserInfo(payload)
    // transfer.isPending, transfer.cancel() available
}

// RECEIVE
func session(_ session: WCSession,
             didReceiveUserInfo userInfo: [String: Any] = [:]) {
    DispatchQueue.main.async { /* insert into local store */ }
}
```

> Gotcha: `transferUserInfo` is unreliable in the Simulator. Test on real devices.

### 3c. Message (real-time dictionary, both reachable)

Immediate, two-way. Requires `session.isReachable == true` or it errors via the
`errorHandler`. Supports a `replyHandler` for request/response patterns. Keep
messages small. From **watch -> iOS**, the iOS app is woken in the background to
respond. From **iOS -> watch**, the watch app must be foreground/high-priority to
receive (it is reachable far less often than iOS).

```swift
// SEND with reply
session.sendMessage(["action": "fetchLatestPlan"],
    replyHandler: { response in
        DispatchQueue.main.async { /* use response */ }
    },
    errorHandler: { error in
        // WCError.notReachable, .deliveryFailed, etc.
    })

// RECEIVE (counterpart must implement the replyHandler variant if reply was requested)
func session(_ session: WCSession,
             didReceiveMessage message: [String: Any],
             replyHandler: @escaping ([String: Any]) -> Void) {
    let result = handle(message)
    replyHandler(result)
}
```

If you send *with* a replyHandler but the receiver implements only the no-reply
delegate method, you get an error. Always match the variants.

### 3d. MessageData (real-time binary)

Same semantics as `sendMessage` but takes `Data` instead of a dictionary. Useful
when you already have encoded data (e.g., a JSON `Data` blob).

```swift
session.sendMessageData(encodedBlob,
    replyHandler: { data in /* ... */ },
    errorHandler: { error in /* ... */ })

func session(_ session: WCSession,
             didReceiveMessageData messageData: Data,
             replyHandler: @escaping (Data) -> Void) {
    replyHandler(responseData)
}
```

### 3e. File Transfer (background, queued)

Sends a file (URL) plus optional metadata dictionary. Queued like userInfo,
delivered when conditions permit. The received file lands in the app's **Document
Inbox** and is **deleted when you return from `didReceive`**. You must move or
process it synchronously before returning (don't kick off async work and expect
the file to still be there).

```swift
// SEND
let transfer = session.transferFile(fileURL, metadata: ["type": "catalogExport"])
// transfer.isPending, transfer.cancel()

// RECEIVE
func session(_ session: WCSession, didReceive file: WCSessionFile) {
    // MOVE file.fileURL to a permanent location BEFORE returning
    let dest = documentsDir.appendingPathComponent(file.metadata?["name"] as? String ?? "file")
    try? FileManager.default.moveItem(at: file.fileURL, to: dest)
}
```

Use this for larger payloads: a full exercise catalog snapshot, an exported
SQLite/SwiftData store, or images.

### 3f. Complication UserInfo (iOS -> watch only)

`transferCurrentComplicationUserInfo` is a prioritized userInfo transfer that
jumps ahead of the normal queue, subject to a **daily budget** (Apple allows ~50
per day). Check `remainingComplicationUserInfoTransfers`. If budget is exhausted,
it falls back to the normal userInfo queue. Use only to update an active
WidgetKit complication.

---

## 4. Reachability

`isReachable == true` means the counterpart is available for **live messaging**
right now. Background transfers do **not** require reachability.

What makes the counterpart reachable:
- Devices are within Bluetooth range **or** on the same Wi-Fi network, AND
- The counterpart app is running (foreground or high-priority background).

Asymmetry that matters (WWDC21):
- **watchOS app -> iOS app**: the iOS app has *no foreground requirement*. If the
  watch sends a message, iOS is activated in the background to receive it. So the
  iOS app is reachable from the watch most of the time.
- **iOS app -> watchOS app**: the watch app must be foreground or running a
  long-running background session (e.g., a workout session) to be reachable. The
  watch app is reachable far *less* of the time.

Monitor changes via the delegate:
```swift
func sessionReachabilityDidChange(_ session: WCSession) {
    let reachable = session.isReachable
    // update UI affordances, queue messages, etc.
}
```

Also note `iOSDeviceNeedsUnlockAfterRebootForReachability` (iOS): after an iPhone
reboot, the phone must be unlocked at least once before it is reachable from the
watch.

Practical implication for vivobody: if the watch starts a workout (a long-running
background session), it will be reachable from iOS for the duration. Outside of
that, prefer background transfers (context/userInfo) for iOS -> watch pushes and
reserve `sendMessage` for when you know the watch is foregrounded.

---

## 5. Data Syncing Patterns for Workout Data

### Recommended layered strategy

1. **Application Context** for lightweight current-state sync (settings, active
   workout presence, unit preference, today's plan id). Coalescing is fine here
   because only the latest matters.
2. **UserInfo Transfer** for discrete, ordered events that must all arrive
   (completed workout sessions, individual set logs, body-weight entries). Encode
   each event as JSON `Data` inside the dictionary.
3. **File Transfer** for bulk snapshots (full exercise catalog, templates, history
   archive) when the catalog changes meaningfully.
4. **SendMessage** only for real-time, both-foreground interactions (e.g., watch
   requests the current workout state while iOS is open; iOS requests live heart
   rate from the watch during an active session).
5. **App Group + shared `UserDefaults`/files** for data that both targets can read
   directly when on the *same* device is not the goal (note: App Groups do NOT
   sync across devices, only across targets on one device).

### Encoding pattern

```swift
// Encode a workout session for transfer
struct WorkoutTransferPayload: Codable {
    let id: UUID
    let templateName: String
    let date: Date
    let sets: [SetTransferPayload]
    // ...
}

func pushCompletedSession(_ session: WorkoutSession) {
    let payload = WorkoutTransferPayload(from: session)
    guard let data = try? JSONEncoder().encode(payload) else { return }
    ConnectivityCoordinator.shared.sendUserInfo([
        "type": "completedWorkout",
        "version": 1,
        "data": data,
        "date": session.date
    ])
}
```

### Sync direction considerations for vivobody
- **iOS -> Watch**: templates/catalog/settings are authored on iPhone. Push via
  context (settings) and file transfer (catalog snapshot). Use `sendMessage` only
  when the watch is foregrounded.
- **Watch -> iOS**: workouts captured on the watch should push via
  `transferUserInfo` (guaranteed, queued, works in background during/after a
  workout session). This is the reliable path.

### Background task handling on watchOS (critical)

When WatchConnectivity delivers data while the watch app is suspended, watchOS
wakes the app with a `WKWatchConnectivityRefreshBackgroundTask`. You **must**
complete every such task or the app exhausts its background budget and crashes.

```swift
final class WatchExtensionDelegate: NSObject, WKApplicationDelegate {
    private var wcBackgroundTasks: [WKWatchConnectivityRefreshBackgroundTask] = []

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let wcTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                wcBackgroundTasks.append(wcTask)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
        completeBackgroundTasks()
    }

    func completeBackgroundTasks() {
        let session = WCSession.default
        // Complete only when done processing AND no more content pending AND activated
        guard session.activationState == .activated,
              !session.hasContentPending,
              !wcBackgroundTasks.isEmpty else { return }
        for task in wcBackgroundTasks { task.setTaskCompletedWithSnapshot(false) }
        wcBackgroundTasks.removeAll()
    }
}
```

Observe `activationState` and `hasContentPending` (KVO) to know when it is safe to
complete the tasks (the sample code uses `NSKeyValueObservation`).

---

## 6. Alternative Approaches

WatchConnectivity is one of several tools. WWDC21 groups them as: iCloud-based
(Keychain iCloud sync, Core Data + CloudKit), paired-device (WatchConnectivity),
and direct-to-server (URLSession/sockets). Choose based on: data type, where it
lives, whether a companion is required, Family Setup support, and urgency.

### 6a. SwiftData + CloudKit (sync across all devices)
SwiftData's `ModelConfiguration` accepts a `cloudKitContainerIdentifier` to enable
automatic CloudKit sync. Syncs to all of the user's devices signed into the same
iCloud account. **Does not require a paired iPhone** and supports Family Setup.
This is the natural fit for vivobody since the app already uses SwiftData.

Requirements:
- CloudKit capability + a shared iCloud container (`iCloud.<bundleid>`).
- Both iOS and watchOS targets must reference the **same** CloudKit container and
  the same `Schema`/`ModelContainer` configuration.
- Schema constraints for CloudKit sync: all model attributes must have **default
  values** (CloudKit requires this), relationships must be optional or have
  inverses, and `@Attribute(.unique)` is not supported.

Caveat (from Apple Developer Forums, 2023): getting the container id exactly right
is finicky; a stale container id silently breaks watch sync while iOS-to-iOS still
works. Sync is **not instantaneous**, it depends on network/battery conditions,
and you can pull too much data onto the watch if you share the whole store.
Use multiple Core Data/SwiftData **configurations** to segment watch-appropriate
data from phone-only data (WWDC21 advice).

> Note: vivobody's existing `@Model` types use additive defaulted fields, which is
> compatible with CloudKit sync requirements. This is the most promising path for
> a future cross-device sync, but is a larger undertaking than WatchConnectivity.

### 6b. Core Data + CloudKit (`NSPersistentCloudKitContainer`)
Same idea as SwiftData + CloudKit but the older Core Data stack. Watch the same
"too much data on the watch" pitfall; use multiple configurations in the model to
segment. Synchronization is not instant.

### 6c. HealthKit (shared health store)
HealthKit is a secure central repository on iPhone and Apple Watch. A workout
written to HealthKit from the watch is visible to the iPhone's HealthKit (and vice
versa) via the user's health store, subject to authorization. This is the right
channel for *health/fitness sample data* (workouts, heart rate, active energy),
not for app-specific structured data (templates, custom sets, preferences).
HealthKit does not replace WatchConnectivity for app data, but it is the canonical
way to share workout *metrics* and is already planned for vivobody
(see `specs/healthkit-tier-a.md`).

### 6d. iCloud Keychain Synchronization (Keychain Sharing)
For **small, infrequently-changing** shared data: OAuth tokens, credentials,
preferences. Add Keychain Sharing (or App Groups) capability to both targets and
set `kSecAttrSynchronizable: true` on the keychain query. Syncs to all the user's
devices, no companion app required, supports Family Setup. Limitation: customers
can disable iCloud Keychain and it is not available in all regions. Good for
sharing an auth token between the iOS and watch apps.

### 6e. App Groups (same-device only)
App Groups let the iOS app and its watch extension share a container on the *same*
device. It does **not** sync across devices. Useful for sharing files/UserDefaults
that both targets read locally, but it is not a cross-device sync mechanism.

### 6f. URLSession (direct to server)
For independent watch apps or Family Setup. Use **background** URLSession
configurations (`URLSessionConfiguration.background`, `sessionSendsLaunchEvents =
true`) and handle `WKURLSessionRefreshBackgroundTask`. Set `isDiscretionary = true`
for large transfers (system defers to Wi-Fi + power). watchOS allows up to ~4
background refresh tasks per hour if a complication is active; schedule at least
15 minutes apart.

### Quick picker (from WWDC21 decision framework)
- Small, infrequent, credentials/preferences, all devices, Family Setup ->
  **iCloud Keychain sync**.
- Structured app data, all devices, no companion needed, can tolerate latency ->
  **SwiftData/Core Data + CloudKit** (segment data per device).
- Workout metrics / health samples -> **HealthKit**.
- Paired phone + watch, optimize responsiveness, share device-only data ->
  **WatchConnectivity** (context/userInfo/file for background; sendMessage for
  live).
- Server data, independent watch or Family Setup -> **URLSession** (background
  preferred).

---

## 7. Project Setup: Capabilities & Entitlements

To add a watchOS companion app and use WatchConnectivity with an existing iOS app:

### Target structure (modern Xcode, single watch target)
- iOS app target (existing) with bundle id `astanciu.vivobody.app`.
- watchOS app target with bundle id based on the iOS app's, e.g.
  `astanciu.vivobody.app.watchkitapp` (Apple sample uses `<ios>.watchkitapp`).
- In the watch app's Info.plist, set `WKCompanionAppBundleIdentifier` to the iOS
  app's bundle id so the system knows the pairing.

### Capabilities/entitlements
- **No special capability is required to use WatchConnectivity itself.** The
  framework is available on iOS 9+/watchOS 2+ and `WCSession` works without an
  entitlement. You just need the watch target embedded in the iOS app.
- Add a shared **App Group** to both iOS and watch targets only if you want to
  share a local container (e.g., shared `UserDefaults` or files on the same
  device). Not required for WatchConnectivity transfers.
- Add **Keychain Sharing** (same access group on both targets) only if sharing
  keychain items.
- Add **iCloud** (CloudKit) + a shared iCloud container to both targets only if
  using SwiftData/Core Data + CloudKit sync.
- Add the **HealthKit** capability (and `NSHealthShareUsageDescription` /
  `NSHealthUpdateUsageDescription`) to both targets for HealthKit.
- For complications, add the **WidgetKit** extension target and the App Group
  for shared timeline data.

### Signing
Set the same developer team on all targets and let Xcode auto-manage
provisioning. Verify bundle id hierarchy in each target's Signing & Capabilities
tab.

### Running both apps in the simulator
Xcode supports running the iOS app and its watch app together. Choose a paired
simulator runtime (iPhone + Watch). Launch from the iOS scheme; the watch app
installs automatically. For background-transfer testing, note that
`transferUserInfo` is unreliable in the simulator, so validate on real hardware.

---

## 8. Best Practices

1. **Activate the session early** in app launch (app delegate / `@main` init), on
   both platforms, so the app is ready to receive data ASAP.
2. **Check `activationState == .activated` before initiating any transfer.** On
   iOS also check `isPaired` and `isWatchAppInstalled` before background pushes.
3. **Send only what changed.** All transfers consume wireless power; avoid sending
   the full data set every time (Apple guidance).
4. **Handle errors gracefully.** Check `WCError` in handlers (insufficient space,
   malformed data, communication errors, `.notReachable` for live messages).
5. **Delegate callbacks run on a non-main serial queue.** Dispatch to main for UI
   updates. Methods are called serially, so no reentrancy needed.
6. **Match reply-handler variants.** If you send with a `replyHandler`, the
   receiver must implement the delegate method that includes a `replyHandler`, or
   you get an error.
7. **Always complete watch background tasks** (`WKWatchConnectivityRefreshBackgroundTask`,
   `WKURLSessionRefreshBackgroundTask`). Uncompleted tasks consume the background
   budget and eventually crash the app. Complete them only when processing is done
   AND `hasContentPending == false` AND the session is activated.
8. **File transfers: move/process the file before returning** from
   `didReceive` (the inbox file is deleted on return). Don't start async work and
   expect the file to persist.
9. **Prefer background transfers over live messages** whenever you can tolerate
   latency; treat background transfers like "posting a letter" (delivery is
   eventual, timing depends on system conditions).
10. **Segment CloudKit-synced data** into multiple configurations so the watch
    only receives the subset it needs (avoid pulling the whole database onto the
    watch).
11. **Don't use WatchConnectivity for Family Setup** (no paired phone). Use
    CloudKit or URLSession instead.
12. **Test on real hardware** for `transferUserInfo` and reachability edge cases;
    the simulator is unreliable for these.
13. **State restoration**: because background deliveries wake the app cold,
    persist received data immediately and reconstruct UI state from local storage
    on launch (don't rely on in-memory state surviving suspension).
14. **Connection drops**: background transfers auto-resume; for live messaging,
    listen to `sessionReachabilityDidChange`, queue the intent, and replay via a
    background transfer (context/userInfo) when reachability returns.
15. **Multiple watches**: implement `sessionDidBecomeInactive` /
    `sessionDidDeactivate` on iOS and re-`activate()` on deactivation. Use
    `watchDirectoryURL` for per-watch data if needed.

---

## 9. Recommendation for vivobody

Given vivobody uses SwiftData on-device with additive defaulted `@Model` fields
(Storm: no migrations needed), the two viable paths are:

- **Phase 1 (companion watch app, paired-only): WatchConnectivity.** Lower risk,
  fits the existing on-device-only philosophy, no CloudKit dependency. Use
  `applicationContext` for settings/active-state, `transferUserInfo` for
  completed workouts captured on the watch, and `sendMessage` only for live
  interactions while the watch is foregrounded. This keeps all data on-device
  (transferred point-to-point, no cloud).
- **Phase 2 (optional, cross-device/Family Setup): SwiftData + CloudKit.** Only if
  cross-device sync beyond a paired phone becomes a requirement. Requires CloudKit
  capability, shared iCloud container, schema audit for CloudKit constraints, and
  data segmentation to avoid over-syncing to the watch.

WatchConnectivity requires no new entitlements, just the watch app target
embedded in the iOS app, so Phase 1 can proceed immediately without capability
changes.
