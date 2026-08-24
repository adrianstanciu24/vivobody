# Strength Routine Builder

- Status: Implemented, temporarily hidden
- Product surface: No public entry; retained behind a DEBUG verification route
- Scope: deterministic strength-only routine generation, review, and template creation

## Product decision

The builder's job is:

> Turn a few explicit constraints into a balanced weekly strength-plan draft
> that the user can understand, adjust, and choose to save.

It creates a conservative starting structure, not an optimal or individualized
program. It runs entirely on device, uses authored catalog facts and optional
local workout history, and always requires review before saving. Generated
copy must say **Build routine**, **Draft**, or **Starting plan**; it must never
claim **optimal**, **personal trainer**, or equivalent certainty.

## Entry and flow

1. The builder is temporarily hidden from **Library > Templates**. The public
   create action and empty state expose only manual template creation. A DEBUG
   launch argument keeps the complete flow reachable for deterministic tests.
2. When opened through that verification route, **Build Routine** uses one
   compact planning sheet, not an onboarding wizard. Required choices and the
   build action remain in one scrollable surface; optional preferences are
   disclosed only on request.
3. **Build plan** produces an in-memory multi-day draft. Nothing is inserted
   into SwiftData yet.
4. Review leads with the weekly shape, any gaps, and a day selector. The
   selected day then shows its ordered exercises, initial set/rep target, and
   one short typed selection reason.
5. The user may lock exercises, swap one slot, or regenerate every unlocked
   slot with the next deterministic alternative. Every edit recomputes the
   typed gaps.
6. One **Save routine** action creates all generated `WorkoutTemplate` rows
   and their existing child entities in one transaction. Cancel discards the
   transient draft.

The builder is never launched, suggested, or paywalled from an active-workout
surface. It does not read or mutate the active session.

## Input contract

### Required

- **Training days:** 2–4 exact weekdays. Day count alone is insufficient;
  spacing and the resulting `scheduledWeekdays` values come from the selected
  weekdays.
- **Session duration:** exactly 30, 45, or 60 minutes. This is an approximate
  slot budget, not a completion-time promise.
- **Goal:** **Strength**, **Muscle**, or **Balanced**. All three goals select
  only strength modalities; the goal changes ordering and starting set/rep
  policy, not exercise eligibility.

### Optional

- **Equipment:** any available external `Equipment` values. Bodyweight is a
  baseline capability and remains eligible without an explicit selection;
  every other equipment value is a hard filter, never a ranking bonus. An
  exercise whose external equipment is not selected cannot be generated or
  swapped into the plan.
- **Emphasis:** one muscle group to favor after required weekly coverage is
  satisfied. It is a soft preference and must not erase an opposing movement
  or another major region merely to satisfy the emphasis.
- **Include exercises:** explicit hard inclusions. The sheet blocks a selected
  exercise that conflicts with equipment, modality, or avoidance constraints
  instead of silently dropping it.
- **Avoid exercises:** explicit hard exclusions from generation and swaps.
- **Prefer familiar exercises:** a soft, default-on tie-breaker when qualifying
  history exists. Familiarity is derived from `ExerciseHistorySummary`; users
  are not asked to re-enter exercises they already perform.

The same exercise cannot be both included and avoided. Invalid weekday counts
and conflicting hard preferences disable generation with a concrete correction
beside the affected control. With no external equipment selected, the builder
attempts a bodyweight-only draft and reports catalog coverage gaps honestly.

## Eligibility and source-of-truth boundaries

The automatic candidate pool contains current, visible catalog items whose
modality is `.dynamicStrength` or `.isometricStrength`, whose tracking mode is
compatible with that modality, and whose authored classification and primary
muscle facts are sufficient for the requested slot. Power, conditioning, and
mobility exercises are excluded even when their equipment matches.
Bodyweight exercises remain eligible regardless of external-equipment
selections; explicit avoids still remove them.

Only bundled reviewed items may be chosen automatically, explicitly included,
avoided, or offered for swap in V1. Custom catalog items remain usable through
the manual template editor, but the planner does not treat user-authored
classification as reviewed programming evidence or invent missing metadata.

The builder consumes catalog identity, family, equipment, mechanic, training
role, movement pattern and direction, laterality, modality, tracking mode,
and categorical muscle roles. It may use favorite and history signals only as
stable tie-breakers. It does not reinterpret names, scrape instructions, or
invent biomechanical classifications.

Catalog default load, reps, and duration remain picker UI seeds under the
[Exercise Data Contract](exercise-data-contract.md). The builder must not use
`defaultWeight`, measured 1RM, or a guessed percentage of 1RM to prescribe a
starting weight. Generated templates start without a prescribed external load;
the existing compatible-history path may still prefill working values when a
saved template is started.

## Deterministic programming policy

`StrengthRoutineBuilder` is a pure domain policy. It performs no queries,
writes, logging, or UI work. Given the same canonical catalog snapshot,
constraints, history summary, locks, and per-slot replacement exclusions, it
returns byte-for-byte equivalent plan structure, reasons, and gaps regardless
of catalog input order.

### Weekly topology

| Days | Split | Ordered template names |
|---|---|---|
| 2 | Full body | Full Body A, Full Body B |
| 3 | Full body | Full Body A, Full Body B, Full Body C |
| 4 | Upper / lower | Upper A, Lower A, Upper B, Lower B |

The UI orders selected weekdays with the established locale-aware
`WeekdayLabels.ordered()` helper and passes that explicit order into the pure
builder. The builder deduplicates while preserving caller order, then assigns
the topology in order. Each resulting template owns exactly one selected
weekday. V1 does not persist a parent routine or infer recovery readiness
between dates.

### Session budget and ordering

The duration buckets initially budget 4, 5, and 6 exercise slots for 30, 45,
and 60 minutes. The number is a transparent density rule, not an estimated
timer. Hard inclusions may consume those slots; the builder reports a blocking
conflict rather than silently exceeding the selected duration.

Within a day, compound movements precede isolation work. The policy spreads
squat/hinge and pressing/pulling compounds across the selected days, avoids
two exercises from the same family in one session, and penalizes unnecessary
weekly repetition. A deliberate repeat may win for the Strength goal or an
explicit include, but the same catalog exercise is never duplicated on one
day. Every duration bucket gives a selected emphasis one explicit slot only
after required movement and body-region coverage remains intact. A four-day
emphasis is placed only on its matching upper or lower days. When a sparse
catalog cannot supply a distinct same-day choice, that slot stays empty and
blocks save rather than repeating an exercise. These are classification-based
workload proxies; V1 has no exercise fatigue or recovery score.

### Coverage

The weekly draft attempts to cover:

- horizontal push and horizontal pull;
- vertical push and vertical pull;
- squat or lunge, plus hinge;
- the major upper-body, lower-body, and trunk primary-muscle regions supported
  by the eligible catalog.

Push/pull and squat/hinge are coverage relationships, not universal 50/50 set
targets. Muscle roles are categorical catalog facts, not exact physiological
fractions. If equipment, includes, avoids, or the session budget prevent a
relationship, the output reports a typed movement or body-region gap instead
of fabricating coverage.

### Initial prescription

Every generated exercise receives a uniform prescription that existing
`TemplateExercise` can persist:

| Goal | Compound | Isolation |
|---|---|---|
| Strength | 3 × 5 | 2 × 10 |
| Muscle | 3 × 8 | 3 × 12 |
| Balanced | 3 × 6 | 2 × 10 |

An isometric strength exercise uses the same goal/mechanic set-count rule and
an exact 30-second target. Planning, review, and the saved template show the
same exact target; V1 does not display a range that disappears on save.

The policy is versioned in code and covered by table-driven tests. It is a
conservative editable seed, not medical advice or an individualized load
prescription. The evidence boundary is the 2026 ACSM position stand, which
supports 2–3 sets per exercise for strength, heavier loads for strength, and
higher weekly volume for hypertrophy while finding no consistent advantage
from equipment type or complex periodization. V1 deliberately applies only
the bounded set/volume structure and does not infer load from that evidence:
[PMID 41843416](https://pubmed.ncbi.nlm.nih.gov/41843416/),
[DOI 10.1249/MSS.0000000000003897](https://doi.org/10.1249/MSS.0000000000003897).

## Reasons, gaps, and variation

Selection output carries typed reasons from the same facts used to select it,
for example:

- required horizontal pull;
- squat-pattern coverage;
- primary chest coverage;
- selected emphasis;
- explicitly included;
- familiar eligible choice.

SwiftUI renders only the highest-priority reason as one short row subtitle.
Additional typed reasons remain domain evidence rather than another visible
report section. A generated sentence is never the source of truth.

Gaps are also typed and severity-bearing. Blocking gaps include an impossible
include, no eligible exercise for a required slot, an empty day, stale catalog
identity, or insufficient template capacity. Reviewable warnings include a
missing preferred direction or emphasis after every feasible higher-priority
requirement is satisfied. Warnings remain visible before save and VoiceOver
announces their affected scope; blockers disable save.

**Swap** ranks only alternatives that satisfy the selected slot's hard role,
equipment, modality, includes/avoids, and current locks. A hard-included
exercise does not expose Swap because relocating that requirement would make a
one-row action misleading. **Lock** preserves an exercise and its day/slot
across regeneration. **Regenerate** walks unlocked slots in stable order,
preserves the rest of the visible draft as temporary locks, and excludes each
slot's current exercise while choosing its next deterministic alternative. It
never uses randomness. If no distinct valid alternative exists, that slot
stays unchanged and receives a typed advisory.

## Review hierarchy and accessibility

The planning sheet's first viewport exposes the required choices and **Build
plan**, without introductory body copy. Optional preferences remain collapsed.

The review screen answers one question: **Is this weekly starting plan balanced
enough to save?** Its hierarchy is:

1. **Glance:** a compact week card with day count, exercise count, duration,
   and a large ready/gap state.
2. **Compare:** the exact selected weekdays in a day selector.
3. **Act:** the selected day's ordered exercise rows, with the set/rep target,
   one reason, lock, and swap actions.
4. **Explain:** typed coverage warnings behind one gap disclosure.

The week card uses exact counts rather than a decorative score, and color only
reinforces the visible ready/gap label. It must not display a numeric quality
score. Exercise rows remain readable at accessibility sizes instead of
shrinking names or reasons. The persistent save action stays reachable above
the safe area.

- Every chip, day, lock, swap, regenerate, and save control has a 44pt minimum
  target and an accurate enabled/selected state.
- Weekday, goal, duration, equipment, and selected review day expose
  `.isSelected`; lock state is expressed by label and symbol, not color alone.
- The combined week card, day selector, and gap disclosure announce the session
  bucket, exact weekdays, counts, readiness, and typed gaps. Each exercise
  announces its full name, day, order, prescription, selection reason, and lock
  state.
- Real section titles are accessibility headings. Decorative coverage marks
  are hidden after their equivalent combined semantic owner is supplied.
- The DEBUG route opens the sheet directly. Harness identifiers cover the
  sheet, required choice groups, build action, review root, day selection,
  first exercise lock/swap, regenerate, gap state, and save action. Repeated
  child views do not inherit one section identifier.
- Dark, light, Accessibility Extra Large, Reduce Motion, and Differentiate
  Without Color are required review states.

## Persistence, entitlement, and failure paths

V1 adds no persistent `Routine` model and does not change the SwiftData schema.
Saving materializes only existing `WorkoutTemplate` and uniform
`TemplateExercise` entities; generated V1 rows do not require per-set
`TemplateSet` children. Templates append with consecutive `sortOrder` values,
carry one exact selected weekday each, and preserve catalog snapshots through
the existing draft-to-template bridge.

The hidden DEBUG route may open regardless of entitlement so the complete flow
remains verifiable. At save, the entire requested batch must fit the current
free-template allowance. An insufficient allowance presents the existing
template-limit unlock path; it never creates a partial routine.

Save inserts the entire batch, then calls `saveOrRollback()` exactly once. On
failure, the context rolls back all inserted models, the draft remains on the
review screen, and the standard save error is shown. Widget and Spotlight
publication happen only after the successful save. If a reviewed catalog item
disappears before save, validation blocks the transaction and asks the user to
rebuild or swap that slot.

If generation cannot satisfy the chosen hard constraints, the planning sheet
stays open, names the unsatisfied slot or conflicting exercise, and offers no
empty placeholder day. Relaxing equipment, include, avoid, duration, or day
choices is always a user action.

## Non-goals

- No claim of optimality, clinical safety, injury accommodation, or coaching.
- No experience-level inference, exercise difficulty score, fatigue estimate,
  recovery model, progression, autoregulation, deload, or adaptive replanning.
- No starting-weight or percentage-of-1RM prescription.
- No mobility, conditioning, or power programming; no unilateral quota.
- No persistent routine relationship, routine history, cloud service, ML, or
  generated prose.
- No modification of existing templates or active workouts.

## Test and evidence contract

Candidate-projection tests cover hidden bundled-item exclusion. Pure domain
tests cover strength eligibility, implicit bodyweight availability, all three
day topologies and duration budgets, every goal policy, external-equipment hard
filtering, hard include/avoid constraints, movement and muscle coverage,
redundancy penalties, stable ordering, familiarity tie-breaks,
locks, swaps, deterministic unlocked regeneration, typed reasons/gaps,
insufficient catalog matches, and input-order determinism.

Persistence tests cover multi-template materialization, exact weekdays,
consecutive ordering, catalog snapshots, capacity preflight and save-time
drift, one atomic save, and zero persisted rows after a forced failure. Existing
template start/history-prefill contracts remain green.

Recommended semantic scenarios:

- `strength-routine-builder-hidden`: prove the empty and populated public
  Library surfaces expose manual template creation but no builder entry.
- `strength-routine-builder`: enter through the DEBUG route, choose a
  deterministic 3-day/45-minute fixture, inspect review semantics, save,
  relaunch, and prove all three scheduled templates exist.
- `strength-routine-builder-insufficient-catalog`: a bodyweight-only draft
  exposes truthful missing-pattern blockers and no saved template.
- `strength-routine-builder-template-cap`: a free-tier fixture cannot create a
  batch beyond remaining capacity and reaches the existing unlock path without
  inserting models.

Inspect settled review screenshots and accessibility trees in dark and light
appearance at standard size, plus Accessibility Extra Large. The five-second
check is: selected weekdays are obvious, ready/gap state is dominant, the
current day's exercises are scannable, and Save or the corrective action is
immediately findable.
