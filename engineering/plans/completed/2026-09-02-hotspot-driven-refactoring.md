# Hotspot-driven refactoring

- Status: completed
- Started: 2026-09-02
- Completed: 2026-09-03
- Baseline revision: `a706418`
- Governing guidance: [Architecture](../../../ARCHITECTURE.md),
  [workout app principles](../../../workout-app-principles.md),
  [engineering quality](../../quality.md),
  [verification](../../verification.md), and
  [code review](../../code-review.md)
- Prior completed slice:
  [active exercise card completion refactor](../completed/2026-09-02-active-exercise-card-refactor.md)

## Goal and non-goals

Turn the size-and-change hotspot report into a sequence of small,
behavior-preserving ownership changes. Success is not more files by itself: a
ratchet is retired only when a cohesive responsibility has a named owner, its
behavior is covered independently, and the old file no longer coordinates that
responsibility.

Completion criteria:

- Remove the ten current entries from
  [`source_size_baseline.json`](../../../Scripts/source_size_baseline.json)
  without adding a replacement allowance; every production Swift file is at or
  below the ordinary 600-line limit.
- `ExerciseDetailScreen` owns queries, navigation, and presentation state, but
  no longer computes archive reports; focused sections consume immutable input.
- `ActiveExerciseCardSections.swift` no longer combines set navigation, every
  logging modality, and RIR controls in one change surface. The extracted
  instrument views receive explicit values, bindings, and actions and do not
  acquire persistence or analytics access.
- Remove `DebugSeed.seedIfRequested` from the complexity baseline while
  preserving every launch argument used by checked-in Baguette scenarios.
- Keep the canonical build, focused logic tests, relevant semantic scenarios,
  and inspected accessibility evidence green after every slice.

This plan does not redesign a screen, change copy or gestures, alter exercise
or receipt semantics, change the SwiftData schema, edit generated catalog JSON,
introduce an app-wide view-model framework, merge app and widget renderers, or
make Code Maat part of `Scripts/check.sh`. The completed active-set transaction
and shared `ExerciseCatalogBrowser` extraction are fixed starting points, not
work to redo.

## Current evidence and priority

The 2026-09-01 Code Maat snapshot at `19c7bfd` covered committed production
Swift since 2026-07-01 and excluded changesets over ten production files. At
that point ten of eleven oversized allowances appeared in the top twelve
size-and-change ranking. Since then `ActiveExerciseCard.swift` has been reduced
from 621 to 346 lines and its allowance removed; the Library/picker browsing
contract has also been extracted.

Current source checks at `a706418` pass with ten oversized allowances and
nineteen complexity allowances. The remaining portfolio is:

| Slice | Current signal | Responsibility to separate | Order |
|---|---:|---|---:|
| Exercise detail | `ExerciseDetailSections` 998 lines / 26 audit revisions; `ExerciseDetailScreen` 463 / 28 | archive-derived read model, focused visual sections, and root navigation/mutations | 1 |
| Active instrument | `BareScrubber` 920 / 17; `ActiveExerciseCardSections` 599 / 22 | deterministic scrub motion, visual mechanism, set header, reps/duration instruments, and effort controls | 2 |
| Catalog editing | `CustomExerciseEditorSheet` 1,050 / 20; `ExerciseCatalog` 659 / 27 | draft validation/normalization, atomic catalog mutations, taxonomy, reconciliation, and form sections | 3 |
| Analytics cache | `SessionAnalytics` 791 / 16 | observable coordinator, report payloads, worker, and widget projection | 4 |
| Today | `TodayScreenSections` 650 / 23 | pure Up Next presentation plus body, readiness, and journal sections | 5 |
| Settings | `SettingsScreen` 763 / 17 | root-owned integrations and sheets versus binding-driven preference/about sections | 5 |
| Me | `MeScreen` 744 / 15 | immutable summary formatting versus focused dashboard sections and navigation | 5 |
| Debug fixtures | `DebugSeed` 705 / 23; `seedIfRequested` complexity 12 | launch-argument router versus independent deterministic fixture families | 6 |
| Training signature | `SignatureSection` 808; size-only, outside the audit top twelve | section composition, motion host, and stateless Canvas renderer | 6 |

Code Maat history is sticky, so an immediate fall in revision counts is not an
acceptance criterion. It chooses investigation order; source ownership, focused
tests, ratchet removal, and future change locality prove the refactor.

## Invariants and risks

- Preserve SwiftData model declarations, defaults, delete/reset behavior, and
  the recoverable store policy. Model-type movement is out of scope; moving
  pure taxonomy declarations does not authorize a schema change.
- Preserve workout interaction ordering, scrub cancellation, flywheel feel,
  haptic/audio routing, 44-point targets, `completeSetButton`, pager gesture
  coexistence, RIR eligibility, and persistence on every interaction.
- Preserve analytics request fingerprints, generation checks, cancellation,
  last-complete-result visibility, core/deep coherence, and the rule that no
  SwiftData model crosses into `AnalyticsWorker`.
- Preserve catalog identity and unique name/alias rules across create, bundled
  edit, custom edit, duplicate, delete, reset, launch reconciliation, and
  Spotlight follow-up. Index only after a successful save.
- Preserve each screen's first-viewport hierarchy, Dynamic Type behavior,
  VoiceOver semantics, selected traits, and stable scenario identifiers. Leaf
  views may receive bindings/actions but must not reach through new environment
  singletons.
- Do not lower a baseline merely because code moved into another large file.
  New files need accurate purpose headers; genuinely reusable controls keep a
  nearby DEBUG gallery.

## Milestones

- [x] **0. Freeze and score the current behavior.** Re-run the strict Code Maat
  report against the starting revision, record current physical line counts and
  complexity, and save the report under `.verify/code-maat/`. For each slice,
  list the exact user branches and focused tests before production edits. Capture
  settled dark, light, and Accessibility Dynamic Type evidence only for the
  screens touched by that slice. If inspection finds one cohesive file with no
  useful ownership boundary, record that exception here before changing its
  ratchet.

- [x] **1. Extract the Exercise Detail vertical slice.** Build an immutable,
  pure `ExerciseDetailReadModel` from the existing `ExerciseHistorySummary`,
  `ExerciseProgress`, effort, cadence, and volume contracts. It owns the
  zero/one/many-session branches, recent rows, effective-load explanation,
  record selection, one-rep-max seed, and accessibility-ready metric text;
  `ExerciseDetailScreen` chooses presentation state but does not rescan archived
  sessions. Move chart, performance, recent-history, and bottom-action UI into
  focused feature views with explicit inputs. Keep the root as the only query,
  sheet-order, and navigation owner. Remove the `ExerciseDetailSections.swift`
  allowance and ensure neither the root nor a replacement section becomes a
  hotspot-sized catch-all before proceeding.

- [x] **2. Isolate the active logging instrument.** First extract pure scrub
  calculations—axis claim, clamping, detent crossings, rubber-band distance,
  flick eligibility, and coast schedule—behind deterministic tests. Keep Task,
  haptic, animation, scene-phase, and accessibility effects in `BareScrubber`,
  then move its graduation rail and first-use hint into focused visual files.
  Next separate the active card's identity/set controls, reps instrument,
  duration instrument, and RIR/action area. Pass a small typed instrument input
  plus bindings/actions rather than the whole session environment. Preserve the
  existing completion coordinator and controller transaction unchanged. Remove
  the `BareScrubber` allowance and delete or reduce
  `ActiveExerciseCardSections.swift` to composition only.

- [x] **3. Separate catalog semantics from the editor.** Move draft validation,
  first-invalid-field selection, and dependent normalization rules into a pure
  `CatalogDraftValidation` result. Add a focused catalog mutation boundary that
  applies create/edit/duplicate/reset/delete, saves through
  `saveOrRollback()`, returns a typed result, and performs Spotlight work only
  after commit. Split classification vocabulary from the SwiftData model and
  launch reconciliation from model accessors; keep generated `CatalogData` as
  source truth. Break the editor into basics, classification, logging-default,
  and search sections driven by the draft and validation result. Remove both
  source-size allowances without changing identity, load, muscle, or alias
  contracts.

- [x] **4. Split analytics construction from cache orchestration.** Move the
  Sendable report payloads, widget snapshot projection, and
  `AnalyticsWorker` into focused files while keeping `SessionAnalytics` as the
  sole observable MainActor coordinator. Characterize same-key core-to-deep
  promotion, supersession, explicit invalidation, cancellation at both tiers,
  synchronous history fallback, widget joining, and failure retention before
  rewiring. Remove the allowance only after the concurrency suite proves that
  no stale generation can publish and core/deep reports still share one
  accumulator.

- [x] **5. Thin the three shell screens independently.** Land one reversible
  change per screen. Today gets a pure `TodayUpNextPresentation` for scheme,
  duration, muscle summary, date, and PR-proximity copy, plus focused body,
  readiness, Up Next, and journal views. Settings keeps `@AppStorage`, HealthKit,
  catalog reset, mail, URL, and sheet orchestration at the root while
  binding-driven sections render controls. Me builds one immutable presentation
  summary from `ArchiveOverview`, standing records, and the bounded body-weight
  query, then passes it to journey, milestone, records, weight, and recap views.
  Do not introduce a generic card/row abstraction unless a second real consumer
  appears. Remove each allowance in its own change.

- [x] **6. Close support and renderer debt.** Turn `UITestSupport` into a small
  argument router and move active-workout, archived-history, template, and
  Insights fixtures into independent idempotent seeders with deterministic
  relative dates and fixed values where screenshots depend on them. Remove its
  size and complexity allowances. For Training Signature, keep data
  geometry/tuning in VivoKit but
  split app-only section composition, animation scheduling, and stateless Canvas
  drawing passes; do not make the widget import app code or force both targets
  into a lifecycle-inappropriate shared renderer. Prove still and animated
  output before removing the final size allowance.

- [x] **7. Consolidate evidence and close the program.** Re-run the strict
  history report as an advisory comparison, inspect new temporal-coupling pairs,
  and confirm no replacement catch-all was created. Run every final gate, audit
  the complete diff series against `engineering/code-review.md`, update only
  architecture/spec text whose ownership descriptions changed, record results
  and deviations here, and move this plan to `completed/`.

Every milestone is a stop/go boundary and should normally be its own pull
request. Keep the old path callable until the replacement has focused tests,
then remove it in that same slice. Do not stack a later milestone on an
unexplained parity failure.

## Verification

Focused suites by slice:

```bash
# Exercise Detail
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO test \
  -only-testing:vivobodyTests/ExerciseHistorySummaryTests \
  -only-testing:vivobodyTests/ExerciseProgressInsightsTests \
  -only-testing:vivobodyTests/ExerciseEffortTests \
  -only-testing:vivobodyTests/ProgressionCadenceTests

# Catalog editor and synchronization
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO test \
  -only-testing:vivobodyTests/CatalogSyncTests \
  -only-testing:vivobodyTests/CatalogDuplicateTests \
  -only-testing:vivobodyTests/ExerciseCatalogBrowserTests \
  -only-testing:vivobodyTests/MuscleMappingTests

# Analytics, Today, Me, and signature
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO test \
  -only-testing:vivobodyTests/SessionAnalyticsConcurrencyTests \
  -only-testing:vivobodyTests/UpNextTests \
  -only-testing:vivobodyTests/MeJourneyTests \
  -only-testing:vivobodyTests/TrainingSignatureTests
```

Add focused tests for the new Exercise Detail read model, scrub-motion policy,
catalog validation/mutation result, settings bindings, and debug argument
routing before removing their old implementations.

Relevant Baguette evidence, selected per changed slice rather than run as one
full UI suite:

- Exercise Detail: `exercise-detail-hero`,
  `exercise-detail-single-session-point`, `exercise-detail-dormant-chart`,
  `exercise-detail-weekly-volume`, and `exercise-comparison`.
- Active instrument: `active-resistance`, `active-no-load`,
  `active-assistance`, `active-superset-completion`, and
  `active-completion-restoration`.
- Catalog: `custom-exercise-type`, `custom-exercise-assistance`,
  `library-training-role-filters`, and `exercise-picker-training-role-filters`.
- Shell/renderer: `today-actions`, `today-journal-accessibility`,
  `insights-showcase`, `insights-empty`, and `insights-accessibility`; add one
  Settings semantic flow if preference wiring changes.

For every milestone, finish with:

```bash
/usr/bin/python3 Scripts/check_architecture.py
/usr/bin/python3 Scripts/check_naming.py
/usr/bin/python3 Scripts/check_source_sizes.py
/usr/bin/python3 Scripts/check_complexity.py
swiftformat --dryrun vivobody/ vivobodyWidgets/ VivoKit/Sources/
Scripts/check.sh
```

After a measured shrink, run the corresponding `--update` command and inspect
the JSON diff so only genuinely removed debt is locked in. Automated evidence
cannot prove haptic/audio timing, physical scrub feel, one-handed reach, real
VoiceOver order, HealthKit authorization, or mail composition; record those as
physical-device checks for the affected milestone and never substitute
Simulator.app or XCTest UI tests.

## Rollback and recovery

No milestone changes a persisted schema or cross-target payload, so rollback is
source-only. Keep slices in independent commits, preserve the public call shape
until its replacement passes, and revert only the failing slice. Retain useful
characterization tests even if an extraction is abandoned. If a split requires
a second state owner, duplicate save, environment singleton, target dependency
reversal, or user-visible workaround, stop and revise this plan instead of
shipping the split.

## Progress and discoveries

- Milestone 0 froze committed revision `a706418` under
  `.verify/code-maat/milestone-0-a706418/`: the strict history report covered
  149 commits / 297 entities / 1,520 changes, the source-size and complexity
  ratchets passed with 10 and 19 allowances respectively, and the four focused
  Exercise Detail suites passed 50 tests. `ExerciseDetailSections.swift`
  remained the top current size/change hotspot. Its settled dark, light, and
  Accessibility XXXL baseline captures were inspected. Exact pre-edit branch,
  test, semantic-scenario, LOC, and ratchet inventories for milestones 2–6 are
  recorded beside the report. An earlier aggregate UI attempt was rejected
  because invalid Library-segment preconditions caused real timeouts while
  stale result files still said `passed`.
- The committed structural baseline at `a706418` passes: 252 production Swift
  files, 10 existing source-size allowances, and 19 existing complexity
  allowances.
- The original top operational hotspot, `ActiveExerciseCard.swift`, and the
  Library/picker duplication seam have already been addressed. Their fresh
  boundaries should be protected while this plan works outward.
- `SignatureSection.swift` is the one current allowance not corroborated by the
  audit's top-twelve ranking. It remains last because its renderer is cohesive;
  the milestone must produce a real composition/motion/rendering boundary, not
  a cosmetic file split.
- Milestone 1 replaced the 998-line Exercise Detail catch-all with an immutable
  `ExerciseDetailReadModel`, one coherent worker-produced cache generation, and
  focused leaf views. The old allowance was removed and the existing
  `SessionAnalytics` ratchet lowered from 791 to 769 lines. Eight focused suites
  passed 105 tests; all 11 relevant Baguette flows passed; dark, light, and
  Accessibility XXXL screenshots were inspected and their normalized semantic
  trees exactly matched baseline. Independent review caught and closed the
  multi-session unknown-bodyweight Best-set fallback before the final
  `Scripts/check.sh` pass. Physical-device audio, haptic, and scrub feel were
  unaffected by this slice and remain outside automated evidence.
- Milestone 2 moved scrub axis, detent, wall, rubber-band, and coast decisions
  into a 253-line pure policy with 13 deterministic tests; `BareScrubber` now
  owns only host gesture/effect orchestration and is 586 lines. The active card
  now assembles one immutable instrument input for focused identity, reps,
  duration, and effort/action leaves; its former sections file is 123 lines of
  composition. The obsolete scrubber allowance was removed. A disposable
  headless simulator recovered a wedged test service, after which 60 focused
  tests, eight active-workout Baguette scenarios, baseline-equivalent dark,
  light, and Accessibility XXXL semantics, independent review, and
  `Scripts/check.sh` all passed. Physical scrub/flywheel feel, tick and wall
  audio-haptics, one-handed reach, and real VoiceOver order remain device
  checks.
- Milestone 3 moved the catalog taxonomy, bundled launch reconciliation, pure
  draft validation/normalization, and all create/edit/duplicate/delete/reset
  writes behind focused owners. `ExerciseCatalog.swift` fell from 659 to 400
  lines and the editor root from 1,050 to 387; both allowances were removed.
  The focused suites passed 56 tests, including every frozen save-failure path,
  post-commit Spotlight/tombstone ordering, bundled-only reconciliation,
  ab-wheel/band normalization, and the complete draft-to-model bridge. All four
  catalog Baguette flows passed, and inspected dark, light, and Accessibility
  XXXL screenshots retained byte-equivalent normalized semantics and frames.
  Baguette groups the focused navigation toolbar rather than exposing its Save
  child, so invalid-Save focus behavior remains covered by pure tests and visual
  inspection instead of a semantic tap. Independent review findings were closed
  before `Scripts/check.sh` passed. The current catalog expansion also required
  correcting its stale five-versus-six untargeted-muscle test expectation.
- Milestone 4 left `SessionAnalytics` as the sole observable MainActor cache
  coordinator and moved immutable report payloads, pure widget projection, and
  the Sendable worker boundary into focused files. The coordinator fell from
  769 to 447 lines and its allowance was removed. Nineteen deterministic
  concurrency tests now cover same-key promotion, stale core/deep rejection,
  invalidation, asymmetric failure retry, synchronous history fallback, widget
  joining, and one coherent retained accumulator. Review replaced scheduler-hop
  assertions with captured task barriers and restored cancellation checkpoints
  between every core and deep report. `Scripts/check.sh` passed, all three
  Insights scenarios passed, and their final accessibility trees matched the
  frozen baseline byte-for-byte.
- Milestone 5 reduced the Today, Settings, and Me roots to 309, 313, and 190
  lines respectively. Today now derives one immutable Up Next presentation and
  delegates its body, readiness, plan, and journal leaves; Settings retains all
  integration and sheet ownership while binding-driven sections render the
  preferences; Me builds one immutable dashboard snapshot for focused journey,
  Insights, milestone, record, body-weight, and recap leaves. Thirty-seven new
  presentation/policy tests joined the existing shell suites for 82 passing
  focused tests. `today-up-next`, `settings-preferences`, `me-showcase`,
  `today-actions`, and `today-journal-accessibility` passed headlessly, and
  settled dark, light, and Accessibility XXXL captures were inspected. The
  journal run also reproduced and explained a pre-existing late-evening
  `HistorySeeder` boundary race (a randomized day-14 completion can cross
  midnight); rerunning across midnight restored its promised count, and
  Milestone 6 owns the deterministic fixture fix. All three old shell
  allowances were removed, independent reviews were closed, and
  `Scripts/check.sh` passed. HealthKit authorization, mail composition, haptic
  feel, and real VoiceOver order remain physical-device checks.
- Milestone 6 reduced `DebugSeed.swift` from 705 to 194 lines and split ordered
  execution into focused active, archive, Insights, template, reset, and
  coordinator owners. Fixed durations and shared injected clocks removed the
  late-evening history race and prevented future same-day Me weights. The
  Training Shape section fell from 808 to 97 lines; app-only motion scheduling,
  exact accessibility prose, top-level Canvas pass order, and stateless petal
  material now have named owners while VivoKit tuning and the widget boundary
  remain unchanged. Forty-one focused tests passed across the routing/fixture
  and Signature suites. Eight representative Baguette flows passed, including
  Accessibility XXXL; normal-motion frames advanced while two settled Reduce
  Motion frames one second apart were byte-identical. An initial widget run was
  covered by the system notification prompt after the mailbox had successfully
  started a session; dismissing it headlessly allowed the unchanged scenario to
  pass. Independent review found no remaining parity blocker,
  `source_size_baseline.json` now has zero allowances, the stale DebugSeed
  complexity entry is gone, and `Scripts/check.sh` passed.
- Milestone 7 re-ran the strict Code Maat pipeline under
  `.verify/code-maat/milestone-7-current-worktree/`. Because `HEAD` remains the
  frozen uncommitted baseline `a706418`, its history input has the same SHA-256
  and therefore the same 149 commits, 297 entities, 1,520 changes, and coupling
  rows; no historical locality improvement is claimable until the work is
  committed and subsequent changes accumulate. The current-worktree scan is
  conclusive for structure: 310 production Swift files, none above 600 lines,
  no source-size allowances, and no new persistence/navigation/state catch-all.
  The largest file is the pre-existing 589-line `StrengthRoutineBuilder`; the
  largest new owner is the model-free 518-line `MePresentation`.

## Final result

- All ten frozen source-size allowances and the stale
  `DebugSeed.seedIfRequested` complexity allowance are retired. Architecture,
  naming, formatting, documentation, generated catalog, persistence baseline,
  VivoKit snapshot contracts, and the canonical app build pass through
  `Scripts/check.sh`.
- The final aggregate contract run passed 305 tests across 25 affected suites.
  Every milestone-specific Baguette flow recorded above passed headlessly, with
  inspected dark/light/Accessibility evidence and explicit Reduce Motion still
  evidence where applicable. Independent data-flow and UI reviews found no
  actionable correctness, ownership, accessibility, or motion issue.
- The first aggregate runner stalled in CoreSimulator before any test began; an
  identical run on a disposable headless simulator passed and the simulator was
  removed. No XCTest UI run or Simulator.app was used. The slices remain an
  uncommitted working-tree series rather than separate milestone pull requests.
- Physical-device verification remains for scrub inertia and wall feel,
  audio/haptic timing, one-handed reach, real VoiceOver order, HealthKit and
  mail handoffs, catalog invalid-Save focus, and Training Signature pacing/GPU
  rendering. No persistence schema or widget payload changed.
