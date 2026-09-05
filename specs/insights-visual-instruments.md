# Insights visual instruments

- Status: Implemented
- Product surface: Insights tab
- Scope: visual analytics, navigation, accessibility, and deterministic verification

## User job

Insights answers four questions about completed training history:

1. **Shape** — Where does my training go?
2. **Load** — How does my current workload compare with my recent range?
3. **Rhythm** — How regularly am I training?
4. **Balance** — Which opposing movements or muscle groups are receiving more work?

The screen is an instrument panel, not a report. A user should be able to
name the current read from the dominant visual before reading supporting
labels.

## Navigation contract

- The four instruments share one vertical scroll in the fixed order Shape,
  Load, Rhythm, then Balance. No mode control separates them.
- Each section owns one primary decision and one dominant visual.
- Shape may link to **Exercise mix** and **Rep mix** details. Those are
  drill-outs, not permanent chapters in the main scroll.
- Movement Coverage follows the Shape previews; Set-series Stamina follows Load;
  Direct vs. Indirect follows Balance. Full rosters and definitions stay in drill-outs.
- Balance shows a focused set of comparisons first and links to the full
  comparison board when more qualified pairs exist.
- Empty and loading states continue to replace the instrument panel as a whole.

## Information hierarchy

Every populated section follows the same order:

1. **Glance** — one large verdict or identity plus the dominant visual.
2. **Compare** — labels, axes, or beams that explain the relationship encoded
   by position, length, area, or intensity.
3. **Explain** — at most one short legend line when the visual convention is
   not self-evident.
4. **Drill out** — secondary distributions or full rosters behind an explicit
   navigation target.

Visible paragraphs are not part of a populated instrument. Prose belongs in
empty-state guidance or accessibility descriptions. Important verdicts use
title or metric type; labels may use compact type but must remain readable at
the supported Dynamic Type sizes.

## Visual mappings

| Instrument | Data | Visual channel | Scope |
|---|---|---|---|
| Training shape | Muscle-region share | Petal reach and area around a fixed six-region axis | All time |
| Exercise mix | Working-set share by exercise and exercise type | Horizontal fill length | Last 4 weeks |
| Rep mix | Low, moderate, and high-rep sets | Stacked bar height by week and fill category | Last 12 weeks |
| Training load | Rolling seven-day volume load when comparable load exists, otherwise estimated hard sets, versus personal range | Line position, range band, endpoint | Up to last 12 weeks; current read is 7 days |
| Training rhythm | Completed sets by day and week | Calendar-cell intensity and weekly area | Last 6 months |
| Movement coverage | Fractional hard-set share by anatomical plane | Three intersecting plane arcs with explicit percentages | All time |
| Set-series stamina | Last/first reps in equal-weight runs | Retention rails; per-exercise rep traces and matched history | All time |
| Direct vs. indirect | Muscle hard sets split by primary/secondary role | Stacked beams on a common scale | All time |
| Training balance | Pair-relative effective sets | Mirrored beam length around a fixed center | Last 4 weeks |

Orange identifies the primary series, dominant category, or active control.
Secondary series step down through neutral `Ink` tokens. Color never carries a
meaning that is absent from position, length, label, or accessibility value.

## Mode contracts

### Shape

- Lead with the six-petal training signature and a large plain-language
  identity such as “Legs-led.”
- Keep only two supporting reads beside the emblem: evenness and region
  coverage. Cadence belongs to Rhythm.
- The equal-share reference may use one micro legend. Do not show an
  explanatory paragraph.
- Exercise mix and Rep mix appear as compact visual navigation cards. Their
  full charts live on dedicated detail screens.
- Rep mix uses readable fixed-width weekly stacks and enough trailing plot
  inset to keep the newest date label fully visible beside the Y axis.
- Each preview uses two independently rounded segments: orange for the top
  category and neutral gray for the combined remainder. A single compact
  legend labels both roles without requiring color interpretation.
- The Exercise mix drill-out preserves every named exercise and exercise-type
  share as its own rounded segment with visible separation. Its adjacent
  legends repeat the exact category names and percentages, so color is never
  the only mapping.

### Load

- Lead with the current volume-load value and the user's weight unit when
  comparable load exists; otherwise retain the estimated-hard-set value.
  Pair either measure with the same large range verdict.
- The rolling line and personal range band are the primary comparison.
- The current seven-day window and four preceding baseline windows select one
  measure for the whole report. Selection is reevaluated as that trailing
  35-day span moves; after a long hard-set-only period, resumed comparable
  loading rebuilds its volume-load range from recent weeks.
- Hard sets remain visible as a driver when volume load leads. Sessions count
  every workout represented by either Training Load currency, including
  external-load power; supporting drivers do not repeat the hero value.
- When only part of the current window has comparable load, show one short
  coverage note rather than implying the volume-load total is complete.
- Baseline-building state uses the same dormant chart geometry and factual
  collection progress.

### Rhythm

- Lead with weekly cadence and the six-month training calendar.
- Weekly-set direction is a compact companion visual inside the same card,
  separated from the daily heatmap by a quiet hairline.
- Days trained and average RIR are supporting reads. Rep-range distribution
  does not compete with the calendar here; it remains a Shape drill-out.

### Balance

- Lead with the highest-priority qualified balance comparisons as mirrored
  tug-of-war beams.
- Do not permanently show threshold explanations, comparison counts, or all
  qualified rows above the fold.
- Distribution-only pairs remain explicitly descriptive and never imply that
  50/50 is a target.
- Qualification progress is shown only while no meaningful comparison exists,
  or as a compact building indicator after the focused rows.

## Locked, empty, and failure states

- Free users see the full ordered real-data preview visually obscured and
  removed from accessibility; the unlock action is the only exposed data-area
  target.
- The persistent purchase control remains available without replacing the
  real instrument geometry.
- No archived workouts shows the existing whole-screen first-use state.
- Archived history without qualifying signals shows factual next-action
  guidance. Dormant per-instrument visuals never fabricate data.
- Insights never presents an interruption during an active workout.

## Accessibility and verification

- Shape, Load, Rhythm, and Balance expose stable, unique section headings in
  their visual and accessibility order.
- Every chart or custom drawing exposes the decision, comparison, values,
  units, and timeframe without relying on color.
- Repeated child nodes must not inherit a section identifier. Harness IDs live
  on one semantic owner.
- Default dark, light, accessibility Dynamic Type, Reduce Motion, and
  Differentiate Without Color are required review states.
- The deterministic populated fixture must render all four modes quickly and
  must not depend on an intermediate History-screen launch.

## Training dimensions

### Movement Coverage

- Use all completed archived sessions up to now, with no lower date cutoff; exclude
  future dates. Price exercises with SetStimulus, then split credit equally across
  unique snapshotted planes. The classified denominator counts each exercise once.
- Show the same three-plane glyph as Exercise Detail with arc length encoding share.
  Whole percentages use largest-remainder rounding and sum to 100 when data exists.
- Unclassified hard sets remain visible and outside the denominator. Family actions
  are looked up from immutable generated metadata through the captured family ID;
  unknown family credit is disclosed in the drill-out.
- The drill-out lists unrecorded planes and joint actions with owning catalog families.
  Action coverage is at joint-action level, unioning ordered phases; produced,
  resisted, and yielding actions remain distinct. Conditions remain part of the
  authored family contract, rather than separate coverage categories. Stabilizers
  and forbidden actions never count as performed actions.
- Only actions owned by strength families that can earn hard-set credit enter the
  gap roster. Missing coverage is a diary observation, never a recommendation or
  a claim that unclassified work did not train that action.

### Direct vs. Indirect

- Use the same all-time completed history and SetStimulus pricing. Primary snapshot
  credit 1.0 enters direct work; secondary 0.5 enters indirect work; stabilizers
  earn none. These are credited hard sets, not literal exercise-set counts.
- The headline names the muscle with most indirect hard-set credit. Bars compare
  direct and indirect work on one common scale; text labels carry both roles.
- The roster covers every muscle, including a collapsed no-recorded-work list. Each
  muscle detail shows its indirect exercise sources and up to three current bundled
  exercises where it is authored primary, preferring family variety. Examples link
  to Exercise Detail and do not prescribe exercise selection.

### Set-Series Stamina

- Use only archived dynamic-strength, rep-tracked exercises. Within one exercise
  occurrence, consecutive completed positive-rep sets at exactly identical finite
  nonnegative logged weight form a run. At least three sets are required. Invalid,
  incomplete, or changed-weight sets break runs; sessions/exercises never merge.
- Retention is last reps / first reps, without clamping values above 100%. Pattern
  reads are arithmetic means of eligible run ratios across all completed history,
  excluding future dates. The cards, drill-outs, and Exercise Detail share this scope.
- A higher logged RIR than any earlier rated set marks that set held back. Preserve
  the whole run for its rep trace but exclude it from the pattern average and trend.
  Missing RIR stays unknown and is disclosed; it is never inferred as fatigue.
- Matched trends compare the same history identity, load profile, logged weight,
  relevant bodyweight, run length, first reps, first RIR, and full/partial effort
  logging status. Non-comparable resistance and unknown required bodyweight cannot
  establish a matched load. Pattern change compares the first and latest recorded
  date for each key across all history. Multiple runs at either endpoint contribute
  their mean retention; a key needs two distinct dates. Average the differences
  across matched keys, excluding unmatched prescriptions. Label the change
  “first → latest matched”; there is no rolling comparison window.
- Exercise Detail receives indexed reports from the same core analytics generation.
  It stays outside active-workout exercise picking. It shows the latest eligible
  run and its full matched history; higher RIR sets have diamond marks. Dates
  identify the year when history spans years. This derived section uses the existing Pro cover.
  No qualifying run hides the exercise section; Insights retains its building state.
- Retention is a descriptive rep signal; rest duration, fatigue, and physiological
  recovery are not measured. No timer or logging behavior changes.

## Non-goals

- No change to existing analytics formulas, persistence, entitlement, or purchase flow.
- No new user score or prescriptive training recommendation.
- No change to existing per-exercise strength progress, widgets, or active-workout UI.

## Implementation

- The populated tab presents Shape, Load, Rhythm, and Balance as one ordered
  vertical instrument scroll with clear section separators and no mode control.
- Exercise mix, Rep mix, and the full balance roster are visual drill-outs.
- `--ui-test-insights-showcase` supplies a focused deterministic history for
  normal, locked, light, and accessibility verification.
- Bright brand orange remains the data-mark color. `Tint.primaryText` provides
  the contrast-safe light-appearance endpoint for orange labels and readouts.
