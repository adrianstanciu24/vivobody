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
  How muscles are trained follows Balance. Movement Coverage is a standalone card;
  other full rosters and definitions stay in drill-outs.
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
| Movement coverage | Fractional hard-set share by anatomical plane | Illustrated plane rows with share bars on a common 0–100% scale | All time |
| Set-series stamina | Last/first reps in equal-weight runs | Movement retention rails and comparable changes | All time |
| How muscles are trained | Within-muscle targeted/supporting credit shares | Two-color 24pt proportional capsules | All time |
| Training balance | Pair-relative effective sets | Two-color proportional capsule segments | All time |

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
  full charts live on dedicated detail screens. Keep the two previews grouped
  closely, with less padding and visual weight than the main instruments.
  Each preview names its leading category and percentage above a 24pt share
  bar; keep the last-four-weeks scope visible. Names and values retain their
  readable type sizes, wrap freely, and stack at accessibility text sizes.
  When recent data is absent, use a short factual label without an empty chart.
- Rep mix uses readable fixed-width weekly stacks and enough trailing plot
  inset to keep the newest date label fully visible beside the Y axis.
- Each preview uses two independently rounded segments: the leading segment
  repeats the named category's percentage, and the neutral segment is the
  combined remainder. The name, number, and filled length carry the summary;
  repeated Top/Other legends stay off the preview. Full category legends live
  in the drill-outs; accessibility labels retain both shares and their scope.
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

- Lead with recent versus lifetime weekly cadence and the six-month training calendar.
  Share a “Workouts / week” heading: orange “Last 4 weeks” uses the trailing
  28-day session count divided by four; neutral-primary “All time” uses the
  existing lifetime average, including inactive weeks (minimum seven-day span).
  Keep the values close together, aligned on their numeric baseline; the lifetime
  value is smaller (26pt versus 40pt). Stack them at accessibility text sizes.
- Weekly-set direction is a compact companion visual inside the same card,
  separated from the daily heatmap by a quiet hairline.
- Days trained and average RIR are supporting reads. Rep-range distribution
  does not compete with the calendar here; it remains a Shape drill-out.

### Balance

- Aggregate all recorded workout history through the report date, excluding
  future-dated sessions, in both the preview and full comparison list.

- Preview qualified Horizontal Push/Pull, Vertical Push/Pull, then Compound
  Push/Pull in that fixed order; other pairs live in All comparisons. The
  Horizontal Push label includes diagonal pushing work.
- Render qualified comparisons as two rounded capsule
  segments, 24pt tall, separated by a small gap, with 32pt between comparison
  rows. Orange represents the left named side and
  neutral gray the right; segment widths reflect their shares of the pair total.
  Names share one line above the bar in headline type; the complementary
  whole percentages sit beneath them in compact metric type, anchored to the
  bar's leading and trailing ends. At accessibility sizes each side stacks as
  its own name-and-number line. Omit set totals, center markers, and empty tracks.
- Do not permanently show threshold explanations, comparison counts, or all
  qualified rows above the fold.
- Distribution-only pairs remain explicitly descriptive and never imply that
  50/50 is a target.
- Qualification progress is shown only while no meaningful comparison exists,
  or as a compact building indicator after the focused rows.

## Access, empty, and failure states

All reports are interactive and included in the [upfront app price](paid-app.md).

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
- Show three rows, each pairing a body-and-plane illustration with its anatomical
  name, plain-language direction, whole percentage, and horizontal share bar.
  All bars use the same 0–100% scale. Whole percentages use largest-remainder
  rounding and sum to 100 when data exists; these are shares, not completion targets.
- Keep the all-time hard-set scope visible. Unclassified hard sets remain visible
  and outside the denominator.
- The card has no navigation action, chevron, or detail screen. Unrecorded plane,
  joint-action, and family rosters are not presented.
- VoiceOver exposes each plane's direction, percentage, currency, and scope.
  Labels and values stack at accessibility text sizes.

### How muscles are trained

- Use the same all-time completed history and SetStimulus pricing. Primary snapshot
  credit 1.0 enters direct work; secondary 0.5 and stabilizer 0.1 enter indirect work. These are credited hard sets, not literal exercise-set counts.
- Preview the muscles with most supporting credit. Label primary work “targeted”
  and secondary/stabilizing work “supporting”; show complementary whole percentages
  instead of weighted set totals. Pure-role rows say “Supporting work only” or
  “Targeted work only.”
- Each muscle has a full-width 24pt two-color capsule bar: orange targeted and gray
  supporting, separated by 3pt when both exist, with no unused track. Preview rows
  have 32pt spacing. Zero-work rows show no percentage or bar.
- Keep “All time” visible. Source exercises show their share of supporting work.
- The roster includes only muscles with recorded work, without footer disclosures. Each
  muscle detail shows its indirect exercise sources and up to three current bundled
  exercises where it is authored primary, preferring family variety. Examples link
  to Exercise Detail and do not prescribe exercise selection.

### Set-Series Stamina

- The preview explains “Reps retained compared with your first set.” below
  “Reps held · all time” and above the pattern rows, applying to the whole card.
- Pattern details describe rounded retention changes across comparable series
  in percentage points, using “No change across comparable series” for zero.
  Their sample count reads “Based on N set series · all time”.
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
  in percentage points across comparable series; there is no rolling comparison window.
- Insights stamina detail contains movement patterns only: retention, comparable
  change, and series counts. No “What counts” disclosure, exercise roster, or
  exercise-level graph appears there.
- Exercise Detail receives indexed reports from the same core analytics generation.
  It stays outside active-workout exercise picking. Its overall average and history
  include every non-held-back series across all time, even when loads or set counts
  differ or resistance is unquantified. Each series receives equal weight. Individual
  runs, including held-back traces with diamond marks, are available on demand.
  Dates identify the year when history spans years. No qualifying run hides the
  exercise section; held-back-only history shows an empty average with series access.
- Retention is a descriptive rep signal; rest duration, fatigue, and physiological
  recovery are not measured. No timer or logging behavior changes.

## Non-goals

- No change to existing analytics formulas or persistence.
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
