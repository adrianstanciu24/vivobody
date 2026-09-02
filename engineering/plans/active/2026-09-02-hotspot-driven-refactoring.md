# Hotspot-driven refactoring

- Status: active
- Started: 2026-09-02
- Baseline revision: `147de6c`
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

Current source checks at `147de6c` pass with ten oversized allowances and
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

- [ ] **0. Freeze and score the current behavior.** Re-run the strict Code Maat
  report against the starting revision, record current physical line counts and
  complexity, and save the report under `.verify/code-maat/`. For each slice,
  list the exact user branches and focused tests before production edits. Capture
  settled dark, light, and Accessibility Dynamic Type evidence only for the
  screens touched by that slice. If inspection finds one cohesive file with no
  useful ownership boundary, record that exception here before changing its
  ratchet.

- [ ] **1. Extract the Exercise Detail vertical slice.** Build an immutable,
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

- [ ] **2. Isolate the active logging instrument.** First extract pure scrub
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

- [ ] **3. Separate catalog semantics from the editor.** Move draft validation,
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

- [ ] **4. Split analytics construction from cache orchestration.** Move the
  Sendable report payloads, widget snapshot projection, and
  `AnalyticsWorker` into focused files while keeping `SessionAnalytics` as the
  sole observable MainActor coordinator. Characterize same-key core-to-deep
  promotion, supersession, explicit invalidation, cancellation at both tiers,
  synchronous history fallback, widget joining, and failure retention before
  rewiring. Remove the allowance only after the concurrency suite proves that
  no stale generation can publish and core/deep reports still share one
  accumulator.

- [ ] **5. Thin the three shell screens independently.** Land one reversible
  change per screen. Today gets a pure `TodayUpNextPresentation` for scheme,
  duration, muscle summary, date, and PR-proximity copy, plus focused body,
  readiness, Up Next, and journal views. Settings keeps `@AppStorage`, HealthKit,
  catalog reset, mail, URL, and sheet orchestration at the root while
  binding-driven sections render controls. Me builds one immutable presentation
  summary from `ArchiveOverview`, standing records, and the bounded body-weight
  query, then passes it to journey, milestone, records, weight, and recap views.
  Do not introduce a generic card/row abstraction unless a second real consumer
  appears. Remove each allowance in its own change.

- [ ] **6. Close support and renderer debt.** Turn `UITestSupport` into a small
  argument router and move active-workout, archived-history, template, and
  Insights fixtures into independent idempotent seeders with deterministic
  relative dates and fixed values where screenshots depend on them. Remove its
  size and complexity allowances. For Training Signature, keep data
  geometry/tuning in VivoKit but
  split app-only section composition, animation scheduling, and stateless Canvas
  drawing passes; do not make the widget import app code or force both targets
  into a lifecycle-inappropriate shared renderer. Prove still and animated
  output before removing the final size allowance.

- [ ] **7. Consolidate evidence and close the program.** Re-run the strict
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

- The committed structural baseline at `147de6c` passes: 252 production Swift
  files, 10 existing source-size allowances, and 19 existing complexity
  allowances.
- The original top operational hotspot, `ActiveExerciseCard.swift`, and the
  Library/picker duplication seam have already been addressed. Their fresh
  boundaries should be protected while this plan works outward.
- `SignatureSection.swift` is the one current allowance not corroborated by the
  audit's top-twelve ranking. It remains last because its renderer is cohesive;
  the milestone must produce a real composition/motion/rendering boundary, not
  a cosmetic file split.
