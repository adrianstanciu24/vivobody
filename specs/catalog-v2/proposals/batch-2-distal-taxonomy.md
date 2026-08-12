# Batch 2 — distal upper-body taxonomy foundation

Status: integrated foundation record. The 41-muscle, 62-mesh-base, and
44-action foundation is active in catalog-v2 together with the required
existing-family migration. This document remains non-validator design input;
the isolated Swift runtime intentionally stays on the shipped catalog until
the later atomic catalog cutover.

## Decision summary

The pre-Batch-2 `biceps` and `forearms` regions were too coarse. They made
anatomically different contracts indistinguishable:

- `biceps` owns both the `Biceps` and `Brachialis` meshes, then gives the whole
  region shoulder flexion and forearm supination even though brachialis crosses
  neither the shoulder nor the radioulnar joints;
- `forearms` owns brachioradialis, radial and ulnar wrist flexors, radial and
  ulnar wrist extensors, a finger flexor, and a finger extensor, then gives the
  whole region elbow flexion, pronation, every wrist action, and grip; and
- no represented muscle can distinguish supinator from biceps brachii or the
  pronator muscles from unrelated wrist and finger muscles.

Replace those two aggregate regions with eleven functional anatomical regions.
The clean-slate taxonomy therefore changes from **32 to 41 muscles**. Existing
mesh ownership rises from **61 to 62 base names** because
`Flexor_Digitorum_Profundus`, already present bilaterally in `BodyModel.scn`,
becomes owned for the first time. No existing mesh is discarded.

Also replace the task label `hand.grip` with the joint actions
`hand.fingerFlexion` and `hand.fingerExtension`. “Grip” is not one cardinal-
plane joint action: dynamic closing, isometric support, pinch, and hanging do
not share one movement signature. This foundation enables a narrow future
finger-flexion family without pre-approving every grip task.

## Scene audit

The current app runtime confirms the same coarse ownership as the v2 source:
`Muscle.biceps` paints `Biceps|Brachialis`, while `Muscle.forearms` paints
`Brachioradialis`, the five prime carpal movers, FDS, and EDC. Direct inspection
of `BodyModel.scn` establishes bilateral nodes for every proposed visual owner:

| Proposed muscle ID | Exact `meshBaseNames` | Visual decision |
|---|---|---|
| `bicepsBrachii` | `Biceps` | Split from the current biceps aggregate |
| `brachialis` | `Brachialis` | Split from the current biceps aggregate |
| `brachioradialis` | `Brachioradialis` | Split from the current forearm aggregate |
| `forearmPronators` | none | `BodyModel.scn` has neither pronator teres nor pronator quadratus |
| `supinator` | none | `BodyModel.scn` has no supinator surface mesh |
| `flexorCarpiRadialis` | `Flexor_Carpi_Radialis` | Exact visible muscle |
| `flexorCarpiUlnaris` | `Flexor_Carpi_Ulnaris` | Exact visible muscle |
| `extensorCarpiRadialis` | `Extensor_Carpi_Radialis_Longus`, `Extensor_Carpi_Radialis_Brevis` | The two muscles share the Batch-2 wrist actions |
| `extensorCarpiUlnaris` | `Extensor_Carpi_Ulnaris` | Exact visible muscle |
| `fingerFlexors` | `Flexor_Digitorum_Superficialis`, `Flexor_Digitorum_Profundus` | FDS and FDP share finger flexion; FDP is newly owned |
| `fingerExtensors` | `Extensor_Digitorum_Communis` | Kept separate so radial deviation is never attributed to EDC |

Exact unvisualized reasons:

```json
{
  "id": "forearmPronators",
  "meshBaseNames": [],
  "unvisualizedReason": "BodyModel.scn has no pronator-teres or pronator-quadratus surface mesh."
}
```

```json
{
  "id": "supinator",
  "meshBaseNames": [],
  "unvisualizedReason": "BodyModel.scn has no supinator surface mesh."
}
```

All eleven regions remain in the coarse app group `arms`. Suggested display
names are the anatomical names shown by the IDs, except
`extensorCarpiRadialis` displays as “Radial Wrist Extensors” and
`forearmPronators` displays as “Forearm Pronators.”

## Why these are the minimum regions

The split follows a strict rule: combine muscles only when every combined
muscle shares the action that is load-bearing for Batch 2.

- Biceps brachii, brachialis, and brachioradialis must be separate. All flex
  the elbow, but only biceps brachii is an unconditional supinator and shoulder
  flexor. Brachioradialis changes its rotational moment direction around the
  neutral forearm position.
- Pronator teres and pronator quadratus may remain one unvisualized
  `forearmPronators` region because their shared, Batch-2-defining action is
  forearm pronation and neither has a mesh. Pronator-teres-specific elbow
  flexion and deep-pronator-quadratus-specific radioulnar stabilization are not
  promoted into shared group actions. A future contract that needs either
  distinction must split this region first.
- Supinator cannot be folded into `forearmPronators` or `bicepsBrachii` without
  making the opposite rotation or biceps visualization false.
- FCR and FCU must be separate because one deviates radially and the other
  ulnarly. ECRL and ECRB can remain one radial-extensor region because both
  extend and radially deviate the wrist; ECRL-specific elbow behavior is not a
  Batch-2 group capability. ECU must remain separate because it deviates
  ulnarly.
- FDS and FDP can remain one `fingerFlexors` region because both dynamically
  flex the fingers and participate in loaded grip. EDC must remain a separate
  `fingerExtensors` region; assigning it to a radial wrist-extensor group would
  falsely make it eligible for radial-deviation roles.

This proposal deliberately does **not** create separate FDS/FDP, ECRL/ECRB,
pronator-teres/pronator-quadratus, biceps-head, or individual-finger regions.
Those splits would not alter any currently proposed family contract. It also
does not claim the visible thumb and intrinsic-hand meshes. Pinch and thumb-
opposition work require their own action and taxonomy review rather than an
expansion hidden inside a generic `grip` family.

## Exact joint-action change

Remove:

```json
{
  "id": "hand.grip",
  "region": "hand",
  "plane": "sagittal",
  "displayName": "Grip"
}
```

Add:

```json
{
  "id": "hand.fingerFlexion",
  "region": "hand",
  "plane": "sagittal",
  "displayName": "Finger flexion"
}
```

```json
{
  "id": "hand.fingerExtension",
  "region": "hand",
  "plane": "sagittal",
  "displayName": "Finger extension"
}
```

The action vocabulary consequently changes from 43 to 44 actions. The `hand`
region is retained: the IDs describe finger-joint motion at the product's hand
region granularity, not motion of the wrist.

Add two position conditions for brachioradialis:

```json
{
  "id": "fromSupinatedPosition",
  "displayName": "From a supinated position toward neutral",
  "definition": "The action is produced only while the forearm begins on the supinated side of neutral and rotates toward neutral.",
  "appliesTo": ["forearm.pronation"]
}
```

```json
{
  "id": "fromPronatedPosition",
  "displayName": "From a pronated position toward neutral",
  "definition": "The action is produced only while the forearm begins on the pronated side of neutral and rotates toward neutral.",
  "appliesTo": ["forearm.supination"]
}
```

These conditions are load-bearing. They let the capability map state the
observed return-to-neutral behavior without allowing brachioradialis to satisfy
an unconditional full-range pronation or supination contract. Bremer et al.
found its moment direction changed around neutral, while Boland et al. found
its strongest and most consistent function during elbow flexion and only a
secondary rotational role.

## Exact capability profiles

The replacement profiles should be authored exactly as follows. These are
capabilities, not automatic exercise roles; every family still decides which
capable muscles are admitted and emphasized.

```json
[
  {
    "muscleID": "bicepsBrachii",
    "produces": [
      "shoulder.flexion",
      "elbow.flexion",
      "forearm.supination"
    ],
    "stabilizes": ["shoulder", "elbow", "forearm"],
    "evidenceRefs": [
      "holzbaur-2005-upper-extremity",
      "murray-1995-elbow-forearm-moment-arms",
      "bremer-2006-forearm-rotator-moment-arms",
      "gordon-2004-forearm-rotation-emg"
    ]
  },
  {
    "muscleID": "brachialis",
    "produces": ["elbow.flexion"],
    "stabilizes": ["elbow"],
    "evidenceRefs": [
      "holzbaur-2005-upper-extremity",
      "murray-1995-elbow-forearm-moment-arms"
    ]
  },
  {
    "muscleID": "brachioradialis",
    "produces": [
      "elbow.flexion",
      {
        "action": "forearm.pronation",
        "condition": "fromSupinatedPosition"
      },
      {
        "action": "forearm.supination",
        "condition": "fromPronatedPosition"
      }
    ],
    "stabilizes": ["elbow", "forearm"],
    "evidenceRefs": [
      "murray-1995-elbow-forearm-moment-arms",
      "bremer-2006-forearm-rotator-moment-arms",
      "boland-2008-brachioradialis-function"
    ]
  },
  {
    "muscleID": "forearmPronators",
    "produces": ["forearm.pronation"],
    "stabilizes": ["forearm"],
    "evidenceRefs": [
      "holzbaur-2005-upper-extremity",
      "bremer-2006-forearm-rotator-moment-arms",
      "gordon-2004-forearm-rotation-emg"
    ],
    "notes": "This grouped profile records the shared pronation action only; it does not promote pronator-teres-specific elbow flexion or deep-pronator-quadratus-specific stabilization into a capability of the whole region."
  },
  {
    "muscleID": "supinator",
    "produces": ["forearm.supination"],
    "stabilizes": ["forearm"],
    "evidenceRefs": [
      "holzbaur-2005-upper-extremity",
      "bremer-2006-forearm-rotator-moment-arms",
      "gordon-2004-forearm-rotation-emg"
    ]
  },
  {
    "muscleID": "flexorCarpiRadialis",
    "produces": ["wrist.flexion", "wrist.radialDeviation"],
    "stabilizes": ["wrist"],
    "evidenceRefs": [
      "holzbaur-2005-upper-extremity",
      "garland-2018-wrist-tendon-moment-arms",
      "nichols-2015-wrist-muscle-moment-arms"
    ]
  },
  {
    "muscleID": "flexorCarpiUlnaris",
    "produces": ["wrist.flexion", "wrist.ulnarDeviation"],
    "stabilizes": ["wrist"],
    "evidenceRefs": [
      "holzbaur-2005-upper-extremity",
      "garland-2018-wrist-tendon-moment-arms",
      "nichols-2015-wrist-muscle-moment-arms"
    ]
  },
  {
    "muscleID": "extensorCarpiRadialis",
    "produces": ["wrist.extension", "wrist.radialDeviation"],
    "stabilizes": ["wrist"],
    "evidenceRefs": [
      "holzbaur-2005-upper-extremity",
      "garland-2018-wrist-tendon-moment-arms",
      "nichols-2015-wrist-muscle-moment-arms"
    ],
    "notes": "The region combines ECRL and ECRB only at their shared wrist actions; ECRL-specific elbow flexion is deliberately not assigned to the whole region."
  },
  {
    "muscleID": "extensorCarpiUlnaris",
    "produces": ["wrist.extension", "wrist.ulnarDeviation"],
    "stabilizes": ["wrist"],
    "evidenceRefs": [
      "holzbaur-2005-upper-extremity",
      "garland-2018-wrist-tendon-moment-arms",
      "nichols-2015-wrist-muscle-moment-arms"
    ]
  },
  {
    "muscleID": "fingerFlexors",
    "produces": ["wrist.flexion", "hand.fingerFlexion"],
    "stabilizes": ["wrist", "hand"],
    "evidenceRefs": [
      "an-1983-index-finger-moment-arms",
      "mirakhorlo-2018-hand-wrist-model",
      "ferrer-uris-2023-finger-dead-hangs"
    ]
  },
  {
    "muscleID": "fingerExtensors",
    "produces": ["wrist.extension", "hand.fingerExtension"],
    "stabilizes": ["wrist", "hand"],
    "evidenceRefs": [
      "an-1983-index-finger-moment-arms",
      "mirakhorlo-2018-hand-wrist-model",
      "ferrer-uris-2023-finger-dead-hangs"
    ]
  }
]
```

The four carpal profiles intentionally omit small cross-joint actions that are
not shared by their grouped anatomy or load-bearing for these contracts. The
capability map must not infer FCR pronation, ECRL elbow flexion, or another
minor modeled moment into an exercise role simply because one source can
resolve a nonzero moment arm. A future family that needs such a function must
review and, if necessary, further split the region.

## Evidence registered for the migration

All registry additions have a DOI and can satisfy the current evidence schema.
The IDs and DOI spelling are frozen here to prevent activation-time collisions.

| Evidence ID | Primary source | DOI | Load-bearing use |
|---|---|---|---|
| `murray-1995-elbow-forearm-moment-arms` | Murray, Delp, Buchanan, “Variation of muscle moment arms with elbow and forearm position” | `10.1016/0021-9290(94)00114-J` | Distinguishes biceps, brachialis, brachioradialis, pronator teres, and triceps mechanics across position ([PubMed](https://pubmed.ncbi.nlm.nih.gov/7775488/)) |
| `bremer-2006-forearm-rotator-moment-arms` | Bremer, Sennwald, Favre, Jacob, “Moment arms of forearm rotators” | `10.1016/j.clinbiomech.2006.03.002` | Unconditional pronator/supinator actions and brachioradialis return-to-neutral behavior ([PubMed](https://pubmed.ncbi.nlm.nih.gov/16678316/)) |
| `boland-2008-brachioradialis-function` | Boland, Spigelman, Uhl, “The function of brachioradialis” | `10.1016/j.jhsa.2008.07.019` | Confirms elbow flexion as the consistent primary function and bounds its secondary rotation role ([PubMed](https://pubmed.ncbi.nlm.nih.gov/19084189/)) |
| `gordon-2004-forearm-rotation-emg` | Gordon, Pardo, Johnson, King, Miller, “Electromyographic activity and strength during maximum isometric pronation and supination efforts in healthy adults” | `10.1016/S0736-0266(03)00115-3` | Fine-wire evidence for PT/PQ pronation and supinator/biceps supination without grip ([PubMed](https://pubmed.ncbi.nlm.nih.gov/14656682/)) |
| `garland-2018-wrist-tendon-moment-arms` | Garland, Shah, Kedgley, “Wrist tendon moment arms: Quantification by imaging and experimental techniques” | `10.1016/j.jbiomech.2017.12.024` | Direct FCR, FCU, ECRL, ECRB, and ECU flexion/extension and deviation moment arms ([PubMed](https://pubmed.ncbi.nlm.nih.gov/29306550/)) |
| `nichols-2015-wrist-muscle-moment-arms` | Nichols, Bednar, Havey, Murray, “Wrist salvage procedures alter moment arms of the primary wrist muscles” | `10.1016/j.clinbiomech.2015.03.015` | Independent tendon-excursion confirmation of the five prime wrist motors and both wrist degrees of freedom ([PubMed](https://pubmed.ncbi.nlm.nih.gov/25843482/)) |
| `an-1983-index-finger-moment-arms` | An, Ueba, Chao, Cooney, Linscheid, “Tendon excursion and moment arm of index finger muscles” | `10.1016/0021-9290(83)90074-X` | Direct extrinsic finger flexor/extensor actions across finger joints ([PubMed](https://pubmed.ncbi.nlm.nih.gov/6619158/)) |
| `mirakhorlo-2018-hand-wrist-model` | Mirakhorlo, Van Beek, Wesseling, Maas, Veeger, Jonkers, “A musculoskeletal model of the hand and wrist: model definition and evaluation” | `10.1080/10255842.2018.1490952` | Coherent hand-wrist model validating finger and wrist moment arms and extrinsic flexor force ([PubMed](https://pubmed.ncbi.nlm.nih.gov/30257101/)) |
| `ferrer-uris-2023-finger-dead-hangs` | Ferrer-Uris, Arias, Torrado, Marina, Busquets, “Exploring forearm muscle coordination and training applications of various grip positions during maximal isometric finger dead-hangs in rock climbers” | `10.7717/peerj.15464` | Exercise-level FDS, FDP, FCR, and EDC recruitment during loaded isometric finger support ([PubMed](https://pubmed.ncbi.nlm.nih.gov/37304875/)) |

Kaufmann et al.'s cadaveric comparison of FDS and FDP grip-force production
was also reviewed and directly supports treating both as grip generators
([PubMed](https://pubmed.ncbi.nlm.nih.gov/17948164/)). It has no DOI in the
PubMed record, while the current registry requires a DOI and canonical DOI URL.
Do not weaken the evidence schema merely to register it: the DOI-backed An,
Mirakhorlo, and Ferrer-Uris sources are sufficient for the proposed capability
profile. The Kaufmann paper can remain disclosed here as corroboration rather
than becoming an unused or schema-exception source.

## Family consequences

### Batch 2 ownership

The split unlocks these contracts without anatomical aliases:

| Candidate | Primary-capability envelope after the split |
|---|---|
| `elbow-flexion` | `bicepsBrachii|brachialis|brachioradialis`, with role emphasis conditioned by reviewed forearm orientation rather than inferred from an exercise name |
| `elbow-extension` | existing `triceps`; the current combined triceps mesh is sufficient because elbow extension is shared by all heads |
| `forearm-pronation` | `forearmPronators`; brachioradialis cannot satisfy an unconditional full-range contract |
| `forearm-supination` | `supinator|bicepsBrachii`; elbow posture may alter emphasis but not anatomical capability |
| `wrist-flexion` | `flexorCarpiRadialis|flexorCarpiUlnaris`, with `fingerFlexors` eligible only as reviewed secondary contributors |
| `wrist-extension` | `extensorCarpiRadialis|extensorCarpiUlnaris`, with `fingerExtensors` eligible only as reviewed secondary contributors |
| `wrist-radial-deviation` | `flexorCarpiRadialis|extensorCarpiRadialis` |
| `wrist-ulnar-deviation` | `flexorCarpiUlnaris|extensorCarpiUlnaris` |
| `grip` | Do not activate as a generic family. A future `finger-flexion-grip` may use `hand.fingerFlexion` and `fingerFlexors`; pinch, static support, and hanging remain explicit separate decisions. |

A dynamic hand-gripper fixture would author `fingerFlexors` as primary.
Wrist extensors, when required to hold wrist posture, remain stabilizers rather
than secondaries because they do not produce finger flexion. A dead hang is not
silently admitted by that fixture: its bodyweight load, closed kinetic chain,
shoulder demands, and isometric support semantics require their own contract.

### Existing-family migration

Activation is not local to Batch 2. Five active families reference `biceps`
and eight reference `forearms`:

- replace shoulder-flexion capability uses of `biceps` with
  `bicepsBrachii` only;
- re-review elbow-flexion roles in `vertical-pull`,
  `shoulder-extension-row`, and `shoulder-horizontal-abduction-row` against
  all three elbow flexors rather than mechanically renaming biceps;
- re-review the elbow stabilizer in `reverse-fly` rather than copying all
  three flexors; and
- replace each `forearms` hand/wrist stabilizer with an explicit reviewed
  combination. In loaded gripping fixtures, `fingerFlexors` can stabilize the
  hand while a carpal or finger-extensor region controls the wrist. The exact
  pair must be evidence-backed per family; a global search-and-replace would
  recreate the aggregate under two names.

The affected contracts are `vertical-pull`, `shoulder-extension-row`,
`shoulder-horizontal-abduction-row`, `shoulder-extension-isolation`,
`shoulder-flexion-raise`, `shoulder-abduction-raise`, `chest-fly`, and
`reverse-fly`. The global family identity counts remain unchanged during this
foundation migration.

## Rejected alternatives

1. **Keep `forearms`.** Rejected because one region could be primary for four
   mutually opposing wrist actions and pronation, making family membership
   tests tautological.
2. **Split only into flexors and extensors.** Rejected because radial and ulnar
   deviation would still be indistinguishable and the flexor group would still
   conflate wrist motion with finger closing.
3. **Use `biceps` as the elbow-flexor family primary and treat grip orientation
   as a role modifier.** Rejected because brachialis is not a supinator and a
   variant axis cannot repair a false anatomical region.
4. **Make brachioradialis an unconditional pronator or supinator.** Rejected
   because its moment direction changes around neutral. The two explicit
   conditions preserve that boundary.
5. **Combine EDC with radial wrist extensors.** Rejected because EDC would then
   inherit radial deviation and become eligible for a role it does not share.
6. **Represent pronators or supinator with a nearby forearm mesh.** Rejected;
   visual approximation is worse than an explicit unvisualized reason.
7. **Model every thumb, intrinsic-hand, and individual-finger muscle now.**
   Rejected as premature. It would expand taxonomy without a reviewed pinch or
   digit-specific family and still would not turn all grip tasks into one
   movement.
8. **Keep `hand.grip` as a sagittal action.** Rejected because it is a task
   label, not one joint rotation. Finger flexion, pinch, and isometric support
   need distinct signatures.

## Atomic activation gates — completed

1. Update `taxonomy.json` to exactly 41 IDs and 62 uniquely owned mesh bases;
   remove only `biceps|forearms`, add the eleven exact IDs above, and verify
   bilateral scene nodes for every visual mesh.
2. Update `joint-actions.json`: replace `hand.grip` with the two finger actions,
   add the two brachioradialis conditions, remove the old two profiles, and add
   the eleven exact profiles above.
3. Register all nine DOI-backed evidence IDs with exact metadata and limitation
   scopes. Every source must be cited by a profile or activated family so
   evidence-coverage validation remains meaningful.
4. Update `Scripts/catalog_v2.py`: header, `EXPECTED_MUSCLE_IDS`, the exact
   taxonomy count, and `EXPECTED_SPLIT_MESHES`. Lock every proposed visible
   owner, including the two-mesh ECR and FDS/FDP groups; do not lock only the
   previously split shoulder/chest regions.
5. Update the root README's exact muscle/action/mesh counts and document that a
   position-conditioned capability cannot satisfy an unconditional rotation.
6. Migrate all eight affected active family contracts in the same change.
   Preserve their exact family/exercise identities while replacing anatomy
   deliberately, then rerun every per-rule matching/contrast and mutation test.
7. Add foundation tests proving the old IDs and `hand.grip` are absent; the
   eleven IDs, 41 count, 62 mesh bases, 44 actions, and both conditions are
   exact; and pronators/supinator carry their exact unvisualized reasons.
8. Add capability tests proving each radial/ulnar antagonist pair, the three
   elbow flexors, biceps/supinator supination, pronator pronation, and
   finger-flexor/extensor actions. Negative tests must prove, at minimum, that
   brachialis cannot supinate, brachioradialis cannot satisfy unconditional
   rotation, FCR cannot ulnarly deviate, FCU cannot radially deviate, ECR cannot
   ulnarly deviate, ECU cannot radially deviate, and finger extensors cannot
   flex the fingers.
9. Add mutation tests for both new action conditions: deleting a condition,
   swapping it to the opposite action, or using either conditional capability
   to satisfy an unconditional prime action must fail.
10. Add migration tests across all eight affected families proving every
    assigned stabilizer can satisfy an actual declared hand/wrist demand and no
    removed ID survives in any allowed role, requirement, rule, or exercise.
11. Keep the future Swift cutover explicit: replace the runtime `biceps` and
    `forearms` cases with matching cases/display names/groups/node ownership
    and extend mesh-mapping tests. Do not add a persistence migration or a new
    involvement-snapshot repair for the retired raw values: the product is
    pre-production and the store may reset at cutover. Stale raw values must
    still be absent from bundled fixtures and deterministic debug seeds.
12. Run the catalog validator, the complete catalog-v2 Python suite,
    `git diff --check`, and the generic iOS Simulator build before calling the
    activation complete. Simulator test suites remain opt-in under repository
    policy.

## Residual scope

`triceps` still combines all triceps heads while advertising shoulder extension,
an action specific to the long head. Batch 2 does not need to split it because
its family-defining elbow extension is shared by all heads and the scene offers
only one `Triceps` mesh. No new family may use the aggregate shoulder-extension
capability as its sole anatomical justification; revisit it if a future
long-head-specific contract becomes load-bearing.

Likewise, `forearmPronators` deliberately represents only the shared pronation
capability, and `extensorCarpiRadialis` only the shared wrist capabilities. This
is bounded aggregation, not a claim that their constituent muscles are
identical in every joint position.
