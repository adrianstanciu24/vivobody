# Exercise Substitution

Status: **Implemented.**

During an active workout, the user can replace an exercise that has no
completed sets with a ranked catalog alternative. The feature is deliberately
small and transparent: it uses existing authored catalog facts, shows what the
alternative preserves and changes, and never presents substitutions as
identical or medically safe.

## Product decision

The sheet answers one question:

> Which available exercise best preserves this workout slot?

It is a live-workout instrument, not a comparison report. The first viewport
keeps the source identity, equipment control, top recommendations, selected
alternative, and replacement action visible without requiring a paragraph of
reading.

## Entry and flow

1. The active workout's top-bar options pill and the exercise-name long-press
   menu both offer **Replace exercise**.
2. A large sheet opens with the three strongest compatible catalog
   alternatives. The user can drag it to medium at standard Dynamic Type
   sizes, and the first recommendation is selected by default.
3. Equipment chips filter the same recommendations without leaving the sheet.
4. Each candidate shows its match tier, exercise, equipment, and selection
   state. The selected card expands into a separated two-row tradeoff ledger
   with one short **Keeps** fact and one short **Changes** fact; the other rows
   stay compact for fast scanning.
5. The persistent bottom action commits the selected replacement. Its explicit
   **Replace exercise** label is the confirmation; no second alert is shown.
6. The complete compatible result list remains available below the initial
   recommendations without requiring a keyboard during the workout.

The sheet contains no Pro gate, anatomy view, exercise instructions, numerical
match percentage, or source-load transfer.

## Ranking contract

`ExerciseSubstitution` is a pure deterministic domain model. It excludes
the source and candidates whose modality or tracking semantics differ, then
ranks structurally plausible catalog candidates using only existing structured
fields:

1. assign an honest compatibility tier from family, primary-muscle,
   performance-semantic, laterality, and movement agreement;
2. rank within each tier by weighted family, muscle-role, movement,
   movement-plane, load-mode, mechanic, and laterality agreement;
3. use favorite and then exercise history only as tie-breakers;
4. finish ties by normalized name and stable catalog identity.

Equipment is a user-selected constraint rather than a similarity bonus. Missing
facts are not treated as matches. Stable catalog identity and name finish every
tie so input order never changes the result.

The internal score is never rendered. Recommendations expose only honest
tiers—**Closest match**, **Good match**, and **Partial match**—plus typed
preserved and changed facts. Explanations are generated from the same deltas
used by the ranker so ranking and visible copy cannot disagree.

## Replacement contract

The app replaces an exercise only when it belongs to the active draft and none
of its sets are complete. The transaction:

- preserves the workout session, slot order, active page, live set count,
  and superset membership;
- creates fresh exercise and set identities with the selected catalog item's
  copied metadata;
- seeds the new sets from that candidate's own compatible history, falling
  back to its catalog defaults;
- never copies the source load, reps, duration, RIR, record history, catalog
  identity, or set IDs;
- treats the source's live set rows as authoritative when a cached planned
  count has drifted, and always creates at least one actionable candidate set;
- saves through `saveOrRollback()` and emits `SessionSideEffects.updated` only
  after success;
- rolls back without dismissing the sheet or firing success feedback when the
  save fails.

When any source set is complete, the UI explains that logged work cannot be
relabeled and keeps the existing Add Exercise route available. A future
"switch remaining sets" design must retain the original completed exercise as
a separate historical series and define superset round behavior first.

## Accessibility and state

- Options, recommendation rows, filters, and the commit action have 44pt
  minimum targets.
- Selection is expressed by symbol, text, and `.isSelected`, never color alone.
- A recommendation's VoiceOver label includes its full name, equipment, tier,
  compact ranked rationale, and selection state.
- Names and fact lines wrap at accessibility Dynamic Type sizes; the commit
  action remains reachable in the bottom safe area.
- A genuinely empty restored exercise says **No sets**, never **Exercise
  complete**, exposes no set-only RIR control, and provides a thumb-reachable
  **Add set** recovery action.
- Stable identifiers cover the options entry, sheet, equipment filters,
  recommendation selection, and replacement action required by the semantic
  scenario.

## Non-goals

- No body-position, support, joint-action, or movement-exposure taxonomy.
- No pain, injury, rehabilitation, or medical-safety recommendations.
- No machine learning, embeddings, collaborative filtering, or generated prose.
- No replacement after a completed set and no automatic template edits.
- No attempt to translate weight or performance records between exercises.

## Verification

- Pure ranker tests cover hard compatibility, ordering, missing facts, stable
  ties, equipment filtering, history tie-breaking, and explanation agreement.
- Controller tests cover metadata freshness, candidate-history prefill,
  preserved slot/set count/superset membership, completed-set rejection, stale
  requests, cached-count drift, a nonempty-set floor, and live-graph rollback
  after a forced save failure.
- `exercise-substitution-sheet` verifies ranking controls and explanatory
  semantics; `replace-active-exercise` proves the replacement survives app
  relaunch; `replace-active-exercise-blocked` protects completed work; and
  `active-zero-set-recovery` verifies honest recovery from malformed old data.
- Dark, light, and accessibility-size screenshots and accessibility trees were
  inspected before completion.
