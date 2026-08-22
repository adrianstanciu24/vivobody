# Today action and instrument hierarchy

- Status: completed
- Started: 2026-08-22
- Completed: 2026-08-22
- Product guidance: [Workout app principles](../../../workout-app-principles.md)

## Goal and non-goals

Make Today answer one immediate question: what should the user do now? The
screen will present one truthful pinned workout action, place the scheduled
workout ahead of supporting analytics, turn Training Load into a glanceable
current-versus-usual instrument, and keep the journal quiet until it has real
history.

Non-goals:

- no changes to the 3D body model, muscle-development calculation, or scene;
- no changes to training-load formulas, thresholds, or physiological claims;
- no persistence-model, widget, HealthKit, or StoreKit changes;
- no workout-session lifecycle ownership outside `WorkoutSessionController`.

## Invariants and risks

- Today exposes exactly one prominent action: open the workout chooser, or
  resume or finish the active workout.
- A due template becomes the chooser's featured `Start Today's Plan` action;
  Repeat, Fresh, and other saved templates remain available below it.
- A live workout always wins over schedule presentation and cannot be replaced
  or interrupted by another start path.
- Template starts continue through the existing controller method and retain
  its persistence and side-effect behavior.
- Visual encodings retain exact VoiceOver equivalents and remain readable in
  light, dark, and Accessibility Dynamic Type appearances.
- Empty history does not create inactive journal controls or repeated prose.
- Rollback is view-only: the analytics and controller contracts are unchanged.

## Milestones

- [x] Audit the existing dark, light, active, empty, and Accessibility Large
  screenshots and semantic trees.
- [x] Replace competing start controls with one state-derived pinned action.
- [x] Move Up Next before Training Load and make its preview responsive.
- [x] Replace the segmented Training Load decoration with a bold labelled
  current-versus-usual gauge and secondary seven-day receipt.
- [x] Remove redundant empty journal surfaces and consolidate compact
  Consistency VoiceOver semantics.
- [x] Inspect fresh dark, light, active, empty, and Accessibility Large
  evidence and iterate on visual hierarchy.
- [x] Run focused tests, `Scripts/check.sh`, final diff review, and move this
  plan to completed with the recorded result.

## Verification

```bash
/usr/bin/python3 Scripts/check_architecture.py
/usr/bin/python3 Scripts/check_naming.py
swiftformat --dryrun vivobody/ vivobodyWidgets/ VivoKit/Sources/
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' \
  -parallel-testing-enabled NO test \
  -only-testing:vivobodyTests/UpNextTests \
  -only-testing:vivobodyTests/TrainingLoadTests \
  -only-testing:vivobodyTests/ReadinessTests
Scripts/check.sh
SCENARIO=today-actions Scripts/verify.sh
SCENARIO=today-journal-accessibility Scripts/verify.sh
SCENARIO=start-complete-rest Scripts/verify.sh
```

Manual checks not fully observable by the harness: body-model gesture feel,
the pinned control's physical one-handed reach, and direct VoiceOver rotor
navigation.

## Progress and discoveries

- The current scheduled state presents both `Start this workout` and a pinned
  generic `Start Workout`. During an active workout, the scheduled control can
  only expand the active session, so its visible label is false.
- Training Load precedes the scheduled plan even though it is supporting
  context, and its 48 tiny segments consume space without making the current
  value or personal range legible.
- Empty history renders a full two-week grid, a detail link, and a second Last
  Workout placeholder. Accessibility exposes all fourteen compact day cells.
- Accessibility Large truncates the exercise identity and set scheme because
  the normal row remains horizontal and scales text down.

## Result and evidence

Today now presents one stable, thumb-reachable start action. An active workout
replaces it with Resume or Finish; otherwise `Start Workout` opens one chooser.
When a plan is due, `Start Today's Plan` leads that sheet with the template name
underneath, while Repeat, Fresh, and alternate templates remain neutral choices
below it. The scheduled preview still sits ahead of supporting analytics and
reflows at Accessibility sizes.

Training Load is now a current-versus-usual instrument with a large verdict,
an explicit personal range and continuous gauge, and a secondary seven-day
receipt. Cold-start journal placeholders are gone. Once history exists,
Consistency is one exact VoiceOver overview rather than fourteen decorative
focus stops. The 3D body model and its data remain unchanged.

Inspected visual evidence:

- `.verify/today-final-dark-top.jpg`
- `.verify/today-final-dark-content.jpg`
- `.verify/today-new-load-light.jpg`
- `.verify/today-final-ax-top.jpg`
- `.verify/today-final-ax-load.jpg`
- `.verify/today-start-chooser-dark.jpg`
- `.verify/today-start-chooser-sheet-dark.jpg`
- `.verify/today-start-chooser-sheet-history-dark.jpg`
- `.verify/today-start-chooser-sheet-light.jpg`
- `.verify/today-start-chooser-sheet-ax.jpg`

Automated evidence:

- 41 focused tests passed across `UpNextTests`, `TrainingLoadTests`, and
  `ReadinessTests`; log: `.verify/today-focused-tests.log`.
- `today-actions`, `today-journal-accessibility`, and `start-complete-rest`
  semantic scenarios passed; results are under `.verify/scenarios/`.
- `swiftformat --dryrun vivobody/ vivobodyWidgets/ VivoKit/Sources/` passed.
- `Scripts/check.sh` passed, including architecture, documentation, naming,
  source-size, complexity, generated catalog, snapshot contracts, and build.

The first scheduled-start scenario attempt reached the active workout but was
covered by the simulator's one-time notification permission prompt. After
dismissing that system prompt, the unchanged flow passed through set
completion. Physical one-handed reach and direct VoiceOver rotor traversal
remain manual checks.
