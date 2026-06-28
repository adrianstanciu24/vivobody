# HealthKit Tier A — Design

Write one `HKWorkout` to HealthKit each time a workout is archived, so the
session appears in the Apple Health app's workout history and is available to the
rest of the ecosystem. No calorie sample is written (see "Why no calories").

This is the minimal, version-independent integration. It is intentionally
scoped below a live workout session (Tier B) and writes nothing in real time.

## Tier A vs Tier B

| | Tier A (this doc) | Tier B (future) |
|---|---|---|
| When | After the session is archived | Live, during the workout |
| API | `HKWorkoutBuilder` | `HKWorkoutSession` + `HKLiveWorkoutBuilder` |
| Sensors | None | Heart rate, live energy |
| Activity rings | Not affected (needs a Watch) | Watch fills them with real data |
| iOS floor | All supported versions | iOS 26+ on iPhone |
| Result | One `HKWorkout` in Health history | Same, plus live metrics + rings |

## Why no calories (and no rings)

The headline benefit people imagine from HealthKit is "fill my Activity rings."
On an iPhone-only app that is not achievable, and writing an estimated calorie
sample is actively the wrong move:

- The Activity rings are computed by Apple's Activity engine — the Apple Watch,
  or on a Watch-less iPhone the phone's own motion coprocessor (Move ring only).
  They are **not** the sum of arbitrary `activeEnergyBurned` samples in the
  store. A third-party app writing a finished workout + energy sample does
  **not** reliably move the rings without a Watch (widely reported; e.g. a
  non-Apple workout shows up in Fitness but the Move ring does not budge).
- Without a Watch there is **no Exercise ring** at all — only the Move ring,
  which we cannot drive.
- With a Watch, the Watch already logs the session's real active energy, so our
  estimate would **double-count** the Move ring.
- Strength-training calories on iPhone have no sensor basis anyway; any number
  would be fabricated.

So Tier A records the honest fact that the workout happened (type + time span)
and leaves calories/rings to a real sensor — the Apple Watch, via a future
Tier B. The reliable, Watch-independent value we keep is: the workout in Apple
Health's history, readable by other apps, trends, and Siri.

## Design principles

- **Single service boundary.** Every `import HealthKit` in the app lives in
  `HealthKit/HealthKitWorkoutService.swift`. The rest of the app calls one
  function. Adding a live session or a Watch target later does not ripple
  through screens or `AppState`.
- **Opt-in, write-only.** Default OFF. Authorization is requested only when the
  user enables the toggle, and only for the workout type we write. No read types
  → no `NSHealthShareUsageDescription` needed.
- **No fabricated data.** We write only measured facts (activity type, start,
  end). No estimated energy.
- **Idempotent.** The saved workout's `UUID` is stamped back onto the
  `WorkoutSession`; a session that already has a UUID is never written twice.
- **Never blocks logging.** Any HealthKit failure is swallowed. The SwiftData
  archive is the source of truth; HealthKit is a best-effort mirror.

## Requirements

### Entitlement (`vivobody/vivobody.entitlements`)
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array/>
```
The target already references `vivobody.entitlements` for App Groups, so adding
these keys is enough for the build to pick them up. For device provisioning,
automatic signing adds the HealthKit capability from the entitlement; if it
complains, enable HealthKit in Xcode Signing & Capabilities.

### Privacy string (`vivobody/Info.plist`)
```xml
<key>NSHealthUpdateUsageDescription</key>
<string>vivobody saves your finished workouts to the Health app so they appear
in your workout history.</string>
```
Only the write (update) string is required. The share/read string is added in
the Watch phase, when we read heart rate.

### Device
HealthKit does not run in the iOS Simulator. The build links and the UI renders,
but actual workout writes require a physical device. CI / the simulator-based
`Scripts/verify.sh` can only confirm the toggle UI and that the code compiles.

## Authorization flow

1. Settings exposes an "Apple Health" toggle, hidden when
   `HKHealthStore.isHealthDataAvailable()` is false.
2. Enabling it calls `requestAuthorization()` →
   `requestAuthorization(toShare: [workoutType], read: [])`.
3. For the write type, `authorizationStatus(for:)` reports `.sharingAuthorized`
   / `.sharingDenied`, so the toggle reflects the real grant; if not granted it
   reverts to off.

## Save flow

Triggered from `AppState.dismissActiveWorkout()`, immediately after the archive
`context.saveOrRollback()` succeeds (next to the existing Live Activity / widget
side effects).

```
dismiss → stamp completedAt + save → HealthKitWorkoutService.saveWorkout(session, ctx)
  ↓ gates
  toggle on  &&  isHealthDataAvailable  &&  workout sharing authorized
  &&  session.healthKitWorkoutUUID == nil  &&  completedAt != nil  &&  totalSets > 0
  ↓ build (HKWorkoutBuilder, .traditionalStrengthTraining)
  beginCollection(start) → endCollection(end) → finishWorkout   (no samples)
  ↓ on success
  session.healthKitWorkoutUUID = workout.uuid; ctx.save()
  ↓ on failure
  swallow (archive already durable)
```

Capturing the `session` reference in the async `Task` is safe: it is persisted,
not deleted, even after `AppState` sets `activeSession = nil`.

## Idempotency

`WorkoutSession` carries `var healthKitWorkoutUUID: UUID? = nil` (additive,
defaulted → no migration). Set after a successful save. The service no-ops when
it is already non-nil, so re-archiving or a retry cannot create duplicates.

## Files

| File | Change |
|---|---|
| `specs/healthkit-tier-a.md` | This doc |
| `vivobody/vivobody.entitlements` | HealthKit entitlement keys |
| `vivobody/Info.plist` | `NSHealthUpdateUsageDescription` |
| `vivobody/HealthKit/HealthKitWorkoutService.swift` | Service boundary (only HealthKit import) |
| `vivobody/Models/WorkoutSession.swift` | `healthKitWorkoutUUID` field |
| `vivobody/App/SettingsKeys.swift` | `healthKitEnabled` key + default |
| `vivobody/Screens/Me/SettingsScreen.swift` | "Apple Health" toggle row |
| `vivobody/App/AppState.swift` | `saveWorkout` call in archive path |

## Out of scope (future Watch / Tier B)

- Live `HKWorkoutSession` / `HKLiveWorkoutBuilder` (the real path to Activity
  rings and live metrics).
- Heart rate and other sensor sample types; active energy from a real sensor.
- Read access and `NSHealthShareUsageDescription`.
- watchOS target and session mirroring.

The `healthKitWorkoutUUID` field and the single service boundary are the hooks
that make that later work additive rather than a rewrite. When a Watch is added,
the Watch runs the live session and owns calories + rings; the phone keeps
Tier A's history write as the no-watch fallback, gated so the two paths never
double-write.
