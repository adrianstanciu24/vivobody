# Freeze SwiftData SchemaV1

- Status: accepted
- Date: 2026-09-14
- Owners: Vivobody
- Supersedes: none

## Context

The unversioned pre-release model graph could be replaced during development,
but it could not serve as a durable compatibility boundary for shipped workout
history.

## Decision

The current model graph is `VivobodySchemaV1`. Production containers use
`VivobodyMigrationPlan`; future model changes add a schema version and migration
stage rather than replacing an existing version or fixture.

## Consequences

The SchemaV1 fixture is permanent. Every later schema must reopen every retained
fixture. Model types remain in their feature files; the versioned schema records
their membership without duplicating their definitions.

## Evidence

See [persistence](../../vivobody/App/Persistence.swift),
[architecture](../../ARCHITECTURE.md), and the
[store contract](../../vivobodyTests/PersistenceStoreContractTests.swift).
