# Batch 6 ankle dorsiflexion activation

Status: **activation-ready after shared evidence registration and integration
tests**. The family contract is authored with one directly reviewed exercise.

## Outcome

Activate `ankle-dorsiflexion` with one deliberately narrow fixture:

| Exercise | Evidence status | Seed |
|---|---|---:|
| Seated Band Ankle Dorsiflexion | Direct non-occluded condition from Kjeldsen et al. | 0 lb, 15 reps |

The zero load is intentional. Elastic-band resistance is `nonComparable`, so
the exercise does not invent a stack or free-weight equivalent and does not
carry `defaultWeightKg`.

## Family boundary

This is a strict unilateral open-chain isolation. The athlete is seated with
the working foot on the reviewed board, moves that foot toward the shin
against a band affixed to the board, reaches an individualized comfortable
dorsiflexion stop, and returns until the sole contacts the board.

The fixed movement signature is only:

```text
planeBasisActions: ankle.dorsiflexion
primeActions:      ankle.dorsiflexion
planes:            sagittal
```

All other joint actions are forbidden as prime actions. In particular:

- `ankle.inversion` is not promoted merely because tibialis anterior can
  produce it;
- `ankle.eversion` is not promoted merely because fibularis tertius can
  produce it;
- `foot.toeExtension` is not promoted merely because the long toe extensors
  can assist dorsiflexion; and
- `ankle.plantarflexion` is not a second prime action during the controlled
  return. The band supplies the returning external torque while the
  dorsiflexors lengthen under control. The catalog records the concentric
  training action rather than converting every eccentric return direction
  into another mover action.

That boundary keeps banded inversion, eversion, and toe-extension drills out
of the family even though neighboring muscles can participate in more than
one anatomical action.

## Direct exercise evidence

Kjeldsen et al. studied 17 healthy adults in two acute sessions. Each person
performed the same unilateral ankle-dorsiflexion exercise once without blood
flow restriction and once with a thigh cuff. The active catalog record uses
only the ordinary, non-occluded training condition.

The directly reported setup and repetition are unusually concrete:

- participants sat comfortably with the foot resting on a board;
- the cohort's mean resting ankle angle was 130 plus or minus 7 degrees;
- each participant's maximum comfortable dorsiflexion was established and a
  physical stop prevented movement beyond it;
- a blue elastic band was affixed to the board and passed over the foot;
- the foot dorsiflexed to the stop for the concentric phase, remained there
  for three seconds, and returned until the sole touched the board; and
- surface EMG was recorded from tibialis anterior during all 75 contractions.

The paper measured each participant's knee and ankle angle so the posture
could be reproduced between sessions, but it does not report one universal
knee angle. Measurement is study metadata rather than an exercise variant, so
the contract uses `kneePosture: selfSelected`; it does not manufacture a
90-degree seated fixture or encode the researchers' measurement procedure.
Likewise, the cohort mean resting ankle angle is disclosed here but is not
encoded as an exercise prescription. `ankleStartPosition:
selfSelectedRestingPosition` and `rangeOfMotion:
toComfortableDorsiflexionStop` preserve what the study actually controlled.

The research protocol used four sets of 30, 15, 15, and 15 repetitions. The
catalog's 15-repetition seed and recommended 15-to-30 range are programming
defaults within that directly reviewed range, not a claim that users should
copy the study's fatigue protocol or three-second endpoint hold.

The study's blood-flow-restriction condition does not authorize a second
exercise. A cuff changes a training intervention, not the mechanical identity
of band ankle dorsiflexion, and Vivobody should not silently prescribe an
occlusion protocol through an exercise record.

## Taxonomy audit

The Batch-4 lower-leg split already provides four relevant visible regions:

| Muscle region | Authored capabilities | Batch-6 decision |
|---|---|---|
| `tibialisAnterior` | ankle dorsiflexion, ankle inversion | Required primary |
| `fibularisTertius` | ankle dorsiflexion, ankle eversion | Not assigned |
| `toeExtensors` | ankle dorsiflexion, toe extension | Not assigned |
| `fibularisLongusBrevis` | ankle plantarflexion, ankle eversion | Outside mover policy |

`arnold-2010-lower-limb` establishes possible action capabilities, not an
exercise-specific role hierarchy. Kjeldsen et al. explicitly trained and
measured tibialis anterior in the exact dynamic band fixture. That combination
supports tibialis anterior as the practical training emphasis and sole
categorical primary.

It does **not** prove that fibularis tertius and the long toe extensors were
electrically silent. They remain unassigned because neither was measured and
capability alone is not enough to award exercise volume. Adding them as
secondaries would create more certainty than the reviewed experiment permits.
The contract can be widened later if a condition-matched intramuscular or
imaging study supports it.

The same logic rejects a stabilizer workaround. Tibialis anterior's anatomy
profile already covers the declared ankle and foot control demands while
serving as the mover. No separate stabilizer is needed merely to satisfy the
validator, and no unmeasured dorsiflexor is relabeled as a stabilizer to get it
into the roster.

## Variant vocabulary

| Axis | Admitted value | Reason |
|---|---|---|
| `kineticChain` | `open` | The foot moves rather than remaining fixed to the environment. |
| `bodyPosition` | `seated` | Directly reported posture. |
| `pelvisSupport` | `seat` | Inherent in the reported seated setup. |
| `kneeMotion` | `positionHeld` | The task is isolated at the ankle and posture was reproduced between sessions. |
| `kneePosture` | `selfSelected` | The exercise holds a self-selected posture; measurement in the study is evidence metadata. |
| `ankleMotion` | `dorsiflexes` | Direct concentric action. |
| `ankleStartPosition` | `selfSelectedRestingPosition` | Avoids treating the cohort mean as a prescription. |
| `rangeOfMotion` | `toComfortableDorsiflexionStop` | Direct individualized endpoint. |
| `movingSegment` | `foot` | The foot moves relative to the lower leg. |
| `footBoardContact` | `soleAtBottom` | Directly reported bottom condition. |
| `loadInterface` | `footUnderBand` | Preserves the paper's wording without inventing a metatarsal landmark. |
| `resistanceGeometry` | `bandAffixedToFootBoard` | Directly reported anchor geometry. |
| `fixedPath` | `false` | A board-anchored band does not constrain an external load with rails or a lever. |
| `lowerBodyContribution` | `isolatedJointMotion` | Hip and knee propulsion are outside the task. |

The source does not report whether a chair back supported the torso. The
family therefore does not declare `torsoSupport` and does not claim either
`none` or a backrest. This omission is deliberate evidence preservation, not
an axis accidentally forgotten from the calf-raise sibling.

The individualized physical dorsiflexion stop is part of the authored setup,
not merely a laboratory note. The movement definition tells the athlete to
set and use it; a future record that uses an unconstrained endpoint requires a
separate review rather than silently inheriting this fixture.

`footBoardContact: soleAtBottom` does not mean the foot is closed-chain. Board
contact defines the bottom/reset position; the foot leaves that surface as it
dorsiflexes against the band.

## Exercise record

### Seated Band Ankle Dorsiflexion

- `catalogID`: `seated-band-ankle-dorsiflexion`
- equipment: `band`
- laterality: `unilateral`
- modality/tracking: `dynamicStrength` / `reps`
- load mode: `nonComparable`
- primary: `tibialisAnterior`
- default: 15 repetitions, no comparable load seed

The canonical name says what a user needs to reproduce. “Tibialis raise” is
not an alias: current gym usage often refers to a standing, heel-supported
bodyweight or plate-loaded movement, which is not the reviewed board-and-band
fixture. Blood-flow-restriction language is also absent from the name and
aliases because that condition is intentionally not activated.

## Explicit exclusions and deferrals

| Candidate | Decision |
|---|---|
| Blood-flow-restricted band dorsiflexion | Not a separate catalog exercise; intervention is not prescribed. |
| Standing heel-supported tibialis raise | Deferred pending a directly reviewed load and support geometry. |
| Wall-supported tibialis raise | Deferred with the standing branch. |
| Plate-loaded tibialis raise | Deferred pending direct apparatus and load-interface evidence. |
| Dorsiflexion machine | Deferred; no reviewed commercial mechanism is generalized from the band board. |
| Cable dorsiflexion | Deferred; different anchor and load semantics. |
| Manual-resistance dorsiflexion | Deferred; external resistance is not reproducibly trackable here. |
| Isometric dorsiflexion testing | Outside this dynamic-strength contract. |
| Bilateral band dorsiflexion | Deferred; the direct exercise was unilateral. |
| Gait, balance, and unstable-surface tasks | Not ankle-isolation exercises. |
| Banded inversion or eversion | Future frontal-plane ankle families, not variants. |
| Toe-extension drills | Future toe-action family, not a dorsiflexion variant. |

## Evidence registration payload

The shared `evidence.json` integration should register exactly:

```json
{
  "id": "kjeldsen-2019-dorsiflexor-training",
  "sourceType": "experimentalEMGStudy",
  "title": "Neuromuscular effects of dorsiflexor training with and without blood flow restriction",
  "authors": [
    "Simon Svanborg Kjeldsen",
    "Erhard Trillingsgaard Næss-Schmidt",
    "Gunhild Mo Hansen",
    "Jørgen Feldbæk Nielsen",
    "Peter William Stubbs"
  ],
  "year": 2019,
  "doi": "10.1016/j.heliyon.2019.e02341",
  "pmid": "31467996",
  "url": "https://doi.org/10.1016/j.heliyon.2019.e02341",
  "scope": "Seventeen healthy adults performed unilateral seated concentric-eccentric ankle dorsiflexion against a blue elastic band affixed to a foot board, both without and with thigh-cuff blood-flow restriction. The directly reported self-selected resting board position, individualized comfortable dorsiflexion stop, return until sole contact, and tibialis-anterior EMG anchor the non-occluded band exercise. The source does not establish fibularis-tertius or toe-extensor roles, a universal knee or ankle angle, comparable band load, a fixed external path, or a separate blood-flow-restriction exercise."
}
```

Bibliographic metadata:

- Simon Svanborg Kjeldsen, Erhard Trillingsgaard Næss-Schmidt, Gunhild Mo
  Hansen, Jørgen Feldbæk Nielsen, Peter William Stubbs.
- *Heliyon* 5(8):e02341 (2019).
- DOI `10.1016/j.heliyon.2019.e02341`.
- PMID `31467996`; PMCID `PMC6710534`.

## Activation gates

1. Register `kjeldsen-2019-dorsiflexor-training` with the exact metadata and
   limitations above.
2. Validate one family and exactly one exercise with globally unique canonical
   name, aliases, and `catalogID`.
3. Pin the fixed action, sagittal plane, isolation mechanic, null pattern and
   direction, equipment, laterality, modality, tracking, and load mode.
4. Assert that `forbiddenPrimeActions` is the exact 43-action complement and
   mutate every forbidden action into `additionalPrimeActions`.
5. Remove and demote the tibialis-anterior requirement independently.
6. Pin every single-value enum axis and mutate it outside its admitted domain.
7. Mutate `fixedPath` directly and require the fixed-value validation error.
8. Prove the roster's assigned mover covers both `ankle` and `foot` stability
   demands without a fabricated stabilizer.
9. Pin no involvement for `fibularisTertius`, `toeExtensors`,
   `fibularisLongusBrevis`, gastrocnemius, soleus, or flexor hallucis longus.
10. Pin zero `bodyweightFraction`, zero `defaultWeight`, no
    `defaultWeightKg`, and `nonComparable` band semantics.
11. Pin the exact movement definition and aliases transparently rather than
    through an opaque hash.
12. Assert that no active record or alias calls this fixture a tibialis raise,
    dorsiflexion machine, or blood-flow-restriction exercise.
13. Re-run the whole catalog suite so the new global names and evidence
    reference remain collision-free.

No taxonomy, joint-action, family schema, or validator extension is required
for this activation.
