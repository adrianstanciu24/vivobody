# Current work

Goal: correct Training Load's Sessions driver semantics and make recent-window
measure transitions explicit.

Progress:

- Training Load now uses comparable volume load when recent history supports
  it and otherwise preserves the hard-set instrument.
- Model, UI, docs, targeted tests, snapshot contracts, repository checks, and
  headless evidence for both measures are complete; the execution plan records
  exact results.
- No persistence or VivoKit snapshot-shape change was made. Muscle surfaces
  and `SetStimulus` remain on hard-set currency.
- Sessions now means every workout carrying hard-set or comparable-volume work,
  so power-only volume no longer reports zero sessions.
- The decision, spec, and completed plan now state that one measure drives each
  report but is reevaluated from the trailing 35 days; returning to weighted
  work after a long gap intentionally rebuilds the recent volume baseline.

Verification complete: 31 focused Training Load tests and 78 tests across the
four affected suites passed. `Scripts/check.sh` and the headless
`insights-showcase` scenario also passed.

Next: retain real-history volume-load volatility as the remaining product
observation.

User steering: use multiple agents and preserve the measure boundary above.
