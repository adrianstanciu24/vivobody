# Template loads follow explicit intent

- Status: accepted
- Date: 2026-09-16
- Owners: Vivobody maintainers
- Supersedes: none

## Context

Saved catalog seed weights become stale. Workout startup previously remembered
recent loads and reps while previews and planned snapshots retained the old
prescription, giving three different meanings to one template.

## Decision

Templates own workout structure and repetition/time targets. An explicit policy
chooses compatible remembered load or fixed programming. A shared resolver owns
preview/startup values. Planned-load snapshots capture the resolved session plan.

SchemaV2 persists this policy and a starting-load presence flag. Freeze V1's
stored graph separately; lightweight migration preserves existing templates as
fixed plans rather than guessing whether their saved loads were deliberate.

## Consequences

Ordinary new templates remember training naturally. Existing templates require
an explicit switch. Changing a target does not pretend that the last logged
weight is a personalized recommendation. Legacy sessions remain unchanged.

## Evidence

[Contract](../../specs/template-starting-loads.md),
[resolver](../../vivobody/Models/Domain/TemplateLoadResolution.swift),
[migration boundary](../../vivobody/App/Persistence.swift),
[persistence contracts](../../vivobodyTests/PersistenceStoreContractTests.swift),
and [focused scenario](../../Scripts/verify_scenarios/template-starting-loads.json).
