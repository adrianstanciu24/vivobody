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
- `arguments`: additional deterministic debug launch arguments. Pass
  `--static-body` on any scenario that lands on a screen with the 3D body
  model: the idle turntable starves the simulator's accessibility bridge
  (polls return skeleton trees) and makes screenshots nondeterministic.

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

## Today action contract

`today-actions` exercises the pinned start/active states and both chooser
hierarchies in one deterministic run. Its Today taps are intentional uniqueness
assertions: an accidental second matching action makes the scenario fail before
interaction. The existing `start-complete-rest` flow chooses the featured plan
and proves the scheduled start through set completion.

- Empty, unscheduled Today exposes one generic `Start Workout`, with no
  scheduled or active action and no empty Consistency / Last workout journal.
- A due template keeps the same single `Start Workout` action. Its chooser
  features `Start Today's Plan` first, then Fresh, Repeat, and other saved
  templates without duplicating the featured plan.
- An active workout wins over a simultaneously due template and exposes one
  `Resume Workout` action, with no start action present;
  the final relaunch also proves that restored state keeps the same hierarchy.

`today-journal-accessibility` scrolls a fixed history seed to the compact
Consistency journal and requires one exact two-week overview plus its detail
drill-out. It forbids the former per-day `Rest` / `Trained` values so the
fourteen visual dots cannot silently return as fourteen VoiceOver stops.

`insights-load-rep-drivers` scrolls the showcase history to Training load and
requires the centered seven-day Sessions, 1–5 reps, and 6–12 reps driver cells.
