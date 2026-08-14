# Technical debt

This is a small, evidence-backed ledger of known compromises. It is not a
wishlist or issue dump. Add an entry only when the debt is confirmed in source,
has a concrete cost, and has a clear exit condition.

## Status vocabulary

- **Open** — confirmed and worth fixing when its trigger arrives.
- **Scheduled** — owned by an active execution plan.
- **Blocked** — cannot proceed until a named external condition changes.
- **Resolved** — move the entry to the resolved section with verification.

## Open

### Remove the orphaned template detail screen

- Status: Open
- Last checked: 2026-08-14
- Evidence: `vivobody/Screens/Library/TemplateDetailScreen.swift` defines
  `TemplateDetailScreen`, but repository search finds no construction site.
  Library creation and editing use `TemplateEditorScreen` with `TemplateDraft`.
- Cost: dead UI and duplicate template-editing code increase review surface and
  can mislead contributors toward an unused pattern.
- Exit condition: delete the orphaned screen, update stale comments that name
  it, then pass `Scripts/check.sh` and manually verify template creation/editing
  if any shared code changes.
- Plan required: No, unless removal reveals a user-visible flow redesign.

## Entry template

```markdown
### Short title

- Status: Open | Scheduled | Blocked
- Last checked: YYYY-MM-DD
- Evidence: file, command, or reproducible behavior
- Cost: concrete maintenance or product impact
- Exit condition: observable completion criteria
- Plan required: Yes/No, with link when Yes
```

## Resolved

Resolved items should stay only when their history prevents recurrence. Record
the resolution date, implementation link, and verification, then remove routine
cleanup notes after they no longer add decision value.
