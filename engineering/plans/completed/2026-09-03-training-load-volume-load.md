# Training Load measures volume load

- Status: completed
- Started: 2026-09-03
- Decision: [Training Load measures volume load; the muscle map measures hard sets](../../decisions/2026-09-03-training-load-measures-volume-load.md)
- Product guidance: [Workout app principles](../../../workout-app-principles.md)

## Goal and non-goals

Make the Training Load instrument respond to the weight on the bar. Today it
counts RIR-discounted hard sets, so adding 5 lb a week at fixed sets × reps
draws a flat line and a deload at 60% reads as a normal week. After this
change the headline, trend, seven-day strip, and verdict are computed from
weekly **volume load** (Σ effective load × reps, canonical pounds) whenever the
user's history carries comparable load, and hard sets remain visible as a
driver. Users with no comparable load (bodyweight, bands, never-entered weight)
keep the current hard-set instrument unchanged.

Non-goals:

- no change to `SetStimulus`, `MuscleVolume`, `MuscleDevelopment`, the 3D body,
  landmarks, or `MuscleCalibrationTests`; those surfaces keep hard sets;
- no per-lift relative-intensity factor, decaying e1RM reference, warm-up
  demotion, or RIR discount on volume load;
- no change to the 0.8…1.3 recent band, the 28-day / 3-active-week baseline
  gate, or the rolling-window geometry;
- no persistence change and no widget snapshot shape change;
- no new tunable parameters.

## Relevant source, specs, and decisions

- `vivobody/Models/Insights/TrainingLoad.swift`: report, windows, trend, strip.
- `vivobody/Models/Insights/AnalyticsAccumulator.swift`: per-session replay
  values (`totalSetEquivalent`, `heavySets`, `moderateSets`).
- `vivobody/Models/Insights/AnalyticsSnapshot.swift`:
  `AnalyticsExerciseSnapshot.comparableTonnageSummary` and
  `effectiveLoad(loggedWeight:)`; bodyweight is already threaded per session.
- `vivobody/Models/Domain/WorkoutSession.swift`: `ComparableTonnageSummary`,
  `ComparableTonnageAvailability`, and `merging`, the same fold History uses.
- `vivobody/Models/Domain/ExerciseClassification.swift`:
  `supportsComparableTonnage(for:loadMode:)` decides which sets carry load.
- Consumers: `Screens/Insights/TrainingLoadSection.swift`,
  `Screens/Today/TodayReadinessSection.swift`,
  `Screens/Today/TrainingLoadDetailsSheet.swift`,
  `Components/Displays/ReadinessCard.swift` and its gallery,
  `Models/Insights/Readiness.swift`, `Models/Insights/UpNext.swift`,
  `App/WidgetSnapshotWriter.swift`.
- Specs: `specs/insights-visual-instruments.md` (Training load row),
  `specs/exercise-data-contract.md` (tonnage eligibility and availability),
  `specs/hard-set-currency.md` and `specs/muscle-attention-simplification.md`
  (why load left the shared set currency).
- Tests: `vivobodyTests/TrainingLoadTests.swift`,
  `vivobodyTests/SessionInsightsTests.swift` (tonnage availability cases).

## Design

### Measure

```
session volume load = fold(exercise.comparableTonnageSummary, merging)
```

per completed session, over exercises where
`modality.supportsComparableTonnage(for: trackingMode, loadMode:)` is true:
dynamic-strength reps with a comparable load mode, and power reps with external
load. Isometric holds, non-comparable modes, and bodyweight-dependent modes
with unknown session bodyweight contribute nothing and mark the session
`partial` or `unavailable`, exactly as History's week numeral already does.
Power work therefore counts toward Training Load (it is systemic stress) while
still earning no hard sets (it is not hypertrophy volume). Within one exercise,
effective load is uniformly available or uniformly missing, so the existing
exercise-level summary is the right granularity.

### Which measure drives the instrument

`TrainingLoadReport.measure` is `.volumeLoad` when the current window plus the
four baseline windows contain any known volume load; otherwise `.hardSets`.
This is one stable choice per generated report, not a different measure for
each plotted week. Selection is reevaluated as the trailing 35-day span moves:
a bodyweight-only lifter stays on hard sets, an external-load lifter stays on
volume load while recent comparable work exists, and someone who never enters
weight (external mode, weight 0, `complete` availability, zero subtotal) stays
on hard sets. `currentLoad`, `usualLoad`, `ratio`, `points`, and `recentDays`
are all in the chosen measure. The verdict, band, gauge geometry, baseline
gate, and `provisionalRatio` logic do not change.

### Report additions

- `measure: TrainingLoadMeasure` (`.volumeLoad` | `.hardSets`).
- `loadAvailability: ComparableTonnageAvailability` for the current window so
  the UI can say "some sets have no comparable load" when `.partial`.
- `drivers.volumeLoad: LoadDriver` in canonical pounds, always populated.
  `drivers.hardSets` keeps the RIR-discounted set count. Sessions counts every
  workout carrying either Training Load currency, including external-load
  power. Heavy and moderate drivers are unchanged.
- The explicit initializer defaults `measure` to `.hardSets` and
  `loadAvailability` to `.complete` so existing fixtures, galleries, and the
  details-sheet preview compile and still describe set counts.

### Presentation

Stored values stay canonical pounds; every label converts through
`WeightFormatter` at the view boundary. In `.volumeLoad` the headline reads
"Volume load · 7 days" with the user's unit, the chart y-axis and accessibility
summary use the same unit, and Hard sets appears as a driver row. In
`.hardSets` every label is exactly what ships today. Accessibility identifiers
on harness-critical controls do not change.

## Invariants and risks

- The muscle map and Training Load now intentionally use different measures.
  `SetStimulus.swift` and `TrainingLoad.swift` headers must say so; the
  "every surface agrees by construction" sentence is scoped to the muscle
  surfaces.
- History's week numeral and Training Load's weekly volume load use the same
  fold over the same eligibility rule, so the two never disagree about one
  session's volume.
- Partial coverage can bias the ratio: a lifter whose comparable work is a
  subset of their sets reads low in a week they skip that subset. The
  `partial` note is the honesty mechanism for the first release; a coverage
  fraction is a possible follow-up, not part of this plan.
- A hard-set-only period longer than the trailing selection span can switch the
  report to hard sets. The first comparable-load session back selects volume
  load again and rebuilds its three active baseline weeks instead of comparing
  against stale weighted history.
- Volume load is more volatile week to week than set counts. The 0.8…1.3 band
  stays as is; record observed behaviour on seeded history in progress notes
  and decide separately whether to widen.
- `Readiness`, `UpNext`, and the widget snapshot read only `verdict` and
  `hasEnoughHistory`; the VivoKit payload shape is unchanged, so no snapshot
  version bump. Confirm with the snapshot contract tests.
- Uncommitted user work already touches `TrainingLoad.swift`,
  `AnalyticsAccumulator.swift`, `TrainingLoadSection.swift`,
  `TrainingLoadTests.swift`, `specs/insights-visual-instruments.md`, and
  `worklog.md` (moderate-sets driver and the single-scroll Insights layout).
  Build on top of it and do not revert it. Commit that work first so this
  change lands as its own reviewable diff.
- Rollback: the change is model plus view labels. Forcing `measure` to
  `.hardSets` in the accumulator restores today's numbers everywhere in one
  line; no data is written.

## Milestones

- [x] **Session volume load in the replay.** `AnalyticsSessionReplay` gains a
  `volumeLoad: ComparableTonnageSummary` folded from each exercise's
  `comparableTonnageSummary`. Tests: external dynamic sets sum
  load × reps; power with external load counts; isometric and non-comparable
  contribute nothing; unknown bodyweight on a bodyweight-dependent exercise
  marks the session `partial`/`unavailable`; a session with no comparable
  exercises is `.zero`.
- [x] **Measure selection and report.** `Measurement` and `Window` carry both
  hard sets and volume load; the accumulator picks `measure` by the rule
  above; report exposes `measure`, `loadAvailability`, `drivers.volumeLoad`.
  Tests: same sets with +5 lb per week yields ratio > 1 and a rising trend;
  a 60% deload with the same sets reads `.low`; bodyweight-only history
  reports `.hardSets` and matches today's numbers exactly; weight-never-
  entered history reports `.hardSets`; mixed history reports `.partial`; all
  existing `TrainingLoadTests` pass with default fixtures (constant 100 lb ×
  8 reps means volume load and hard sets move together, so ratios are
  unchanged).
- [x] **Insights and Today presentation.** `TrainingLoadSection`,
  `TrainingLoadDetailsSheet`, `ReadinessCard`, `TodayReadinessSection`, and
  the galleries read `measure` and format through `WeightFormatter`. Add the
  Volume load driver row and the partial-coverage note. Update the
  accessibility summary strings. Verify both measures render in the galleries.
- [x] **Docs.** Update `TrainingLoad.swift` and `SetStimulus.swift` headers,
  the Training load row in `specs/insights-visual-instruments.md`, and the
  `hard-set-currency.md` "Rejected alternatives" note so it says tonnage was
  rejected for the muscle currency and later adopted for Training Load with a
  link to the decision record. Mark the decision record accepted.
- [x] **Verification and closure.** Run the commands below, inspect
  screenshots and accessibility trees for Insights and Today with seeded
  history in both measures, review the diff against
  `engineering/code-review.md`, record results here, and move this plan to
  `completed/`.

## Verification

```bash
/usr/bin/python3 Scripts/check_architecture.py
/usr/bin/python3 Scripts/check_naming.py
swiftformat --dryrun vivobody/ vivobodyWidgets/ VivoKit/Sources/
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' \
  -parallel-testing-enabled NO test \
  -only-testing:vivobodyTests/TrainingLoadTests \
  -only-testing:vivobodyTests/SessionInsightsTests \
  -only-testing:vivobodyTests/ReadinessTests \
  -only-testing:vivobodyTests/UpNextTests
Scripts/check.sh
SCENARIO=insights-showcase Scripts/verify.sh
SCENARIO=insights-accessibility Scripts/verify.sh
TAB=today Scripts/verify.sh
```

Also run the VivoKit snapshot contract suite named in
`engineering/verification.md` to confirm the widget payload shape is
untouched.

Manual checks the harness cannot observe: whether the unit-suffixed headline
stays legible at Accessibility Large, and whether the week-to-week swing of
volume load on real (not seeded) history feels informative rather than noisy.

## Progress and discoveries

- 2026-09-03: Load was in the shared set currency from 2026-07-11
  (`e55f0b0`, relative e1RM factor) until 2026-08 (`9c8fff7`), removed to
  simplify the muscle map. Training Load inherited the removal through the
  shared-currency invariant without its own decision.
- A relative-to-own-max load factor cannot show progressive overload: the
  reference rises with each PR, so the ratio saturates at 1.0. Only an
  absolute-unit measure compared against the user's own recent median (which
  is already Training Load's structure) moves the chart when weight goes up.
- `ComparableTonnageSummary`, its `merging` fold, and
  `AnalyticsExerciseSnapshot.comparableTonnageSummary` already exist and are
  tested in `SessionInsightsTests`; no new tonnage math is required.
- `Readiness.compute` and `UpNext.compute` read only `verdict` and
  `hasEnoughHistory`; `WidgetSnapshotWriter` passes the report through to
  them. No VivoKit change.
- The hard-set UI scenario initially replayed the prior weighted fixture when
  reset history had the same count and newest completion date. DEBUG reset and
  launch seeding now invalidate `SessionAnalytics`, rejecting any pre-seed
  report without changing the production constant-time request key.

## Result and evidence

Completed 2026-09-03.

- The replay now folds each exercise's existing comparable-tonnage summary,
  and one report-wide measure drives the headline, verdict, trend, daily strip,
  and baseline. Hard sets remain the fallback and a visible driver. Sessions
  counts every workout carrying either currency, including external-load power,
  and the long-gap measure transition is documented and tested.
- Focused `TrainingLoadTests`, `SessionInsightsTests`, `ReadinessTests`, and
  `UpNextTests` passed: 78 tests across four suites. VivoKit's five snapshot
  contract tests passed with no payload change.
- `Scripts/check.sh` passed, including architecture, naming, formatting,
  complexity, source-size, documentation, catalog, snapshot, and build gates.
- `insights-showcase`, `insights-accessibility`, and the new
  `insights-hard-sets` semantic scenarios passed. Inspected artifacts confirm
  the 2 × 2 volume-load driver hierarchy, the unchanged hard-set fallback, and
  readable unit-bearing values at Accessibility Large. Today screenshots for
  both measures were also inspected.
- Independent diff review found no remaining actionable issues. The seeded
  60% deload reads below range as intended. Week-to-week volatility on real
  personal history remains a post-implementation product observation.
