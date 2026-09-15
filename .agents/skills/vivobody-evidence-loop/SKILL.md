---
name: vivobody-evidence-loop
description: Track hypotheses, expected observations, and evidence during explicitly requested Vivobody bug fixes or uncertain implementation work. Use only when the user invokes this skill.
---

# Vivobody evidence loop

Use small, evidence-driven steps to complete the user's task. This workflow is
explicit-only; do not activate it merely because a task seems difficult.
User instructions take precedence over skill guidance. Preserve the task's scope
and existing authorization; invoking this skill does not authorize implementation
of a review or plan, commits, external messages, or broader verification.

## Start and resume

Read the repository [AGENTS.md](../../../AGENTS.md) and its task-specific routing.
Inspect `git status --short` before edits. Identify the requested outcome, relevant
contract, and what observable result would establish success. Distinguish facts,
hypotheses, and gaps in the available evidence.

For implementation, keep a task note at
`.verify/evidence-loop/<task-slug>-<unique-id>.md`, relative to the repository root.
This directory is already ignored. Reuse a note only when it belongs to this task;
never overwrite another task's note. Include the goal, task identifier, branch,
and starting commit, followed by these sections:

- Verified facts: each with the command/result or artifact that supports it.
- Ruled out: explanations rejected by evidence, with the reason.
- Open questions: current hypotheses and missing evidence.
- Surprises: observations that contradicted expectations.
- Next action: the next useful step and its expected observation.

Keep the whole note under 60 lines. Update it when evidence, the hypothesis, or
the next action materially changes; prune stale entries. Read it when resuming
this task and after compaction while this skill is active. Compare its branch,
commit, and relevant file state with the current checkout before trusting old
evidence. A note survives on disk but does not automatically activate the skill
in a new session; give its path in the handoff. For read-only requests, keep these
notes in the response unless the user permits a scratch file.

## Act, observe, adjust

Before a meaningful edit or diagnostic probe, briefly state the hypothesis and
expected observation. Predict an observable result, not just command success:
for example, "Expect: restoring this fixture exposes two active sessions."
Routine reads and individual shell commands do not each need narration.

For a bug, reproduce the failure with an existing focused check when practical.
Do not require a new test or a failing-test-first ritual for every change.
Make one coherent change, then use the smallest relevant verification from
[the verification guide](../../../engineering/verification.md#default-agent-validation).
Non-UI work normally needs an incremental affected build; UI or interaction work
needs a focused Baguette check with inspected evidence. Baguette already builds.
Do not run it after every tiny edit or add a separate build before it.

Compare the result with the prediction. On a mismatch, investigate before making
further dependent changes. Record what the result establishes and what it leaves
unknown. Compilation does not establish runtime behavior; a scenario establishes
only the states and assertions it actually exercised.

After two equivalent failures, stop repeating that approach. Change the
hypothesis or obtain new diagnostic evidence before another attempt. Continue
safe, in-scope investigation independently; ask the user only when progress
requires missing information, new authority, or resolution of a material contract
conflict. Do not bypass permission or authentication boundaries. Existing
authorization remains valid; do not ask for it again.

## Finish

Review the diff against the requested outcome and contract. Record the final
evidence and remaining gaps in the task note. Report the result, exact check and
its outcome, unverified behavior, and note path briefly. Do not claim behavior
was tested when only a build ran. Leave deeper validation to the user unless
requested. Commit or launch a separate review agent only when explicitly requested.
