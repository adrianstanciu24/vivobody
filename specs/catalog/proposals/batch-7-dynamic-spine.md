# Batch 7 — dynamic spine decisions

Status: `spine-flexion` and `spine-rotation` are active with shared evidence
registered. `spine-extension` and `spine-lateral-flexion` remain held; no
family JSON is authored for either one.

## Outcome

| Family | Initial fixture | Decision |
|---|---|---|
| `spine-flexion` | 30-Degree Curl-Up | Activate narrowly |
| `spine-extension` | MedX Isolated Lumbar Extension | Hold for truthful visible lumbar-extensor taxonomy |
| `spine-rotation` | Seated Machine Torso Twist | Activate narrowly |
| `spine-lateral-flexion` | none | Hold |

The two active families each declare one unconditioned spinal prime action,
its one cardinal basis plane, and the exact 43-action complement as forbidden.
Both are isolation families with null pattern and direction and group under
`core`.

## Spine flexion

Ha and Shin tested dynamic concentric and eccentric curl-ups at 30, 60, and
90 degrees in fourteen healthy males. They measured rectus abdominis,
external oblique, internal oblique, and iliopsoas with EMG and transversus
abdominis thickness with ultrasound. Abdominal activity decreased as angle
increased, so the first contract admits only the 30-degree condition.

The record authors `abs` primary and `obliques` secondary. That order is a
training-emphasis judgment for a strict symmetric sagittal curl-up, not a
claim that surface EMG numerically partitions contribution. The current
`obliques` region combines internal and external obliques on both sides;
although Ha measured both muscle classes, the product cannot display their
separate or side-specific activity. Iliopsoas activity does not become a role:
the contract holds the hips and excludes a sit-up or other hip-driven
repetition.

The exercise stays `nonComparable` with zero bodyweight fraction because the
source did not establish a catalog load fraction. It pins the directly
reviewed 0-to-30-degree trunk-elevation range, explicitly not a segmental
lumbar-angle claim, but deliberately does not invent a universal arm, knee, or
foot configuration. Full sit-ups, higher curl angles, external-load
variants, reverse crunches, leg raises, diagonal curl-ups, unstable-surface
work, and isometric holds require separate review.

## Spine extension

Fisher et al. trained twenty-six asymptomatic adults for six weeks with
dynamic isolated lumbar extension at either 80 or 50 percent of maximum
voluntary contraction. The MedX setup is unusually auditable: a thigh
restraint, distal-femur restraint, footboard, and rolling posterior-pelvis pad
prevent pelvic lift and rotation while allowing lumbar motion. The reviewed
range is 72 degrees of lumbar flexion to the machine's 0-degree full-extension
reference. Repetitions take at least two seconds to extend, hold full
extension for one second, and take at least four seconds to return.

The fixture evidence is sufficient, but the current product taxonomy is not.
`lowerBack` is named for lumbar extensors while its only visible meshes are
quadratus lumborum and superior/inferior posterior serratus. It exposes no
erector-spinae or multifidus surface. Assigning that region as the sole primary
would therefore award all volume and highlight the wrong visible anatomy for a
canonical lumbar-extension exercise. Disclosure cannot repair that user-facing
result, so the candidate remains held and has no family JSON or registered
evidence entry.

Resolve the hold atomically by introducing a truthful lumbar-extensor region
with actual erector-spinae/multifidus meshes, or an explicitly unvisualized
region until those assets exist; move `spine.extension` and the MedX role to
that region; recast quadratus lumborum for its reviewed lateral-flexion and
stability functions; stop using posterior serratus as a lumbar-extensor proxy;
and re-review every current `lowerBack` assignment. Only then should the exact
MedX setup, 72-to-0-degree range, 2/1/4-second cadence, and product seeds be
activated. Unsupported hyperextensions, Roman-chair and 45-degree variants,
reverse hypers, hinges, floor supermans, limited-range protocols, and other
machines remain outside even that future narrow contract.

The reviewed hold source is Fisher et al., *Heavier- and lighter-load isolated
lumbar extension resistance training produce similar strength increases, but
different perceptual responses, in healthy males and females* (2018), DOI
`10.7717/peerj.6001`, PMID `30498645`. The proposed evidence ID
`fisher-2018-isolated-lumbar-extension` remains unregistered until a family can
cite it without producing false visible credit.

## Spine rotation

Vinstrup et al. directly tested left-to-right torso twists in a horizontal
seated machine at an individually established ten-repetition maximum. The
athlete began rotated left, placed the feet behind ankle rollers, held handles
at shoulder height, contacted the photographed shoulder-pad lever, rotated to
the maximal controlled rightward endpoint, and returned under control. The
handles establish hand position; the shoulder pads, not the grips, are the
external-load interface. The paper calls this torso rotation and reports the
setup, but unlike its standing-band condition it does not state or measure zero
pelvic motion. The catalog therefore makes one explicit coaching
adaptation: hold the pelvis against the seat while the spine rotates.
`pelvisMotion: positionHeldCatalogAdaptation` prevents that inference from
masquerading as a measured source fact.

The ten-repetition-maximum calibration belongs to the study protocol, not the
exercise identity or a catalog prescription. It remains in the evidence scope
and is deliberately absent from the variant axes; changing the selected stack
load does not create a different torso-twist exercise.

Vinstrup measured rectus abdominis, bilateral external oblique, and bilateral
erector spinae. External oblique reached the clearest high machine signal.
Stevens et al. separately measured fourteen abdominal and back sites during
dynamic seated axial rotation at 30, 50, and 70 percent maximum mean force in
a Tergumed device; both internal and external oblique were active, supporting
the combined oblique region as the family mover rather than proving topology
equivalence between machines.

The active record assigns only `obliques` primary. The one product region
cannot represent the ipsilateral/contralateral or internal/external strategy,
so the side-specific limitation is disclosed. Rectus-abdominis and
erector-spinae signals are not automatically promoted to stabilizer credit:
EMG presence is not a categorical volume oracle, and the existing
`lowerBack` surface also aggregates quadratus-lumborum and posterior-serratus
meshes rather than exposing the measured erector-spinae subdivisions.
The primary oblique region already covers the declared spine and pelvis
stability demands.

The active roster remains unilateral at the set level: one logged direction is
completed and returned before the machine is reset. The one record prescribes
equal work in both directions rather than awarding direction-aggregated oblique
volume from left-to-right work alone. `setDirection: oneDirectionAtATime`
captures the observable single-direction set topology, while
`trainingDirectionPrescription: bothDirections` explicitly labels the mirrored
right-to-left direction as a mechanics-and-training adaptation, not a measured
condition or a fabricated second record. Vinstrup's left-to-right condition
remains evidence provenance in the definition and source scope rather than a
variant axis. Standing band twists, cable
rotations, wood chops, Russian twists, landmine rotations, medicine-ball
throws, alternating-direction repetitions, flexion-rotation, and anti-rotation
work remain separate branches.

## Why spine lateral flexion remains held

The clean condition-matched dynamic fixture is Konrad et al.'s side-lying
lateral trunk lift to 30 degrees (`PMID 12937449`, `PMCID PMC155519`). That
paper has no DOI. The current evidence registry requires a non-empty DOI and
the exact canonical `https://doi.org/{doi}` URL; inventing a DOI is not an
option.

The DOI-backed alternatives do not close the exercise-specific gap:

- Andersson et al., DOI `10.1016/0268-0033(96)00033-2`, tested maximal
  **isometric** ipsilateral trunk flexion in side-lying rather than a dynamic
  repetition.
- Marras and Granata, DOI `10.1016/S0021-9290(97)00010-9`, studied loaded
  industrial lateral-bending tasks at different velocities, not a narrow gym
  fixture that can be coached and assigned without invention.

The taxonomy adds a second reason not to guess. `lowerBack` combines a
quadratus-lumborum surface with posterior-serratus surfaces, while `obliques`
combines internal and external obliques bilaterally. Both profiles can produce
`spine.lateralFlexion`, but the available admissible evidence does not support
a truthful exercise-specific categorical rank across those aggregate regions.

The hold can be reopened by either a directly reviewed DOI-backed dynamic
fixture or a separately approved evidence-schema migration. A minimal
alternate-identifier migration would require exactly one supported canonical
identifier route: DOI plus DOI URL, or PMID/PMCID plus a canonical NCBI URL;
the validator and mutation tests would need to reject missing, conflicting,
or fabricated identifiers. That migration is outside this batch.

## Exact evidence registration payloads

The three active sources below are all referenced by an active family or
exercise, so evidence coverage remains closed. The held extension and
lateral-flexion sources are not registered while their families remain held.

```json
{
  "id": "ha-2020-curl-up-angle",
  "sourceType": "experimentalEMGStudy",
  "title": "The effects of curl-up exercise in terms of posture and muscle contraction direction on muscle activity and thickness of trunk muscles",
  "authors": [
    "Sun-Young Ha",
    "DooChul Shin"
  ],
  "year": 2020,
  "doi": "10.3233/BMR-191558",
  "pmid": "32144977",
  "url": "https://doi.org/10.3233/BMR-191558",
  "scope": "Fourteen healthy males performed concentric and eccentric curl-ups at 30, 60, and 90 degrees while rectus-abdominis, external-oblique, internal-oblique, and iliopsoas EMG plus transversus-abdominis ultrasound thickness were collected. Abdominal activity decreased as the curl-up angle increased, directly anchoring the active 30-degree dynamic range and measured abdominal participation. The study does not establish a comparable external load, bodyweight fraction, universal arm or lower-limb geometry, zero iliopsoas activity, a categorical numeric role split, full sit-ups, loaded or unstable variants, rotation, lateral flexion, or higher-angle roster records."
}
```

```json
{
  "id": "vinstrup-2015-torso-twist",
  "sourceType": "experimentalEMGStudy",
  "title": "Core Muscle Activity, Exercise Preference, and Perceived Exertion during Core Exercise with Elastic Resistance versus Machine",
  "authors": [
    "Jonas Vinstrup",
    "Emil Sundstrup",
    "Mikkel Brandt",
    "Markus D. Jakobsen",
    "Joaquin Calatayud",
    "Lars L. Andersen"
  ],
  "year": 2015,
  "doi": "10.1155/2015/403068",
  "pmid": "26557405",
  "url": "https://doi.org/10.1155/2015/403068",
  "scope": "Seventeen healthy untrained men performed three controlled left-to-right torso-twist repetitions at individually determined ten-repetition-maximum loads using elastic resistance and a horizontal seated Technogym machine. The machine condition directly anchors the left-rotated start, feet behind ankle rollers, hands on shoulder-height handles, the photographed shoulder-pad lever interface, controlled maximal rightward torso-rotation endpoint, return, and rectus-abdominis, bilateral external-oblique, and bilateral erector-spinae EMG context. Machine-condition pelvic kinematics were neither stated as stationary nor measured, so the source does not prove zero pelvic motion, internal-oblique activity, a universal range or stack load, chronic training outcomes, upper-limb roles, a mirrored record, or another topology."
}
```

```json
{
  "id": "stevens-2007-seated-axial-rotation",
  "sourceType": "experimentalEMGStudy",
  "title": "The relevance of increasing resistance on trunk muscle activity during seated axial rotation",
  "authors": [
    "Veerle Stevens",
    "Erik Witvrouw",
    "Guy Vanderstraeten",
    "Thierry Parlevliet",
    "Katie Bouche",
    "Nele Mahieu",
    "Lieven Danneels"
  ],
  "year": 2007,
  "doi": "10.1016/j.ptsp.2006.09.021",
  "url": "https://doi.org/10.1016/j.ptsp.2006.09.021",
  "scope": "Thirty healthy adults performed dynamic seated axial rotation in a Tergumed training device at 30, 50, and 70 percent of maximum mean force while fourteen abdominal and back muscle sites were measured. Internal oblique reached approximately 30 percent MVIC at the lowest load, while external oblique and the examined back muscles reached approximately 60 percent, and activity increased with resistance. The study supports dynamic internal-and-external-oblique participation in resisted seated rotation, not equivalence to the active Technogym topology, its exact contacts, a categorical numeric role partition, a universal range or load, zero pelvic motion, or chronic training outcomes."
}
```

## Integration tests

1. Pin exactly the two active family IDs and one roster record per family;
   assert that `spine-extension.json` and `spine-lateral-flexion.json` remain
   absent while their holds are unresolved.
2. Pin each fixed plane against its basis action and require the exact
   43-action forbidden complement; mutate every forbidden action directly.
3. Remove and demote every required muscle independently. Assert no iliopsoas,
   abs, or `lowerBack` proxy role is fabricated where the active contract omits
   it.
4. Pin every single-value enum, boolean, and number axis and mutate each with
   the exact validator failure. The one-record contracts use axis invariants,
   not always-true exercise rules.
5. Assert that flexion remains 0-to-30 degrees of study-defined trunk
   elevation (not segmental lumbar angle), and rotation retains the explicit
   `positionHeldCatalogAdaptation` pelvis disclosure, the
   `oneDirectionAtATime` set topology, and the one-record `bothDirections`
   training prescription.
6. Verify stability coverage from assigned regions: flexion uses abs and
   obliques, while rotation uses obliques. Do not add joint demands merely
   because an external pad or restraint contacts them.
7. Pin zero bodyweight fraction for the non-comparable curl-up and the clean
   metric seed for the externally loaded rotation machine.
8. Pin globally unique catalog IDs, names, and aliases, keep the three active
   evidence sources referenced, and pin the user-visible extension hold so a
   `lowerBack` proxy cannot silently activate later.

No family-schema, joint-action, validator, or resisted-action change is
required for the two narrow activations. The held extension family requires
an atomic taxonomy/body-model migration before it may activate.
