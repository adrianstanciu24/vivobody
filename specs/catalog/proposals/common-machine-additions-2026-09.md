# Common gym machine additions — September 2026

Status: three exact Life Fitness Insignia fixtures active following owner authorization on 2026-09-18.

## Fixture and ownership decisions

| Fixture | Active family | Reviewed repetition | Muscle roles |
|---|---|---|---|
| SS-AB seated abdominal crunch | [seated-machine-abdominal-crunch](../families/seated-machine-abdominal-crunch.json) | Seated upper-torso curl; arms guide, hips stay seated without deliberately driving the repetition. | Abs primary; obliques secondary. |
| SS-BE seated back extension | [seated-machine-back-extension](../families/seated-machine-back-extension.json) | Supported torso extension with seated hip opening; lower-back contact with the lumbar pad is the endpoint. | Lumbar extensors primary; gluteus maximus secondary. |
| SS-GLB belt-loaded glute bridge | [belt-loaded-machine-glute-bridge](../families/belt-loaded-machine-glute-bridge.json) | Both feet planted, centered hip belt, supported upper torso, crossed arms; raise hips until thighs align with torso. | Gluteus maximus primary; vasti secondary; biceps femoris, lumbar extensors, gluteus medius and soleus stabilizers. |

Duplicate review confirmed none of these exact fixtures was active. Each gets
its own family and stable exercise ID. Existing cable/floor crunch, restrained
MedX, Roman-chair, barbell thrust/bridge and bodyweight bridge contracts remain
unchanged. SS-ABD, SS-GLD, plate-loaded glute drives and other mechanisms are
excluded even when conventional search names overlap.

## Evidence ledger

Source search and diagram inspection: **2026-09-18**.

| Claim | Primary source | Support and limitation |
|---|---|---|
| Exact seat, pad, foot, handle/belt contacts and execution endpoints | Life Fitness (2024), [Insignia Series Owner's Manual, 9481201 BE](https://kb.cybexintl.com/Owners_Manuals/Strength/Life_Fitness_Insignia_Series_Owners_Manual_9481201_Rev_BE.pdf), printed pages 8, 12 and 21 | Official fixture standard and start/finish diagrams, not measured joint kinematics or muscle rankings. Reuses `life-fitness-2024-insignia-series-manual`. |
| Crunch spinal flexion; back-extension spinal and hip extension | Manual above; Christophy et al. (2012), [lumbar musculoskeletal model](https://doi.org/10.1007/s10237-011-0290-6); Arnold et al. (2010), [lower-limb model](https://doi.org/10.1007/s10439-009-9852-5) | Bounded instruction/schematic/anatomy inference. Back-extension diagrams cannot partition lumbar motion from pelvic rotation. No numeric range or motionless pelvis is claimed. |
| Bridge hip extension and accompanying knee extension | Manual page 21; Arnold lower-limb model above | Hip action follows the instruction; knee opening follows the schematic. Hip-dominant emphasis supports glute-primary/vasti-secondary categorical roles, without transferred barbell EMG or knee angles. |
| Trunk, pelvic, knee and planted-foot control | Christophy and Arnold models above plus exact fixture contacts | Conservative anatomy-and-mechanics inference, not an exhaustive roster or measured stabilizer ranking. Biceps femoris receives only knee-control credit, preserving the unsplit region's capability boundary. |

Independent evidence, contract and product reviews accepted the limited claims.
Review corrections removed an unsupported SS-ABD classification and replaced
ambiguous knee-opening copy with plain knee-straightening instructions.

## Product and integration boundaries

All three use bilateral machine equipment, dynamic strength, repetitions,
external load and zero bodyweight fraction. Record the selected stack weight
once and compare progress only on the same machine and setup. A stack setting
is not measured interface force or equivalent to a barbell or another machine.
The runtime preserves exact exercise identity but cannot distinguish separate
physical stations logged under the same exercise ID; instructions state the
comparison convention explicitly.

Existing anatomy supports every authored role. Lumbar extensors receive exact
text and analytics credit but have no matching body-model surface; no substitute
quadratus-lumborum or posterior-serratus highlighting is introduced. No shared
schema, taxonomy, anatomical capability, persistence or historical-snapshot
changes are needed.

Catalog output is generated through `Scripts/catalog.py`. Focused mutation
checks cover fixture/load geometry, required contributor loss, extra actions,
and insertion into neighboring families. The `catalog-common-machines`
Baguette scenario covers Library discovery and exercise details; its light and
accessibility variants exercise the same new entries at their relevant states.

## Verification evidence

`Scripts/catalog.py --check` passes with 240 exercises, 102 real families and
277 evidence sources. All 237 existing runtime records are unchanged; exactly
three new stable exercise IDs are present. Twelve focused catalog tests pass,
including rejection of alternate fixtures, unsupported load semantics, missing
contributors and neighboring-family admission. Documentation and whitespace
checks pass.

The incremental app build through `Scripts/verify.sh` passes. The
`catalog-common-machines` dark-mode scenario passes Library/detail discovery,
anatomy roles and all three instruction sequences. The light-mode variant
passes and its glute-bridge screenshot preserves readable role wrapping and
the explicit lumbar-extensor surface limitation. Artifacts are under
`.verify/scenarios/catalog-common-machines/` and
`.verify/scenarios/catalog-common-machines-light/`.

The accessibility-large light-mode crunch scenario also passes. Its inspected
screenshot shows the complete exercise name wrapping across four lines without
truncation, the highlighted abdominal surface and the primary Abs role.
Library discovery uses the full list because the Core chip is horizontally
offscreen at this text size. Its screenshot and accessibility tree are under
`.verify/scenarios/catalog-common-machines-accessibility/`.

Physical machine execution, broader catalog suites and device VoiceOver remain
user-run verification. Schematic inference does not establish numeric joint
motion, medical benefits, hypertrophy rankings or cross-machine load equivalence.
