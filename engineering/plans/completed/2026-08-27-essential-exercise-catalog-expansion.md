# Essential exercise catalog expansion

## Outcome

Add the twenty owner-approved lifter exercises from the 2026-08-27 catalog
gap review, using source-exact fixtures and Vivobody's family-first contracts.
Every candidate ends as an active reviewed exercise or as an evidence-blocked
proposal with a concrete unlock; no candidate is generalized merely to make
the batch complete.

## Non-goals

- Do not add Conditioning or Mobility back to the product.
- Do not redesign Library, exercise detail, or active-workout controls.
- Do not add setup fields, persistence changes, or new joint-action vocabulary
  unless a reviewed candidate cannot be represented truthfully without them.
- Do not treat familiar names, commercial machines, EMG magnitude, or model
  output as universal biomechanics.

## Sources and invariants

- Catalog contract: [specs/catalog/README.md](../../../specs/catalog/README.md)
- Addition workflow: [vivobody-add-exercise](../../../.agents/skills/vivobody-add-exercise/SKILL.md)
- Canonical family sources: [specs/catalog/families/](../../../specs/catalog/families/)
- Runtime output is generated only by `Scripts/catalog.py`.
- The coordinator is the only writer for family files, evidence, schemas,
  shared documentation, tests, and generated output.
- Existing dirty-worktree changes belong to the owner and remain intact.

## Candidate batches

### Lower body

- 45-degree incline leg press
- machine hack squat
- barbell rear-foot-elevated split squat
- bilateral seated leg curl
- bilateral prone leg curl
- seated hip-abduction machine
- seated hip-adduction machine

### Posterior chain, core, arms, and chest

- 45-degree back extension
- hanging knee raise
- hanging straight-leg raise
- standing straight-bar barbell curl
- standing single-arm supinated dumbbell curl
- bilateral cable triceps pushdown
- standing dual-cable crossover
- close-grip barbell bench press

### Power and hold

- power clean
- two-hand kettlebell swing
- hang power snatch
- split jerk
- wall sit

## Risks and recovery

- Multi-phase Olympic lifts may exceed the current single-signature contract.
  If phase semantics cannot be expressed without false actions, retain a
  proposal rather than weakening validation.
- Commercial machine names do not define linkage, support, or range. Admit
  only the exact studied fixture and expose its limits in instructions.
- Family expansions can collide with neighboring contracts. Add negative
  fixtures and mutation coverage before generating runtime output.
- The batch is recoverable because authored source and proposals remain
  separate from generated runtime data. A blocked candidate is removed from
  active family input, not forced through the compiler.

## Milestones

1. Complete three independent discovery packets covering evidence, boundaries,
   and product semantics for all twenty candidates.
2. Integrate evidence-sufficient existing-family expansions and their mutation
   coverage.
3. Integrate evidence-sufficient new families, one contract at a time.
4. Record any unresolved candidate as an evidence-blocked proposal with the
   smallest concrete unlock.
5. Generate runtime catalog output and update catalog counts/documentation.
6. Pass catalog checks, catalog unit tests, `Scripts/check.sh`, and final diff
   review.
7. Verify Library discovery and one representative exercise-detail screen for
   Strength Reps, Power, and Strength Hold; inspect screenshots and
   accessibility trees.

## Validation

```bash
python3 Scripts/catalog.py --check
python3 -m unittest discover -s Scripts/tests -p 'test_catalog.py'
python3 Scripts/catalog.py --emit-runtime
Scripts/check.sh
TAB=library Scripts/verify.sh
```

## Progress

- 2026-08-27: Owner explicitly approved all named new families and existing-
  family expansions. Three read-only discovery lanes started; coordinator
  retained sole write ownership.
- 2026-08-27: All twenty candidates passed the family-boundary and evidence
  gates. Nine new family contracts and ten existing-family additions produced
  twenty active records; no candidate remained evidence-blocked.
- 2026-08-27: Independent lower-body, upper/core, and power/hold reviewers
  approved the final contracts after reciprocal fixture rules, exact action
  sets, evidence disclosures, and adversarial mutations were tightened.

## Final result

Completed on 2026-08-27.

- Runtime catalog: 166 records across 72 family contracts, backed by 187
  registered evidence sources. Conditioning and Mobility remain absent;
  active modalities are dynamic strength, isometric strength, and power.
- Catalog proof: 413 mutation-oriented Python tests passed, generated output
  matched source, and the canonical catalog digest is `5228570709ec`.
- Project proof: `Scripts/check.sh` passed, including architecture,
  documentation, formatting, generated-data, VivoKit, and app-build gates.
- Targeted app proof: `CatalogBiomechanicsTests` passed on iPhone 17 Pro.
- UI proof: `catalog-essential-strength`, `catalog-essential-power`, and
  `catalog-essential-hold` passed with inspected screenshots and accessibility
  trees under `.verify/scenarios/`.
