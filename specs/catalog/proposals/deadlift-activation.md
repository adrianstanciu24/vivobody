# Deadlift activation record

Status: approved and activated as two source-bounded families containing four
barbell exercises. The enforceable sources are
`families/conventional-deadlift.json` and
`families/romanian-deadlift.json`; this record preserves the evidence limits,
family split, product adaptations, and exclusions behind those contracts.

This decision supersedes only the deadlift deferrals in
`batch-5-hip-patterns.md`. The original Batch-5 good-morning and
hip-thrust/bridge decisions remain active and historically accurate.

## Outcome

| Family | Display name | Activated records | Direct fixture evidence |
|---|---|---|---|
| `conventional-deadlift` | Conventional Deadlift | `conventional-barbell-deadlift` | Lee 2018; Lyons 2026 supplies supporting vastus-lateralis evidence |
| `romanian-deadlift` | Romanian and Stiff-Leg Deadlift | `barbell-romanian-deadlift`; `barbell-stiff-leg-deadlift`; `barbell-romanian-deadlift-15-cm-step` | Coratella 2022; Lee 2018 and Lyons 2026 bound the ordinary Romanian technique |

The four canonical records are:

- `conventional-barbell-deadlift` — **Conventional Barbell Deadlift**;
- `barbell-romanian-deadlift` — **Floor-Touch Barbell Romanian Deadlift**;
- `barbell-stiff-leg-deadlift` — **Barbell Stiff-Leg Deadlift**; and
- `barbell-romanian-deadlift-15-cm-step` — **15 cm Step Barbell Romanian
  Deadlift**.

The first Romanian record is displayed as **Floor-Touch Barbell Romanian
Deadlift**. The familiar names **Barbell Romanian Deadlift**, **Romanian
Deadlift**, and **RDL** remain aliases, but they do not broaden the record into
a top-start continuous hinge that stops above the floor.

## Why there are two families

The conventional fixture has three training-defining actions:
`hip.extension`, `knee.extension`, and `ankle.plantarflexion`. Its directly
measured floor-pull mechanics require knee-extensor and plantarflexor roles.

The Romanian/stiff-leg fixtures have `hip.extension` as their sole dynamic
prime and `spine.flexion` as a resisted action. Coratella describes them as
hip-dominant, isometric-knee variations, but did not measure knee kinematics.
The contract therefore records the prescribed knee techniques without
inventing a `positionHeld` finding or promoting knee extension to a prime.

Combining these records would make required conventional knee and ankle
actions optional for every exercise and would hide the Romanian sources'
unmeasured-knee limitation. Separate families keep anatomy credit, training
analytics, validation, and user-facing substitutions aligned with the actual
fixtures.

The active good morning remains in `hip-hinge`. Its bar stays on the posterior
shoulder/upper-back surface between repetitions and its measured segmental
spine extension is a prime action. A familiar exercise name is not enough to
erase those mechanical differences.

## Source-exact family boundaries

### `conventional-deadlift`

Lee et al. studied 21 men with at least three years of conventional- and
Romanian-deadlift experience. The exact conventional condition used:

- a symmetric medium stance equal to 100 percent of pelvis width;
- a free straight bar held double-overhand with the arms outside the thighs;
- the same absolute load as the Romanian condition, equal to 70 percent of
  the tested Romanian-deadlift one-repetition maximum;
- five trials at a self-selected but consistently repeated speed; and
- an upright position, descent until the plates touched the floor, and return
  to upright standing.

The catalog presents those same measured phases in the familiar
floor-to-standing-to-floor order. That is an explicit product reordering, not
a claim that Lee tested a floor-first repetition. The source did not prescribe
a dead-stop pause, reset, or complete unloading at the bottom, so
`interRepSupport` is `floorContactNoSpecifiedReset`. It also did not report
foot orientation or spinal kinematics; those remain `unreported` and
`nonstandardized` rather than being inferred from conventional-deadlift
coaching.

Gluteus maximus and vasti are non-ranked co-primary emphases. Rectus femoris,
gastrocnemius, and soleus are secondary dynamic contributors. Medial
hamstrings and the combined biceps-femoris surface receive conservative hip,
pelvis, and knee-control credit rather than a false whole-region hip-extension
claim. The remaining authored muscles control the free bar, extended elbows,
shoulder girdle, trunk, wrists, and hands.

The runtime initializes the record at 45 lb / 20 kg and five repetitions, with
a recommended three-to-eight-repetition range. Those are product defaults,
not a conversion of Lee's 70-percent Romanian-deadlift one-repetition-maximum
load.

### `romanian-deadlift`

Coratella et al. studied ten male competitive bodybuilders. Each active
fixture used a free barbell, six non-exhausting repetitions at 80 percent of
that variation's separately tested one-repetition maximum, two-second ascent
and descent phases, and an approximately half-second isometric transition.
The plates touched the floor at the bottom of every repetition, but the paper
does not locate that isometric phase or prescribe a floor pause, reset, or
complete unloading.

All three records use a bilateral hip-distance stance, shoulder-distance
grip, free hands-in-front load, and a straight-spine instruction. Grip
orientation and foot orientation were not reported and remain unstandardized.

| Catalog record | Prescribed knee technique | Floor relationship |
|---|---|---|
| `barbell-romanian-deadlift` | Slightly flexed start and extended standing endpoint; kinematics unmeasured | Feet and bar plates use the same floor |
| `barbell-stiff-leg-deadlift` | Knees prescribed extended throughout; kinematics unmeasured | Feet and bar plates use the same floor |
| `barbell-romanian-deadlift-15-cm-step` | Same Romanian prescription; kinematics unmeasured | Both feet use an exact 15 cm step while the plates use the lower floor |

The step record is an exact 15 cm fixture, not a generic deficit range.
Coratella found materially different posterior-chain excitation in that
condition, so it remains a separate exercise rather than an invisible range
option. No step stiff-leg condition was tested.

Medial hamstrings and gluteus maximus are non-ranked co-primary emphases.
Lumbar extensors are secondary because they oppose the declared
`spine.flexion` tendency under the straight-spine instruction. The combined
biceps-femoris surface, gluteus medius, lower-leg, loaded-grip, shoulder-girdle,
and trunk regions retain stabilizer roles. Surface EMG supports this
conservative envelope but does not supply numeric contribution or hypertrophy
rankings.

The three records initialize at 95 lb / 42.5 kg and six repetitions. The fixed
weight is a product seed, not a claim to know 80 percent of an individual
athlete's variation-specific one-repetition maximum.

## Evidence ownership and limitations

The canonical metadata and full limitation scopes live in `evidence.json`.
Every registered source must remain referenced by anatomy or an active family.

### `coratella-2022-romanian-step-stiff-leg-deadlift`

Coratella directly supports the three barbell fixtures, their exact dose and
cadence, the 15 cm step, the flexed-versus-extended knee prescriptions, and a
posterior-chain EMG panel. It collected no kinematics or joint kinetics.
Its introduction calls these isometric-knee variations, while the Romanian
method starts slightly flexed and instructs a fully extended knee endpoint.
The contract preserves both reported technique facts but invents no measured
knee action. Accordingly, the study cannot prove literal zero knee excursion,
a universal depth, equal or ranked muscle contribution, hypertrophy,
unilateral geometry, or equivalence to another implement.

### `lee-2018-conventional-romanian-deadlift`

Lee directly supports the conventional stance, grip, load, floor contact,
three-dimensional lower-extremity kinematics, ground reaction forces, net
joint torques, and rectus-femoris, biceps-femoris, and gluteus-maximus EMG.
The common absolute load was 70 percent of the Romanian one-repetition maximum
and therefore was not the same relative intensity for both lifts. The EMG
normalization does not permit cross-muscle ranking. Some participants could
not achieve the instructed floor touch in the Romanian condition, so that
condition cannot authorize a universal Romanian depth or static knee angle.
Lee also did not establish spinal motion, a dead-stop reset, another grip,
sumo stance, trap-bar geometry, or equipment equivalence.

### `lyons-2026-conventional-romanian-deadlift`

Lyons studied 15 recreationally active adults using their typical uncoached
techniques, barefoot, at the same absolute load equal to 50 percent of a
self-reported or estimated Romanian-deadlift one-repetition maximum. The study
used sagittal two-dimensional video and measured only biceps femoris and
vastus lateralis with surface EMG. It supports greater conventional
vastus-lateralis excitation and, more importantly, shows that an ordinary
Romanian technique can have material knee motion.

The published paper is internally inconsistent about Romanian knee range of
motion. The results paragraph reports 38.3 +/- 14.5 degrees during ascent and
37.8 +/- 14.3 degrees during descent. Table 5 reports 33.6 +/- 12.8 and
33.0 +/- 12.7 degrees, and the later discussion rounds those table values to
34 and 33 degrees. The catalog therefore uses the study only as adverse
evidence against `positionHeld`; it does not select one of those values as a
canonical Romanian range.

### Boundary-only evidence

`schellenberg-2013-deadlift-goodmorning-kinematics` remains family-level
context for the conventional contract and direct evidence for `hip-hinge`.
Its different stance, grip, repetition topology, and good-morning measurements
do not supply fixture details to `conventional-barbell-deadlift`.

## Explicit exclusions

| Candidate | Decision boundary |
|---|---|
| Sumo deadlift | Wider stance, arms-inside-thighs grip geometry, and different hip/knee mechanics require a separate reviewed contract. |
| Hex/trap-bar deadlift | Handle height, load line, neutral-grip geometry, and knee-extensor demand are not straight-bar equivalence. |
| Single-leg or unilateral deadlift/RDL | Laterality, balance, pelvis control, and frontal/transverse demands differ from both bilateral families. |
| Staggered or B-stance RDL | Asymmetric support and load sharing require direct review; it is not a stance-width option. |
| Dumbbell or kettlebell variants | Implement path, floor reach, grip, load placement, and possible unilateral geometry differ. |
| Cable, Smith, lever-machine, or selectorized variants | Resistance direction, fixed path, mechanism, and external support are new contract facts. |
| Band-, chain-, or otherwise variable-resistance variants | Setup-dependent resistance is non-comparable and was not studied by these sources. |
| Top-start or continuous RDL that stops above the floor | The activated Romanian record is explicitly floor-touch; the common gym alternative needs its own reviewed range and inter-repetition topology. |
| Arbitrary deficits, conventional deficit pulls, block pulls, or rack pulls | Only the 15 cm step Romanian fixture is active; another height or support point is not an axis. |
| Step stiff-leg deadlift | Coratella tested no elevated stiff-leg condition. |
| Mixed grip, hook grip, snatch grip, straps, or grip assistance | Lee's conventional exercise is double-overhand, while Coratella did not report orientation; grip changes alter the fixture and grip demand. |
| Paused, dead-stop, reset, or touch-and-go as a distinct technique | Floor contact was measured, but pause, unloading, and reset behavior were not standardized. |
| Good morning | Remains owned by `hip-hinge`; posterior bar placement, no floor support, and measured spinal action are different. |

Names and aliases never override these boundaries. A candidate joins an active
family only after its action topology, support, path, stance, implement, and
source limitations match the family contract.

## Validation expectations

1. Keep exactly the two family IDs and four catalog IDs above, with global ID,
   name, and alias uniqueness. The integrated catalog contains 59 real
   families and 140 exercises.
2. Keep all three newly registered evidence IDs referenced and preserve the
   157-source coverage invariant. Unused registry entries and unknown refs
   must fail validation.
3. Pin the conventional prime actions to hip extension, knee extension, and
   ankle plantarflexion. Pin the Romanian family to hip extension as its only
   dynamic prime plus resisted spinal flexion; dynamic knee and spine actions
   must remain forbidden.
4. Mutation-test every required role, variant invariant, and source-exact
   rule. In particular, reject a conventional grip, stance, reset, or action
   change; reject swapped Romanian knee techniques; reject arbitrary platform
   heights; and require the 15 cm support/range fields only on the step record.
5. Prove neither Romanian knee prescription can become `positionHeld`, and
   keep Coratella's unmeasured kinematics plus the Lyons inconsistency visible
   in the evidence limitation tests.
6. Pin the source loads separately from the product defaults: Lee's common
   70-percent-Romanian-1RM load versus 45 lb / 20 kg, and Coratella's
   variation-specific 80-percent-1RM loads versus 95 lb / 42.5 kg.
7. Regenerate the bundled runtime and Xcode input list only through
   `Scripts/catalog.py --emit-runtime`, then run the full Python catalog suite,
   `Scripts/check.sh`, and `git diff --check`.
8. Because the new records are user-visible, pin all four canonical names in
   catalog/runtime tests and inspect Library plus exercise-detail screenshot
   and accessibility-tree evidence for one representative from each family.
   Record anything the semantic harness cannot observe as a manual
   verification item.

The canonical command sequence from the repository root is:

```bash
/usr/bin/python3 Scripts/catalog.py --emit-runtime
/usr/bin/python3 -m unittest discover -s Scripts/tests -p 'test_catalog.py'
Scripts/check.sh
```
