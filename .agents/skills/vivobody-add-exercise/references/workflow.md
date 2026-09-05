# Exercise Addition Graph

This graph converts a proposed exercise into an auditable catalog decision. Agent count is an implementation detail; the gates and artifacts are the workflow.

```text
intake
  -> duplicate / alias gate ----duplicate----> no-op alias
  -> closest-family hypothesis
       -> biomechanics research -----------\
       -> catalog-boundary review ----------+-> synthesis
       -> product-semantics review --------/
                                                -> evidence gate
                         insufficient/conflict -> blocked proposal
                                                -> contract gate
                   shared/unrequested change --> proposal + owner approval
                   authorized local contract --> draft exercise
                         unchanged contract ---> draft exercise
                                                   -> evidence review ----\
                                                   -> contract review -----+-> integration gate
                                                   -> product review -----/
                                                       fail -> feedback loop
                                                       pass -> one-writer integration
                                                           -> catalog compiler/tests
                                                           -> repository check
                                                           -> UI evidence
                                                           -> added
```

## Intake contract

Record the candidate as an exact fixture, not merely a label:

- names and aliases;
- start, transition, and end positions;
- athlete-to-implement geometry and resisted direction;
- open or closed kinetic chain;
- external support and constrained surfaces;
- grip, stance, range of motion, and meaningful angles;
- equipment and whether its path is free, rail-guided, lever-guided, or otherwise constrained;
- unilateral or bilateral execution;
- intended modality, set tracking, and load semantics;
- source of the requested variation, including a video or manufacturer model when relevant.

If two common interpretations would cross a family boundary, do not pick one silently. Request the missing fixture.

## Gate 1: duplicate and alias

Search family exercise IDs, names, aliases, and reviewed proposals. Compare authored axes and mechanics, not normalized strings alone.

Return `no-op alias` when the proposed movement is already represented by the same fixture. Recommend an alias addition only when the name is genuinely useful, unambiguous, and supported by the existing record. A marketing name does not create a new exercise.

## Parallel discovery lanes

Each lane is read-only and returns a compact packet. Use all three lanes for a new family, ambiguous fixture, or shared semantic change. For a routine exact fixture, evidence and product semantics may be combined, but family-boundary review remains independent. Give subagents the exact candidate fixture, repository root, closest-family hypothesis, and a prohibition on editing files.

### Multi-exercise batches

For an authorized batch, divide candidates into independent family/evidence
review slices and assign a separate cross-family audit of shared vocabulary,
anatomy gaps, evidence identity, schema, and negative fixtures. The coordinator
integrates findings and is the sole writer of shared taxonomy, evidence,
schemas, documentation, central tests, family files, and generated output.

Integrate each supported family only after its own contract, roster, and review
are ready. Keep blocked candidates as proposals with concrete unlocks; they do
not block unrelated supported candidates. Reviewers exchange contracts instead
of approving their own work. Preserve per-family rule mutations and roster
coverage, then run cross-family boundary and global identity/evidence checks.
Agent count follows the independent work available; the completed roadmap is
decision history, not an additional operating procedure.

### Biomechanics researcher

Responsibilities:

- search current online primary literature for the exact or nearest defensible fixture;
- map each claimed joint action, plane, support constraint, and muscle-role implication to a source;
- distinguish direct measurement from inference;
- identify source geometry mismatches and conflicting evidence;
- report what the evidence cannot establish.

Return:

```text
Candidate fixture:
Search terms and date:
Sources: title | stable URL/DOI/PMID/PMCID | study type | exact fixture
Claim map: claim | source | direct/supporting/inferred | limitation
Conflicts:
Evidence verdict: sufficient | insufficient
Concrete unlock if insufficient:
```

### Catalog-boundary reviewer

Responsibilities:

- identify duplicates and the nearest active families;
- compare every candidate value with `fixed`, `allowed`, `movementSignature`, `musclePolicy`, `variantAxes`, and `exerciseRules`;
- name every proposed contract delta instead of describing the fit as “close”;
- test neighboring-family exclusions and likely cross-family collisions;
- classify the result as unchanged-family fit, contract expansion, new family, or unsupported.

Return:

```text
Duplicate result:
Closest family and neighbors:
Field-by-field fit:
Required contract deltas:
Negative-boundary cases:
Boundary verdict:
```

### Product-semantics reviewer

Responsibilities:

- review modality, equipment, laterality, load kind, resistance comparability, and set tracking;
- confirm that setup and execution can be explained without medical or sensing claims;
- identify whether app anatomy can represent every authored region truthfully;
- flag any persistence, UI, search, or history behavior affected beyond catalog data.

Return:

```text
Modality and tracking:
Load semantics:
Equipment and laterality:
Instruction boundary:
Anatomy/product gaps:
Product verdict:
```

## Research quality gate

For every non-duplicate addition, browse the current web even when local evidence appears reusable. Prefer stable primary routes such as DOI, PubMed, PMC, the journal article, or an official technical standard.

Evidence is sufficient when:

- an authoritative technical standard, exact study protocol, or owner-specified fixture is precise enough to defend family ownership and declared axes;
- categorical joint-action and muscle-role claims are either directly supported or transparently bounded inferences;
- contradictory sources are reconciled by fixture, method, population, or measurement differences;
- limitations are explicit and no claim depends on a commercial name or generic coaching prose;
- every active evidence entry will be referenced by a capability, family, or exercise.

An authoritative technical standard may establish conventional setup, execution, and endpoints without DOI-backed exercise-specific research. Existing primary anatomy, moment-arm, and musculoskeletal-model evidence may establish possible actions and stabilizing capability; a family may then make a transparent categorical anatomy-and-mechanics inference for the exact fixture. Exact exercise-specific EMG is required only when adding a new anatomical capability or making a quantitative, ranked, comparative, medical, or surprising claim. Its absence alone is not an evidence failure.

Do not use blogs, exercise databases, search snippets, or vendor marketing as biomechanical proof. They may clarify what variation the user means. Do not convert EMG amplitude into force, hypertrophy, or universal percentages. Do not present OpenSim or another model as measured physiology. Do not infer medical benefits from coaching standards.

When evidence is insufficient and file changes are authorized, create or update `specs/catalog/proposals/<candidate>.md` with the reviewed fixture, candidate boundary, sources, rejected inferences, and a concrete unlock. For a review-only request, return the same proposal-ready content without writing it. Do not add unused sources to `evidence.json`.

## Contract gate

Choose exactly one path:

| Outcome | Condition | Authorized action |
|---|---|---|
| `no-op alias` | Exact fixture already exists | Explain match; optionally propose a justified alias |
| `fast lane` | Active family accepts every value without contract or vocabulary changes | Draft the exercise and supporting referenced evidence |
| `authorized local contract` | The owner asked to add the exact fixture and it needs a narrow new family or fixture-specific expansion | Draft, independently review, and integrate it |
| `proposal awaiting approval` | The request was review-only, or admission changes shared schema/taxonomy/capabilities or broadens an existing family beyond the named fixture | Write or return proposal; pause before active catalog edits |
| `blocked by evidence` | Fixture, anatomy, or primary evidence cannot support the claims | Write or return blocked proposal and concrete unlock |

Changing an allowed equipment value, axis domain, action, muscle whitelist, rule, taxonomy entry, or joint-action capability is a contract change even if it is only one JSON line. Do not weaken a family merely to admit one exercise.

An explicit request to add a named exact fixture authorizes its smallest local family contract. It does not authorize unrelated variants, a broader family domain, shared schema or taxonomy changes, or new anatomical capabilities. Those surfaces need an explicit owner decision.

## Draft and independent review

For an authorized draft:

1. Edit one family at a time under `specs/catalog/families/`.
2. Add evidence only when the active catalog references it.
3. Keep identifiers stable, categorical roles explicit, and every axis authored.
4. Never edit generated runtime JSON by hand.

After drafting, use reviewers who did not author the changed claims, proportionate to risk:

- evidence reviewer: challenge source identity, claim support, fixture match, and overstatement;
- contract reviewer: run a field-by-field family audit and adversarial neighboring-family cases;
- product reviewer when semantics or instructions changed: challenge tracking, load comparability, anatomy truthfulness, and user copy.

A failing review must cite a concrete unsupported claim, boundary leak, product inconsistency, or missing test. Send that item back to the relevant discovery lane or draft. Re-review only the changed surface plus interactions. If one feedback loop does not resolve a semantic conflict, stop as a proposal or blocked result.

The coordinating agent is the only writer for family files, `evidence.json`, schemas, shared documentation, central tests, and generated runtime output.

## Deterministic gates

Run from the repository root. Start with the narrowest useful checks:

```bash
python3 Scripts/catalog.py --check
python3 -m unittest discover -s Scripts/tests -p 'test_catalog.py'
```

When active catalog source changed, generate through the compiler and then re-check:

```bash
python3 Scripts/catalog.py --emit-runtime
python3 Scripts/catalog.py --check
/usr/bin/python3 Scripts/documentation_inventory.py --write
```

If a family contract changed after explicit approval, add or update per-family rule mutations, exact roster coverage, and cross-family negative fixtures before the global tests.

Finish active catalog or contract changes with:

```bash
Scripts/check.sh
```

An active exercise addition is user-visible. Use the [feature/scenario map](../../../../Scripts/verify_scenarios/README.md#choose-evidence-for-the-change) to choose the smallest relevant flow, then inspect screenshot and accessibility-tree evidence for Library discovery and exercise detail. Proposal-only Markdown changes follow the [prose-only checks](../../../../engineering/verification.md#documentation-and-process-tooling), with no build or UI capture. Changes to active catalog JSON, schema, or generated app inputs still require the full gates above.

Follow the repository's headless, targeted-suite policy; do not run the full simulator suite as part of this workflow.

## Failure handling

- Catalog validation failure: repair the authored source; never patch generated JSON.
- Evidence identity failure: use the canonical source identity and remove duplicates.
- Unused evidence failure: remove the registry entry or connect it to the active claim that truly uses it.
- Cross-family collision: tighten the proposed record or stop for a contract decision.
- Reviewer disagreement: resolve from evidence and explicit contracts, never by majority vote.
- Dirty worktree overlap: preserve user changes; stop if the same lines cannot be safely separated.
