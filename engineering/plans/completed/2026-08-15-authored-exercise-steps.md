# Author explicit exercise instruction steps

- Status: completed
- Started: 2026-08-15
- Spec/decision: user-requested catalog and exercise-detail readability change

## Goal and non-goals

Replace each catalog exercise's prose `movementDefinition` with an ordered
`movementSteps` array and render those authored steps directly. Custom exercise
copies retain the ordered instructions in SwiftData.

This work does not change biomechanics, muscle roles, movement signatures,
logging semantics, or workout-session ownership. It does not infer steps from
punctuation at runtime.

## Invariants and risks

- Every current catalog exercise keeps all meaningful setup, execution,
  control, safety, side/direction, and logging guidance.
- The catalog compiler validates each step independently and remains the only
  writer of the bundled runtime JSON.
- `ExerciseCatalogItem` stores ordered strings directly; no sentence parser or
  delimiter convention reconstructs them.
- The app remains the only SwiftData writer and retains the recoverable
  in-memory fallback.
- This is a pre-release schema replacement. The checked-in development fixture
  is regenerated intentionally and its contract updated; no `VersionedSchema`
  is introduced before the first public release.

## Milestones

- [x] Replace the family schema, fixture, generator, and runtime decoder
  contract with `movementSteps`.
- [x] Re-author all catalog exercise instructions as ordered step arrays.
- [x] Replace the persisted paragraph with ordered steps and update all editor,
  duplication, reconciliation, and instruction-screen paths.
- [x] Regenerate the bundled catalog and the pre-release persistence fixture.
- [x] Run focused catalog, duplication, persistence, and instruction tests.
- [x] Run canonical verification and inspect screenshot plus accessibility-tree
  evidence for the detail and instruction screens.

## Verification

```bash
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
```

## Progress and discoveries

- The current catalog has 136 exercises across 57 family files. Existing prose
  contains two to six sentences, but sentence boundaries are not a durable UI
  contract and several sentences contain multiple user actions.
- The current custom-exercise editor does not author movement instructions,
  but duplicated bundled exercises retain them. The new stored array preserves
  that behavior while leaving manually created exercises with no instruction
  row.

## Result

The 136 bundled exercises now contain 528 explicitly authored instructions,
with three to seven steps per exercise and no legacy prose field. Three agents
reviewed disjoint family groups so setup, movement, control, side changes,
logging conventions, and source-specific limitations remained explicit.
The user-facing steps use plain coaching language instead of biomechanical
terms such as `supine`, `pronated`, or `scapular retraction`; a catalog-wide
test prevents those terms from returning to movement instructions.

The compiler and runtime decoder validate and transport arrays directly. The
SwiftData catalog item, bundled/custom reconciliation, duplication flow, and
editor summary retain the same ordered values. Exercise detail now links to a
dedicated screen that presents `Step 1`, `Step 2`, and subsequent headings with
their descriptions beneath them.

Evidence:

- 366 Python catalog tests passed.
- 24 focused Swift catalog/domain/duplication tests passed.
- The pre-release persistence-store reopen contract passed with the refreshed
  fixture and checksum.
- `Scripts/check.sh` passed, including catalog parity and app build.
- `.verify/exercise-instructions.jpg` and
  `.verify/exercise-instructions-ui.json` were inspected on iPhone 17 Pro Max;
  all three step cards were visible, unclipped, and exposed as combined heading
  elements with their descriptions.
- `.verify/plain-language-instructions.jpg` and
  `.verify/plain-language-instructions-ui.json` were inspected after the copy
  pass; all three plain-English steps remained readable and semantically exposed.
