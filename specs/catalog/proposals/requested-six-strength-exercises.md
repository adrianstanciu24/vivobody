# Six requested strength exercises

Status: Activated catalog additions, 2026-09-18.

The owner requested these six exact additions. Independent biomechanics/product
and family-boundary reviewers checked the drafts before integration. No shared
schema, taxonomy, or anatomical-capability expansion was required. The source
files in [the family directory](../families/) own the active contracts.

## Fixtures and gate decisions

All six passed duplicate, evidence, local-contract, and independent-review gates.
None was an alias for an existing fixture.

| Exercise | Active family and exact boundary | Tracking and load |
|---|---|---|
| Landmine T-Bar Row | `shoulder-extension-row`: unsupported hip hinge, close neutral handle, tucked elbows, anchored bar arc; excludes chest-supported, flared and unilateral landmine rows | Strength/reps, bilateral; added plates only, same bar/anchor/handle setup |
| Standing Dumbbell Calf Raise | `ankle-plantarflexion`: two dumbbells at sides, both forefeet on a stable raised surface, held extended knees | Strength/reps, simultaneous bilateral; combined dumbbell mass |
| Leg-Press Calf Raise | `ankle-plantarflexion`: back and pelvis supported, forefeet secure with heels free, held extended knees; excludes hip/knee pressing | Strength/reps, simultaneous bilateral; entered load on the same machine |
| Cable Pallof Press | New `anti-rotation-press`: standing hip-width parallel stance, chest-height side cable, two-hand press and return with trunk held | Strength/reps, cable load; complete prescribed reps on each cable side |
| Dead Bug | New `dead-bug`: supine, opposite arm and leg reach, head/torso supported, no floor contact by reaching limbs | Strength/reps, no comparable load; each opposite arm-leg reach and return counts once, alternate sides |
| Bird Dog | New `bird-dog`: quadruped opposite arm/leg extension with trunk held; excludes same-side reaching and elbow-to-knee crunch | Strength/reps, no comparable load; each opposite arm-leg raise and return counts once, alternate sides |

The static band Pallof hold and forearm plank retain their original contracts.
The row and calf expansions retain existing records and require explicit new
fixture branches. Existing template and workout snapshots are not rewritten.

## Evidence ledger

Web verification date: 2026-09-18. Technical standards establish geometry;
existing primary anatomical models and capability profiles support categorical
muscle-role inference. These are not quantitative recruitment rankings,
exercise-specific hypertrophy measurements, or medical claims.

| Claim | Source | Support and limitation |
|---|---|---|
| Unsupported close-neutral landmine row | [Lincoln et al., Exercise Technique: The Landmine Row](https://doi.org/10.1519/SSC.0000000000000751) | NSCA technique standard; author-uploaded full text confirms the narrow shoulder-extension T-bar fixture. Existing row anatomy supports categorical roles. |
| Paired dumbbells and raised forefoot surface | [NSCA, Developing Endurance](https://books.google.com/books?id=Su96DwAAQBAJ) | Original book technique inspected via a text mirror; catalog narrows its knee options to extended knees. [Official NASM calf-training guidance](https://www.nasm.org/resource-center/blog/training/calf-training-how-to-program-this-stubborn-muscle-group-for-clients) independently corroborates the step-based dumbbell fixture. |
| Leg-press calf geometry | [NASM Leg Press Calf Raise](https://www.nasm.org/resource-center/exercise-library/leg-press-calf-raise) | Official technique; held extended knees are the catalog's explicit restriction. Machine settings do not imply equivalent foot force. |
| Standing cable antirotation press | [ACE Standing Anti-Rotation Press](https://www.acefitness.org/resources/everyone/exercise-library/332/standing-anti-rotation-press/) | Official geometry and movement standard; oblique and limb roles are bounded anatomical inferences. |
| Straight-limb contralateral dead bug | [NASM Dead Bug](https://www.nasm.org/resource-center/exercise-library/dead-bug) | Official setup and execution; produced limb actions occur at different moments of the repetition, not one simultaneous concentric phase. No bodyweight fraction is invented. |
| Quadruped contralateral bird dog | [ACE Bird-dog](https://www.acefitness.org/resources/everyone/exercise-library/14/bird-dog/) | Official geometry; trunk stays held while limbs move. Lumbar-extensor involvement does not paint unrelated anatomy meshes. |

Undated official pages use retrieval year in the evidence registry, explicitly
identified in each source scope. Added-plate, combined-dumbbell and alternating
rep counting are authored logging conventions, not experimental measurements.

## Review and verification

Independent review required the dumbbell calf fixture to enforce its grip and
trunk/hip stabilizers and stability demands. It also corrected the cable press
to a mixed kinetic chain: feet planted, hands moving. Focused mutations reject
supported/wide/unilateral T-bar substitutions, bent-knee calf substitutions,
band/hold Pallof substitutions, and incorrect core limb pairing or floor contact.

`Scripts/catalog.py --emit-runtime` generates runtime JSON, fingerprint and Xcode
inputs. `Scripts/catalog.py --check` checks their parity. The 29 focused tests
cover changed row/calf contracts, the family registry, and new core boundaries.
The `catalog-six-*` scenarios cover Library discovery and detail, including
light and dark states across the batch. All six semantic scenarios passed.
Dead Bug additionally has a live Accessibility Large capture (`accessibility.jpg`
and `accessibility-ui.json`); the system text size was restored afterward.
Bird Dog has a settled isolated-device rerun under
`.verify/scenarios/catalog-six-bird-dog-isolated/` (`final.jpg` and `final-ui.json`).
Its scenario scrolls the row clear of the tab bar before tapping.
See their execution results
under `.verify/scenarios/`; a declared scenario alone is not runtime evidence.

Broader catalog, persistence and workout suites remain user-run under the
repository verification policy. Exercise-specific EMG is not established for
all six; only source-bounded categorical roles are claimed.

Additional historical checks exposed existing reverse-fly seed/tautological-rule
failures in an unchanged family. Those remain outside these additions.
The final documentation check passed.
