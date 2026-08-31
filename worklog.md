# Current work

Goal: add the exact six evidence-reviewed default catalog fixtures approved on
2026-08-31 without merging distinct equipment, movement, or load histories.

Approved fixtures:

- Single-Dumbbell Goblet Squat; Two-Dumbbell Stationary Split Squat;
  Two-Dumbbell Reverse Lunge.
- Bilateral Dumbbell Shrug; Scapular Pull-Up; High-Handle Trap-Bar Farmer
  Carry, with Trap-Bar Farmer Carry retained as an alias.

Progress:

- All six exact fixtures are authored as five existing-family expansions and
  one new `scapular-pull-up` family; the generated projection is 97 families,
  231 exercises, and 255 evidence sources.
- Full-record and evidence identity digests, exhaustive variant/rule mutations,
  reciprocal equipment rules, aliases, load-entry copy, and negative ownership
  boundaries are pinned by 439 passing catalog tests.
- Independent post-draft review exposed and closed one dumbbell-shrug
  configuration leak; the final lower-body, upper-body/carry, and catalog-
  boundary re-reviews have no outstanding contract blocker.
- `Scripts/check.sh` passes. The headless
  `catalog-default-candidate-follow-up` scenario passes with inspected Library,
  detail, screenshot, and accessibility-tree evidence for the trap-bar carry.

Next:

- None; ready for handoff.

User steering: implement all six exact approved fixtures using multiple agents;
do not substitute adjacent variants or weaken exact source and load boundaries.
