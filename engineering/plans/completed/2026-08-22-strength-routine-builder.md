# Strength Routine Builder

- Status: completed
- Started: 2026-08-22
- Spec: [Strength Routine Builder](../../../specs/strength-routine-builder.md)

## Outcome and non-goals

The clean, on-device strength-only routine builder is implemented but
temporarily hidden from the public Library surface. A DEBUG route retains the
complete flow for verification. It combines 2–4 exact weekdays, a
30/45/60-minute density bucket, external equipment, goal, and optional
preferences into an understandable multi-day draft. The user reviews typed
reasons and gaps, can lock/swap/regenerate, and saves all days atomically as
existing workout templates.

It does not add a persistent routine model, prescribe weight, claim optimality,
or implement fatigue, recovery, progression, deload, mobility, conditioning,
power, or active-workout coaching.

## Relevant boundaries

- [Architecture](../../../ARCHITECTURE.md) keeps presentation in `Screens/`,
  pure selection policy in `Models/Domain/`, and SwiftData writes app-owned.
- [Exercise Data Contract](../../../specs/exercise-data-contract.md) owns
  catalog semantics and defines defaults as UI seeds rather than prescriptions.
- `WorkoutTemplate.swift` and `TemplateDraft.swift` own the existing
  template/child materialization path; V1 must reuse those entities without a
  schema change.
- `ExerciseHistorySummary.swift` may supply familiarity as a tie-breaker and
  the established workout-start prefill; history never becomes a hard
  eligibility gate.
- `ProGate.canCreateTemplate` and the Library create path own free-template
  capacity and the existing unlock presentation.
- `ModelContext.saveOrRollback()` owns transactional failure recovery.
- [Workout app principles](../../../workout-app-principles.md) forbid a wizard
  and any interruption during an active workout.

## Invariants, risks, and recovery

- Generation is pure, deterministic, on device, and independent of catalog
  fetch order. Internal scores and policy precision never appear in UI.
- External equipment, modality, includes, and avoids are hard constraints;
  bodyweight is always available. Emphasis, favorites, and familiarity are
  only soft ordering signals.
- Every visible reason and gap is typed output from the same domain policy that
  selected and audited the plan.
- Catalog defaults and 1RM data never prescribe generated weight. Saved
  external load starts neutral; compatible history may prefill only when the
  existing template-start flow runs.
- The planning sheet and review are value drafts. Cancel, generation failure,
  and entitlement failure leave the store unchanged.
- The entire generated batch must fit template capacity at save. A free-tier
  overflow uses the existing unlock context and inserts nothing.
- Saving inserts every generated template and child, calls
  `saveOrRollback()` once, and publishes widgets/Spotlight only after success.
  A thrown save rolls back the complete batch, keeps review open, and surfaces
  the standard error.
- No builder entry or gate appears inside a live workout and no generated
  action reaches `WorkoutSessionController`.
- Risks are policy overclaiming, an impossible sparse-equipment plan, unstable
  regeneration, a crowded planning sheet, Dynamic Type truncation, stale
  catalog identities at save, and accidental partial persistence. Each has a
  corresponding typed failure path, focused test, or rendered evidence item.
- Rollback is code removal plus deletion of unsaved transient drafts; there is
  no store migration or new persistent type to reverse. Already saved output
  remains ordinary user-owned templates and must never be bulk-deleted by a
  rollback.

## Milestones

- [x] Record the product, policy, UI, accessibility, entitlement, and atomic
  persistence contracts in the active spec and index.
- [x] Implement pure constraints, topology, slot policy, deterministic ranking,
  typed reasons/gaps, locks, swaps, and unlocked regeneration with focused tests.
- [x] Implement a value-draft planning and review flow using existing kits and
  a restrained instrument hierarchy; retain it behind a DEBUG route while its
  public Library entry is hidden.
- [x] Implement capacity preflight and atomic multi-template materialization,
  including save rollback and post-success publication tests.
- [x] Add deterministic UI fixtures and semantic scenarios for success,
  insufficient catalog matches, and free-tier capacity.
- [x] Inspect dark, light, and accessibility-size screenshots/trees; address
  hierarchy, truncation, semantic state, and target-size issues.
- [x] Run targeted suites, `Scripts/check.sh`, final review, record deviations
  and evidence, then move this plan to completed.

## Test matrix

| Area | Required cases |
|---|---|
| Eligibility | reviewed dynamic/isometric strength accepted; hidden bundled items and power/conditioning/mobility/custom items rejected; external equipment hard filter; bodyweight always eligible |
| Inputs | 2–4 exact weekdays; optional external equipment; 30/45/60 budgets; Strength/Muscle/Balanced policy |
| Selection | required movement coverage; muscle-region coverage; same-day family exclusion; weekly redundancy; emphasis; include/avoid conflicts; stable ties |
| History | familiarity is a tie-break only; no-history output remains valid; input/catalog/history order does not change output |
| Draft actions | lock stability; slot-compatible swap; deterministic unlocked regeneration; no-alternative state; gaps recomputed after every edit |
| Explanations | reasons agree with selected facts; gaps name exact missing/conflicting scope; no numeric quality or optimality claim |
| Persistence | exact one-day schedules; names/order; catalog snapshots; entire batch saved once; forced failure leaves zero new templates |
| Entitlement | requested-batch overflow; save-time count drift; existing template-limit unlock; no partial inserts |
| Session boundary | no live-workout entry, mutation, or premium interruption |

## Verification

Use the smallest targeted suites introduced for the pure builder and atomic
save contract, then the canonical guardrails:

```bash
/usr/bin/python3 Scripts/check_architecture.py
/usr/bin/python3 Scripts/check_naming.py
swiftformat --dryrun vivobody/ vivobodyWidgets/ VivoKit/Sources/
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO test \
  -only-testing:vivobodyTests/StrengthRoutineBuilderTests \
  -only-testing:vivobodyTests/StrengthRoutineSaveTests \
  -only-testing:vivobodyTests/ProStatusTests
Scripts/check.sh
SCENARIO=strength-routine-builder Scripts/verify.sh
SCENARIO=strength-routine-builder-hidden Scripts/verify.sh
SCENARIO=strength-routine-builder-insufficient-catalog Scripts/verify.sh
SCENARIO=strength-routine-builder-template-cap Scripts/verify.sh
SCENARIO=strength-routine-builder-review Scripts/verify.sh
```

Capture and inspect the populated review state in standard dark and light
appearance and dark Accessibility Extra Large. Inspect the semantic tree for
headings, selected weekdays/goal/duration/equipment/day, complete exercise
labels, lock state, blockers, unique identifiers, and reachable Save.

Manual checks not fully established by the simulator harness: VoiceOver
reading order on a physical device, sheet detent/keyboard behavior,
lock/swap haptic restraint, and StoreKit recovery after unlocking from a batch
capacity failure.

## Completion criteria

- The requested happy path and every failure path in the spec are implemented
  without a schema change or active-session side effect.
- Focused logic and transaction suites pass, including forced rollback and
  entitlement drift.
- The four scenarios pass and their screenshots, trees, traces, and saved
  state are inspected rather than only generated.
- The first viewport passes the five-second hierarchy check in dark, light,
  and accessibility size, with 44pt controls and no color-only state.
- `Scripts/check.sh` passes with no unexpected warning and the final diff has
  no unresolved finding under `engineering/code-review.md`.
- Any policy or UI deviation is recorded here before this plan moves to
  `completed/`; physical-device gaps remain explicit.

## Progress and discoveries

- The current catalog already supplies family, equipment, movement,
  laterality, modality, training-role, and categorical muscle facts. The
  missing advanced fatigue/recovery/progression layer is intentionally outside
  V1.
- Existing templates persist one exact weekday, uniform set/rep targets, and
  catalog snapshots, so a generated weekly plan can be a batch of ordinary
  templates with no parent entity.
- Exact V1 targets are Strength 3 × 5 compound / 2 × 10 isolation, Muscle
  3 × 8 / 3 × 12, and Balanced 3 × 6 / 2 × 10. Timed strength uses the same
  set-count rule with a 30-second target; no range or load is presented.
- The existing free gate is expressed for one new template. Batch generation
  requires an explicit whole-batch capacity helper and save-time recheck rather
  than repeated single-item checks.
- Session-duration truth is limited: without exercise-specific rest and setup
  data, 30/45/60 are stable slot-density buckets rather than duration
  predictions.
- The 2026 ACSM position stand supports a bounded 2–3-set starting structure
  and goal-sensitive volume, but does not justify inferred starting weights or
  a claim that complex periodization is required.
- Independent review found and drove fixes for cross-region four-day emphasis,
  same-day sparse-catalog duplication, misleading swaps on hard inclusions,
  incomplete row semantics, missing atomic persistence tests, duration-
  truncated emphasis, and missing 30-minute trunk coverage.
- Every duration now places emphasis only after weekly movement and body-region
  coverage remains intact; four-day emphasis stays in its upper or lower
  region. If no distinct same-day exercise exists, the slot stays empty with a
  blocking gap; duplicate user locks are also rejected instead of silently
  repeating work.

## Result and evidence

Implemented without a schema change. The pure planner lives in
`Models/Domain/StrengthRoutineBuilder*.swift`; the compact sheet/review and
testable batch boundary live in `Screens/Library/StrengthRoutineBuilder*.swift`
and `StrengthRoutineTemplateBatch.swift`.

- Targeted Swift Testing: **37 tests in 3 suites passed**
  (`StrengthRoutineBuilderTests`, `StrengthRoutineSaveTests`, and
  `ProStatusTests`). This includes every topology and duration, deterministic
  ordering, hard constraints, emphasis at every duration, explicit major-body-
  region coverage, sparse-catalog blockers, exact rep and duration persistence,
  stale-catalog rejection, batch capacity, and a forced read-only-store
  rollback proving no partial batch persists.
- Semantic scenarios passed: `strength-routine-builder` proves Library entry,
  review, atomic save, and relaunch persistence;
  `strength-routine-builder-insufficient-catalog` proves truthful blockers and
  disabled save; `strength-routine-builder-template-cap` proves paywall and no
  partial insert; `strength-routine-builder-review` proves ready-state row,
  lock/swap, day, and save semantics.
- Inspected evidence is under `.verify/scenarios/strength-routine-builder*`.
  The review has settled dark and light captures plus dark Accessibility Extra
  Large top and scrolled captures. The sparse-catalog settled capture keeps the
  week status, unique blockers, truthful day counts, and disabled save readable.
- `Scripts/check.sh`, architecture, naming, source-size, complexity,
  SwiftFormat dry-run, and `git diff --check` pass. The final diff was reviewed
  against `engineering/code-review.md`; the independent findings above were
  resolved and retested.
- The review scenario uses the DEBUG-only direct-open launch argument to avoid
  coupling visual evidence to toolbar gesture timing. The ordinary Library
  entry remains covered by the end-to-end save and insufficient-catalog flows.
  Remaining manual checks are the physical-device VoiceOver/haptic/StoreKit
  items listed above.
