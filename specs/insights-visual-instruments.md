# Insights visual instruments

- Status: Implemented
- Product surface: Insights tab
- Scope: view hierarchy, navigation, accessibility, and visual-verification fixtures

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
| Training load | Rolling seven-day estimated hard sets versus personal range | Line position, range band, endpoint | Up to last 12 weeks; current read is 7 days |
| Training rhythm | Completed sets by day and week | Calendar-cell intensity and weekly area | Last 6 months |
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

- Lead with the current estimated-hard-set value and a large range verdict.
- The rolling line and personal range band are the primary comparison.
- The hero already carries estimated hard sets; centered Sessions, 1–5 reps,
  and 6–12 reps remain one compact driver strip without repeating the hero
  value.
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

## Non-goals

- No analytics formula, threshold, persistence, entitlement, or purchase-flow
  change.
- No new user score or prescriptive training recommendation.
- No change to per-exercise progress, widgets, or active-workout UI.

## Implementation

- The populated tab presents Shape, Load, Rhythm, and Balance as one ordered
  vertical instrument scroll with clear section separators and no mode control.
- Exercise mix, Rep mix, and the full balance roster are visual drill-outs.
- `--ui-test-insights-showcase` supplies a focused deterministic history for
  normal, locked, light, and accessibility verification.
- Bright brand orange remains the data-mark color. `Tint.primaryText` provides
  the contrast-safe light-appearance endpoint for orange labels and readouts.
