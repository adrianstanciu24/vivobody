# Replace movement steps with structured execution instructions

- Status: planned
- Created: 2026-08-15
- Spec/decision: user-requested instruction restructuring; supersedes the flat
  step arrays introduced by
  [2026-08-15-authored-exercise-steps.md](../completed/2026-08-15-authored-exercise-steps.md)

## Goal and non-goals

Replace each catalog exercise's flat `movementSteps` string array with one
structured `execution` object whose labeled fields separate sequential phases
from concurrent constraints:

| Field | Content | Presence |
|---|---|---|
| `startingPosition` | Setup, stance, grip, and load placement | required |
| `movement` | The intended movement | required |
| `endpoint` | Where the movement ends; for holds, the held position | required |
| `returnPhase` | How to return to the start | conditional (see below) |
| `controlledJoints` | Joints that must remain controlled or still | required |
| `supportAndPosture` | Support surfaces, bracing, and posture | required |
| `disqualifyingCompensations` | Array; each entry names the compensation and the exercise or pattern it turns the movement into | required, min 1 |
| `sideOrDirection` | Side-switching or travel-direction requirement | conditional (see below) |

Conditional presence is enforced by the schema and compiler, not by author
memory:

- `returnPhase` is required when `trackingMode` is `reps`; it is forbidden for
  duration-tracked movements with no return (static holds, carries). The exact
  rule is finalized in milestone 1 against the real distribution of the 136
  exercises across `modality` and `trackingMode`.
- `sideOrDirection` is required when `laterality` is `unilateral` and for
  direction-based duration exercises such as carries; it is forbidden for
  symmetric bilateral movements.

The `disqualifyingCompensations` field is the user-facing projection of the
movement-signature variant axes each family already encodes; authors derive
entries from those axes and from sibling exercises, not from generic form tips.

Non-goals: no changes to biomechanics, muscle roles, movement signatures,
performance signatures, logging semantics, or session ownership. No runtime
parsing or inference of structure from prose. No `VersionedSchema`; this is a
pre-release schema replacement like its predecessor.

## Relevant source, specs, and decisions

- Schema: `specs/catalog/family.schema.json` (`movementSteps` definition and
  per-exercise `required` list).
- Compiler: `Scripts/catalog.py` (step validation around
  `validate_exercise`, runtime emission in the record builder).
- Compiler tests: `Scripts/tests/test_catalog.py`, including
  `test_movement_steps_use_plain_english` and the pinned-boundary tests that
  assert step content verbatim (for example the hip-hinge load-guidance
  string).
- Authored data: `specs/catalog/families/*.json` (57 files, 136 exercises,
  currently 528 steps) and `specs/catalog/fixtures/valid-family.json`.
- Runtime transport: `vivobody/Models/Domain/CatalogData.swift`
  (`CatalogRecord` decoding plus `validateMovementSteps`).
- Persistence: `vivobody/Models/Domain/ExerciseCatalog.swift`
  (`ExerciseCatalogItem.movementSteps`), duplication and reconciliation paths,
  and the pre-release store fixture exercised by
  `vivobodyTests/PersistenceStoreContractTests.swift`.
- UI: `vivobody/Screens/Library/ExerciseInstructionsScreen.swift` (numbered
  step cards and `ExerciseInstructionSummary`),
  `CustomExerciseEditorSheet.swift`, `CatalogDraft.swift`.
- Contract doc: `specs/exercise-data-contract.md` (`movementSteps` bullet).

## Invariants and risks

- No authored content is lost. Every one of the current steps maps into a
  structured field or is recorded in this plan as a deliberate drop. Load and
  logging guidance (for example the hip-hinge "25 percent of body weight"
  step) moves into `startingPosition`; the pinned test asserting it inside
  `movementSteps` moves with it.
- The catalog compiler remains the only writer of the bundled runtime JSON,
  and every field is validated independently (length, capitalization,
  plain-language lint extended across all fields).
- The app remains the only SwiftData writer and keeps the recoverable
  in-memory fallback. `ExerciseCatalogItem` stores the structured fields
  directly; no delimiter convention or parser reconstructs them.
- Duplicated bundled exercises keep their full structured instructions;
  manually created custom exercises keep having none. Copy-only instruction
  edits still do not change the performance signature or start a new record
  series (`specs/exercise-data-contract.md`).
- Pre-release posture: one current schema, no `VersionedSchema`. The
  development store fixture and its checksum are regenerated intentionally.
- Atomicity risk: the compiler validates all 57 family files against one
  schema, so the schema switch and the 136-exercise re-authoring must land as
  one coordinated pass (the predecessor migration proved this workable with
  parallel review agents over disjoint family groups). Fallback if the pass
  stalls: temporarily accept both `movementSteps` and `execution`, forbid
  mixing within a family, and remove the legacy branch in the final milestone.
- Rollback: all generated artifacts (`vivobody/Resources/catalog.json`, the
  store fixture) are reproducible from the family sources, so reverting the
  source commits fully restores the previous state.

## Milestones

- [x] 1. Contract: replace `movementSteps` with the `execution` object in
  `family.schema.json` and `Scripts/catalog.py`, including the conditional
  `returnPhase` and `sideOrDirection` rules keyed on `trackingMode`,
  `modality`, and `laterality`, cross-validated against each exercise's
  declared values. Update the fixture and the mutation tests so an exercise
  with a missing, forbidden, jargon-laden, or empty field fails compilation.
  Record the finalized conditional rules in this plan.
- [x] 2. Pilot: re-author `hip-hinge` (dynamic, bilateral, load guidance) and
  `anti-lateral-flexion` (isometric hold, side-switching) to validate the
  contract against contrasting exercise types before the mass pass. Adjust
  field definitions here if the pilot exposes a gap.
- [x] 3. Transport and persistence: decode and validate the structured object
  in `CatalogData.swift`, store it on `ExerciseCatalogItem`, and carry it
  through duplication, reconciliation, and editor-summary paths unchanged.
- [x] 4. UI: replace the numbered "Step N" cards in
  `ExerciseInstructionsScreen` and `ExerciseInstructionSummary` with labeled
  sections in a fixed reading order (starting position, movement, endpoint,
  return, keep controlled, support and posture, compensations, sides and
  direction), rendering only the fields present. Keep 44pt targets, stable
  accessibility identifiers, and heading traits per section.
- [x] 5. Re-author the remaining 55 families with parallel review of disjoint
  family groups, preserving all setup, control, safety, side, direction, and
  load guidance from the current steps and authoring
  `disqualifyingCompensations` from each family's variant axes and siblings.
- [x] 6. Regenerate `vivobody/Resources/catalog.json` and the pre-release
  persistence fixture plus checksum; update pinned content tests and
  `specs/exercise-data-contract.md`; refresh affected source headers.
- [x] 7. Verify: full command list below, plus inspected screenshot and
  accessibility-tree evidence for the exercise detail and instruction screens
  covering one dynamic bilateral, one unilateral, and one isometric exercise.

## Verification

```bash
/usr/bin/python3 -m pytest Scripts/tests/test_catalog.py
/usr/bin/python3 Scripts/catalog.py --check
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -parallel-testing-enabled NO \
  test -only-testing:vivobodyTests/CatalogBiomechanicsTests \
  -only-testing:vivobodyTests/CatalogDuplicateTests \
  -only-testing:vivobodyTests/BiomechanicsDomainTests
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -parallel-testing-enabled NO \
  test -only-testing:vivobodyTests/PersistenceStoreContractTests
Scripts/check.sh
Scripts/verify.sh
```

## Progress and discoveries

- 2026-08-15: Plan authored. Known facts at planning time: 57 family files,
  136 exercises, 528 flat steps; `laterality` domain is
  `{bilateral, unilateral}`; `trackingMode` domain is `{reps, duration}`;
  `modality` domain is `{dynamicStrength, isometricStrength, power,
  conditioning, mobility}` with `dynamicStrength`/`power` pinned to `reps`.
  The plain-language jargon lint exists in `test_catalog.py`
  (`test_movement_steps_use_plain_english`) and must survive the rename.
- 2026-08-15 (milestone 1): Finalized conditional rules against the real
  distribution: 131 rep-tracked exercises (129 dynamicStrength, 2 power),
  5 duration-tracked exercises (all isometricStrength: plank, side plank,
  one anti-rotation hold, farmer carry, suitcase carry), and zero
  conditioning or mobility exercises. The rules are therefore keyed on
  `trackingMode` and `laterality`/family pattern alone, which keeps them
  correct for future conditioning/mobility entries that may track either
  way:
  - `returnPhase` is required exactly when `trackingMode == "reps"` and
    forbidden when `trackingMode == "duration"`. Every duration-tracked
    exercise in the catalog is a static hold or carry with no return to
    the start; every rep-tracked exercise returns each repetition.
  - `sideOrDirection` is required exactly when `laterality ==
    "unilateral"` or the family's `fixed.pattern == "carry"`, and
    forbidden otherwise. Unilateral exercises must name the working side
    and the switch; carries must state travel direction even when
    bilateral (the farmer carry). Symmetric bilateral non-carry movements
    have neither requirement.
  Both rules are enforced in `validate_execution` in `Scripts/catalog.py`
  and pinned in the schema's `executionInstructions` definition; the
  jargon lint now spans every field as
  `test_execution_fields_use_plain_english`.
- 2026-08-15 (milestone 2): Pilot passed on both contrasting types.
  `hip-hinge` (reps, bilateral) carries its 25-percent load guidance in
  `startingPosition`; `anti-lateral-flexion` (duration, unilateral) omits
  `returnPhase` and carries the side switch in `sideOrDirection`. No field
  gaps exposed; the fixed reading order stands.
- 2026-08-15 (milestones 3-5): Six parallel workers landed the Swift side
  and the remaining 55 families in disjoint groups. Swift transport stores
  one Codable `ExecutionInstructions?` on `ExerciseCatalogItem` (line-neutral
  against the 824-line ratchet), validates every field at decode with the
  same conditional rules as the compiler, and renders labeled sections with
  `exercise-execution-*` identifiers. All 57 families validated with zero
  jargon hits. The sentence-level preservation diff against HEAD flagged
  157 sentences across 111 exercises; every flag reviewed as a legitimate
  clause-level split with the content landing in the appropriate field
  (spot-checked pull-up, step-up, wrist curl, torso twist, farmer carry,
  grip trainer, Pallof hold, back squat, forward lunge, side plank). Tempo
  prescriptions ("three seconds", "two seconds", "at least four seconds")
  and logging conventions survived verbatim. Compensations are
  sibling-aware (box squat, good morning, suitcase carry, kipping pull-up).
- 2026-08-15 (milestone 6): `catalog.json` regenerated
  (`Scripts/catalog.py --emit-runtime`). `PersistenceBaseline.store`
  regenerated through a temporary in-target generator harness writing the
  exact fixture graph via `VivobodyStore.makeContainer(at:)` (harness
  deleted after capture); SHA256SUMS refreshed and the checksum gate
  passes. Pinned tests updated: batch2/batch3 roster digests re-pinned to
  the execution-inclusive payloads, batch6 verbatim pins moved to
  `execution_texts`, the batch7 pin renamed to
  `test_batch7_execution_pin_reviewed_boundaries` and re-pinned to the
  full execution dictionaries, and two substring pins re-cased for
  sentence-initial capitalization ("Repeat with the other hand", "Hold the
  top position for five seconds"). One vertical-press fixture test now
  adds `sideOrDirection` when it flips an exercise to unilateral.
- 2026-08-15 (milestone 7): `Scripts/verify_scenario.py` gained a blind
  `swipe` step because `scrollTo` stops at first frame intersection, which
  left the "How to perform" row half-covered by the tab bar on shorter
  detail screens; the row was untappable at its midpoint. Three new
  scenarios (`exercise-execution-bilateral-reps`,
  `exercise-execution-unilateral-reps`, `exercise-execution-isometric`)
  tap through to the instructions screen and assert section presence and
  absence per conditional rule, with screenshots inspected.

## Result

All 136 exercises in 57 families now carry the structured eight-field
`execution` object instead of a flat step list. The schema, compiler,
runtime decoder, persistence model, editor draft, and instructions UI
enforce and render the contract, including the conditional `returnPhase`
(reps only) and `sideOrDirection` (unilateral or carry) rules.

Verification evidence:

- `/usr/bin/python3 -m unittest discover -s Scripts/tests`: 456 tests, OK
  (includes 13 execution mutation tests and the renamed jargon lint).
- `Scripts/catalog.py --check`: passes via the build's Verify Canonical
  Catalog phase and `Scripts/check.sh`.
- `xcodebuild ... -only-testing:vivobodyTests/CatalogBiomechanicsTests
  -only-testing:vivobodyTests/CatalogDuplicateTests
  -only-testing:vivobodyTests/BiomechanicsDomainTests`: all pass,
  including the new `strictCatalogRejectsMalformedExecutionInstructions`.
- `xcodebuild ... -only-testing:vivobodyTests/PersistenceStoreContractTests`:
  passes against the regenerated baseline (checksum
  8adcc922386f3e0b0600d627c027f181ed8cb0788542da119fe141e890262a82).
- `Scripts/check.sh`: passes (VivoKit tests, baseline integrity,
  architecture, source size, naming, complexity, formatting, knowledge
  map, catalog, build).
- UI evidence: three scenario runs pass with inspected screenshots and
  trees under `.verify/scenarios/exercise-execution-*/`, covering a
  dynamic bilateral (Barbell Bench Press: Return present, Sides and
  direction absent), a unilateral rep exercise (Single-Arm Cable Lat
  Pulldown: all eight sections), and an isometric (Side Plank: Return
  absent, Sides and direction present).
- The detail-screen accessibility hint now reads "Opens how-to-perform
  instructions" to match the labeled-section screen.
