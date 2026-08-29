# Current work

Goal: add the second reviewed wave of missing commercial-gym machine exercises
without merging incompatible fixture or unilateral load histories.

Primary candidates: seated dip press, padded plate-loaded pullover, belt squat,
single-leg 45-degree leg press, independent-arm chest press, and
independent-arm shoulder press.

Later candidates: pendulum squat, Smith hip thrust/RDL/split squat, horizontal
calf press, and machine tibialis raise.

Progress:

- Duplicate and alias scan found no exact active duplicates.
- Three independent read-only discovery lanes completed biomechanics,
  contract-boundary, and product/load reviews, then unanimously resolved the
  two material fixture disputes.
- Five source-exact exercises are drafted: two new families for the ERGO-FIT
  VECTOR seated dip press and Hammer PL-PO padded pullover, plus exact Panatta
  1FW090, MTSCP, and MTSSP expansions.
- Belt Squat remains a separate proposal because Joseph's Wenning Gen4 study
  does not define reproducible ROM or load accounting and cannot transfer to
  Hammer's different anchors and loading points. Hammer PL-DIP also remains a
  fixture-specific proposal because current evidence does not close the
  compound humeral-motion gate.
- The coordinating agent is the only writer for catalog sources, evidence,
  generated output, documentation, and tests.
- The later candidates have proposal-only ownership and concrete evidence
  unlocks in `machine-second-wave-2026-08.md`.
- The generated projection is 87 runtime families, 211 exercises, and 232
  evidence sources. Catalog generation and all 431 Python contract tests pass.
- Independent post-draft evidence, contract, and product reviews pass after
  correcting the Panatta coupling direction, MTS false precision, reverse
  ownership rules, and one-value per-side load semantics.
- `Scripts/check.sh` passes, and the targeted `CatalogBiomechanicsTests` suite
  passes all 15 tests on the headless iPhone 17 Pro simulator.
- The `catalog-machine-second-wave` Baguette scenario passes. Its inspected
  screenshot shows the PL-PO detail without clipping, and the accessibility
  tree exposes the title, `STRENGTH · REPS`, and muscle-summary semantics.

Next:

- Final diff review and handoff.

User steering: proceed with the explicitly listed second wave and preserve the
separate belt-squat boundary established by DOI 10.2478/hukin-2019-0126.
