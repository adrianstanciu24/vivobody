# Semantic verification scenarios

Run a scenario through the normal build, simulator, and installation path:

```bash
SCENARIO=active-restoration Scripts/verify.sh
```

Each JSON file declares an initial `launch`, ordered `steps`, and final
`required` / `forbidden` accessibility selectors. Outputs land in
`.verify/scenarios/<name>/` as a screenshot, UI tree, runtime log, action trace,
and result JSON. Screenshots are evidence for review; the pass/fail decision is
made from accessibility semantics and any declared diagnostic-log contracts.

Scenarios may also declare `requiredLogs` and `forbiddenLogs` as arrays of
literal substrings. These assertions read the captured unified `runtime.log`
and are reserved for stable privacy-safe `AppDiagnostics` events, not Apple
framework chatter or user-owned values.

## Launch

- `reset`: adds `--ui-test-reset` when true.
- `tab`: adds `--verify-tab <tab>`.
- `arguments`: additional deterministic debug launch arguments.

## Steps

- `wait`: poll until at least one visible element matches a selector.
- `waitAbsent`: poll until no visible element matches a selector.
- `tap`: require one visible match and tap its on-screen midpoint.
- `scrollTo`: swipe in the declared direction until its semantic `selector`
  becomes visible; coordinates are derived from the application frame.
- `swipe`: perform `count` blind swipes in the declared `direction` with no
  selector. Use it to nudge content clear of the tab bar before tapping a
  row that `scrollTo` leaves half-covered at the screen edge.
- `assert`: poll `required` and `forbidden` selector arrays together.
- `relaunch`: terminate and launch again with a new launch object. State is
  preserved unless `reset` is true.
- `openURL`: open a URL through `simctl` and let the app's real deep-link path
  handle it.

## Selectors

Selectors can combine exact `identifier`, `label`, `role`, and `value` fields.
Text fields also accept `identifierContains`, `labelContains`, `valueContains`,
and their `*Regex` counterparts. `visible` defaults to true; visibility requires
the element frame to intersect the application frame. `enabled` is optional.

Tap selectors must resolve to exactly one visible element. Required selectors
may match one or more elements. Ambiguous taps and malformed selectors fail
with candidate paths and semantic values in `actions.log`.
