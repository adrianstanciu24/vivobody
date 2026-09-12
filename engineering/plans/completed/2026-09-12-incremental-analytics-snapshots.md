# Incremental analytics snapshots

- Status: completed
- Started: 2026-09-12

## Goal

Move production archive graph reads out of SwiftUI's main-actor feeder. A
long-lived SwiftData `ModelActor` owns immutable session snapshots and replaces
only sessions affected by persistent-history transactions. `SessionAnalytics`
keeps its existing generation checks and background report worker.

## Boundaries

- `AnalyticsFeeder` observes saves only as wake-up signals and passes the shared
  snapshot actor, never models or a `ModelContext`, across the actor boundary.
- The app root creates one actor from the production or fallback container and
  injects it into both the feeder and widget writer.
- Cold launch and expired history tokens rebuild the complete snapshot off the
  main actor. Normal inserts, corrections, and deletions rebuild only affected
  archived session graphs.
- Reassembling the ordered value snapshot remains O(archive), and the analytics
  worker still replays the complete immutable graph. Both operations remain off
  the main actor; the O(delta) claim applies to SwiftData relationship faulting
  and model-to-value conversion.
- This work removes O(archive graph) main-actor faults; incremental report
  algorithms are a separate optimization.

## Verification

- Focused tests cover inserted, changed, deleted, and active-to-archived session
  graphs in the snapshot store.
- `analytics-incremental-archive` passed, including a runtime assertion for a
  delta refresh after an archive save.
- `exercise-detail-weekly-volume` passed with four sessions and the expected
  weighted-set analytics in its accessibility tree.
- Documentation inventory, documentation validation, and `git diff --check`
  passed. Structural searches confirm the feeder and widget writer own no
  full-archive query.
