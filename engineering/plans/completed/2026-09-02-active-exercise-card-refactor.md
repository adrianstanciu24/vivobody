# Active exercise card completion refactor

- Status: completed
- Started: 2026-09-02
- Completed: 2026-09-02
- Governing guidance: [Architecture](../../../ARCHITECTURE.md),
  [workout app principles](../../../workout-app-principles.md),
  [engineering quality](../../quality.md), and
  [verification](../../verification.md)

## Goal and non-goals

Turn `ActiveExerciseCard` back into a thin workout instrument by extracting the
set-completion use case behind typed, testable boundaries. A successful set tap
must look, sound, persist, rest, celebrate, and navigate exactly as it does now;
the save-failure path becomes explicit and must not navigate after rollback.

Completion criteria:

- `ActiveExerciseCard.swift` is at most 350 lines and no longer imports or
  directly calls SwiftData persistence, `SessionAnalytics`, or
  `SessionSideEffects`.
- `handleSetToggle` only freezes and flushes scrubbing, captures the request, and
  delegates; it is below the normal SwiftLint complexity limit, so its checked-in
  complexity allowance is removed.
- The 621-line source-size allowance for `ActiveExerciseCard.swift` is removed,
  every new production file stays below the ordinary 600-line threshold, and no
  replacement hotspot is created in `ActiveWorkoutScreen` or
  `WorkoutSessionController`.

Non-goals are a visual redesign, changed scrub sensitivity or flywheel physics,
new set/PR/rest semantics, a persistence-model migration, a generic app-wide
state architecture, or changes to widget payloads, catalog data, HealthKit, and
StoreKit. Do not count a mechanical move of the current method into an extension
as completion; ownership and tests must change with the file split.

## Current evidence and target ownership

The current file contains card composition, weight-step preferences, set
editing, the delayed completion task, live PR detection and formatting, pager
selection, direct persistence fallback, and scrub cancellation. The highest-risk
span starts at
[`handleSetToggle`](../../../vivobody/Screens/ActiveWorkout/ActiveExerciseCard.swift#L280),
continues through the private PR detector, and ends at the persistence helpers.
The checked-in ratchets confirm 621 lines and cyclomatic complexity 21.

Existing boundaries already own most of the domain work:

- [`WorkoutSession.completeActiveSet`](../../../vivobody/Models/Domain/WorkoutSession.swift#L181)
  mutates the set, carries matching prescription values forward, starts rest,
  and returns the authoritative `SetCompletionOutcome`.
- [`WorkoutSessionController`](../../../vivobody/App/WorkoutSessionController.swift#L68)
  owns active-draft persistence, rollback, and `SessionSideEffects` fan-out.
- [`ExerciseHistorySummary`](../../../vivobody/Models/Insights/ExerciseHistorySummary.swift#L45)
  already supplies the archived standing performance used by live PR checks.
- [`ActiveWorkoutScreen`](../../../vivobody/Screens/ActiveWorkout/ActiveWorkoutScreen.swift#L373)
  owns visible pager selection and is therefore the final owner of animated
  navigation during an expanded workout.

Target flow:

```text
Complete tap
  -> card cancels coast, flushes the visible scrub value, and snapshots the set
  -> completion coordinator holds the existing 550 ms acknowledgement
  -> pure live-PR evaluator compares the snapshot with archived + in-session bests
  -> controller validates session/exercise/set, mutates, and saves one transaction
  -> pure route planner maps the committed SetCompletionOutcome
  -> screen applies immediate or guarded 300 ms pager movement
```

Use these focused owners:

| Concern | Owner after the refactor |
|---|---|
| Card layout, bindings, set-edit presentation, and scrub flush | `ActiveExerciseCard` and its existing focused extensions |
| Immutable tap-time performance and PR classification | New pure `LivePersonalRecord` model under `Models/Insights`; no SwiftData query or UI formatting inside it |
| PR value/unit/detail strings | Active-workout presentation helper using `WeightFormatter` and `DurationFormatter` at the UI boundary |
| Completion validation, mutation, atomic save/rollback, and side-effect fan-out | A focused `WorkoutSessionController` set-completion collaborator/extension, split so the existing controller file stays under 600 lines |
| 550 ms acknowledgement, cancellation generation, and 300 ms guarded beat | New `ActiveSetCompletionCoordinator` with an injectable sleep dependency |
| Mapping `SetCompletionOutcome` to stay/immediate/delayed target | Pure active-workout route planner; `ActiveWorkoutScreen` remains the only pager writer |

The coordinator must sequence collaborators, not absorb their logic. It must not
query SwiftData, calculate a PR, derive superset membership, format user copy, or
call `SessionSideEffects`.

## Invariants and risks

- Tap ordering is load-bearing: disable writes, invalidate any coast, flush the
  last visible detent, then capture immutable weight/reps/duration and exercise
  semantics. A late scrub detent must never change the captured set.
- Preserve the cancelable 550 ms completion moment. Disappearance, replacement,
  archive/discard/minimize, or a superseding attempt must leave no late mutation,
  PR, rest interval, or pager move and must restore the input gate.
- PR comparison must retain exact history identity, snapshotted performance
  signature, effective-load/bodyweight rules, and the first-valid-performance
  policy. An unavailable analytics cache is unknown history, not empty history,
  and must never create a false first PR.
- Completion, carried-forward pending values, rest state, and any pending PR
  payload form one controller transaction. Save through `saveOrRollback()`, emit
  update side effects only after success, surface the existing save alert on
  failure, and do not navigate on a rejected or rolled-back commit.
- Preserve every outcome: straight-set rest stays put; a superset partner moves
  after the acknowledgement beat without rest; round completion repositions
  immediately behind the rest overlay; exercise completion skips already-finished
  siblings; the final summary is immediate. A manual swipe during the 300 ms beat
  always wins.
- Do not change the open instrument hierarchy, 44pt targets,
  `completeSetButton` identifier, RIR eligibility, Dynamic Type scrolling,
  Reduce Motion handling, set-completion haptic/audio, thumb-zone placement, or
  `SwipePager` gesture coexistence. The external/widget completion path retains
  its existing no-animation behavior.

## Milestones

- [x] **1. Freeze the behavior before moving it.** Record a compact branch matrix
  for straight sets, all `SetCompletionOutcome` cases, PR/no-PR/cache-unavailable,
  tap-time scrub capture, cancellation, manual-swipe precedence, and save failure.
  Run the current focused tests and capture settled standard, light, and
  Accessibility Dynamic Type card evidence. Record any pre-existing failure;
  do not edit production code until the baseline is reproducible.

- [x] **2. Extract PR classification as a pure vertical slice.** Introduce an
  immutable candidate snapshot and a `LivePersonalRecord` result based on the
  existing `StrengthPerformance` / `StrengthRecordAdvancement` vocabulary. Add
  deterministic tests for heavier load, equal-load higher reps, loaded and
  unloaded duration, bodyweight/assistance effective load, prior in-session
  sets, unsupported modalities, invalid performances, and unavailable history.
  Replace the private detector behind the existing completion path and prove
  identical presentation before proceeding.

- [x] **3. Establish the controller transaction.** Add a typed request containing
  session ID, exercise ID, expected active-set ID, and optional already-formatted
  PR payload. Add a typed result that distinguishes committed outcome, stale or
  invalid request, missing persistence, and save failure. Validate before
  mutation; apply completion and PR payload together; persist once through the
  controller boundary; return an outcome only after success. Reuse the same
  narrow transaction helper from the widget entry where doing so preserves its
  pre-presentation page positioning. Add in-memory success/stale tests and a
  read-only-store rollback test covering completion, rest, carried-forward
  values, and PR fields.

- [x] **4. Cut persistence and analytics out of the card.** Wire the typed commit
  from `AppRoot` through `ActiveWorkoutScreen`. Resolve shared history and format
  PR copy at the screen/UI boundary, then pass the prepared payload into the
  controller request. Keep a deliberate in-memory preview/test adapter rather
  than a second production persistence path. Remove the card's `modelContext`,
  `sessionAnalytics`, local save alert, direct save/side-effect code, and void
  save-result seam from the completion path. After this milestone, a failed
  commit stays on the current set and the existing controller alert explains
  the rollback.

- [x] **5. Extract the cancelable timeline and route planner.** Move pending-set
  state, input gating, task ownership, and generation checks into
  `ActiveSetCompletionCoordinator`; production sleep uses the existing 550/300 ms
  durations while tests advance an injected sleeper without wall-clock delays.
  Move outcome-to-route branching into a pure planner returning stay, immediate,
  or guarded-delayed movement. Test cancellation at each suspension point,
  superseding requests, all outcome routes, finished-superset skipping, immediate
  final-summary routing, and manual selection changes during the delayed beat.
  Reduce `handleSetToggle` to the card-to-coordinator adapter.

- [x] **6. Remove the debt and review the whole flow.** Delete the superseded
  method, private PR enum/detector/formatter, and task state; update purpose
  headers and only the conceptual architecture text if ownership actually
  changed. Remove the two `ActiveExerciseCard.swift` ratchet entries after the
  measured targets pass. Inspect the diff against `engineering/code-review.md`,
  run all evidence below, record deviations/results here, and move the plan to
  `engineering/plans/completed/` only when every required check is green.

Each milestone is a stop/go boundary: keep the previous path callable until its
replacement has focused tests, then delete it in the same milestone. If a branch
cannot be represented without changing successful behavior or the persistence
schema, stop and revise this plan rather than broadening the refactor.

## Verification

Focused logic and transaction suites:

```bash
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO test \
  -only-testing:vivobodyTests/ActiveSetCompletionTests \
  -only-testing:vivobodyTests/LivePersonalRecordTests \
  -only-testing:vivobodyTests/SupersetChoreographyTests \
  -only-testing:vivobodyTests/SetCarryForwardTests \
  -only-testing:vivobodyTests/TemplatePrefillTests \
  -only-testing:vivobodyTests/ExerciseHistorySummaryTests
```

Structural and final gates:

```bash
/usr/bin/python3 Scripts/check_architecture.py
/usr/bin/python3 Scripts/check_naming.py
/usr/bin/python3 Scripts/check_source_sizes.py
/usr/bin/python3 Scripts/check_complexity.py
swiftformat --dryrun vivobody/ vivobodyWidgets/ VivoKit/Sources/
Scripts/check.sh
```

Semantic evidence:

- Keep `start-complete-rest` green for ordinary completion, PR presentation, and
  rest entry.
- Add `active-superset-completion` using the existing deterministic superset seed
  to prove partner hand-off without rest and round-complete rest/resume.
- Add or extend a completion-restoration scenario to complete a set, relaunch,
  and prove the completed set, next working values, rest state, and active page
  came from the saved draft.
- Re-run representative `active-resistance`, `active-no-load`, and
  `active-assistance` states, then inspect settled dark, light, and Accessibility
  Dynamic Type screenshots and trees for unchanged hierarchy, values, labels,
  reachability, and identifier uniqueness.

Baguette cannot prove haptic/audio timing, physical flywheel feel at the exact
tap boundary, one-handed reach, or real VoiceOver rotor order. Verify those on a
device and record them as manual evidence; do not substitute XCTest UI tests or
open Simulator.app.

## Rollback and recovery

This refactor changes no schema or persisted payload shape, so rollback is a
source-only revert. Keep pure helpers and tests landed before wiring changes,
cut over one responsibility at a time, and retain the previous implementation
until that slice passes. On any parity failure, restore the last working wiring
while keeping characterization tests; do not patch around a failed transaction
by adding a second save or a second navigation owner.

## Progress and discoveries

- Source inspection on 2026-09-02 confirmed the checked-in 621-line and
  complexity-21 allowances. The card's completion span currently performs two
  successful saves for a PR completion and erases the controller's Boolean save
  result before navigation.
- Superset outcome semantics and prescription carry-forward already have focused
  domain tests. The missing coverage is the asynchronous UI timeline, live PR
  adapter, controller-level completion rollback, and end-to-end superset route.
- `ActiveWorkoutScreen.swift` is already 545 lines and
  `WorkoutSessionController.swift` is 591 lines. New logic must live in focused
  collaborators rather than pushing either file over the 600-line threshold.
- Prior accepted active-workout decisions preserve the current control
  arrangement, open instrument field, scrubber character, and pager gesture
  model. This plan treats them as fixed contracts rather than redesign inputs.
- Baseline on 2026-09-02 passed 18 tests across
  `SupersetChoreographyTests`, `SetCarryForwardTests`, and
  `ExerciseHistorySummaryTests`. Settled dark, light, and Accessibility Extra
  Extra Large screenshots and trees are in
  `.verify/baseline-active-exercise-card/`; no pre-existing failure was found.
- Pure live-PR classification now freezes exact identity and performance at tap
  time, distinguishes unknown from empty history, and keeps active-workout copy
  at the UI boundary. All 8 focused tests and `start-complete-rest` pass with
  the existing celebration value, unit, and detail.
- The final focused run passed 43 tests across controller completion, live PR,
  superset choreography, set carry-forward, template prefill, and exercise
  history. This includes cancellation at both delays, supersession, manual-swipe
  precedence, the external/widget path, and read-only-store rollback.
- The read-only-store test exposed that SwiftData clears change tracking on a
  failed save while loaded models can retain their mutated values. The
  controller transaction now restores its captured set, rest, PR, normalization,
  and pager fields before returning `.saveFailed`; the corrected test is green.
- Final Baguette runs passed `start-complete-rest`,
  `active-superset-completion`, `active-completion-restoration`,
  `active-resistance`, `active-no-load`, and `active-assistance`. Post-refactor
  dark, light, and Accessibility Extra Extra Large artifacts are in
  `.verify/final-active-exercise-card/`; their accessibility trees are
  byte-for-byte identical to the baseline, and visual inspection found no
  hierarchy, clipping, reachability, or identifier regression.
- `ActiveExerciseCard.swift` is 346 lines, `ActiveWorkoutScreen.swift` is 551,
  and `WorkoutSessionController.swift` is 568. The card's source-size and
  complexity allowances are removed, `ARCH012` prevents it from reclaiming
  persistence or analytics, every focused structural gate passes, and
  `Scripts/check.sh` passes.
- Follow-up review found and closed five code issues: post-commit scrub
  cancellation, nil-set external foregrounding, archive-failure draft
  restoration, PR transaction timing, and a dead scrub-save parameter. Focused
  tests cover the controller, archive failure, coordinator cleanup, and PR
  transaction boundary; the relevant Baguette completion/restoration flows and
  the post-fix canonical `Scripts/check.sh` pass.
  Haptic/audio timing, physical flywheel feel, one-handed reach, and real
  VoiceOver rotor order remain device-only manual checks.
- Deliberate parity deviation: when an out-of-order completion makes the whole
  session complete, routing now opens the summary immediately instead of landing
  on the next already-completed exercise card. The route-planner test locks this
  more direct result.

Baseline branch matrix:

| Branch | Frozen result |
|---|---|
| Straight set with work remaining | Commit, start rest, stay on the card |
| Superset partner | Commit without rest, then guarded 300 ms hand-off |
| Superset round complete | Commit with rest and reposition immediately behind the overlay |
| Exercise complete | Skip completed siblings; delay the next card, but show final summary immediately |
| PR / no PR / unavailable history | Persist one prepared payload / no payload / never infer a first PR |
| Tap during scrub coast | Freeze writes, invalidate coast, flush, then snapshot the visible values |
| Disappear, replacement, or superseding tap | Cancel pending work and reopen the input gate without a late commit |
| Manual swipe during delayed beat | Keep the user's selection and suppress scripted movement |
| Stale request or save failure | Roll back, surface the controller error when present, and do not navigate |
