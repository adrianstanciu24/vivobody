# Active workout inputs

Status: Active product contract

The active instrument lets a person read and adjust the next set's load,
repetitions, or duration with one hand. Large values lead; the rail beside each
editable value signals vertical scrubbing before the person touches it.

- Keep identity, set progress, configuration, working values, effort, and the
  completion action in one open field. A soft adaptive focus behind the working
  values gives the instrument depth without an enclosing card.
- Show the current set position beside the segment timeline. Keep completed
  set editing and the most recent set's readout in that timeline; enlarged
  text stacks the position above the timeline.
- Use secondary ink for supporting labels and units. Keep the completion
  action thumb-reachable with a compact 72pt standard height; accessibility
  text may grow and scroll. Completion feedback retains its stronger accent.
- Keep graduation rails visible while an active value is idle, being dragged,
  or coasting, including after the first-use gesture has been learned.
- Use a fixed index and fine graduations that compress and fade toward the
  ends, like a drum, with no filled roller behind them. Size each rail to
  slightly more than its digits' cap height. At rest, graduations and index
  stay neutral and low-contrast so the value leads; while the value is dragged
  or coasting, the graduations brighten and the index takes the accent color.
  The index is longer than every graduation, so the cue does not rely on hue.
  Compact controls include intermediate marks so the reps rail remains
  recognizable. Those marks do not introduce fractional reps or change steps.
- Reserve horizontal space for the rail so digits and units cannot overlap
  it. Put load and repetition rails to the left of their values. Place
  the compact reps multiplication symbol after the rail, before the value,
  so the load and reps rails share the same leading alignment. Place
  persistent rails directly beside their values at every size;
  the full-width primary scrub target and stable worst-case digit scale remain.
  Persistent rails replace the temporary first-use chevrons on these controls.
  The primary number retains its one-time nudge.
- Keep the configured increments, vertical gesture ownership, flywheel,
  boundary feedback, and save-on-settle behavior. A completed value is a
  readout and does not display an editable rail.
- The STEP control beside the set count cycles the scrub increment for the
  current exercise and remembers it per exercise. Loaded rep exercises cycle
  the unit's weight steps. Timed exercises cycle 1s, 5s, and 10s (default
  5s); Edit Set uses the same time step. Changing the time step does not round
  the current time, and a logged time can be as short as 1s. The exercise
  editor sets the same per-exercise steps. Template target editors keep the
  fixed 5s step.
- Rails are decorative and hidden from accessibility. The existing adjustable
  value exposes its label, exact value, range, and actions. Support light,
  dark, increased contrast, and Reduce Motion without relying on hue alone.

Implementation: [BareScrubber](../vivobody/Components/Inputs/BareScrubber.swift),
[rail renderer](../vivobody/Components/Inputs/ScrubGraduationRail.swift),
[reps instrument](../vivobody/Screens/ActiveWorkout/ActiveRepsInstrument.swift),
and [duration instrument](../vivobody/Screens/ActiveWorkout/ActiveDurationInstrument.swift).

Use the [active assistance scenario](../Scripts/verify_scenarios/active-assistance.json)
for the entered-load and compact-reps layout, then inspect idle and settled
scrubs in both appearances and at Accessibility Large. Physical-device
scrub feel and haptic timing remain manual checks.

The rest readout uses unobstructed digits, without ghost numerals underneath.
Reopening an in-progress rest preserves its full interval in the “of” label
and progress scale while the live remaining time continues counting down.

## Wide display

A workout that expands in a wide, regular-width window on iOS 27.1 or later
fills the window. Each exercise page splits at the fold into two lanes with
one cut in the column, between the configuration and the working values:

- The leading lane holds identity and setup: the exercise name and menu, the
  set position and segment timeline with the last-set readout, and the Sets
  and STEP configuration. Its content aligns to the top.
- The trailing lane holds the set: the working values with their rails, reps
  in reserve, and the completion action. The action sits at the bottom in
  thumb reach, and the working values center in the space above it. Reps in
  reserve stays in this lane because the person sets it just before the
  completion tap.
- The working value keeps its 104pt size and fits the lane width with the
  same stable worst-case digit scale.
- The top bar spans the window and adds a minimize control. The page dots sit
  under the trailing lane. A horizontal swipe across either lane pages whole
  exercises, and vertical scrubs keep gesture ownership.
- The rest timer and the personal-record moment keep their full-window
  scrim, and their content centers in the trailing lane, so no digit sits on
  the fold.
- The Summary page puts the status, hero metric, stat band, intensity line,
  and completed load comparison in the leading lane, and the exercise list
  with Add exercise and Done in the trailing lane.
- At accessibility text sizes each lane scrolls alone, and the completion
  action stays reachable. VoiceOver reads the leading lane, then the trailing
  lane, which is the single-column order.
- On a device with a hinge, such as iPhone Duo, the workout uses the
  full-window presentation in every pose, folded or open. A fold or an
  unfold only resizes the workout and changes its composition: one column
  on the folded display, the two lanes on the open display. Nothing closes,
  and the shell does not show between the two. Other iPhones keep the
  sheet. A wide window without a hinge, such as resizable iPhone Mirroring,
  uses the full-window presentation when the workout opens in it, and keeps
  the presentation until the workout minimizes.
- A page shorter than the standard column, such as the folded iPhone Duo
  display, packs the column tighter instead of scrolling: the exercise name
  takes one line and scales down to fit, the gaps around the instruments
  close, and the working value drops to 80% of its size. Every control stays
  between the top bar and the page dots. Phone sheets keep the standard
  column.
- The pager clips at its side edges, so a neighbor page never shows through
  a horizontal safe area such as the folded display's status bar column.

Use the [Duo active workout scenario](../Scripts/verify_scenarios/duo-active-split.json)
and its `-light` and `-accessibility` variants on the iPhone Duo simulator. A
fold or unfold during a workout, during rest, or with Edit Set open, scrub feel in the
trailing lane, the swipe-down minimize, and VoiceOver order are device checks.
