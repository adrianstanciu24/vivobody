# Active execution plans

Keep one Markdown file per in-progress high-risk or multi-session change. Name
it `YYYY-MM-DD-short-title.md`, link the governing spec or decision, and update
progress as facts change.

Start with this compact template:

```markdown
# Outcome

- Status: proposed | active | blocked
- Started: YYYY-MM-DD
- Spec/decision: links
- Authorized scope: request or approval, and any implementation still awaiting approval
- Baseline revision: commit and relevant existing working-tree changes

## Goal and non-goals

## Invariants and risks

## Rollback or recovery

## Milestones

- [ ] Step with observable result

## Verification

## Progress and discoveries

## Next action and handoff
```

When complete, add the result and verification evidence, change the status,
and move the file to [../completed/](../completed/).
