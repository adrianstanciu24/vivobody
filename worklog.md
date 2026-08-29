# Current work

Goal: add the first reviewed wave of missing commercial-gym machine exercises
without weakening source-exact catalog contracts.

Candidates: assisted dip, seated machine triceps extension, lever machine glute
kickback, upper-arm-pad pec-deck fly, machine hip thrust/glute drive, and seated
abdominal-crunch machine.

Progress:

- Duplicate and alias scan completed; no exact active duplicates.
- Independent evidence, catalog-boundary, and product-semantics discovery and
  post-draft reviews completed.
- The coordinating agent is the only writer for catalog sources, evidence,
  generated output, documentation, and tests.
- Four exact fixtures are active in the draft. Machine hip thrust and seated
  abdominal crunch remain proposal-only with concrete evidence unlocks.
- All three independent post-draft reviewers approve the evidence, family
  boundaries, search behavior, and product semantics.
- Final catalog: 85 active families, 206 exercises, and 227 evidence sources.
- `Scripts/catalog.py --check`, all 429 Python catalog tests, 37 targeted Swift
  tests, and `Scripts/check.sh` pass.
- The assisted-dip, pec-fly, pec-fly Accessibility Large, and active-assistance
  Baguette scenarios pass with inspected screenshots and accessibility trees.
- The exercise-detail muscle-role legend now adapts at accessibility sizes:
  full-width stacked role rows prevent awkward word wrapping while preserving
  the compact standard-size layout and combined VoiceOver labels.

Final review: no actionable catalog, runtime, search, or verification findings
remain. Unrelated worktree changes were preserved.

User steering: use multiple agents for this first wave.
