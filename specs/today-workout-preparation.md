# Today workout preparation

Status: Implemented product design.

Today helps the user start or resume a workout. The body visualization leads,
followed by Up next, Consistency, and Last workout. Every section renders on a
fresh install; sections without data show quiet placeholders in the same card
layout. One pinned action reads **Start Fresh Workout** and opens the exercise
picker directly when there is no workout history or saved template. Once
another start path exists, it reads **Start Workout** and opens the chooser. An
active workout replaces it with Resume Workout or Finish Workout and hides Up
next, including its placeholder.

## Up next

- Scheduled templates retain their existing Today, Tomorrow, or future-day
  label. The heading shows the workout name with its exercise count and
  duration estimate.
- When no templates are scheduled, show the most recently used nonempty saved
  template as a **Repeat option**. Never-used templates do not imply a previous
  workout. If no eligible template exists, show a static placeholder card
  headed **No plan** that points to scheduling a template in Library. The
  placeholder is not a start action; the pinned start action remains available
  for fresh workouts and template selection.
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

## Consistency and Last workout

- Both sections always render. Before the first archived workout, Consistency
  shows the two-week strip with every day untrained and **0 sessions**, and
  View detail still opens the Consistency screen.
- Last workout then reads **None yet** and keeps its Time, Volume, and Sets
  strip with dimmed dashes in place of values, followed by one caption that
  says a finished workout fills them in. VoiceOver reads the placeholder card
  as one element.

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

## Wide display

On a wide, regular-width window on iOS 27.1 or later, such as the open iPhone
Duo display held wide, Today shows two panes clear of the fold. The leading
pane holds the body model, the Training development legend, and the one pinned
start or resume action. The trailing pane scrolls Up next, Consistency, and
Last workout on its own; while a workout is active it starts at Consistency
with no divider above it. Up next and View detail still push over the whole
tab. Every other window, including the tall open pose and the outer display,
keeps the single scrolling column.

The figure keeps one size while the user works in the panes. Its height
latches to the tallest container seen at the current width, so a collapsing
title or a minimized tab bar does not re-scale the model. In the leading pane
the figure takes the height left above the measured start or resume bar and
the Training development legend, so the whole legend stays above the bar. The
resume bar adds a status line, so the figure is a little shorter while a
workout is active. The height is also capped so the turntable fits the pane
width.

## Evidence

Use the focused [Today scenario](../Scripts/verify_scenarios/today-up-next.json)
for the scheduled preview and pinned action, and
[today-actions](../Scripts/verify_scenarios/today-actions.json) for the empty
placeholders. Inspect dark, light, and large Dynamic Type states. Repeat-option, compatible-history, and active-workout
behavior also require focused evidence when those paths change. The wide panes
use [duo-today-split](../Scripts/verify_scenarios/duo-today-split.json) with
its [light](../Scripts/verify_scenarios/duo-today-split-light.json) and
[Accessibility Large](../Scripts/verify_scenarios/duo-today-split-accessibility.json)
variants on the iPhone Duo simulator, and
[TodayHeroSizingTests](../vivobodyTests/TodayHeroSizingTests.swift) pins the
figure height. Folding and unfolding with a pushed detail need a device check.

Implementation: [Today](../vivobody/Screens/Today/TodayScreen.swift),
[selection](../vivobody/Screens/Today/TodayScreenDerived.swift),
[presentation](../vivobody/Screens/Today/TodayUpNextPresentation.swift),
[wide panes](../vivobody/Screens/Today/TodaySplitContent.swift), and
[figure height](../vivobody/Screens/Today/TodayHeroSizing.swift).
