# Training Load measures volume load; the muscle map measures hard sets

- Status: proposed
- Date: 2026-09-03
- Owners: astanciu
- Supersedes: none. Narrows the "one shared set currency for every surface"
  language in `specs/muscle-attention-simplification.md` to the muscle
  surfaces only.

## Context

`SetStimulus` prices a completed set as `1.0 × effort(RIR)`. `MuscleVolume`,
`MuscleDevelopment`, and `TrainingLoad` all consume that price so they agree
on what a set is worth. Load entered the price in 2026-07 as a relative e1RM
factor and left in 2026-08 when the muscle map was simplified; Training Load
lost load as a side effect rather than by its own decision.

The two surfaces answer different questions. The muscle map asks where
training attention has gone, which the hypertrophy literature counts in hard
sets per muscle per week. Training Load asks how much systemic work the user
did this week versus their usual, which strength practice counts in volume
load (sets × reps × load). A hard-set count cannot show progressive overload
at fixed sets × reps, cannot distinguish a deload from a normal week, and
cannot see power work. A relative-to-own-max factor cannot either, because the
reference rises with every PR and the ratio saturates.

Raw tonnage was rejected twice for the muscle currency because it is not
additive across muscles or exercises and double-counts reps against load.
Those objections apply to per-muscle attribution, not to a self-relative
weekly total compared against the same user's four-week median.

## Decision

Training Load computes its headline, trend, seven-day strip, and verdict from
weekly volume load, folded from the same `ComparableTonnageSummary` History
uses, whenever the user's recent history contains any comparable load.
Otherwise it falls back to the existing hard-set instrument unchanged. Hard
sets stay visible as a driver in both cases.

The muscle map, 3D body, volume bars, and symmetry keep `SetStimulus` hard
sets and are not changed. The shared-currency invariant is scoped to those
surfaces.

Volume load carries no RIR discount, no warm-up demotion, no per-lift
reference, and no new tunables. The recent band, baseline gate, and window
geometry are unchanged.

## Consequences

Easier: progressive overload and deloads are visible on the Training Load
chart; power work counts toward systemic load; the number is a unit the user
recognizes and can verify against their log.

Harder: Training Load and the muscle map no longer share one measure, so both
file headers and the specs must say which surface uses which. Partial load
coverage (some exercises comparable, some not) can bias the ratio in weeks
where the comparable subset is skipped; the report exposes availability so the
UI can say so. Volume load is more volatile week to week than set counts; the
band is unchanged for now and observed behaviour is recorded in the plan.

Intentionally unsupported: a load factor inside `SetStimulus`, an absolute or
cross-user load threshold, and any change to the persistence model or widget
snapshot shape.

## Evidence

- Plan: `engineering/plans/active/2026-09-03-training-load-volume-load.md`
- Source: `vivobody/Models/Insights/TrainingLoad.swift`,
  `vivobody/Models/Insights/AnalyticsAccumulator.swift`
- Tests: `vivobodyTests/TrainingLoadTests.swift`,
  `vivobodyTests/SessionInsightsTests.swift`
- Prior rationale: `specs/hard-set-currency.md`,
  `specs/muscle-attention-simplification.md`, `specs/simplify-muscle-model.md`
