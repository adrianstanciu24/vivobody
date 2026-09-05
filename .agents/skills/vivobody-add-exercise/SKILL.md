---
name: vivobody-add-exercise
description: Research, propose, review, or add a named exercise to Vivobody's canonical family-first catalog using biomechanics evidence, explicit family-boundary gates, independent reviewers, catalog validation, and UI evidence. Use for catalog exercise authorship or family-ownership decisions. Do not use for runtime user-created exercises, workout-plan selection, substitutions, or UI-only copy changes.
---

# Vivobody Add Exercise

Use this repository-specific workflow to turn a proposed exercise into one of four honest outcomes: `no-op alias`, `added`, `proposal awaiting approval`, or `blocked by evidence`.

Read [references/workflow.md](references/workflow.md) completely before researching or editing. Read [references/review-packet.md](references/review-packet.md) when preparing the synthesis and final report.

## Establish the request

Collect or infer:

- the exercise's conventional name and aliases;
- exact athlete position, implement path, support, grip, range of motion, and equipment;
- intended modality, tracking, load semantics, and laterality;
- any user-supplied video, image, manufacturer page, or source.

Ask one concise question only when missing geometry could change duplicate detection or family ownership. Treat a name alone as insufficient whenever it can describe materially different mechanics. State benign assumptions explicitly.

Respect the requested action boundary. A request to research or review does not authorize catalog edits. A request to add an exact exercise authorizes the smallest exercise-specific family addition or local contract expansion needed to represent it. Shared schema, taxonomy, or anatomical-capability changes still need explicit owner approval.

## Run the graph

1. Read `AGENTS.md`, `specs/index.md`, `specs/catalog/README.md`, the closest family files and relevant proposals, and verification guidance. Use [references/workflow.md](references/workflow.md) for the operating procedure, including batch coordination. The completed catalog roadmap is historical context only. Inspect `git status --short` and preserve unrelated changes.
2. Search canonical family rosters and aliases before browsing. End as `no-op alias` when the candidate is already represented; explain the exact match and do not manufacture a second record.
3. Form a closest-family hypothesis from authored mechanics, never from the exercise name alone.
4. Tell the user when this skill is fanning out independent review lanes. Use the biomechanics, catalog-boundary, and product-semantics lanes proportionally: run all three for new families, shared semantics, or ambiguous fixtures; a routine exact fixture may combine evidence and product review while preserving an independent boundary review. Give each reviewer a bounded task and require the packet defined in the workflow reference.
5. Synthesize claims rather than tallying votes. Route a resolvable disagreement back to the responsible lane once. Block unresolved conflicts instead of selecting the permissive interpretation.
6. Apply the evidence and contract gates:
   - Use the fast lane when the exact exercise fits an active family without changing `fixed`, `allowed`, `movementSignature`, `musclePolicy`, `variantAxes`, `exerciseRules`, shared taxonomy, or joint-action capabilities.
   - When the owner explicitly asked to add the exact exercise, integrate the smallest local new-family or existing-family delta after review. Pause for approval only when the request was review-only or admission changes shared schema, taxonomy, anatomical capabilities, or an existing family beyond the named fixture.
   - Prepare a blocked proposal with a concrete unlock when exact mechanics, anatomy, or primary evidence are insufficient. Write it to the repository only when the request authorizes changes.
7. For an authorized addition, let only the coordinating agent edit shared catalog files and generated output. Reviewers remain read-only.
8. After the draft, run independent evidence and contract reviews. A reviewer must not approve its own work. Feed concrete failures back to the draft once, then re-review the changed claims.
9. Run the deterministic catalog and repository gates from the workflow reference. Because a catalog addition is user-visible, also inspect Library discovery and exercise-detail semantics unless the request stopped at a proposal.
10. Return the review packet with source links, gate decisions, changed files, verification evidence, and remaining uncertainty. Never call a blocked or proposal-only result “added.”

## Non-negotiable catalog rules

- Keep the source of truth in `specs/catalog/`; never hand-edit `vivobody/Resources/catalog.json`.
- Preserve family-first `fixed` / `allowed` / `recommended` semantics and role-aware muscle authorship.
- Never infer biomechanics, axes, aliases, or topology from prose names.
- Prefer categorical, reviewable facts over universal percentages or false precision.
- Use primary research for biomechanical claims and authoritative technical standards for conventional fixture geometry. Existing anatomical capability evidence may support transparent categorical inferences. Exact exercise-specific EMG is required only for a new capability or a quantitative, ranked, comparative, medical, or otherwise surprising claim; its absence is not a blocker by itself.
- Register evidence in `evidence.json` only when an active capability, family, or exercise references it. A proposal may cite a source without registering unused evidence.
- Keep one writer for shared registries, schemas, central tests, and generated output.
