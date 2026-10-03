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
