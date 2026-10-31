# Active workout on wide displays

Status: Proposed on 2026-10-31. Revised after review on 2026-10-31.
Implemented on 2026-10-31; the device-only checks are open. The step 1 spike
showed that `.presentationSizing(.page)` gives a centered card that crosses the
fold, so the open display uses the full-screen cover.

On the open iPhone Duo display held wide, the active workout shows as a narrow
form sheet in the middle of the screen. The sheet is shorter than the
instrument stack, so the top bar cuts the exercise name and the page dots touch
the completion action. The 104pt working value fills the sheet, the fold runs
through it, and the Today tab shows on both sides. This plan gives the wide
window its own composition. The phone and every other window do not change.

This plan does not authorize implementation. Start a step only on request.

## Target layout

The workout fills the window. Each exercise page splits at the fold into two
lanes from [DashboardLanes](../../../vivobody/Components/Containers/DashboardLanes.swift).
The split is one cut in the current column, between the configuration and the
working values:

| Leading lane (identity and setup) | Trailing lane (the set) |
|---|---|
| Exercise name and exercise menu | Working load and reps (or duration), with their rails |
| Set position and set lamps, with the last-set readout | Reps in reserve |
| Sets and STEP configuration | Complete set / Finish exercise |

- Reps in reserve stays with Complete set. The user sets it just before the
  completion tap, so the fold must not separate the two. One
  `ActiveExerciseEffortActionInput` already supplies both.
- The leading lane aligns its content to the top. In the trailing lane,
  Complete set sits at the bottom, in thumb reach as on the phone, and the
  working values center in the space above it.
- The pager still pages whole exercises with a horizontal swipe across both
  lanes. Vertical scrubbing keeps gesture ownership.
- The top bar spans the full width. The page dots sit under the trailing lane.
- The working value keeps its 104pt size. `BareScrubber` with `fitsWidth`
  already scales it to the lane width with the stable worst-case digit scale.
  A lane is 332pt to 397.5pt wide; the phone hero gets about 326pt.
- The rest timer and the PR celebration keep their full-window scrim. Their
  content centers in the trailing lane, so no digit sits on the fold.
- The Summary page splits at its existing section boundary: status, hero
  metric, stat band, intensity line, and the completed load comparison in the
  leading lane; the exercise list and the Done and Add exercise actions in the
  trailing lane. Each lane scrolls alone.
- At accessibility text sizes each lane scrolls alone, as the single column
  does now. The completion action stays reachable.
- VoiceOver reads the leading lane, then the trailing lane. With this split,
  that is the current single-column order, so no sort priorities are needed.

## Steps

1. **Presentation spike.** `AppRoot` measures the layout on the `TabView`, so
   neither `AppRoot` nor the workout sheet gets `\.appDisplayLayout`. Lift the
   value to `AppRoot`, pass it into the presented workout's environment, and
   update the `\.appDisplayLayout` doc comment that says the sheet keeps the
   phone layout. On `regularWide`, try `.presentationSizing(.page)` and check
   on the Duo that the sheet fills the window. Expect it not to: `.page` is a
   page-size sheet, and a custom `PresentationSizing` cannot read the window
   size (`PresentationSizingContext` has no public members in the iOS 27.1
   SDK).

   If the sheet does not fill the window, present a `fullScreenCover` on
   `regularWide` with `.navigationTransition(.zoom(sourceID:in:))`, and put
   `matchedTransitionSource` on the mini-bar and the Today resume bar. Check
   that its swipe-down dismissal minimizes the workout, does not take vertical
   scrubs, and stays blocked by `interactiveDismissDisabled` during the PR
   celebration. Add an explicit minimize control to the top bar in either
   case, because the top edge is far from the thumbs on a wide display.

   Choose the presentation when the workout expands and keep it until the
   workout minimizes. In the sheet, the content stays a column. In the cover,
   the content follows the layout: split on `regularWide`, column otherwise.
   A fold must not swap presentations: that would tear down
   `ActiveWorkoutScreen` and its child sheets (Edit Set, the picker,
   substitution), end a scrub, and run `onDismiss`. To keep an unfold from
   leaving the folded sheet in place, a device whose window reports a hinge
   (`UIHingeInteraction`, iOS 27.1) uses the cover in every pose. A swap on
   unfold was tried and rejected: the sheet closes, the shell shows, and the
   cover opens again. Files:
   `vivobody/App/AppRoot.swift`, `vivobody/App/AppDisplayLayout.swift`.
2. **Lanes in the workout screen.** `ActiveWorkoutScreen` reads the window's
   fold division outside the pager (as Insights and Me do) and passes
   `DashboardLanes?` to each page. Build the lanes in page coordinates.
   `SwipePager` makes each page `2 × (peekWidth + spacing)` (36pt) narrower
   than the window and starts it 18pt in. Window lanes used without change
   move 18pt toward the trailing edge: with the 40pt test fold at x 455, the
   leading lane ends 2pt from the fold and the trailing lane runs 16pt past the
   page. Use the page width with the divisions offset by the pager inset, in a
   pure function that a unit test can pin, or set peek and spacing to 0 in the
   split. Move the wide composition into a new `ActiveWorkoutSplitContent.swift`
   to stay under the source-size ratchet (`ActiveWorkoutScreen.swift` is 574
   lines).
3. **Split exercise card.** Give `ActiveExerciseCard` a column or split
   composition. Separate `ActiveExerciseConfigurationSection` from the metric
   instrument inside `heroBlock`, so the configuration can sit in the leading
   lane and the metric, reps in reserve, and action in the trailing lane. The
   card keeps all of its state (completion coordinator, edit and delete sheets,
   scrub cancellation). Files: `ActiveExerciseCard.swift`,
   `ActiveExerciseCardSections.swift`.
4. **Rest and PR.** Limit `RestTimerOverlay` and `PRCelebration` content to
   the trailing lane in the split.
5. **Summary page.** Split `WorkoutSummaryCard` as described above.
6. **Contracts.** Add a "Wide display" section to
   [active workout inputs](../../../specs/active-workout-inputs.md). Update the
   wide-display paragraph in [ARCHITECTURE.md](../../../ARCHITECTURE.md), the
   [scenario map](../../../Scripts/verify_scenarios/README.md), and the
   regenerated scenario index.

## Verification

- Unit tests (Swift Testing): the lanes in page coordinates, with and without
  a fold: the leading lane keeps its gutter from the fold, and the trailing
  lane ends inside the page. If the presentation choice lives in a pure value,
  pin that a layout change during one expansion does not change it. Lane
  geometry in viewport coordinates is already covered by
  `InsightsCardLayoutTests`, and the layout decision by `AppDisplayLayoutTests`.
- New Duo scenarios `duo-active-split`, `-light`, and `-accessibility`, run
  with `SIMULATOR_NAME='iPhone Duo' SIMULATOR_OS=27.1`. Launch from a standard
  partial workout (`--ui-test-active-partial`, as in `duo-today-split`), not
  the assistance fixture, whose label and direction hint are a special load
  mode. Open the resume bar, check both lanes, complete one set, check the rest
  timer, page to the Summary, and minimize. Also check a duration exercise
  (`--ui-test-active-bodyweight-duration`, as in `active-duration`), because
  step 3 moves both instruments.
- Phone regression: `active-assistance`, `active-duration`, and
  `active-superset-completion` on the default iPhone.
- Final gate: `Scripts/check.sh`.
- Keep Device Hub open while the Duo scenarios run. Gestures reach the
  simulator, and quitting Device Hub folds the device to a black screen.
- Device-only checks: an active fold; fold and unfold during a workout, during
  rest, and with Edit Set open; scrub feel and haptics in the trailing lane;
  the minimize gesture; and VoiceOver order across the lanes.

## Follow-up and rejected options

- Follow-up, not in this plan: put the rest timer in the leading lane and keep
  the trailing lane usable during rest, so the user can set the next load while
  loading the bar. The next set's values would also show what comes next. This
  changes the rest contract, such as what Complete set does during rest, so it
  needs a spec decision first.
- Rejected: the unchanged phone card in one lane and a workout list in the
  other. A lane is about as wide as a phone page, but the window is about 669pt
  tall, roughly three quarters of a phone, so the column does not fit.
- Rejected: a smaller fixed hero size in the split. `fitsWidth` already fits
  the lane, and a fixed smaller size would shrink the numeral on the larger
  display, against the principle that large, stable numerals lead.
