# Vivobody Security Threat Model

Version: 1.0.0
Updated: 2026-08-08

## 1. System Overview

Vivobody is a native iOS workout tracker built with SwiftUI, SwiftData, WidgetKit,
ActivityKit, App Intents, SceneKit, HealthKit, CoreSpotlight, notifications, and
a local Swift package shared with its widget extension. The app has no backend
and stores workout history, templates, body weight, exercise metadata, and
settings on the device. The app is the only SwiftData writer. Widgets consume
versioned, reduced snapshots through the App Group
`group.astanciu.vivobody`; widget intents place bounded handoff flags there and
open the app for mutations.

Major components:

- `vivobody`: UI, SwiftData store, analytics, deep-link handling, system
  integrations, and catalog resources.
- `vivobodyWidgets`: widgets, Live Activity, Dynamic Island, and Control Center
  surfaces.
- `VivoKit`: shared snapshot, intent, ActivityKit, formatting, and design types.
- HealthKit boundary: `HealthKitWorkoutService`.
- External-entry boundary: `IncomingAction` and `IncomingActionParser`.
- Lifecycle side-effect boundary: `SessionSideEffects`.
- Local website: public marketing, privacy, and support content only.

## 2. Trust Boundaries and Security Zones

1. **Untrusted external input**: URL-scheme payloads, Handoff activities,
   Spotlight identifiers, App Intent parameters, notification responses, and
   imported/resource data. Every value must be parsed into a closed,
   validated domain type before it can select or mutate stored records.
2. **Application boundary**: SwiftUI and app controllers are trusted to operate
   on local user data, but must treat identifiers and numeric input as
   malformed until validated.
3. **Persistent-data boundary**: SwiftData and UserDefaults contain private
   user-generated health and workout information. Reads and writes must remain
   scoped to the app and approved App Group.
4. **Extension boundary**: widgets are less trusted than the app for mutation.
   They may read minimized snapshots and request actions, but never open or
   write the SwiftData store.
5. **System-service boundary**: HealthKit, StoreKit, notifications, Spotlight,
   and ActivityKit are OS-mediated. Entitlements and authorization state must
   be checked at the single integration boundary.
6. **Developer tooling boundary**: scripts accept local paths and may rewrite
   assets. They are not shipped in the app and must fail closed on malformed
   input, avoid shell interpolation, and validate output.

There is no authenticated server zone, remote API, account system, or
multi-tenant authorization boundary.

## 3. Attack Surface Inventory

- `vivobody://` deep links and all other `IncomingAction` sources.
- App Intents and widget handoff values in the App Group.
- StoreKit entitlement state and product metadata.
- HealthKit authorization, workout reads, and workout writes.
- User-entered names, weights, repetitions, durations, RIR values, and body
  weights.
- SwiftData migrations, startup repair jobs, catalog seeding, and bundled JSON.
- Spotlight indexing and restoration identifiers.
- Notification scheduling and response handling.
- SceneKit archives and local asset-replacement tooling.

## 4. Critical Assets

- **Sensitive personal data**: workout history, exercise performance, body
  weight, inferred training readiness, and HealthKit workout records.
- **Integrity-critical state**: active workout, completed sets, templates,
  personal records, entitlement state, and model migration/repair markers.
- **Credentials and secrets**: signing material and App Store credentials must
  remain outside the repository. No runtime API keys are expected.
- **Availability assets**: persistent SwiftData store, catalog, widget
  snapshots, and launch path.

## 5. Threat Analysis

### 5.1 Spoofing

- A forged deep link, Spotlight activity, or widget handoff could impersonate a
  legitimate action. Mitigation: central parsing into a closed
  `IncomingAction`, identifier validation, and app-owned mutation paths.
- Stale or forged local entitlement mirrors could briefly misrepresent Pro
  access. The StoreKit result must remain authoritative; cached state is only a
  launch-time presentation optimization.
- App Group access is controlled by signed entitlements. Do not expand the
  group or use unauthenticated shared containers.

### 5.2 Tampering

- Malformed external identifiers could select or alter the wrong local model.
  Resolve stable IDs through bounded fetches and verify expected record type.
- Corrupt SwiftData, catalog JSON, or widget snapshots could distort analytics
  or crash launch. Existing mitigations include the in-memory fallback,
  canonical decoding, versioned widget payloads, and save-or-rollback
  semantics. During pre-production, model-breaking SwiftData changes reset the
  development store instead of carrying migration code.
- Widgets must not mutate SwiftData directly. All changes route through the app
  and normal session controller.
- Asset tools can overwrite a caller-selected path. They must use typed file
  APIs rather than shell execution, validate expected nodes and geometry, and
  reload written output before reporting success.

### 5.3 Repudiation

- The product is single-user and local-only, so server-grade audit logging is
  not applicable. Completed workout timestamps and HealthKit metadata provide
  normal product history.
- Sensitive workout contents should not be copied into diagnostic logs.
  Failures should identify the operation without exposing full user records.

### 5.4 Information Disclosure

- Workout and body-weight data are health-adjacent personal information.
  Minimize widget snapshots, avoid lock-screen detail not needed by the widget,
  and never print records, App Group contents, HealthKit samples, or StoreKit
  transaction material.
- Spotlight entries may be visible in system search. Index only intentional,
  minimal fields and honor deletion/reindex behavior.
- Do not add secrets, provisioning profiles, private keys, tokens, or raw user
  exports to source control.

### 5.5 Denial of Service

- Unbounded startup fetches and repairs can delay first paint. Launch work must
  be one-time or version-gated, idempotent, and stamp completion only after a
  successful save.
- Large histories can cause repeated analytics work. Existing fingerprint
  caching and pure aggregation should be preserved; avoid nested scans in
  render paths.
- External strings and collection sizes should be bounded before expensive
  parsing, indexing, or SceneKit loading.
- Corrupt assets or persistence must degrade to a recoverable state rather
  than terminate the application.

### 5.6 Elevation of Privilege

- Widgets or App Intents must not bypass app authorization, entitlement, or
  session-lifecycle checks. Handoff flags are requests, not proof that an
  operation is allowed.
- HealthKit writes require explicit system authorization and must occur only
  through `HealthKitWorkoutService` via `SessionSideEffects`.
- No code path should grant paid capabilities solely from mutable
  UserDefaults.

## 6. Vulnerability Pattern Library

### External action validation

Unsafe:

```swift
let id = url.lastPathComponent
modelContext.delete(fetchByName(id))
```

Preferred:

```swift
guard let action = IncomingActionParser.parse(url) else { return }
handle(action)
```

Parsing must reject unknown routes, malformed IDs, unsupported values, and
unexpected collection sizes. Fetches should use stable identifiers and verify
the target exists.

### Persistence integrity

Unsafe:

```swift
try? context.save()
defaults.set(true, forKey: completionKey)
```

Preferred:

```swift
do {
    try context.saveOrRollback()
    defaults.set(true, forKey: completionKey)
} catch {
    return
}
```

Never stamp a migration or repair complete before its durable save succeeds.

### Command and path injection

Avoid constructing shell commands from arguments:

```swift
system("tool \(userPath)")
```

Use Foundation or framework APIs with `URL` values. Tooling that writes files
must validate the input format and output before success. A user-selected
output path may intentionally overwrite a file, so usage must be explicit.

### Information disclosure

Unsafe:

```swift
print(session)
print(transaction)
```

Log only operation names and non-sensitive error categories. Do not include
workout details, body weight, HealthKit samples, receipts, tokens, or shared
container contents.

### Resource exhaustion

Do not add repeated whole-store fetches to SwiftUI `body`, per-row accessors, or
ungated launch paths. Prefer fingerprinted analytics caches, bounded parsing,
single-pass aggregation, and explicitly gated maintenance work.

### Web patterns

SQL injection, XSS, SSRF, IDOR, and HTTP authentication bypass are currently
not applicable to the native app because it has no backend or dynamic web
endpoint. Reassess this threat model before adding network services, account
sync, uploads, or server-rendered user content.

## 7. Security Testing Strategy

- Scan every commit for secrets, unsafe external-input flows, direct widget
  persistence, bare saves, sensitive logging, and unbounded launch work.
- Build the main scheme with warnings treated as defects under project policy.
- Test parsers with malformed routes and identifiers.
- Test migrations and repair jobs for idempotence, failed-save retry, custom
  record isolation, and corrupt legacy values.
- Keep muscle mapping and catalog validation tests around SceneKit and bundled
  JSON changes.
- Review entitlements and privacy disclosures when adding system capabilities.

## 8. Assumptions and Accepted Risks

- The device, iOS sandbox, code signing, Keychain, App Group, and HealthKit
  authorization controls behave as documented.
- A person with an unlocked device can view and edit that device's local app
  data; Vivobody has no separate account authentication layer.
- User-controlled developer-script paths may overwrite local files when the
  developer explicitly invokes the tool. Scripts must not silently broaden the
  target or execute path contents.
- Local analytics are wellness guidance, not clinical diagnosis.

## 9. Changelog

- 1.0.0 (2026-08-08): Initial threat model for the native app, widget
  extension, local persistence, system integrations, and asset tooling.
