# Widget Implementation Notes

## Capability State

- App target entitlement: `group.astanciu.vivobody`
- Widget extension entitlement: `group.astanciu.vivobody`
- Widget extension bundle id: `astanciu.vivobody.app.widgets`
- App URL scheme: `vivobody://`
- Live Activities plist key: `NSSupportsLiveActivities`

## Manual Provisioning Risk

The Xcode project and entitlements declare the App Group for both targets, but Apple Developer portal capability registration and provisioning profile regeneration may still be required outside this repo. If a device/archive build fails signing with an App Group error, enable `group.astanciu.vivobody` for both app identifiers in the developer account and refresh automatic signing profiles.

## Runtime Boundary

Widgets read Codable snapshots from `UserDefaults(suiteName: "group.astanciu.vivobody")`. The app remains the only SwiftData writer. Interactive widget and Live Activity buttons use App Intents that write a small App Group handoff flag and open the app, where `AppRoot` executes the normal SwiftData-backed workout action.
