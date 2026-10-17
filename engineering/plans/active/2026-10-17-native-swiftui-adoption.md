# Native SwiftUI adoption

Status: Proposed on 2026-10-17.

Replace custom code that duplicates native SwiftUI and iOS 26 features. The
audit used commit `d762ad8`. It found 19 issues and 2 extra issues. This plan
groups them into 6 batches. Each batch builds and passes its checks alone.

This plan does not authorize implementation. Start a batch only on request.
Line numbers are from the audit commit. Find each site again before you edit.

## Rules for every batch

- Keep controls at 44pt or larger. See [product principles](../../../workout-app-principles.md).
- Keep tap-to-complete, drag-to-adjust, and exercise paging. Do not change how they feel.
- Use the closure form of `.sensoryFeedback`. Return `nil` when the app Haptics
  setting is off. Keep `Haptics` calls where a sound plays with the haptic.
- Respect Reduce Motion. Native effects do this; custom fallbacks must too.
- Inspect light and dark appearance for each changed screen.
- Do not change `WeightFormatter` or `DurationFormatter`. Tests cover them.
- Do not edit `vivobody/App/DebugAppStoreSeeder.swift` as part of this plan.
- Verify with the smallest relevant Baguette scenario. See the
  [scenario map](../../../Scripts/verify_scenarios/README.md). The user runs
  device tests and deeper suites.

## Batch overview

| Batch | Name | Issues | Risk | Run after | Open decision |
|---|---|---|---|---|---|
| B1 | App shell and Today bar | 1, 3 (part), 9, 15, B | Low | None | Resolved: iOS 26.1 target |
| B2 | Motion and number primitives | 2, 3 (part), 4, 5, A | Medium | B1 | None |
| B3 | Forms, pickers, and links | 6, 11, 12, 14 | Medium | None | Native picker or shared custom picker; `Form` or card style |
| B4 | Charts and formats | 7, 16 | Medium | B2 | None |
| B5 | Active workout interactions | 8, 10, 13, 17 | High | B2, B3 | Ripple origin; system dialog colors |
| B6 | App Intents and Spotlight | 18, 19 | High | B1 | Scope of `IndexedEntity` |

Order: B1, then B2 and B3, then B4, then B6, then B5. B5 is last because it
changes the main workout screen. B6 needs its own detailed plan first.

## Batches

### B1. App shell and Today bar

Issues: 1, 3 (mini bar, Today, and rest expiry clocks), 9, 15, extra B.

- Decide first: raise the deployment target to iOS 26.1, or use `#available`
  for `.tabViewBottomAccessory(isEnabled:)` and keep the current fallback.
- Do the Today bar (extra B) with issue 15. Both change the Today start controls.
- Checks: `today-actions`, `start-complete-rest`, `active-restoration`.
  Inspect light and dark.
- User test: the review prompt on a device. The simulator does not show it reliably.
- Decisions: the target is iOS 26.1. The `primaryButtonStyle` modifier
  (system `.glassProminent` in the `Radius.card` shape) replaces
  `PrimaryButtonStyle` at all sites.

### B2. Motion and number primitives

Issues: 2, 3 (`BreathingTimer`), 4, 5, extra A.

- Do extra A first. Then the digit change (issue 2) touches one scrubber, not two.
- Keep the instant digit swap while the user scrubs. Animate only after release.
- Checks: `start-complete-rest`, `receipt-live-summary`,
  `receipt-live-summary-light`, `onboarding-first-workout`,
  `template-starting-loads`, `me-showcase`.
- Capture one Reduce Motion state. If no scenario supports it, report the gap.

### B3. Forms, pickers, and links

Issues: 6, 11, 12, 14.

- Decide first: native `Picker(.segmented)` (about 32pt tall, no orange thumb)
  or one shared custom picker that replaces all copies. The 44pt rule applies.
- Decide first: system `Form` look or the current card look with native
  controls inside.
- If the rest control changes, update the `settings-preferences` scenario. It
  taps "90 second rest". Then run
  `/usr/bin/python3 Scripts/documentation_inventory.py --write`.
- Checks: `settings-preferences`, `library-first-visit-dark`,
  `library-first-visit-accessibility-light`, `custom-exercise-type`,
  `custom-exercise-assistance`, `onboarding-first-workout-light`,
  `onboarding-first-workout-accessibility`.

### B4. Charts and formats

Issues: 7, 16.

- Run after B2. B2 and B4 both edit `WorkoutSummaryCard.swift` and
  `StreakCalendar.swift`.
- Compare copy in screenshots. Format styles can change punctuation and order.
- Checks: `insights-showcase`, `insights-accessibility`,
  `insights-movement-coverage`, `insights-muscle-directness`,
  `insights-rhythm-cadence`, `insights-stamina`, `insights-stamina-light`,
  `me-showcase`, `exercise-detail-hero`, `archive-to-history`.

### B5. Active workout interactions

Issues: 8, 10, 13, 17.

- Gate: build a paging prototype for issue 17 first. Test it on a device with
  the vertical scrubbers. If drags conflict, keep `SwipePager` and do the
  other three issues.
- Decide first: the ripple starts at the center or at the tap point.
- Decide first: accept system colors in the end workout dialog, or keep the
  custom dialog.
- Checks: `start-complete-rest`, `active-superset-completion`,
  `active-superset-add-partner`, `active-completion-restoration`,
  `replace-active-exercise`, `active-zero-set-recovery`, `archive-to-history`.
- User test: paging, scrubbing, and set completion on a device.

### B6. App Intents and Spotlight

Issues: 18, 19.

- Write a detailed plan in this folder first. This changes data flow across
  the app, widget, and `VivoKit` targets.
- Update the "App Intent mailboxes" part of [ARCHITECTURE.md](../../../ARCHITECTURE.md).
- Update the CoreSpotlight boundary in `Scripts/check_architecture.py` if
  `IndexedEntity` replaces the indexer.
- Update `DebugSeedCoordinator.swift:82` and `DebugSeedRoutingTests.swift:221-244`.
  Both use the mailbox keys.
- Checks: build the app, widget, and `VivoKit` targets; run
  `widget-start-handoff` and `deep-link-insights`.
- User test: Siri, Shortcuts, Control Center, Live Activity, and Spotlight on a device.

## Shared files

| File | Batches | Note |
|---|---|---|
| `ActiveWorkoutMiniBar.swift` | B1, B2 | B1 changes the clock. B2 changes the pulse dot. |
| `AppRoot.swift` | B1, B6 | B1 changes the accessory and rest ticker. B6 changes intent handling. |
| `TodayScreenDerived.swift` | B1, B4 | B1 touches clock text. B4 changes date formats. |
| `WorkoutSummaryCard.swift` | B2, B4 | B2 changes the count-up. B4 changes date formats. |
| `StreakCalendar.swift` | B2, B4 | B2 changes the pulse. B4 changes date formats. |

## Issues

Each issue lists the files, the current code, the native replacement, the
gain, and the risk.

### 1. Conditional tab bar accessory

- Batch: B1.
- Files: `vivobody/App/AppRoot.swift:438-452`, `:353-356`.
- Now: an `if/else` applies `.tabViewBottomAccessory` only during a workout.
  The two branches have different view identity. Tab state can reset when a
  workout starts or ends.
- Native: `.tabViewBottomAccessory(isEnabled:)`. It needs iOS 26.1. The target is 26.0.
- Gain: stable view identity and less code.
- Risk: low.

### 2. Custom digit roll

- Batch: B2.
- Files: `DigitTicker.swift`. Users: `BareScrubber`, `NumberScrubber`, `BreathingTimer`.
- Now: a custom view animates each digit.
- Native: `Text` with `.contentTransition(.numericText(value:))` and `.monospacedDigit()`.
- Gain: less code and system motion that respects Reduce Motion.
- Risk: medium. The roll looks different. Disable the transition during scrubbing.

### 3. Live clocks

- Batch: B1 (mini bar, Today, rest expiry) and B2 (`BreathingTimer`).
- Files: `ActiveWorkoutMiniBar.swift:53`, `TodayStartControls.swift:46`,
  `BreathingTimer.swift:92-118`, `AppRoot.swift:459-472` (`RestExpiryTicker`).
- Now: `TimelineView` clocks redraw views each second. `BreathingTimer` runs at
  30 fps and also polls every 50 ms. Durations use `String(format: "%d:%02d")`.
- Native: `Text(timerInterval:countsDown:)` for live text. One
  `.task(id: restEndsAt)` that sleeps until the rest ends. `Duration.formatted`
  for fixed durations.
- Gain: fewer wakeups and less battery use.
- Risk: low for text. The breathing ring still needs a timeline while visible.

### 4. Repeating pulse animations

- Batch: B2.
- Files: 12 `repeatForever` sites. Examples: `ScreenKit.swift:94-137`,
  `PanelKit.swift:220-239` (with a 16 ms sleep before it starts),
  `ActiveWorkoutMiniBar.swift:223-257` (`PulseDot`), `CadenceDot` at line 107,
  `StreakCalendar.swift:229`. Find all sites with `rg repeatForever`.
- Now: each site toggles state in `onAppear` to start a forever animation.
- Native: `.phaseAnimator`, or `.symbolEffect(.breathe)` and `.symbolEffect(.pulse)` on symbols.
- Gain: animations restart correctly and stop when views leave. No sleep hack.
- Risk: low to medium. Timing curves can change.

### 5. Summary count-up loop

- Batch: B2.
- Files: `WorkoutSummaryCard.swift:417-465`.
- Now: a `Task.sleep` loop changes the number in steps.
- Native: animate the value with `withAnimation`. Show it with
  `.contentTransition(.numericText(value:))` or an animatable text modifier.
- Gain: frame-synced motion that cancels with the view.
- Risk: low.

### 6. Safari wrapper

- Batch: B3.
- Files: `SafariView.swift`. Users: `SettingsScreen.swift:120`, `:288`.
- Now: a `UIViewControllerRepresentable` wraps `SFSafariViewController`.
- Native: `Link`, with `.onOpenURL(prefersInApp: true)` to open an in-app browser.
- Gain: delete the wrapper and the sheet state.
- Risk: low. Keep `MailComposeView`; it has no native SwiftUI replacement.

### 7. Fixed date patterns

- Batch: B4.
- Files: 17 `DateFormatter` uses and 41 `String(format:)` uses. Examples:
  `WorkoutSummaryCard.swift:410`, `HistoryComponents.swift:197-207`, `:530`,
  `:563-573`, `TodayScreenDerived.swift:176-186`, `MePresentation.swift:423`,
  `BodyWeightDetail.swift:433`, `SessionDetailPresentation.swift:177`, `InsightsFormat`.
- Now: fixed `dateFormat` strings and printf-style number formats.
- Native: `Date.FormatStyle`, `Text(_:format:)`, `Duration.formatted`, and
  number format styles with precision.
- Gain: correct output for each locale, cached formatters, and less code.
- Risk: medium. Copy changes in screenshots. Keep fixed patterns where code parses the output.

### 8. Set count buttons

- Batch: B5.
- Files: `ActiveExerciseIdentitySection.swift:183-230`, `:232-250`.
- Now: custom plus and minus buttons. VoiceOver does not read the set count.
  A button cycles through increment values.
- Native: `Stepper(onIncrement:onDecrement:)` with a label. A `Menu` with a
  `Picker` for the increment.
- Gain: VoiceOver reads and adjusts the count. Users see all increments at once.
- Risk: medium. Check the `Stepper` look inside the glass panel.

### 9. Review prompt scene lookup

- Batch: B1.
- Files: `ReviewRequestController.swift:50-57`.
- Now: the code finds a window scene and calls `AppStore.requestReview(in:)`.
- Native: `@Environment(\.requestReview)`.
- Gain: no scene lookup.
- Risk: low. The architecture check allows StoreKit only in this file. Put the
  view modifier that reads the environment in the same file.

### 10. Set complete button

- Batch: B5.
- Files: `SetCompleteButton.swift`.
- Now: a `DragGesture(minimumDistance: 0)` acts as a button. About 120 lines
  track the press.
- Native: `Button` with a custom `ButtonStyle` that reads `isPressed`.
  `.symbolEffect(.drawOn)` for the checkmark. Use `SpatialTapGesture` only if
  the ripple must start at the tap point.
- Gain: standard button behavior and accessibility, with less code.
- Risk: medium. This is the main workout action. Tap-to-complete must feel the same.

### 11. Segmented controls

- Batch: B3.
- Files: `StepSelector.swift`, `LibrarySegmentViews.swift:20-72`,
  `CatalogEditorFields.swift:11-73`, `OnboardingScreen.swift:260-330`, and
  three chip groups in `SettingsPreferencesSection.swift`.
- Now: seven custom segmented controls.
- Native: `Picker` with `.pickerStyle(.segmented)`. Use `.searchScopes` for the Library scope.
- Gain: one system control and standard accessibility.
- Risk: medium. The native control is about 32pt tall and loses the orange
  thumb. If that is not acceptable, merge the seven copies into one shared view.

### 12. Settings rows

- Batch: B3.
- Files: `SettingsPreferencesSection.swift:61-308`.
- Now: custom rows with titles, subtitles, toggles, and choices.
- Native: `Form` and `Section`. `Toggle { Text(title); Text(subtitle) }`. `Picker` for choices.
- Gain: system layout, Dynamic Type, and accessibility.
- Risk: medium. The screen loses the card look if it uses the system `Form` style.

### 13. End workout dialog

- Batch: B5.
- Files: `EndWorkoutConfirmationDialog.swift` (88 lines), `ActiveWorkoutScreen.swift:153-177`.
- Now: a custom overlay dialog.
- Native: `.confirmationDialog` or `.alert` with a destructive button role.
- Gain: delete 88 lines. System focus, dismissal, and VoiceOver.
- Risk: low to medium. The dialog uses system colors.

### 14. Catalog choice sheet and plane chips

- Batch: B3.
- Files: `CatalogEditorFields.swift:120-186`, `:75-118`.
- Now: a custom sheet for single choices. Custom chips for planes.
- Native: an inline `Picker` with `.navigationLink` or `.menu` style. `Toggle`
  with `.toggleStyle(.button)` for the chips.
- Gain: less sheet state and standard selection behavior.
- Risk: low.

### 15. Primary button style

- Batch: B1.
- Files: `PrimaryButtonStyle`, `PrimaryActionButton.swift:46-69`, `:87-90`.
- Now: a custom style draws the main button. The action button measures its
  subtitle and adds accessibility modifiers that the button already has.
- Native: `.buttonStyle(.glassProminent)` with `.tint`, `.buttonBorderShape`,
  and `.controlSize(.large)`. Remove the measurement and the extra modifiers.
- Gain: system glass behavior and less layout code.
- Risk: medium. The main button can look different. Check light and dark.

### 16. Path charts and fraction bars

- Batch: B4.
- Files: `MiniChart.swift`, `ProgressionRhythmSection.swift:172-367`,
  `ConsistencySection.swift:268-360`, fraction bars in five Insights files,
  `MuscleMapDetailsSheet.swift:81-91`.
- Now: charts draw with `Path`. Each Insights file draws its own bar.
- Native: Swift Charts. `LineMark` with `.interpolationMethod(.stepEnd)` for
  the rhythm chart. `RectangleMark` for the consistency grid. `Gauge` with
  `.linearCapacity`, or `ProgressView(value:)`, for fraction bars. One shared
  bar view if the native look does not match.
- Gain: chart accessibility and audio graphs, and less path math.
- Risk: medium. Visual match and list scroll performance.

### 17. Swipe pager

- Batch: B5.
- Files: `SwipePager.swift:21-252`.
- Now: a custom drag gesture pages between exercises.
- Native: a horizontal `ScrollView` with
  `.scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))`,
  `.scrollPosition(id:)`, `.contentMargins`, `.scrollTransition`, and `.sensoryFeedback`.
- Gain: system scroll physics and less gesture code.
- Risk: high. The pages contain vertical scrubbers. Prototype first.

### 18. App Intent mailbox

- Batch: B6.
- Files: `VivoKit` `WidgetIntents.swift:15-44`, `AppShortcuts.swift:118-137`, `AppRoot.swift:418-428`.
- Now: intents write requests to App Group defaults. The app reads them when it becomes active.
- Native: `AppDependencyManager` and `@Dependency` to call the app directly.
  `supportedModes` to run in the app. `LiveActivityIntent` for Complete Set
  from the Live Activity.
- Gain: no mailbox keys and no read-on-activation step.
- Risk: high. Only the app writes SwiftData. Widget code must not gain write access.

### 19. Shortcut template query

- Batch: B6.
- Files: `AppShortcuts.swift:19-27`, `:44-109`.
- Now: the template query reads the App Group snapshot.
- Native: read SwiftData directly when the intent runs in the app. Optional:
  `IndexedEntity` to replace `SpotlightIndexer` and `SpotlightIndexStore`.
- Gain: current data and less snapshot code.
- Risk: medium. Spotlight changes cross the CoreSpotlight architecture boundary.

### Extra A. Duplicate scrubber

- Batch: B2.
- Files: `NumberScrubber.swift` (393 lines).
- Now: it repeats the `BareScrubber` drag physics. Only the `WeightScrubber`
  `.card` style uses it.
- Change: merge it into `BareScrubber`.
- Gain: one scrubber to maintain and test.
- Risk: medium. Drag-to-adjust must feel the same.

### Extra B. Today bottom bar

- Batch: B1.
- Files: `TodayScreen.swift:194`, `TodayStartControls.swift:123-134`.
- Now: fixed 104pt and 160pt `safeAreaPadding`, and a custom gradient fade.
- Native: `.safeAreaBar(edge: .bottom)` and `.scrollEdgeEffectStyle(.soft, for: .bottom)`.
- Gain: correct insets for every text size, and no fixed numbers.
- Risk: low.

## Keep custom

These parts have no good native replacement, or the custom code is the product:

- `BareScrubber` and the `BreathingTimer` gestures.
- Signature renderers.
- `SoundEngine` and `HapticPatternEngine`.
- `Haptics` (178 calls; it pairs sound and respects the setting).
- `GlassStyle` and `StatStripRowLayout`.
- Widget snapshots and the Live Activity queue.
- `MailComposeView`.

## Progress

- [x] B1. App shell and Today bar. Done on 2026-10-17. `today-actions`,
  `start-complete-rest`, and `active-restoration` passed on iPhone Air, iOS 26.5.
  The iOS 27.0 simulator did not accept taps.
- [x] B2. Motion and number primitives. Done on 2026-10-17. `NumberScrubber` is
  merged into `BareScrubber` (card chrome in `ScrubberCardSurface.swift`).
  `DigitTicker` keeps its API and draws native numeric text. No `repeatForever`
  remains. `start-complete-rest`, `receipt-live-summary`,
  `receipt-live-summary-light`, `onboarding-first-workout`, and
  `template-starting-loads` passed on iPhone Air, iOS 26.5. They also passed with
  Reduce Motion on (`start-complete-rest`, `receipt-live-summary`).
  `me-showcase` failed: the fixture shows "Week streak, 10 of 12", but the
  scenario expects 11 of 12. B2 does not change streak math. No product screen
  uses the card scrubber; only DEBUG galleries do.
- [x] B3. Forms, pickers, and links. Done on 2026-10-17. Decisions: one shared
  custom picker (`SegmentedPicker`, 44pt, orange thumb) replaces all seven copies,
  including `StepSelector` and the Library scope; Settings keeps the card look
  with native `Toggle`s. Catalog single choices are native menu pickers; plane
  chips are `.button` toggles. The privacy link uses
  `openURL(_:prefersInApp: true)`; `SafariView` is deleted. The scenario
  runner gained `tapIn` because a native `Toggle` row's title does not toggle.
  `settings-preferences`, `library-first-visit-dark`,
  `library-first-visit-accessibility-light`, `custom-exercise-assistance`,
  `onboarding-first-workout-light`, and `onboarding-first-workout-accessibility`
  passed on iPhone Air, iOS 26.5. `custom-exercise-type` is flaky: the editor
  sheet often does not open at launch. The pre-B3 commit fails the same way. A
  manual run showed the native menu with the three allowed types.
- [x] B4. Charts and formats. Done on 2026-10-17. All fixed `DateFormatter`
  patterns use `Date.FormatStyle`; the "  ·  " separators stay. In en_US, times
  get a narrow no-break space before AM or PM, and History rows read
  "Sun, May 3". Display `String(format:)` uses number format styles; seeder
  UUIDs, `WeightFormatter`, `DurationFormatter`, and one DEBUG gallery counter
  keep printf. `MiniChart` uses Swift Charts. The rhythm staircase and the
  consistency heatmap stay custom: the staircase draw-in and staggered dots
  have no Charts equivalent, and the heatmap is a calendar grid. A shared
  `FractionBar` (`ProgressView` with a custom style) replaces three
  single-value bars. Split, segmented, and vertical bars stay custom.
  `insights-movement-coverage`, `insights-muscle-directness`,
  `insights-rhythm-cadence`, `insights-stamina`, `insights-stamina-light`,
  `exercise-detail-hero`, and `archive-to-history` passed on iPhone Air,
  iOS 26.5. `me-showcase`, `insights-showcase`, and `insights-accessibility`
  fail the same way on the pre-B4 commit: their fixture values and scroll
  stops are out of date. A temporary scenario showed the body weight
  sparkline in light and dark. The simulator region (Romania) uses decimal
  commas and 24-hour time. `WeightFormatter` still prints "12.5k" and forces
  "," grouping, so one screen can mix decimal marks. Fix that in a later
  change, not in this plan.
- [x] B5. Active workout interactions. Done on 2026-10-17. Decisions: the
  ripple starts at the center; the end workout dialog is a native
  `.confirmationDialog` (a popover from the end button on iOS 26);
  `EndWorkoutConfirmationDialog.swift` is deleted. `SetCompleteButton` is a
  native `Button` with a press style, and the checkmark uses
  `.symbolEffect(.drawOn)`. The set count keeps its 44pt buttons: the native
  `Stepper` segments are 32pt tall, so a `Stepper` is only the accessibility
  representation. The step increment is a `Menu` with a `Picker`.
  `SwipePager` is a native paging `ScrollView`. Scrubbers inside it share
  their drag (`scrubberSharesDrags`); scrubbers elsewhere keep exclusive
  drags. One swipe moves one page. `start-complete-rest`,
  `active-superset-completion`, `active-superset-add-partner`,
  `active-completion-restoration`, `replace-active-exercise`,
  `active-zero-set-recovery`, and `archive-to-history` passed on iPhone Air,
  iOS 26.5. Temporary scenarios showed the workout screen and the dialog in
  light and dark. The paging gate is not closed: the user must test paging,
  scrubbing near the sheet edge, and set completion on a device. If a
  downward scrub moves the sheet, remove `scrubberSharesDrags` from
  `SwipePager` first; if that fails, restore the old `SwipePager`.
- [ ] B6. App Intents and Spotlight.
