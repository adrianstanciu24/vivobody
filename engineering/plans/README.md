# Workflow, handoffs, and execution plans

## Request boundaries

| Request | Authorized work | Completion boundary |
|---|---|---|
| Review or investigate | Read, inspect, and report; run relevant non-mutating checks | Findings and evidence, without edits unless fixes were requested |
| Make a plan | Inspect contracts and prepare an executable plan; write a plan file when useful | Deliver the plan and wait for implementation authorization |
| Implement or fix | Complete the requested change and proportional verification | Reviewable result, documentation updates, and explicit remaining gaps |

Approval and steering persist across turns. An implementation request does not
require another approval for routine steps within its scope. If genuinely new
scope needs a decision, finish the independent authorized work and present the
concrete proposed change. Preserve unrelated work and disclose overlapping edits.

## Current work and handoffs

[worklog.md](../../worklog.md) is a compact handoff for the current task. Update
it when the task, scope, next action, or verification state changes. A completed
entry is not an instruction to resume that work. Use this shape:

```markdown
# Current work

- Status: active | blocked | completed | idle
- Updated: YYYY-MM-DD
- Task: requested outcome, or none
- Authorized scope and steering: explicit boundaries and accepted decisions
- Plan/contract: links, or no plan needed with a short reason
- Progress: completed milestones and unresolved issues
- Next action: one concrete action, named unblock condition, or none
- Worktree: baseline revision and relevant uncommitted/overlapping changes
- Verification: command, result, tested revision or working-tree scope, evidence location
```

Record verification as pending until it actually runs. For an uncommitted
change, say “working tree based on `<revision>`” and identify the tested scope;
do not imply that the base commit contains the change. Local `.verify/` artifacts
are ignored by Git: describe the command/result in the handoff and attach needed
evidence to the review rather than assuming another checkout has those files.

At completion, move lasting behavior and user decisions into the active spec,
product principles, or a decision record. Record substantial results in the
completed plan when there is one. Mark the task completed with no next action;
replace its details when a new task starts. Do not accumulate a session diary
or carry old test results forward as evidence for a new change.

## When to create an execution plan

Checked-in plans are for expensive, risky, or multi-session work where losing
context would create rework or product risk. Use them for persistence
migrations, HealthKit or StoreKit changes, widgets, watchOS, large UX changes,
and similarly cross-cutting work. Small changes do not need a plan file.

Active plans live in [active/](active/). Completed plans move to
[completed/](completed/) after their result and evidence are recorded.

A useful plan is executable by another contributor and stays current while
work proceeds. It contains:

- outcome and non-goals;
- relevant source, specs, and decisions;
- risks, invariants, and rollback or recovery strategy;
- ordered milestones with observable completion criteria;
- validation commands plus device/manual checks;
- progress notes and newly discovered facts;
- final result, deviations, and evidence.

Do not copy schema versions, target settings, or other volatile inventories
into a plan unless the exact before/after value is the subject of the change.
Link the source of truth instead.
