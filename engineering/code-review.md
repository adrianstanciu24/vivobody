# Code review

Review for behavioral and architectural risk first. Formatting-only findings
belong in automation, not in a human or agent review report.

## Review order

1. Read the request, relevant spec or plan, and the diff.
2. Trace changed state from its source through persistence and side effects.
3. Check failure, restoration, and repeated-action paths.
4. Compare the implementation with the boundaries in
   [ARCHITECTURE.md](../ARCHITECTURE.md).
5. Confirm the evidence required by
   [verification.md](verification.md) exists and matches the changed behavior.

## Findings bar

Report a finding only when it has a concrete impact: incorrect behavior, data
loss, duplicate side effects, stale external state, a broken boundary,
accessibility failure, launch regression, or missing verification for a risky
path. Include the file and smallest useful line range, explain the trigger and
impact, and suggest the established safe path when one exists.

If no actionable findings remain, say so and identify any residual risk or
manual verification gap.

## Repository checklist

### State and persistence

- Does every user mutation persist, surface save failure, and preserve rollback
  behavior?
- Can restoration repeat safely without duplicating sessions, HealthKit writes,
  Live Activities, notifications, or widget snapshots?
- Does a model change match the policy in `vivobody/App/Persistence.swift` and
  preserve the fallback in `vivobody/vivobodyApp.swift`?
- Are edits to model-child collections buffered with value drafts where direct
  mutation could leak partial state?

### Boundaries

- Is SwiftData still app-owned, with widgets reading only snapshots?
- Did shared app/widget code move to `VivoKit` instead of reaching across
  targets?
- Do lifecycle effects route through `SessionSideEffects` and external actions
  through the central parser/handler?
- Are system-framework imports and sensitive call sites still within the
  executable allowlists?
- Do diagnostic events route through `AppDiagnostics`, use stable kinds, and
  exclude user-owned values and identifiers?
- Does new launch work have a critical-path reason, a frequency bound, and a
  deferral strategy where possible?

### UI and accessibility

- Does the flow preserve workout state and keep primary actions thumb-reachable
  with 44pt-or-larger targets?
- Does it reuse the component kits and weight-formatting boundary?
- Are meaningful controls represented semantically, with stable identifiers
  only where scenarios need them?
- Does Reduce Motion remain respected, and does a screenshot/tree review cover
  the changed state?

### Analytics and integrations

- Are insights pure, deterministic, and fed through the shared analytics cache?
- Do widget payload changes bump their contract and retain an old/missing-data
  fallback?
- Are HealthKit and StoreKit behaviors idempotent and non-blocking to workout
  logging?
- Are App Group writes batched rather than added to per-keystroke paths?

### Documentation and tests

- Are changed source headers still accurate?
- Does a durable architectural change update `ARCHITECTURE.md` and, when needed,
  an engineering decision?
- Does a spec status or implementation link need updating in
  [specs/index.md](../specs/index.md)?
- Are tests focused on behavior and deterministic time, rather than private
  implementation detail?
- Did an oversized file grow, or can a reduced size allowance be tightened?
- Is a repeated correction captured at the appropriate durable layer described
  in [quality.md](quality.md), rather than only explained in the current diff?
