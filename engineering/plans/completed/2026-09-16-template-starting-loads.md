# Template starting loads

Status: Completed on 2026-09-16.

Separate template targets from remembered load references, keeping existing
saved programming intact. Contract: [template starting loads](../../../specs/template-starting-loads.md).

- [x] Freeze SchemaV1 stored models and add SchemaV2 with lightweight migration.
- [x] Resolve fixed/remembered loads once for previews and workout startup.
- [x] Preserve template count, reps and duration and capture resolved load snapshots.
- [x] Add policy controls and explicit first-workout load entry to template editors.
- [x] Add retained SchemaV2 fixture and boundary contracts.
- [x] Verify the focused template flow and inspect dark, light and large text.
- [x] Review final diff and update documentation/checks.

## Verification evidence

All six focused Baguette scenarios passed on the existing headless iPhone 17 Pro,
iOS 26.5 runtime. Their incremental app builds passed. The main flow checks
policy editing, relaunch persistence, matching previews/startup and preserved
8-rep targets. First-load evidence checks the disabled commit before explicit
entry and intentional zero afterward; its prompt has a 44pt accessibility frame.
Light, dark and accessibility-large screenshots and trees were inspected, along
with the Today preview and direct editor.

Artifacts live in `.verify/scenarios/template-starting-loads/` and the matching
`-light`, `-accessibility`, `-today`, `-detail`, and `template-first-load` folders.

Documentation, naming, architecture, complexity and source-size checks passed;
16 architecture-tooling tests passed. Both retained persistence fixture hashes
passed, including the unchanged SchemaV1 fixture. Migration and load-resolution
boundary suites were added but remain user-run under repository policy. These
UI/build checks do not prove legacy-store migration or physical-device VoiceOver.
