# Today workout preparation

Status: Implemented product design.

Today helps the user start or resume a workout. The body visualization leads,
followed by Up next when available, Consistency, and Last workout. One pinned
action reads **Start Fresh Workout** and opens the exercise picker directly when
there is no workout history or saved template. Once another start path exists,
it reads **Start Workout** and opens the chooser. An active workout replaces it
with Resume Workout or Finish Workout and hides Up next.

## Up next

- Scheduled templates retain their existing Today, Tomorrow, or future-day
  label. The heading shows the workout name with its exercise count and
  duration estimate.
- When no templates are scheduled, show the most recently used nonempty saved
  template as a **Repeat option**. Never-used templates do not imply a previous
  workout. If no eligible template exists, omit the card; the pinned start
  action remains available for fresh workouts and template selection.
- Tapping the workout heading opens the template. Whenever multiple start paths
  exist, the pinned chooser remains the sole start action and provides access
  to all workout options.
- The card follows the Insights instrument language: a readout heading with a
  tracked legend line, then one row per exercise separated by hairlines. Each
  row carries its muscle group as a quiet caption above a headline-weight name,
  with its set structure (`3 × 8`, `3 × 8–12`, `2 × 0:30 hold`) as a trailing
  monospaced figure with a quiet `×`. Rows never show weights, load policies, or
  starting-load references; loads resolve when the workout starts and remain in
  the exercise editor. Muscle totals are omitted here.
- Standard previews show up to four exercises; accessibility layouts show
  three. When exactly one exercise would remain it is shown; otherwise a
  **+N more** row opens the template. Text wraps rather than shrinking.
- One **Last time** footer closes the card behind a hairline: a tracked legend
  with the relative day (Today, Yesterday, N days ago, or a month-day date),
  then a stat strip with the shared receipt columns (sets, reps when present,
  and volume, known volume, or timed work) from the newest recent archived
  workout that performed at least half of the template's exercises under the
  same identity and performance signature. Templates that were started but have
  no matching recent workout say **Last done** with the date; never-used
  templates say **First time with this workout**, legend only.
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
The Last time footer matches against that same recent window. All-time streak
and PR annotations enrich the existing content when the shared analytics cache
becomes available; they must not be recomputed from a truncated history and
presented as all-time facts.
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
[presentation](../vivobody/Screens/Today/TodayUpNextPresentation.swift).
