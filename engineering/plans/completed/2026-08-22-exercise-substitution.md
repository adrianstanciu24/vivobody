# Exercise substitution

- Status: completed
- Started: 2026-08-22
- Completed: 2026-08-22
- Spec/decision: [Exercise substitution](../../../specs/exercise-substitution.md)

## Goal and non-goals

Ship a compact, deterministic replacement flow inside an active workout. It
ranks compatible alternatives from existing catalog metadata, explains one
preserved and one changed relationship at a glance, and atomically replaces an
unstarted exercise without changing logged work or progression history.

Non-goals are richer catalog biomechanics, pain/injury filtering, numerical
match precision, partial replacement after completed sets, template mutation,
and any ML or remote recommendation service.

## Invariants and risks

- The active session remains independently restorable; sheet state never owns
  workout state.
- A replacement cannot delete or relabel a completed set.
- Source loads and records never cross exercise identity. Candidate values come
  only from compatible candidate history or catalog defaults.
- The transaction stays behind `WorkoutSessionController`, saves through
  `saveOrRollback()`, and fans out through `SessionSideEffects` only on success.
- The ranker stays pure and deterministic; UI copy is derived from its typed
  deltas rather than recomputed in SwiftUI.
- The active card keeps set completion as its dominant control. Replacement is
  a secondary top-bar options action with a long-press shortcut.
- New production files stay under the source-size threshold and existing
  oversized files do not grow past their ratchets.
- Rollback strategy: a failed replacement restores the original SwiftData graph,
  keeps the recommendation sheet open, and emits no success feedback.

## Milestones

- [x] Record the compact ranking, UI, and mutation contracts.
- [x] Add deterministic ranking, typed explanations, and focused unit tests.
- [x] Add the guarded controller transaction and focused persistence tests.
- [x] Add the active-card entry and replacement sheet with equipment filtering.
- [x] Add semantic verification state and inspect dark, light, and accessibility
  evidence.
- [x] Run targeted tests, `Scripts/check.sh`, final diff review, and move this
  plan to completed with evidence.

## Verification

```bash
/usr/bin/python3 Scripts/check_architecture.py
/usr/bin/python3 Scripts/check_naming.py
swiftformat --dryrun vivobody/ vivobodyWidgets/ VivoKit/Sources/
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -parallel-testing-enabled NO test \
  -only-testing:vivobodyTests/ExerciseSubstitutionTests \
  -only-testing:vivobodyTests/WorkoutExerciseReplacementTests \
  -only-testing:vivobodyTests/ExerciseHistorySummaryTests
Scripts/check.sh
SCENARIO=exercise-substitution-sheet Scripts/verify.sh
SCENARIO=replace-active-exercise Scripts/verify.sh
SCENARIO=replace-active-exercise-blocked Scripts/verify.sh
SCENARIO=active-zero-set-recovery Scripts/verify.sh
```

Manual checks not fully observable by the harness: physical long-press menu
feel, replacement haptic, sheet detent drag behavior, and VoiceOver reading
order on a physical device.

## Progress and discoveries

- The runtime catalog already carries the compact V1 inputs, so this slice does
  not require generated-catalog or SwiftData schema changes.
- The active exercise name already owns a context menu; a neutral top-bar
  options pill makes the same actions discoverable without competing with the
  exercise identity.
- Candidate history is already cached by `SessionAnalytics`; the replacement
  factory can reuse the established performance-signature lookup.
- Replacement after completed work would corrupt history if implemented as an
  identity mutation. It remains intentionally blocked in this version.

## Result and evidence

The active workout's options pill now opens a focused replacement sheet. It
shows three ranked alternatives first, filters by available equipment, derives
every visible **Keeps** and **Changes** statement from the ranker's typed facts,
and never renders a numeric equivalence claim. Recommendations remain
deterministic and on-device; no schema, catalog generation, or network service
changed.

The controller replaces only pending exercises. It preserves slot, live set
count, active page, and superset membership while creating fresh exercise/set
identities and using only candidate-compatible history or catalog defaults. A
failed save restores the original materialized SwiftData relationship graph.
Live rows remain authoritative if a cached planned count has drifted, and a
replacement factory can never create an exercise with no actionable set.

Verification completed on iOS 26.5 simulators:

- 22 focused ranker, replacement, and history-factory tests passed in 3 suites,
  including cached-count drift and a forced read-only-store save failure.
- `exercise-substitution-sheet`, `replace-active-exercise`, and
  `replace-active-exercise-blocked` semantic scenarios passed; the success
  scenario also proved the replacement survives app relaunch.
- `active-zero-set-recovery` passed at standard and Accessibility Extra Large
  sizes, proving a malformed legacy exercise is described honestly, exposes no
  inert RIR control, offers an enabled Add set action, and recovers to the
  normal completion control.
- Normal and Accessibility Extra Large screenshots and accessibility trees
  were inspected in dark appearance; normal-size light appearance was also
  inspected.
- `Scripts/check.sh` passed, including architecture, naming, documentation,
  formatting, source-size, complexity, catalog parity, VivoKit contracts, and
  the generic app/widget build.
