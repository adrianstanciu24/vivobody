# Active workout on wide displays

Status: Proposed on 2026-10-31.

On the open iPhone Duo display held wide, the active workout shows as a narrow
form sheet in the middle of the screen. The sheet is shorter than the
instrument stack, so the top bar cuts the exercise name and the page dots touch
the completion action. The 104pt working value fills the sheet, the fold runs
through it, and the Today tab shows on both sides. This plan gives the wide
window its own composition. The phone and every other window do not change.

This plan does not authorize implementation. Start a step only on request.

## Target layout

The workout fills the window. Each exercise page splits at the fold into two
lanes from [DashboardLanes](../../../vivobody/Components/Containers/DashboardLanes.swift):

| Leading lane (context and setup) | Trailing lane (the work) |
|---|---|
| Exercise name and exercise menu | Working load and reps (or duration), with their rails |
| Set position and set lamps, with the last-set readout | Complete set / Finish exercise |
| Sets and STEP configuration | |
| Reps in reserve | |

- The pager still pages whole exercises with a horizontal swipe across both
  lanes. Vertical scrubbing keeps gesture ownership.
- The top bar spans the full width. The page dots sit under the trailing lane.
- The working value uses a smaller fixed size in the split (start at 80pt;
  tune on the Duo). It keeps the stable worst-case digit scale.
- The rest timer and the PR celebration keep their full-window scrim. Their
  content centers in the trailing lane, so no digit sits on the fold.
- The Summary page splits at its existing section boundary: status, hero
  metric, and stat band in the leading lane; the exercise list and the Done
  and Add exercise actions in the trailing lane. Each lane scrolls alone.
- At accessibility text sizes each lane scrolls alone, as the single column
  does now. The completion action stays reachable.
- VoiceOver reads the leading lane, then the trailing lane, in the current
  single-column order.

## Steps

1. **Presentation spike.** `AppRoot` measures the layout on the `TabView`, so
   the workout sheet does not get `\.appDisplayLayout`. Pass the shell's value
   into the sheet's environment. On `regularWide`, try
   `.presentationSizing(.page)` and check on the Duo that the sheet fills the
   window. If it does not, present with `fullScreenCover` on `regularWide`
   only, and add an explicit minimize control to the top bar, because a full
   screen cover has no drag-down to the mini-bar. Keep the PR lock on
   interactive dismissal. Files: `vivobody/App/AppRoot.swift`,
   `vivobody/App/AppDisplayLayout.swift`.
2. **Lanes in the workout screen.** `ActiveWorkoutScreen` reads the window's
   fold division outside the pager (as Insights and Me do) and passes
   `DashboardLanes?` to each page. Move the wide composition into a new
   `ActiveWorkoutSplitContent.swift` to stay under the source-size ratchet
   (`ActiveWorkoutScreen.swift` is 574 lines).
3. **Split exercise card.** Give `ActiveExerciseCard` a column or split
   composition. Separate `ActiveExerciseConfigurationSection` from the hero
   inside `heroBlock`, so configuration can sit in the leading lane. The card
   keeps all of its state (completion coordinator, edit and delete sheets,
   scrub cancellation). Files: `ActiveExerciseCard.swift`,
   `ActiveExerciseCardSections.swift`.
4. **Hero size.** Replace the fixed 104pt in `ActiveRepsInstrument.swift` and
   `ActiveDurationInstrument.swift` with a size the card passes in: 104pt in
   the column, the compact size in the split.
5. **Rest and PR.** Limit `RestTimerOverlay` and `PRCelebration` content to
   the trailing lane in the split.
6. **Summary page.** Split `WorkoutSummaryCard` as described above.
7. **Contracts.** Add a "Wide display" section to
   [active workout inputs](../../../specs/active-workout-inputs.md). Update the
   wide-display paragraph in [ARCHITECTURE.md](../../../ARCHITECTURE.md), the
   [scenario map](../../../Scripts/verify_scenarios/README.md), and the
   regenerated scenario index.

## Verification

- Unit tests (Swift Testing): the column or split decision from the display
  layout, and the hero size for each composition. Lane geometry is already
  covered by `InsightsCardLayoutTests`.
- New Duo scenarios `duo-active-split`, `-light`, and `-accessibility`, run
  with `SIMULATOR_NAME='iPhone Duo' SIMULATOR_OS=27.1`. Launch from
  `--ui-test-active-assistance`, open the resume bar, check both lanes, complete
  one set, check the rest timer, page to the Summary, and minimize.
- Phone regression: `active-assistance`, `active-duration`, and
  `active-superset-completion` on the default iPhone.
- Final gate: `Scripts/check.sh`.
- Gestures do not reach the Duo simulator while Device Hub holds it open.
  Close Device Hub before the Duo scenarios run.
- Device-only checks: an active fold, scrub feel and haptics in the trailing
  lane, the minimize gesture, and VoiceOver order across the lanes.
