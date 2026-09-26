# Active workout inputs

Status: Active product contract

The active instrument lets a person read and adjust the next set's load,
repetitions, or duration with one hand. Large values lead; the rail beside each
editable value signals vertical scrubbing before the person touches it.

- Keep graduation rails visible while an active value is idle, being dragged,
  or coasting, including after the first-use gesture has been learned.
- Use a fixed index, shaded roller, and graduations that recede toward the
  ends. Compact controls include intermediate marks so the reps rail remains
  recognizable. Those marks do not introduce fractional reps or change steps.
- Reserve horizontal space for the rail so digits and units cannot overlap
  it. Persistent rails replace the temporary first-use chevrons on these
  controls. The primary number retains its one-time nudge.
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
