# Forearm grip-stabilizer correction

- Status: Active catalog correction; history refresh is outside this change
- Reviewed: 2026-09-16

## Decision

Credit distinct secure-grip and wrist-control co-contributors in the existing
deadlift, suspended pull-up/chin-up, and external overhead-press fixtures.
Every addition is `stabilizer`. Existing anatomical capabilities already permit
these roles; no taxonomy, mesh ownership, schema, or joint-action changes are needed.
This is not a universal rule for exercises involving the hands.

ECU means extensor carpi ulnaris; EDC means extensor digitorum communis
(`fingerExtensors`); ECR means the grouped radial wrist extensors;
FF means the grouped finger flexors. FCR and FCU mean flexor carpi radialis
and flexor carpi ulnaris. EDC credit is control during gripping,
not an authored resisted finger-extension action. These contributors receive
the existing effort-weighted stabilizer training credit as well as faint anatomy
highlighting; the change is not a paint-only workaround.

## Exercise-by-muscle correction table

| Existing exercise | Previous forearm credit | Added stabilizers | Support |
|---|---|---|---|
| Conventional Barbell Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Floor-Touch Barbell Romanian Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Barbell Stiff-Leg Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| 15 cm Step Barbell Romanian Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Continuous Top-Start Barbell Romanian Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Two-Dumbbell Continuous Romanian Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Barefoot Dead-Stop Sumo Barbell Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Low-Handle Trap-Bar Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| High-Handle Trap-Bar Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Barbell Single-Leg Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Ipsilateral-Load Dumbbell Single-Leg Romanian Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Contralateral-Load Dumbbell Single-Leg Romanian Deadlift | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Pull-Up | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Chin-Up | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Neutral-Grip Pull-Up | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Wide-Grip Pull-Up | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Assisted Pull-Up Machine | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Assisted Chin-Up Machine | ECR, FF: stabilizer | ECU, EDC, FCR, FCU | Exercise-category and grip/wrist-control inference |
| Standing Barbell Overhead Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |
| Standing Dumbbell Overhead Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |
| Single-Arm Standing Dumbbell Overhead Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |
| Seated Dumbbell Overhead Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |
| Seated Barbell Overhead Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |
| Unsupported Seated Dumbbell Overhead Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |
| Single-Arm Seated Dumbbell Overhead Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |
| Single-Arm Standing Kettlebell Overhead Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |
| Seated Smith Machine Overhead Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |
| Machine Shoulder Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |
| Hammer Strength MTSSP Single-Arm Shoulder Press | None | FF, ECR, ECU, EDC, FCR, FCU | Grip/wrist-control inference |

All transfers to these exact catalog fixtures are categorical inferences.
Grip orientation, support, laterality, assistance, range, defaults, and performance
identities retain their existing authored values, including unreported source details.

## Primary evidence ledger

Web research date: 2026-09-16. Searches covered deadlift/pull-up wrist-extensor EMG,
simultaneous handgrip and wrist forces, external wrist-extension assistance,
wrist perturbations, and overhead-press wrist-flexor EMG.

| Claim | Primary source | Support and limitation |
|---|---|---|
| Wrist-extensor participation during deadlift and pull-up categories | [Krings et al., 2021 print / 2019 online](https://pubmed.ncbi.nlm.nih.gov/30694963/) | Standard and thicker-grip exercise trials measured ECR and ECU. EDC and FF were not measured. Category support does not establish recruitment in each exact authored variant. |
| Distinct co-contributors to grip-associated wrist stiffness | [Forman et al., 2019](https://pubmed.ncbi.nlm.nih.gov/30822679/) | Supported-forearm laboratory grip/wrist-force tasks measured ECR, ECU, EDC, FDS, FCR and FCU. Supports active control beyond incidental contact; exercise transfer is inferred. Wrist-flexor activity depends on wrist-force direction and can be low. FDS measurement does not separately establish FDP recruitment or uniform aggregate loading. |
| External extension assistance can reduce extensor demand during gripping | [van Elk et al., 2004](https://pubmed.ncbi.nlm.nih.gov/15189014/) | Grip trials found reduced radial-extensor and EDC activity with assistance. Bounds press transfer; does not measure overhead presses, bells, machines, or adaptation. |
| FCU participation in conventional deadlift grips | [Pratt et al., 2020](https://pubmed.ncbi.nlm.nih.gov/32446132/) | Direct FCU EMG with double-overhand, hook and mixed grips; FCR and other authored deadlift variants were not measured. |
| Distinct wrist-flexor control with power grip | [Mannella et al., 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC9138088/) | FCR/FCU activity increased with grip force during anticipated radial/ulnar perturbations. Supported robot protocol constrained other wrist/forearm planes; lifting/suspension transfer is inferred. Full text excludes biceps from the abstract's generalized grip effect. |
| FCU participation in overhead presses | [Padovan et al., 2024 online / 2025 volume](https://doi.org/10.1007/s11332-024-01301-w) | Direct FCU EMG in standing bilateral barbell and standard-kettlebell presses. Bell/forearm contact did not establish absent control. FCR and seated, dumbbell, single-arm or machine fixtures were not measured. |

## Fixture limits and contract gates

- Deadlift families already declare wrist and hand demands. Their local stabilizer
  requirements and whitelists now include ECU, EDC, FCR, and FCU for the twelve
  existing fixtures.
- Vertical pull requires ECU, EDC, FCR, and FCU only on the six suspended records,
  including assisted variants. The seven seated pulldown records and scapular-pull-up family
  retain their previous rosters.
- External vertical presses require all six grip/wrist contributors and explicit
  wrist and hand demands. Palm loading differs from hanging; standard kettlebell contact
  and guided machines can reduce or change demand without fixing the wrist or hand.
  No extensor dominance, equal effort, or force against gravity by every contributor
  is implied. The separate handstand fixture remains unchanged.
- Shared anatomy/capability gates and duplicate/identity gates are unchanged.
  There are no new exercises or aliases. Independent biomechanics, press-geometry,
  and catalog/product reviews approved the bounded claims and contract scope.

## Wrist-flexor completion

A fresh-install report showed partial forearm improvement with broad gray strips
remaining. An inspection of the archived scene geometry identified the separate
FCR and FCU surfaces beside the corrected extensor surfaces. Both already have
bilateral runtime mesh mappings and wrist-stabilizing capabilities; the missing
contribution was in the authored exercise rosters. The extensor retinaculum at the
wrist has no trainable taxonomy ownership and remains neutral through the renderer
fallback. Thumb and intrinsic-hand display meshes are not part of this correction.

The second pass adds FCR and FCU as stabilizers to the same 29 fixtures. This is
fixture-specific anatomy-and-mechanics transfer, not a claim that every hand task
recruits every forearm muscle. Grip orientation, support, assistance and implement
path affect demand; no equal or uniformly high recruitment is implied. Wrist
flexion does not become a dynamic prime action. Three independent evidence,
press-geometry and contract/product reviews approved the draft.

The previously registered Padovan source is reused rather than duplicated. Its
scope is corrected to the directly studied bilateral kettlebell protocol; the
catalog's single-arm kettlebell remains an explicit transfer. Forman's scope now
also names the measured wrist flexors and their direction-dependent limitations.

## Existing templates and workout history

Launch reconciliation updates bundled Library entries when the generated catalog
fingerprint changes. Templates and workout exercises store their own muscle-role
snapshots; analytics reads those snapshots. This correction therefore applies to
Library anatomy and exercises selected from the corrected catalog.

Completed workouts, active exercises, and existing templates retain their prior
roles. New sessions started from an old template also retain that template's roles
until its exercise is replaced/reselected. This change does not retroactively
recolor the existing Today map. Any targeted snapshot refresh requires a separate
owner decision and persistence/analytics verification.

## Verification

Initial extensor pass verified on 2026-09-16:

- Catalog compiler/parity passed: 58 muscles, 60 mesh bases, 100 families, and
  271 evidence sources. Before/after runtime comparison found exactly 29 changed
  records, with existing IDs and roles preserved.
- All 58 focused catalog checks passed, including removal/promotion mutations,
  wrist/hand requirements, and excluded pulldown/handstand rosters.
- The incremental app build passed. The `catalog-forearm-stabilizers` Baguette
  flow passed on iPhone 17 Pro / iOS 26.5 in dark appearance, covering representative
  deadlift, pull-up, and overhead press. Screenshots and accessibility trees were
  inspected; the overhead-press side view shows the faint forearm stabilizer tint.
  Artifacts are under `.verify/scenarios/catalog-forearm-stabilizers/`.
- Documentation validation and whitespace checks passed.

The Baguette runtime needed a command-scoped `DYLD_FRAMEWORK_PATH` pointing to
Xcode's current SharedFrameworks directory. The successful flow reused the built
app and scenario runner; subsequent exercise-title constraints were checked against
its saved accessibility trees. No global toolchain settings were changed.

Concurrent simulator activity interrupted attempted light and Accessibility XXXL
captures, including a retry on an already booted second simulator. Those rendered
states were unverified at the end of the initial pass. The wrist-flexor completion
below records the subsequent focused checks. A build proves compilation;
screenshots do not establish muscle force, hypertrophy, or historical updates.

Wrist-flexor completion verified on 2026-09-16:

- Catalog compiler/parity passed with 273 evidence sources. Comparison against
  the initial-pass runtime preserved all 237 exercise IDs and their order;
  exactly 29 records append FCR and FCU as stabilizers, with every other exercise
  field unchanged. Shared taxonomy, capabilities and mesh ownership are unchanged.
- All 58 focused catalog checks passed, including removal and forbidden-role
  mutations, the local wrist/hand requirements, and excluded fixtures. Naming,
  architecture, source-size and documentation checks passed.
- The incremental app build passed through the focused
  `catalog-forearm-development` Baguette route. Its DEBUG-only additive fixture
  constructs fresh catalog templates, snapshots them into exercises, marks nine
  sets completed, and saves one session without resetting existing history. The
  normal development analytics and Today renderer consume those saved snapshots.
- The dark Today report shows FCR at 1.2 and FCU at 0.9 effective sets in 14 days;
  both have the Low band and list corrected exercise contributors. FCR also has
  prior rope-pushdown credit. The rear-view forearm muscle surfaces show the faint
  warm Low tint; the unowned retinaculum remains neutral. Screenshots and
  accessibility trees are under `.verify/scenarios/catalog-forearm-development/`.
- The same saved-session route passed in light appearance without a rebuild or
  reset. Both forearm rows and the rear-view tint were inspected under
  `.verify/scenarios/catalog-forearm-development-light/`.
- A focused slice of `catalog-forearm-stabilizers` passed Library discovery and
  conventional-deadlift detail after the wrist-flexor update. Its visible
  Stabilizer row includes FCR, FCU, ECU and finger extensors; primary/secondary
  promotion is forbidden. Screenshot and accessibility evidence are under
  `.verify/scenarios/catalog-forearm-stabilizers-wrist-flexors/`.
- Accessibility XXXL exposed an unrelated report layout failure: narrow text
  columns create rows thousands of points tall. The FCR/FCU accessibility labels
  still contain positive credit, but the focused flow could not reach visible
  rows within 36 swipes. That rendered state is not approved; failure evidence
  is under `.verify/scenarios/catalog-forearm-development-accessibility-xxxl/`.
  The report layout is unchanged by this catalog correction.

This saved-session fixture proves the current-catalog snapshot-to-analytics-to-map
path. It does not exercise normal user taps to complete a workout or refresh prior
workout/template snapshots. A physical-device workout from freshly selected
corrected exercises remains the final user-run check.
