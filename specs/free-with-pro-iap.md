# Free + Pro Lifetime Unlock — Design

Make the app free on the App Store with a single one-time in-app purchase
("Vivobody Pro") that unlocks the depth layer. The recording experience —
logging workouts — is free forever and never gated. There is no trial: the
free tier is generous enough (full logging, 5 templates, full history) that
users experience the app's value before deciding, and the Insights preview
shows exactly what Pro adds using their own data.

## Product philosophy (from workout-app-principles.md)

- "No premium interruptions. Respect the user's effort."
- Free tier is a **complete workout logger**, not a crippled demo.
- The paywall never appears during a workout, at launch, or as a popup.
  It lives only where a locked feature is, plus one quiet row in Settings.
- The user's data is theirs: history is never locked, truncated, or deleted.

## Free vs Pro

| Surface | Free | Pro |
|---|---|---|
| Active workout (logging, rest timer, PRs, summary, Live Activity) | ✅ full, unlimited | — |
| History (all sessions, session detail) | ✅ full, unlimited | — |
| Exercise catalog + custom exercises | ✅ | — |
| Templates | up to **5** | unlimited |
| Body weight logging | ✅ | — |
| Current PRs (PersonalRecordsScreen) | ✅ | — |
| Up Next widget, Start Workout control, Live Activity | ✅ | — |
| **Insights tab** (signature, strength, dominance, intensity, rep trend, movement, rhythm, load, symmetry) | frozen blurred preview | ✅ |
| Exercise progress charts (ExerciseDetailScreen chart sections) | locked; raw stats stay free | ✅ |
| Signature + Consistency widgets | locked placeholder | ✅ |
| HealthKit sync | locked | ✅ |

Rationale: people fall in love with the recording; they pay to see what it all
means. Insights gets *more* valuable the more free data the user has entered,
which is exactly the right conversion pressure — their own charts behind
frosted glass, not a feature list.

## Pricing model

One **non-consumable** StoreKit 2 product:

```
Product ID: astanciu.vivobody.app.pro.lifetime
Type:       Non-consumable
Price tier: ~$24.99 (final price set in App Store Connect)
```

No subscription, no server. StoreKit 2's on-device JWS verification
(`VerificationResult`) is sufficient; there is nothing to validate
server-side. Family Sharing for the non-consumable is an App Store Connect
toggle — decide at submission time, no code impact.

## Entitlement model

Two states, resolved locally:

```
enum ProStatus {
    case pro   // verified lifetime purchase
    case free  // no purchase
}
```

- **Purchase** — from `Transaction.currentEntitlements` at launch, and kept
  current by a `Transaction.updates` listener task for the app's lifetime.
  Works offline (local receipt). The last known value is mirrored to
  UserDefaults (`settings.proUnlockedCache`) so the UI never flashes locked
  while StoreKit resolves on a cold offline launch — the cache is a
  render hint only, never the source of truth.
- **Free** — everything else. No trial, no clocks, no derived state.

`status == .pro` is the single gate every surface checks.

## Architecture

Follows the HealthKit Tier A pattern: **single service boundary**. Every
`import StoreKit` lives in one directory.

```
vivobody/Store/
├── ProStore.swift        # @Observable; owns ProStatus, purchase(), restore(),
│                         #   the Transaction.updates listener, product loading
└── PaywallSheet.swift    # the one purchase surface (see below)
```

`ProStore` hangs off `AppState` exactly like `analytics` does:

```swift
@Observable final class AppState {
    ...
    let pro = ProStore()
}
```

Views read `appState.pro.status`. The widget snapshot writer persists the
resolved `isPro` flag to the App Group so widgets never touch StoreKit.

## Gating points

### 1. Insights tab (`InsightsScreen`)
- `status == .pro`: unchanged.
- `status == .free`: render the **real** `loadedContent` built from the
  user's actual data, but frozen — `.blur(radius:)` + `.allowsHitTesting(false)`
  + a scrim — with a single quiet unlock card floated on top (headline,
  one-line pitch, price, "Unlock" button → PaywallSheet). Seeing *your own*
  symmetry chart behind frosted glass is the pitch.
- Empty state (no sessions) is unchanged — never show a paywall to someone
  who hasn't trained yet.

### 2. Template limit (`LibraryTemplatesContent`, and any other create path)
- Creating a **6th** template while `free` presents PaywallSheet instead of
  the editor. The check is `templates.count >= 5 && status == .free`, applied
  at every `templateEditorTarget = .new(...)` call site.
- If a user somehow ends up over the limit (e.g. a refunded purchase),
  existing templates are grandfathered: fully editable, startable,
  deletable. Only *creation* is gated.

### 3. Exercise progress charts (`ExerciseDetailScreen` / `ExerciseDetailSections`)
- Chart sections get the same frozen-blur + unlock treatment; numeric stats
  (best set, last performed, PRs, totals) stay free.

### 4. Widgets (`vivobodyWidgets`)
- `WidgetSnapshotWriter` adds `isPro: Bool` to the shared snapshot.
- SignatureWidget + ConsistencyWidget render a static locked placeholder
  ("Unlock in Vivobody") when `isPro == false`. Tapping deep-links to the
  paywall (`vivobody://pro`).
- UpNextWidget, StartWorkoutControl, and the Live Activity are always free —
  they drive engagement, which drives conversion.

### 5. HealthKit toggle (`SettingsScreen`)
- The Apple Health row shows a small lock glyph when `free`; tapping it
  presents PaywallSheet instead of toggling. Existing behavior when `pro`.

### 6. Settings row (`SettingsScreen`)
- New section at the top: when `free`, a "Vivobody Pro" row → PaywallSheet.
  When `pro`, a quiet "Vivobody Pro · Unlocked" row with Restore hidden.
- PaywallSheet always contains a **Restore Purchases** button
  (`AppStore.sync()`), required by App Review.

## PaywallSheet

One screen, presented as a sheet. Matches the app's visual language:
black, type-forward, single accent. Contents, top to bottom:

1. Wordmark + "Pro" badge.
2. The feature list as quiet rows (Insights, unlimited templates, progress
   charts, widgets, Apple Health) — sentence case, no checkmark spam.
3. Price pulled live from `Product.displayPrice` (never hardcoded).
4. `PrimaryActionButton` — "Unlock Forever · $24.99".
5. Restore Purchases (footnote-weight button).
6. One line of trust copy: "One-time purchase. No subscription. Your data
   never leaves your device."

Purchase flow: `product.purchase()` → verify → `transaction.finish()` →
`status = .pro` → sheet dismisses with a `Haptics.rigid()` thunk. Errors
surface via the existing `saveErrorAlert`-style alert; `.userCancelled` is
silent.

## Testing

- `Products.storekit` configuration file in the project for local StoreKit
  testing (purchase, restore, refund) in the simulator; attach to the scheme.
- A `--pro` DEBUG launch argument forces `.pro` so both states are reachable
  in `Scripts/verify.sh` without touching StoreKit (the default seeded state
  exercises `free`).
- Unit tests (`vivobodyTests`): `ProStatus` resolution — no entitlement,
  verified entitlement, revoked/refunded entitlement; template gate at
  counts 4, 5, and 6 in both states.
- `Scripts/verify.sh` states: Insights locked (blur + unlock card present in
  the accessibility tree), Insights unlocked (`--pro`), Settings Pro row,
  template limit paywall.
- Sandbox test on device before submission (StoreKit config ≠ sandbox).

## App Store Connect checklist

- Create the non-consumable IAP, attach to the app version.
- App description states which features are Pro (App Review requirement for
  freemium clarity).
- Restore Purchases reachable from the paywall (done, above).
- Privacy: no changes — no new data collected; purchases handled by Apple.

## Files

| File | Change |
|---|---|
| `specs/free-with-pro-iap.md` | This doc |
| `vivobody/Store/ProStore.swift` | New — entitlement store, purchase/restore, updates listener (only StoreKit import) |
| `vivobody/Store/PaywallSheet.swift` | New — the purchase sheet |
| `vivobody/App/AppState.swift` | `let pro = ProStore()` |
| `vivobody/App/SettingsKeys.swift` | `proUnlockedCache` key |
| `vivobody/Screens/Insights/InsightsScreen.swift` | Frozen-blur lock state + unlock card |
| `vivobody/Screens/Library/LibraryScreen.swift` | 5-template gate in `handlePlus` (the single create path once templates exist) |
| `vivobody/Screens/Library/ExerciseDetailSections.swift` | Chart section lock state |
| `vivobody/Screens/Me/SettingsScreen.swift` | Pro row + HealthKit row gate |
| `vivobody/App/WidgetSnapshotWriter.swift` | `isPro` in shared snapshot |
| `vivobodyWidgets/SignatureWidget.swift` | Locked placeholder |
| `vivobodyWidgets/ConsistencyWidget.swift` | Locked placeholder |
| `vivobody/App/IncomingAction.swift` | `vivobody://pro` deep link → paywall |
| `Products.storekit` | StoreKit testing configuration |
| `vivobodyTests/ProStatusTests.swift` | Entitlement resolution tests |

## Out of scope (future)

- Yearly/monthly subscription tier (the `ProStatus` enum and single gate
  make adding one additive: a new entitlement source, same `.pro` checks).
- Free trial (dropped by design: the free tier itself is the trial).
- Promotional offers, promo-code UI, win-back flows.
- Price A/B testing, regional launch pricing (App Store Connect concerns).
- Server-side receipt validation (no server exists; not needed for a
  non-consumable with on-device verification).
