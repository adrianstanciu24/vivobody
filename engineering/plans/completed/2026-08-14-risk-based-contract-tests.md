# Strengthen risk-based contract testing

- Status: completed
- Started: 2026-08-14
- Spec/decision: user-requested harness-engineering follow-up; no separate product spec

## Goal and non-goals

Allow agents to run targeted unit tests autonomously when logic changes, add a
fast compatibility gate for every VivoKit widget snapshot, and add a checked-in
pre-release SwiftData baseline that the production container must reopen
without losing representative user data.

This work does not run the full simulator suite by default, add a
`VersionedSchema` before V1, invent historical schema versions, or revive the
retired migration plan whose versions all referenced mutable live model
classes.

## Invariants and risks

- The app remains the only SwiftData writer and retains its in-memory recovery
  path.
- The checksum exposes accidental baseline changes. Before V1, an intentional
  breaking schema change may replace the baseline because development data is
  not shipped history. At release, `SchemaV1` and its fixture become permanent.
- Widget readers render their explicit empty value for missing, malformed, or
  obsolete payloads and still accept the pre-envelope legacy shape.
- Fast VivoKit package tests may join the canonical non-UI check. The full iOS
  simulator suite remains opt-in.

## Milestones

- [x] Update testing policy and verification routing.
- [x] Add snapshot codec fallback coverage and use it in widget readers.
- [x] Route app and tests through one production container factory.
- [x] Check in a deterministic baseline store and preservation assertions.
- [x] Run focused contract tests and `Scripts/check.sh`.

## Verification

```bash
swift test --package-path VivoKit
xcodebuild -scheme vivobody \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO \
  test -only-testing:vivobodyTests/PersistenceStoreContractTests
Scripts/check.sh
```

## Progress and discoveries

- Historical schema declarations were not frozen: every version referenced the
  same live model types. They remain removed. The checked-in store is a
  pre-release reopen regression, not a migration fixture; versioned migration
  begins only when the first public release freezes `SchemaV1`.

## Result

- Targeted tests are now the default evidence for logic changes; only the full
  simulator suite remains opt-in.
- VivoKit snapshots are host-testable and explicitly fall back for missing,
  malformed, and obsolete data while retaining the legacy raw payload path.
- `PersistenceBaseline.store` is guarded by checksum, opened from a temporary
  copy through `VivobodyStore`, and asserted down to representative child data.
- The focused persistence suite, five snapshot contracts, checksum gate, all
  repository guardrails, and the generic simulator build pass.
