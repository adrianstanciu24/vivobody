# Today workout preparation

Status: Implemented product design.

Today helps the user start or resume a workout. The body visualization leads,
followed by Up next when available, Consistency, and Last workout. One pinned
Start Workout action opens the existing chooser; an active workout replaces it
with Resume Workout or Finish Workout and hides Up next.

## Up next

- Scheduled templates retain their existing Today, Tomorrow, or future-day
  label and exercise target preview. Starting-load references resolve under the
  [template starting loads](template-starting-loads.md) contract.
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

## Up Next Home Screen widget

The small widget uses the system content margins, a leading-aligned workout
name of up to two lines, and an orange planned-set count. A quiet Today label
sits above the name; a subtle warm background follows the app's light/dark
preference. System tinting owns the appearance in accented widget modes. At
larger text sizes, the Today label yields space to the workout name and action.

Tapping the tile opens Today. The separate 44-point orange arrow starts today's
scheduled workout through the existing widget intent, or expands an already
active workout. The app resolves the current schedule when handling the intent;
the widget does not write workout data. Rest-day and unscheduled states retain
their next-workout or no-schedule copy and open Today without a start button.

Use [widget-start-handoff](../Scripts/verify_scenarios/widget-start-handoff.json)
for the app-side action. Inspect the actual Home Screen widget for alignment,
light/dark appearance, large text, and the separate tile/button tap targets.

## Initial content

The pinned start/resume action, Up next template preview, recent consistency
strip, and Last workout render without staggered entrance delays or waiting
for the full analytics report. Today queries only a 45-day recent window,
one latest archived workout, and saved templates for this initial content.
All-time streak, PR annotations, and the compatible Last time reference enrich
the existing content when the shared analytics cache becomes available; they
must not be recomputed from a truncated history and presented as all-time facts.
Full-archive snapshot preparation yields between small batches so it does not
hold the UI thread for the entire archive. The static Training development legend appears without an entrance delay.
The 3D model is visible from its first rendered frame, without an entrance
fade or loading overlay. Geometry does not wait for the full-history development
calculation: available development colors are applied initially, and later
analytics updates cross-fade the existing scene to its new muscle colors over
1.2 seconds.

## Evidence

Use the focused [Today scenario](../Scripts/verify_scenarios/today-up-next.json)
for the scheduled preview and pinned action. Inspect dark, light, and large
Dynamic Type states. Repeat-option, compatible-history, and active-workout
behavior also require focused evidence when those paths change.

Implementation: [Today](../vivobody/Screens/Today/TodayScreen.swift),
[selection](../vivobody/Screens/Today/TodayScreenDerived.swift), and
[last-time reference](../vivobody/Screens/Today/TodayLastTimePresentation.swift).
