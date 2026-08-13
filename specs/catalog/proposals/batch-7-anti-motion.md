# Batch 7 — anti-motion activation

Status: active in three family contracts against the shared resisted-action
foundation, with Batch-7 integration tests and count documentation complete.
The reviewed roster is deliberately limited to one isometric fixture per
family.

## Outcome

| Family | Initial fixture | Decision |
|---|---|---|
| `anti-extension` | Stable Forearm Plank | Active narrowly |
| `anti-lateral-flexion` | Side Plank | Active narrowly |
| `anti-rotation` | Feet-Together Band Pallof Hold | Active narrowly |

These are three contracts, not one generic core family. Each resists a
different spinal action in a different cardinal plane, and each has a distinct
support and resistance topology. Dynamic trunk flexion, lateral flexion, and
rotation remain outside all three contracts.

All three use `fixed.mechanic: compound` and `fixed.pattern: core`. Each hold
materially depends on multiple controlled joints and support regions even
though no joint excursion is tracked, so calling it a single-joint isolation
would contradict both the exercise topology and the app's mechanic semantics.
`core` is the existing reviewed pattern for compound trunk-control tasks; a
null pattern is unavailable because the shared contract reserves null for
isolation families. The family split still comes from the resisted spinal
action and support topology, not from collapsing the records into one generic
core contract.

## Required foundation semantics

An anti-motion exercise does not create a fictional concentric prime action.
The family declares one `movementSignature.resistedActions` entry and no
`primeActions`; `planeBasisActions` names that resisted action so the existing
plane exactness still follows the anatomical action:

| Family | Resisted action | Plane |
|---|---|---|
| `anti-extension` | `spine.extension` | sagittal |
| `anti-lateral-flexion` | `spine.lateralFlexion` | frontal |
| `anti-rotation` | `spine.rotation` | transverse |

The shared foundation proves that an authored primary or secondary can
resist the action. It must not infer that an isometric exercise dynamically
performs the opposite action. The family contracts also need to forbid every
dynamic prime action, including the action being resisted. A plank that adds a
crunch, hip lift, row, shoulder tap, or leg lift is therefore a different or
hybrid family rather than a variant-axis choice.

The current action vocabulary does not encode left and right lateral flexion
or axial rotation. Consequently, a unilateral fixture cannot identify the
loaded-side and contralateral-side fibers through the action ID alone. The
exercise definition must be performed on both sides, while categorical volume
credit remains at the bilateral visible-region level.

## Anti-extension

Lehman et al. directly tested a stable-floor prone bridge in which only the
feet and forearms contacted the floor, the elbows were below the shoulders,
the upper arms were perpendicular to the floor, the spine and legs were held
in neutral alignment, and EMG was collected during a five-second isometric
portion. On the stable surface, mean activity was 26.6% MVC for rectus
abdominis, 44.6% for external oblique, 29.5% for internal oblique, and about
5.0% for erector spinae. The authors explicitly describe rectus abdominis as a
prime mover resisting the gravity-created trunk-extension moment.

The initial record therefore assigns `abs` primary and `obliques` secondary.
That is a practical training-emphasis judgment grounded in the authors'
description of rectus abdominis as a prime mover, not a ranking inferred from
EMG magnitude: mean external- and internal-oblique activity both exceeded
rectus-abdominis activity in the stable fixture. Both visible abdominal regions
also stabilize the declared spine and pelvis demands.

The low measured erector-spinae activity is retained only as context. The
visible `quadratusLumborum` region is now QL alone, while the erector-spinae and
multifidus `lumbarExtensors` region is explicitly unvisualized. Neither signal
creates a role in this family.

The forearm-and-foot bridge nevertheless makes its internal support chain
material rather than incidental. `serratus`, `externalRotators`, and `triceps`
stabilize the scapula, shoulder, and elbow; `gluteMax`, `vasti`, and `soleus`
stabilize the held hip, knee, ankle, and foot. Those six assignments are
conservative anatomy-and-mechanics inferences. Lehman did not measure those
muscles, so neither their inclusion nor their relative magnitude is attributed
to its EMG panel.

Cinarli and Kafkas included stable prone planks for two 30-second sets during
the first three weeks of a six-week anti-movement program before progressing
to a suspended version. That supports the 30-second product seed and use as a
trainable isometric fixture. Because their
intervention combined several anti-motion exercises, its post-training EMG
changes do not isolate the prone plank or establish its per-exercise role
hierarchy.

The proposed record surface is:

- ID/name: `plank`, **Stable Forearm Plank**
- aliases: `Plank`, `Front Plank`, `Forearm Plank`
- bodyweight, bilateral, `isometricStrength`, duration,
  `nonComparable`, zero bodyweight fraction, 30-second seed
- required axes: closed kinetic chain; prone-horizontal body position; floor
  support; forearms for the upper body; feet for the lower body; elbows below
  shoulders; upper arms perpendicular to the floor; neutral straight-line
  body alignment; spine, pelvis, hip, and knee position held; timed isometric
  hold; free rather than rail/lever-guided path; static lower-body support only

`nonComparable` is intentional. Neither reviewed source supplies a validated
fraction of body mass that can be treated like comparable external load for an
isometric hold.

## Anti-lateral flexion

Juan-Recio et al. directly tested a conventional side-bridge endurance hold in
young, healthy, physically active women. Participants supported the preferred
side on the forearm and elbow with shoulder and elbow at 90 degrees, kept both
legs extended and barefoot, placed the non-preferred foot in front, put the
free hand on the contralateral shoulder, and maintained a straight line from
shoulder through hip to feet until exhaustion. External oblique, rectus
abdominis, internal oblique, deltoid, erector spinae, gluteus medius,
latissimus dorsi, and rectus femoris were all measured on the preferred
support side.

External oblique was 50.2% MVIC, rectus abdominis 41.9%, internal oblique
40.6%, deltoid 36.3%, erector spinae 28.2%, and gluteus medius 21.2%. The
initial record therefore assigns:

- `obliques` primary, directly measured and mechanically responsible for the
  named anti-lateral-flexion task;
- `quadratusLumborum` secondary through the exact visible QL region's reviewed
  lateral-flexion capability. The measured erector-spinae signal does not
  establish that role, and neither the action model nor the body mesh can
  encode loaded versus contralateral side;
- `abs` stabilizer, based on directly measured rectus-abdominis activity and
  its spine/pelvis stabilization capability rather than a claim that it is a
  lateral flexor;
- `deltoidLateral` stabilizer, mechanically mapping the study's directly
  measured unheaded deltoid signal to the shoulder-abductor demand rather than
  claiming head-specific measurement; and
- `gluteMed` stabilizer, based on directly measured hip-abductor activity and
  its hip/pelvis stabilization capability; and
- `rectusFemoris` stabilizer, based on the directly measured muscle and the
  extended-knee support posture.

`serratus`, `triceps`, and `soleus` close the materially loaded scapular,
elbow, ankle, and foot support chain through anatomy and mechanics. They were
not measured in the side-bridge study. The `quadratusLumborum` assignment likewise is
not an erector-spinae proxy: its admission is driven by quadratus-lumborum
anatomy and it remains impossible to allocate that credit to a particular
side.

The paper is deliberately adverse to treating side-plank duration as a pure
lateral-flexor diagnostic: shoulder fatigue, anthropometry, and other muscles
materially affected performance. The catalog uses it as a multi-joint
exercise, not as a normalized clinical test or a claim that duration is
comparable between users. Cinarli and Kafkas separately trained lateral planks
for two 30-second sets, which supports the default hold seed but not an
exercise-isolated adaptation claim.

The proposed record surface is:

- ID/name: `side-plank`, **Side Plank**
- aliases: `Side Bridge`, `Side Plank Hold`, `Lateral Plank Hold`
- bodyweight, unilateral, `isometricStrength`, duration,
  `nonComparable`, zero bodyweight fraction, 30-second seed
- required axes: closed kinetic chain; side-bridge body position; floor
  support; preferred-side forearm and elbow upper-body support; extended legs;
  feet as lower-body support; non-preferred foot in front; free hand on the
  contralateral shoulder; shoulder and elbow held at 90 degrees; straight
  shoulder-hip-feet alignment; spine, pelvis, and hips position held; timed
  isometric hold; free path; static lower-body support only

Laterality is unilateral because the external moment and support side are
one-sided. The movement definition instructs performing the hold on both sides;
the `preferredSide` spelling describes the reviewed laboratory setup rather
than prescribing that users train only their preferred side. The both-sides
prescription is a mirrored mechanics/training adaptation, not a claim that the
study recorded bilateral EMG.

## Anti-rotation

Juan-Recio et al. compared five Pallof conditions in twelve physically active
participants. The narrow initial record uses the directly tested
feet-together standing condition on the floor. Participants held both hands at
shoulder height with the arms extended perpendicular to the body, held the
posture for 15 seconds, and resisted a horizontal elastic-band force anchored
to a pulley machine at the side. The investigators deliberately used an
elbows-extended isometric posture instead of a repeated press so sudden arm and
trunk movements would not contaminate the pelvic-acceleration measurement.

The source directly supports the anti-rotation topology, the floor and
feet-together condition, extended-arm posture, horizontal band trajectory,
and 15-second seed. It measured sacral acceleration, not muscle EMG. It
therefore does not directly establish a muscle-role hierarchy. `obliques` is
the sole primary through the reviewed resisted-action capability and the
region's axial-rotation anatomy; this is a mechanics/anatomy-derived assignment
and the aggregate cannot encode internal-versus-external or left-versus-right
oblique recruitment. `abs` and explicitly unvisualized `lumbarExtensors` are
spine/pelvis stabilizers, while
`deltoidAnterior`, `triceps`, `fingerFlexors`, and
`extensorCarpiRadialis` are mechanics-derived stabilizers for the held
shoulder, elbow, and two-hand handle task. Extensor carpi radialis supplies
neutral-wrist counter-control against the finger flexors' wrist-flexion
moment. None of those roles should be presented as a Juan-Recio EMG result.

The study deliberately manipulated stance and support surface to alter the
postural-control challenge, so the feet-together base cannot be modeled as
inert. `serratus`, `gluteMed`, `vasti`, and `soleus` conservatively stabilize
the scapula, hip/pelvis, knee, and ankle/foot chain. These are also
anatomy-and-mechanics-derived roles rather than Pallof EMG findings; the study
measured sacral acceleration only.

The experiment scaled lateral band force by body-mass bracket using a digital
dynamometer. That makes comparisons inside the study interpretable but is not
a usable catalog load unit. The initial exercise transparently adapts load
selection to a self-selected band tension that challenges the hold without
visible torso or pelvic rotation, keeps `loadMode: nonComparable`, and does not
claim that one band color or extension is comparable across products.

Cinarli and Kafkas trained a standing Pallof hold for two 30-second sets with
specified light and medium resistance bands. This supports the exercise as a
trainable anti-rotation hold and a plausible progression, but the mixed
intervention cannot isolate a Pallof-specific adaptation and does not override
the 15-second condition-matched seed.

The proposed record surface is:

- ID/name: `feet-together-band-pallof-hold`, **Feet-Together Band Pallof Hold**
- aliases: `Standing Band Pallof Hold`, `Band Anti-Rotation Hold`
- band, unilateral, `isometricStrength`, duration, `nonComparable`, zero
  bodyweight fraction, 15-second seed
- required axes: closed kinetic chain; standing body position; floor support;
  feet-together stance; spine and pelvis position held; shoulder height;
  both arms perpendicular to the torso; `elbowMotion: angleHeld`
  under the shared upper-body vocabulary; elbows held extended; static
  two-hand handle hold; horizontal lateral band trajectory; self-selected
  challenging band tension; timed isometric hold; free path; static
  lower-body support only

The canonical exercise is a hold, not the common dynamic Pallof press. Any
record that repeatedly moves the hands between chest and extension would need
a separate exercise topology and a reviewed decision about whether the arm
motion is part of the tracked repetition.

## Shared role and action boundaries

Only muscles with a stated basis are admitted. Exercise-specific measurements
are not silently generalized across families:

| Family | Primary | Secondary | Stabilizers |
|---|---|---|---|
| `anti-extension` | `abs` | `obliques` | `serratus`, `externalRotators`, `triceps`, `gluteMax`, `vasti`, `soleus` |
| `anti-lateral-flexion` | `obliques` | `quadratusLumborum` | `abs`, `deltoidLateral`, `gluteMed`, `rectusFemoris`, `serratus`, `triceps`, `soleus` |
| `anti-rotation` | `obliques` | none | `abs`, `lumbarExtensors`, `serratus`, `deltoidAnterior`, `triceps`, `fingerFlexors`, `extensorCarpiRadialis`, `gluteMed`, `vasti`, `soleus` |

All 44 dynamic joint actions are forbidden as prime actions in every family.
This full complement is intentional even when the current role list would also
make an unrelated action fail. It keeps the anti-motion boundary explicit if
the allowed role surface expands later.

The initial families do not admit exercise-level additional resisted actions.
A renegade row, plank shoulder tap, one-arm plank, side-plank row, Copenhagen
plank, or asymmetric loaded plank combines multiple resisted or dynamic actions
and remains deferred. Carries stay outside these three anti-motion contracts;
the same batch activates their distinct topology as separate `farmer-carry`
and `suitcase-carry` families.

## Evidence registration payloads

The shared registry contains these four sources.

### `lehman-2005-stable-prone-bridge`

- Source type: `experimentalEMGStudy`
- Title: *Trunk muscle activity during bridging exercises on and off a Swiss
  ball*
- Authors: Gregory J. Lehman; Wajid Hoda; Steven Oliver
- Year: 2005
- DOI: `10.1186/1746-1340-13-14`
- PMID: `16053529`
- Direct scope: eleven resistance-trained men; stable-floor prone bridge with
  feet and forearms contacting the floor, elbows below shoulders, upper arms
  perpendicular to the floor, neutral spine/leg alignment, and a five-second
  isometric collection; rectus-abdominis, external-oblique,
  internal-oblique, and L3 erector-spinae surface EMG. It supports the exact
  stable fixture and conservative trunk roles, not a universal endurance
  prescription, bodyweight load fraction, sex-independent magnitude, shoulder
  or hip roles, unstable/suspended variants, or hypertrophy.

### `juan-recio-2022-side-bridge-endurance`

- Source type: `experimentalEMGStudy`
- Title: *Is the Side Bridge Test Valid and Reliable for Assessing Trunk
  Lateral Flexor Endurance in Recreational Female Athletes?*
- Authors: Casto Juan-Recio; Amaya Prat-Luri; Alberto Galindo; Agustín
  Manresa-Rocamora; David Barbado; Francisco J. Vera-Garcia
- Year: 2022
- DOI: `10.3390/biology11071043`
- PMID: `36101422`
- Direct scope: recreationally active young women; preferred-side floor
  side-bridge supported by forearm/elbow and feet, shoulder and elbow at 90
  degrees, extended legs, non-preferred foot in front, free hand on the
  contralateral shoulder, straight shoulder-hip-feet alignment, and hold to
  exhaustion; all eight EMG sites were recorded on the preferred support side:
  rectus abdominis, external and internal oblique, rectus femoris, gluteus
  medius, deltoid, latissimus dorsi, and erector spinae. It
  supports the exact fixture and measured regional demand, while its findings
  explicitly warn that shoulder fatigue and anthropometry make the task a
  multi-joint test rather than a pure or cross-user-normalized measure of trunk
  lateral-flexor endurance. It does not resolve left/right credit inside
  bilateral mesh aggregates or directly measure quadratus lumborum.

### `juan-recio-2025-pallof-postural-challenge`

- Source type: `experimentalPosturalControlStudy`
- Title: *Effect of Body Position and Support Surface on the Postural Control
  Challenge During the Pallof Press Exercise: A Smartphone
  Accelerometer-Based Study*
- Authors: Casto Juan-Recio; Amaya Prat-Luri; Heidy Rondón-Espinosa; David
  Barbado; Francisco J. Vera-Garcia
- Year: 2025
- DOI: `10.3390/medicina61020312`
- PMID: `40005429`
- Direct scope: twelve physically active adults; fifteen-second isometric
  Pallof conditions with both hands at shoulder height, elbows extended, arms
  perpendicular to the body, a horizontal elastic band attached to a side
  pulley, body-mass-bracketed dynamometer-standardized lateral force, and
  sacral smartphone acceleration. It directly supports the feet-together
  standing-on-floor topology and postural challenge, not muscle roles,
  self-selected load equivalence, a dynamic press, cable-stack load, or a
  hypertrophy outcome.

### `cinarli-2025-anti-movement-training`

- Source type: `experimentalTrainingStudy`
- Title: *Neuromuscular activation following anti-movement and dynamic core
  training: a randomized controlled comparative study*
- Authors: Fahri Safa Cinarli; Muhammed Emin Kafkas
- Year: 2025
- DOI: `10.1007/s00421-025-05768-4`
- PMID: `40195160`
- Direct scope: thirty-six recreationally trained men randomized to
  anti-movement, traditional-dynamic, or control groups; two sessions weekly
  for six weeks; the anti-movement program used 30-second isometric sets and
  included stable prone plank, lateral plank, and standing Pallof hold among
  several other exercises and progressions. It supports trainability and the
  30-second product detent, not a per-exercise causal adaptation, role
  hierarchy, exact Juan-Recio Pallof geometry, or one exercise's isolated EMG
  response.

## Explicit deferrals

| Candidate | Decision |
|---|---|
| High plank | Defer; changes upper-limb support and shoulder/elbow demands |
| Kneeling plank or side plank | Defer; changes body lever and support topology |
| Unstable or suspension plank | Defer; the stable studies do not transfer exact demand |
| Long-lever, weighted, or loaded plank | Defer; external load location and joint demands need review |
| Plank shoulder tap, reach, drag, row, or leg lift | Defer to hybrid contracts with additional resisted/dynamic actions |
| Side-plank row or hip abduction | Defer; adds a tracked dynamic joint action |
| Copenhagen plank | Defer; adds a distinct adductor/support topology |
| Cable Pallof hold | Defer; external stack load and comparability differ from the reviewed band |
| Dynamic Pallof press | Defer; arm motion is deliberately absent from the initial hold |
| Kneeling, split-stance, tandem, or unstable Pallof | Defer; the reviewed source shows posture changes challenge |
| Loaded carry | Excluded from these anti-motion contracts; Batch 7 activates the reviewed bilateral and unilateral topologies as separate `farmer-carry` and `suitcase-carry` families |

## Activation gates

1. Land and test the shared resisted-action schema, anatomy capability, plane
   basis, and validation semantics before adding family JSON.
2. Register the four evidence payloads exactly once and cite each from at least
   one active family or exercise.
3. Pin exactly one exercise per family, including globally unique IDs, names,
   aliases, definitions, seeds, and evidence references.
4. Assert an empty prime-action list, the exact one-item resisted-action list,
   and the exact cardinal plane for each family.
5. Assert the full 44-action forbidden-prime complement and mutate every
   forbidden action independently.
6. Remove and demote every required role independently; separately pin every
   allowed role so a measured stabilizer cannot be silently promoted.
7. Pin every required enum/boolean axis and mutate every value directly with a
   precise validator message.
8. Pin stability providers and distinguish exercise-measured role evidence
   from anatomy/mechanics-derived stabilization in tests and prose.
9. Pin `nonComparable`, zero bodyweight fraction, and 30/30/15-second seeds;
   do not reintroduce unsupported legacy bodyweight fractions.
10. Pin the anti-lateral-flexion `quadratusLumborum` aggregation and side-resolution
    caveat, the side-bridge diagnostic limitation, the Pallof no-EMG
    limitation, and the mixed-intervention limitation.
11. Assert that dynamic Pallof press and hybrid plank families remain absent,
    and that no carry record leaks into any of the three anti-motion rosters.
