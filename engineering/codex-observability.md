# Codex workflow recording

This project records local Codex tool activity and readable worker handoffs.
Start the normal interactive CLI from this checkout:

```bash
codex
```

On a new machine, review the project hooks with `/hooks` and trust the nine
definitions from `.codex/hooks.json`. The project itself must also be trusted.
Hooks are enabled by default in the tested CLI. Check `/hooks` after changing
their definitions; changed definitions need review again. Setup does not change
the sandbox, approval policy, model, or delegation policy.

Talk to Codex normally. The hooks record activity automatically. When an agent
delegates, the procedure below supplies readable instructions and result/review
records that ordinary hook payloads alone may not expose. Record only actual
delegation; a question or a small direct edit does not need an artificial worker.

Reports refresh when a turn stops, the session is interrupted, or the main
session ends. To list sessions or refresh a specific report from a terminal:

```bash
/usr/bin/python3 Scripts/codex_observe/report.py --list
/usr/bin/python3 Scripts/codex_observe/report.py --latest
/usr/bin/python3 Scripts/codex_observe/report.py --session SESSION_ID
```

The printed path points to `.verify/codex-observe/SESSION_ID/report.md`. Its JSON
companion supplies machine-readable task records, timeline, and evidence gaps.
Reports and raw records remain local and Git-ignored. Each concurrent session
has its own directory. Commands work in a Git worktree when the scripts and hook
configuration are present there; worktrees record separately.

Writable records live under `.verify/` because the normal Codex workspace
sandbox protects `.codex/` recursively. Only hook configuration belongs there.

## What is installed

| File | Responsibility |
| --- | --- |
| [Project hooks](../.codex/hooks.json) | Invoke the recorder for session, prompt, tool, worker, and stop events |
| [record_hook.py](../Scripts/codex_observe/record_hook.py) | Save hook payloads, bind worker IDs to the root session, refresh reports at turn boundaries |
| [workflow.py](../Scripts/codex_observe/workflow.py) | Save task revisions, acknowledgments, file snapshots, checks, and decisions |
| [report.py](../Scripts/codex_observe/report.py) | Link task receipts to observed actors and produce the report |
| [store.py](../Scripts/codex_observe/store.py) | Shared path validation, atomic storage, and per-task locking |

Interactive recording uses hook session IDs directly. It does not require an
`exec --json` launcher. The same project hooks also run for `codex exec`.

## Procedure for assigning agents and workers

Use `/usr/bin/python3 Scripts/codex_observe/workflow.py` for the commands below.
The helper reads `CODEX_THREAD_ID` and the hook's worker-to-session binding;
`context` reports the selected session and actor. Never use `--latest` to choose
a task's session. An explicit `--session SESSION_ID` before the subcommand is
available for terminal inspection/recovery; it is not proof of an observed actor.

1. Before delegation, the assigning agent runs `create` with a title, the full
   readable instructions, one or more `--criterion` values, and any initially
   known individual `--file` paths. Include ownership, allowed edits, constraints,
   and the checks expected for the task in the instructions. Save **all substantive
   handoff instructions** in this assignment, not only a summary of an encrypted
   outgoing message. The output includes the task ID, revision, and saved path.
2. Delegate with that task ID, revision, session ID, and assignment path. The
   worker runs `read`, reads the returned instructions, then runs `ack` with the
   exact returned SHA-256. One worker owns each assignment revision. It then works
   within the assigned scope and runs `submit` with a result summary and every
   affected file. Include deleted files too. A read-only task can submit findings
   as the summary or as a named report file.
3. The assigning agent inspects the submission and runs `check` for the task's
   actual verification commands. The helper captures exit status, duration,
   combined output, and the exact submitted file manifest before/after the check.
   Choose checks from [verification.md](verification.md); recording does not
   replace project verification or prove criteria the command does not test.
4. Run `decide --status accepted --reason ...` only when the recorded checks and
   review justify acceptance. For a correction, use `--status correction_requested`
   with a reason and complete revised instructions. This saves the next assignment
   revision. The worker reads/acknowledges it and submits a new result. Old
   assignments, file snapshots, and check output remain intact. A correction may
   follow a passing command when review reveals an unmet requirement.

Example command shapes (replace the uppercase placeholders):

```bash
/usr/bin/python3 Scripts/codex_observe/workflow.py context
/usr/bin/python3 Scripts/codex_observe/workflow.py create --title "TASK_TITLE" --instructions "FULL_INSTRUCTIONS" --criterion "SUCCESS_CRITERION" --file Scripts/example.py
/usr/bin/python3 Scripts/codex_observe/workflow.py read --task TASK_ID --revision 1
/usr/bin/python3 Scripts/codex_observe/workflow.py ack --task TASK_ID --revision 1 --sha256 ASSIGNMENT_SHA256
/usr/bin/python3 Scripts/codex_observe/workflow.py submit --task TASK_ID --revision 1 --summary "RESULT_SUMMARY" --file Scripts/example.py
/usr/bin/python3 Scripts/codex_observe/workflow.py check --task TASK_ID --revision 1 --command "PROJECT_CHECK_COMMAND"
/usr/bin/python3 Scripts/codex_observe/workflow.py decide --task TASK_ID --revision 1 --status accepted --reason "REVIEW_REASON"
```

`check` runs the provided shell command from the repository root with a default
600-second timeout (`--timeout` changes it). It returns exit 1 when verification
fails and exit 2 on a protocol error. It requires submitted files to match their
snapshot. Acceptance requires recorded passing checks, unchanged check logs, and
the same files still present. Any failure remains in that revision; use a recorded
correction and a new submission for a retry. Multiple workers can operate on
different tasks concurrently. Scope disjoint files when assigning concurrent edits.
Snapshots accept individual regular files, including deleted paths. Symlink
artifacts are rejected explicitly; name their actual regular-file targets.

## Reading the evidence

The task table shows assignment and review state. Timeline rows link to the
exact saved event or hook. “Receipts linked” means the task event's bytes and
identity matched a captured tool-output receipt from the recorded agent. It
does not prove that the worker understood the instructions or that every
requirement was checked. Main-agent acceptance is distinct from user acceptance.
The report also checks preserved assignment, artifact, and verification-log
hashes. Missing files and changed evidence appear as gaps. Worker labels map to
full thread IDs so workers started together remain distinguishable.

General tool rows identify the agent, not a guessed task. Missing completion or
exit status stays unknown. Exact shell exit values can be added from the run's
own native transcript when the installed format is recognized; task-helper
checks capture their own exit values independently. Transcript parsing is
optional and version-dependent. Reports never decrypt collaboration payloads
or display private reasoning.

Receipt timestamps are approximate UTC wall times. The report does not classify
unobserved time as idle work or infer wasted effort from a wait. Hooks do not
observe every hosted/specialized tool. Missing task receipts, absent session-start
events, and malformed records appear under evidence gaps. If recording fails,
Codex continues and the recorder prints a diagnostic; it never forces another
agent turn or changes a tool call.

Records are create-only through the helper and atomically published. Reports
are replaceable views. This is a local diagnostic tool, not a tamper-proof audit
service. Raw hook payloads can include prompts, command output, and source text;
share only the evidence needed for a review. No logging service or runtime app
dependency is added. Hook trust covers definitions; review script changes too.

## Verification and maintenance

```bash
/usr/bin/python3 -m unittest discover -s Scripts/tests -p 'test_codex_observe.py'
/usr/bin/python3 Scripts/check_documentation.py
git diff --check
```

After changing hooks, run a small interactive task and a second conversation
turn. Verify one root session, the expected worker identities, linked task
receipts, and a refreshed report. Keep live smoke-test files under `.verify/`.
The automated suite covers parallel storage, session isolation, revision and
actor checks, failed verification, changed artifacts/logs, and report gaps.

Disable project recording through `/hooks`; remove the recording section in
`AGENTS.md` when retiring the task helper. Historical records remain available
until you explicitly remove `.verify/codex-observe/`.

Source: [official OpenAI hook documentation](https://learn.chatgpt.com/docs/hooks).
