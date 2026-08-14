# Engineering decisions

Use this directory for durable architectural decisions whose rationale will
matter after the implementation diff is gone. Do not create a decision record
for routine refactors, small UI changes, or choices already obvious from code.

Name records `YYYY-MM-DD-short-title.md` and use this shape:

```markdown
# Decision title

- Status: proposed | accepted | superseded
- Date: YYYY-MM-DD
- Owners: names
- Supersedes: links or none

## Context

What constraint or recurring question required a durable choice?

## Decision

What is the chosen boundary or direction?

## Consequences

What becomes easier, harder, required, or intentionally unsupported?

## Evidence

Link source, spec, plan, tests, and verification that prove adoption.
```

When a decision is replaced, keep it, mark it superseded, and link the new
record. Current behavior must still be described by
[ARCHITECTURE.md](../../ARCHITECTURE.md); decision records explain why.
