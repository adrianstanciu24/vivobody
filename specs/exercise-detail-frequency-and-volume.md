# Exercise Detail — Frequency Footer & Weekly Volume Contribution

Status: **Implemented.** Design mockup:
[assets/exercise-detail-frequency-volume.png](assets/exercise-detail-frequency-volume.png)
(source: [assets/exercise-detail-frequency-volume.html](assets/exercise-detail-frequency-volume.html)).

Two additions to `ExerciseDetailScreen` drawn from data the app already
collects at log time. Both answer questions the screen currently cannot:

1. **How often do I actually do this exercise?** — a frequency footer
   inside the Best-set hero card (free).
2. **What is this exercise doing for my muscles right now?** — a weekly
   hard-set contribution card (Pro).

Neither introduces new logging, new persistence, or new user input. Both
are read-only projections of the archived session history the screen
already queries.

## Product fit

From `workout-app-principles.md`: surfaces should respect effort and turn
the user's own diary into meaning without interruption. From
`free-with-pro-iap.md`: raw numeric stats (totals, last performed) stay
free; derived "what it all means" analytics are Pro. The two features map
cleanly onto that split — the frequency footer is raw stats, the volume
contribution card is derived analytics built on the same hard-set
landmark model that is the Insights tab's core value.

## Feature 1 — Frequency footer (free)

### Placement and form

A footer inside the existing Best-set hero card (`bestHeroCard`),
separated from the record by the same hairline (`Surface.edge`, 0.5 pt)
the Recent-sessions card uses between rows. Three columns:

| Column | Label | Value |
|---|---|---|
| Sessions | `SESSIONS` | All-time count of archived sessions containing ≥1 analytics-eligible set of this exercise |
| Per week | `PER WEEK` | Typical weekly frequency (see computation) |
| Last | `LAST` | `RelativeDate.short(lastInstance.sessionDate)` |

Labels use `Typography.metricMicro` at `Ink.quaternary`; values use
`Typography.metricInline` monospaced at `Ink.primary`. No new card
chrome — the footer rides the existing bright hero card, restoring the
useful core of the Last/Times half-cards removed in 05c9263 without
re-adding their bulk.

### Data sources (all already cached)

- Session count: `ExerciseHistorySummary.sessionCount` via
  `sessionAnalytics?.exerciseHistorySummaries[historyKey]` — replaces the
  screen's current O(archive) `sessionCount` reduce.
- Last performed: `lastInstance.sessionDate` (existing).
- Session dates: `progress.points.map(\.date)` (existing series).

### Per-week computation

- Trailing 8 complete weeks, sessions-per-week = count in window ÷ 8.
- If the first logged session is more recent than 8 weeks ago, divide by
  elapsed weeks instead (minimum denominator 1) so a new exercise is not
  diluted by weeks that predate it.
- One decimal, trailing `.0` dropped (`2.1×`, `3×`).
- Fewer than 2 sessions, or a span under 7 days: show `—`.

### Edge cases

- Never logged: the whole footer hides; the hero card keeps its current
  em-dash empty state.
- Exactly one session: `1` / `—` / the relative date.
- Frequency is a descriptive statistic only. It never produces a verdict,
  color, or "you should" copy — the Effort section owns progression
  advice.

## Feature 2 — Weekly volume contribution card (Pro)

### Placement and form

A new section titled **This week**, placed after `performanceRows`
(effective load / 1RM) and before the chart section — inside the screen's
"current standing" cluster, ahead of the trend instruments.

One row per volume-bearing muscle (primaries then secondaries, each group
sorted by contribution descending, capped at 4 rows):

```
Chest · primary                              +4.5
▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░  12.5
```

- Muscle name in `Typography.sectionHeading` at `Ink.secondary`, with a
  `· primary` / `· secondary` role qualifier at `Ink.quaternary`.
- Contribution value: `Typography.metricInline` monospaced in
  `Tint.primary` — the one colored numeral, matching the screen's
  PR-accent vocabulary.
- Slim bar (4 pt, `Radius.pill`): the muscle's **full weekly effective
  sets** on a 0–20 scale, track `Surface.cardTint`, fill `Ink.primary` at
  zone-appropriate opacity, with this exercise's contribution rendered as
  the trailing `Tint.primary` segment. Hairline ticks mark the landmark
  band edges (8 / 18).
- Bar value: the muscle's weekly total in `Typography.metricMicro` at
  `Ink.tertiary`.
- Card caption: "Hard sets from this exercise in the last 7 days. Bars
  show each muscle's full week against its 8–18 productive band."

### Computation

New pure value type `ExerciseVolumeContribution` in
`vivobody/Models/Insights/`, computed per screen appear:

1. Filter `completedSessions` to `now − 7d … now` (window constant shared
   with `MuscleVolume`'s default).
2. For each session exercise matching `matchesCatalogItem(item)`, price
   it with the existing `SetStimulus.credit(for:)` and accumulate
   `[Muscle: Double]`.
3. Join each involved muscle against the already-cached
   `sessionAnalytics.volume` (`[MuscleVolumeStat]`) for its weekly total,
   zone, and landmark.

Because `SetStimulus` pricing is a pure per-set function with no
cross-session state, this needs no chronological replay and no
accumulator changes. Scoping to one exercise over 7 days keeps the pass
small enough to run synchronously on MainActor; if profiling ever
disagrees, it moves into `CoreReports` beside `volume`.

All `SetStimulus` semantics are inherited unchanged: only completed
dynamic-strength reps and completed isometric holds earn credit; RIR
beyond 2 discounts; unlogged RIR stays neutral; stabilizers earn no
volume credit and therefore never appear as rows.

### Gating

Pro, using the existing `LockedRhythmCover` frozen-blur pattern (real
card beneath a blur, whole area opens the screen's local paywall sheet).
The card joins `showsUnlockControl` so the floating unlock pill appears
whenever it is frozen. Rationale: the landmark band and per-muscle weekly
totals are the Insights volume model — the "what it means" layer the IAP
spec reserves for Pro. Raw per-session set counts remain visible for free
in Recent sessions.

### Edge cases

- No contribution in the window (including zero sessions this week):
  the section hides entirely, matching the screen's self-gating sections.
  The Insights neglect list — not this card — owns "you haven't trained
  this" nudges.
- Modality earns no volume (power): hidden.
- Custom exercise with no authored anatomy: hidden.
- Rows are the muscles this exercise actually credited in the window
  (all > 0 by construction). A muscle the current involvement map no
  longer lists — e.g. edited away after the work was logged — keeps its
  share and renders without a role qualifier, sorted last.
- Unknown bodyweight does not affect this card: hard-set credit is
  load-independent.

## Accessibility

- Frequency footer: combined into the hero card's existing
  `.accessibilityElement(children: .combine)`; the label becomes
  "Best set, 225 lb × 5, Aug 12. 24 sessions, 2.1 per week, last 3 days
  ago."
- Volume card: one accessibility element per muscle row —
  "Chest, primary. 4.5 hard sets from this exercise this week. 12.5 total
  this week, inside the 8 to 18 productive band." Bars are
  `.accessibilityHidden(true)` like the rhythm staircase.
- Locked state mirrors `LockedRhythmCover`: content hidden from
  VoiceOver, single button "This week, locked — unlocks with Vivobody
  Pro."

## Testing

Swift Testing, deterministic clocks (inject `now` everywhere):

- `ExerciseVolumeContributionTests`: role weighting (primary 1.0 /
  secondary 0.5 / stabilizer none), RIR discount and unlogged-neutral,
  window boundary (a session at exactly `now − 7d` counts, one second
  earlier does not), future-dated sessions excluded, modality gating,
  multi-session accumulation, custom exercise without anatomy → empty.
- Frequency: per-week rate for <8-week and ≥8-week histories, single
  session → `—`, span <7 days → `—`, formatting (`2.1×` vs `3×`).
- `Scripts/verify.sh` semantic scenarios: footer visible with history /
  hidden without; volume card visible (Pro), frozen (free), hidden
  (no work this week).

## Files

| File | Change |
|---|---|
| `specs/exercise-detail-frequency-and-volume.md` | This doc |
| `vivobody/Models/Insights/ExerciseVolumeContribution.swift` | New — contribution computation over live models |
| `vivobody/Models/Insights/ExerciseFrequency.swift` | New — pure per-week rate |
| `vivobody/Screens/Library/ExerciseBestHeroCard.swift` | New — hero card moved out of the ratcheted sections file, gaining the frequency footer |
| `vivobody/Screens/Library/ExerciseWeeklyVolumeSection.swift` | New — `This week` section, rows, band bars, DEBUG preview |
| `vivobody/Screens/Library/LockedProCover.swift` | New — shared frozen-blur Pro cover, hoisted from the rhythm section |
| `vivobody/Screens/Library/ProgressionRhythmSection.swift` | Adopts the shared cover |
| `vivobody/Models/Insights/ExerciseDetailReadModel*.swift` | Immutable archive-derived frequency, volume, record, and chart inputs |
| `vivobody/Screens/Library/ExerciseDetailScreen.swift` | Section wiring; header comment updated (stale Last/Times reference removed) |
| `vivobody/App/DebugSeedWeeklyVolume.swift` | New — `--ui-test-weekly-volume` deterministic fixture |
| `vivobody/App/DebugSeed.swift`, `DebugSeedCoordinator.swift`, `DebugArchivedHistorySeeder.swift`, `AppRoot.swift` | Pure argument routing plus the focused deterministic weekly-volume dispatch |
| `vivobodyTests/ExerciseVolumeContributionTests.swift` | New |
| `vivobodyTests/ExerciseFrequencyTests.swift` | New |
| `Scripts/verify_scenarios/exercise-detail-weekly-volume*.json` | Pro and locked semantic scenarios |

## Out of scope

- Per-exercise completion time and workout-order surfacing (session-level
  facts; they belong to History/session detail).
- Weekly movement-pattern allocation (an Insights-level story already
  told by the Training Signature; the Movement card states this
  exercise's own pattern).
- Per-muscle trend charts, volume history per exercise, or "only source
  of this muscle" callouts beyond the band context.
- Changes to `SetStimulus` pricing, `VolumeLandmark` values, or the
  `MuscleVolume` aggregation — this feature consumes them read-only.
