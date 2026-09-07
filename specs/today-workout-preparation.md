# Today workout preparation

Status: Implemented product design.

Today helps the user start or resume a workout. The body visualization leads,
followed by Up next when available, Consistency, and Last workout. One pinned
Start Workout action opens the existing chooser; an active workout replaces it
with Resume Workout or Finish Workout and hides Up next.

## Up next

- Scheduled templates retain their existing Today, Tomorrow, or future-day
  label and exercise prescription preview.
- When no templates are scheduled, show the most recently used nonempty saved
  template as a **Repeat option**. Never-used templates do not imply a previous
  workout. If no eligible template exists, omit the card; Start Workout remains
  available for fresh workouts and template selection.
- Tapping the preview opens the template. The pinned chooser remains the sole
  start action and provides access to all workout options.
- A compact **Last time** reference shows the first exercise in template order
  with compatible completed history, its date, and up to five completed sets.
  Additional sets are counted explicitly. Mixed loads are labeled per set;
  duration and bodyweight/assistance semantics retain their existing formatting.
- History comes from the shared analytics index, matching exercise identity and
  exact performance signature. No compatible history means no reference.
- Last time is a logged reference, not a prescribed target or a promised PR.
  The preview does not show load advice or PR-proximity coaching.

Training Load and its detailed range comparison belong in Insights and are not
rendered on Today. The underlying analytics remain available to their existing
consumers.

## Evidence

Use the focused [Today scenario](../Scripts/verify_scenarios/today-up-next.json)
for the scheduled preview and pinned action. Inspect dark, light, and large
Dynamic Type states. Repeat-option, compatible-history, and active-workout
behavior also require focused evidence when those paths change.

Implementation: [Today](../vivobody/Screens/Today/TodayScreen.swift),
[selection](../vivobody/Screens/Today/TodayScreenDerived.swift), and
[last-time reference](../vivobody/Screens/Today/TodayLastTimePresentation.swift).
