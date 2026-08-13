# Batch 4 — knee and ankle isolation review

Status: activated. The three candidates became active only after the
lower-body taxonomy migration replaced the old aggregate `quads`,
`hamstrings`, and `calves` IDs. This file records the evidence, exact migrated
IDs, initial rosters, boundaries, and shared axis spellings used by the active
contracts.

## Outcome

| Candidate | Decision | Initial roster |
|---|---|---:|
| `knee-extension` | Active | 2 |
| `knee-flexion` | Active | 2 |
| `ankle-plantarflexion` | Active | 2 |

The six active exercises are not an equipment survey. They are the six
directly reviewed unilateral machine conditions that make posture-dependent
biarticular behavior testable:

- upright and reclined unilateral knee extensions at 90 and approximately 40
  degrees of hip flexion;
- seated and prone unilateral leg curls at approximately 90 and 30 degrees of
  hip flexion; and
- standing and seated unilateral calf raises at 0 and 90 degrees of knee
  flexion.

Every fixture holds the joints outside the family action still. A posture axis
describes that held geometry; it does not add a hip, knee, ankle, spine, or
pelvis prime action.

Stability coverage is role-agnostic. A declared demand needs an assigned
muscle whose central profile can stabilize it, but that contributor may remain
primary or secondary when dynamic work is its principal role. Knee extension
therefore covers hip with rectus femoris and knee with rectus femoris/vasti;
knee flexion covers pelvis/hip with medial hamstrings, sartorius, and gracilis
and knee with its assigned movers; plantarflexion covers knee with
gastrocnemius and ankle/foot with gastrocnemius/soleus. Their empty stabilizer
whitelists are deliberate rather than missing provider lists.

## Resolved taxonomy dependency

The pre-Batch-4 aggregates cannot express the reviewed contrasts. Activation
assumes these exact migrated IDs and capabilities:

| Old aggregate | Required exact regions for these families | Relevant capabilities |
|---|---|---|
| `quads` | `rectusFemoris`, `vasti` | Rectus femoris produces hip flexion and knee extension; the vasti produce knee extension. |
| `hamstrings` | `medialHamstrings`, `bicepsFemoris` | Both produce knee flexion; only `medialHamstrings` receives aggregate hip-extension capability because the scene's biceps-femoris mesh cannot distinguish its long and short heads. |
| `hipFlexors` | `sartorius` plus separately migrated iliopsoas | Sartorius produces knee flexion as well as its hip actions; iliopsoas does not receive knee flexion. |
| `adductors` | `gracilis` plus separately migrated adductor regions | Gracilis produces knee flexion and hip adduction; the other adductor regions do not inherit knee flexion. |
| `calves` | `gastrocnemius`, `soleus`, `flexorHallucisLongus` | Gastrocnemius produces knee flexion and plantarflexion; soleus produces plantarflexion only; flexor hallucis longus produces plantarflexion and toe flexion. |

This is not cosmetic taxonomy. The knee-extension evidence manipulates hip
angle specifically because rectus femoris crosses the hip while the vasti do
not. The leg-curl evidence measures all four hamstring heads plus sartorius and
gracilis. The calf-raise evidence manipulates knee angle specifically because
gastrocnemius crosses the knee while soleus does not.

The active contracts must not recreate those retired aggregate names. They
also must not give `bicepsFemoris` hip extension merely because one of the two
heads hidden in its unsplittable scene mesh crosses the hip.

## Shared lower-body isolation vocabulary

These spellings are shared with the Batch-4 hip-isolation review. Support and
motion are separate facts: a machine pad does not by itself prove the pelvis or
spine stayed still, so the contracts author both.

| Axis | Values used here | Meaning |
|---|---|---|
| `kineticChain` | `open\|closed` | Whether the distal segment is free to move or remains supported against the environment. Leg extensions and curls are open; calf raises retain forefoot contact and are closed. |
| `bodyPosition` | `standing\|seated\|reclined\|prone` | Gross reviewed body position. `reclined` is the approximately 40-degree hip-flexion leg-extension condition, not a generic seat-back angle. |
| `torsoSupport` | `none\|machinePad` | External surface directly supporting the torso. The knee-machine fixtures use a pad; neither calf fixture has torso contact. |
| `pelvisSupport` | `none\|machineSeat\|machinePadAndStrap` | Actual external pelvis support/restraint. Standing calf raise uses none; seated machine fixtures use a seat; the directly reviewed leg curls add a pelvis strap. It is not a muscle-action claim. |
| `pelvisMotion` | `positionHeld` | The pelvis does not deliberately move to create the repetition. |
| `spineMotion` | `positionHeld` | The spine does not deliberately flex, extend, laterally flex, or rotate to create the repetition. |
| `hipMotion` | `positionHeld` | Hip angle is held while the knee or ankle moves. |
| `kneeMotion` | `positionHeld\|flexes\|extends` | Dynamic or held knee behavior. |
| `ankleMotion` | `positionHeld\|plantarflexes` | Dynamic or held ankle behavior. |
| `footMotion` | `positionHeld` | No deliberate toe flexion/extension, inversion, or eversion creates these repetitions. |
| `hipFlexionDegrees` | exact reviewed value | Hip flexion from anatomical neutral while held. |
| `kneeFlexionDegrees` | exact reviewed value | Knee flexion from full extension while held. |
| `kneeStartFlexionDegrees` / `kneeEndFlexionDegrees` | exact reviewed values | Canonical knee positions at the start and concentric endpoint. |
| `movingSegment` | `lowerLeg\|foot` | The segment whose motion defines the repetition. |
| `loadInterface` | `distalShinPad\|shoulderPad\|distalThighPad` | Where the reviewed machine applies external load to the athlete. |
| `machineType` | `leverKneeExtension\|leverLegCurl\|standingCalfRaise\|seatedCalfRaise` | Machine mechanism used by the reviewed fixture. |
| `fixedPath` | boolean, `fixedValue: true` | A machine lever constrains the external-load path. It retains the established external-load meaning. |
| `lowerBodyContribution` | `isolatedJointMotion` | The named joint action creates the repetition; another lower-body joint does not propel the load. |

The three purpose-built machine families do not also declare
`resistanceGeometry`. In these rosters, `machineType` plus `loadInterface`
already identifies the observable mechanism and where it opposes the athlete;
a second one-to-one enum would duplicate that information. The sibling
`hip-extension` contract retains `resistanceGeometry: limbSegmentGravity`
because it has no machine type and the unsupported limb's gravity load is a
separate mechanical fact.

The numeric axes use `minimum == maximum` for each family only where all
active fixtures share a value. When a family admits two directly measured
values, the numeric range alone is not the permission boundary: reciprocal
rules map the reviewed body position to the exact angle, leaving no truthful
intermediate fixture. A future 60-degree posture requires a contract edit and a
reviewed exercise rather than entering through the numeric interval.

The initial knee-extension and knee-flexion fixtures are unilateral because
the direct training studies randomized one leg to each posture. Bilateral
machine variants are common but are not silently inferred from unilateral
research. The same constraint applies to the calf study's within-person
unilateral conditions.

## Common action boundary

Each isolation family forbids the complete current action complement except
its one prime action. This is stricter and clearer than the older partial-list
style. In particular:

- knee extension forbids hip extension/flexion, ankle plantarflexion, and spine
  extension so a sissy squat, squat, or leg press cannot enter;
- knee flexion forbids hip extension and ankle plantarflexion so a Nordic,
  glute-ham raise, bridge curl, or active ankle strategy cannot enter; and
- plantarflexion forbids knee extension/flexion and hip extension so a jump,
  sled push, or push-press drive cannot enter.

Held posture and eccentric return do not add opposite-direction prime actions.
Every contract uses `mechanic: isolation`, `pattern: null`, `direction: null`,
and `planes: [sagittal]`.

## Family 1: `knee-extension`

### Contract and role policy

The family is a strict open-chain machine movement in which the lower leg
extends at the knee while hip, pelvis, spine, ankle, and foot positions remain
held. Its sole prime and plane-basis action is `knee.extension`; group policy is
`legs` only.

Exact family evidence refs:

- `arnold-2010-lower-limb` for lower-limb musculotendon geometry;
- `larsen-2025-leg-extension-hip-flexion` for the two unilateral training
  postures and region-specific hypertrophy; and
- `mitsuya-2023-leg-extension-hip-flexion` for acute MRI T2 evidence that
  proximal and middle rectus-femoris activity is greater at 0/40 than at 80
  degrees of hip flexion.

Role envelope:

```json
{
  "requirements": [
    { "anyOf": ["vasti"], "minimumRole": "primary" },
    { "anyOf": ["rectusFemoris"], "minimumRole": "secondary" }
  ],
  "allowedByRole": {
    "primary": ["vasti", "rectusFemoris"],
    "secondary": ["rectusFemoris"],
    "stabilizer": []
  }
}
```

`vasti` is primary in both conditions. `rectusFemoris` is also primary in the
reclined 40-degree condition, where Larsen found substantially greater distal
and proximal hypertrophy and Mitsuya found greater proximal/middle T2 change
than in the high-flexion condition. It remains secondary rather than absent in
the 90-degree condition: Larsen still found rectus-femoris hypertrophy there,
and the muscle remains a knee extensor despite its shortened hip posture.

The contract does not split vastus lateralis, medialis, and intermedius because
the body model and migration intentionally preserve one exact `vasti` region.
Larsen directly measured vastus lateralis, not all three vasti; the shared
knee-extension capability, plus broader quadriceps evidence, supports the
aggregate region without pretending the study measured every component.

No antagonist or trunk stabilizer is added merely to fill a role table. The
reviewed machine and authored support/restraint bound the torso/pelvis setup;
they do not substitute for internal stability coverage. Rectus femoris covers
the declared hip demand, while rectus femoris and vasti cover the knee demand
at their already-authored mover roles.

### Rules and exact roster

Required axes are the shared values above plus:

```text
ankleMotion: positionHeld
footMotion: positionHeld
kneeMotion: extends
kneeStartFlexionDegrees: 110
kneeEndFlexionDegrees: 0
movingSegment: lowerLeg
loadInterface: distalShinPad
machineType: leverKneeExtension
fixedPath: true
```

`bodyPosition` admits `reclined|seated`; `hipFlexionDegrees` admits the numeric
40-to-90 span only to store the two exact fixtures. Bidirectional rules require
`reclined <-> 40` and `seated <-> 90`. A fifth rule requires
`rectusFemoris: primary` at 40 degrees; the contrasting 90-degree rule requires
`rectusFemoris: secondary`.

| Catalog ID | Name and aliases | Posture | Seed | Roles | Evidence |
|---|---|---|---:|---|---|
| `reclined-unilateral-machine-leg-extension` | **Reclined Unilateral Machine Leg Extension**; `40-Degree Single-Leg Extension`, `Reclined Single-Leg Extension` | reclined, hip 40 degrees | 20 lb / 10 kg; 12 reps | vasti P, rectusFemoris P | Larsen 2025; Mitsuya 2023 |
| `upright-unilateral-machine-leg-extension` | **Upright Unilateral Machine Leg Extension**; `90-Degree Single-Leg Extension`, `Upright Single-Leg Extension` | seated, hip 90 degrees | 20 lb / 10 kg; 12 reps | vasti P, rectusFemoris S | Larsen 2025; Mitsuya 2023 limitation context |

The start angle follows Larsen's reported approximately 110-to-0-degree knee
range. The study's reclined condition averaged 40.8 degrees with individual
variation; the contract uses 40 as the named authoring target, not laboratory
precision on every user repetition. Product seed weights are conservative
clean scrubber detents, not participant training loads.

Excluded at activation: bilateral extensions, standing cable extensions,
bands, reverse Nordics, sissy squats, terminal-knee-extension rehabilitation
drills, partial-ROM variants, and any posture other than the two reviewed
angles.

## Family 2: `knee-flexion`

### Contract and role policy

The family is a strict open-chain lever-machine movement in which the lower leg
flexes at the knee while hip, pelvis, spine, ankle, and foot positions remain
held. Its sole prime and plane-basis action is `knee.flexion`; group policy is
`legs` only.

Exact family evidence refs:

- `arnold-2010-lower-limb` for lower-limb geometry;
- `maeo-2021-seated-prone-leg-curl` for the direct unilateral seated/prone
  training comparison and individual-muscle MRI volumes; and
- `gallucci-2002-gastrocnemius-leg-curl` as boundary evidence showing that
  ankle posture changes gastrocnemius contribution to maximal isokinetic knee
  flexion. It is not permission to invent an ankle posture for Maeo's fixtures.

Role envelope:

```json
{
  "requirements": [
    { "anyOf": ["medialHamstrings"], "minimumRole": "primary" },
    { "anyOf": ["bicepsFemoris"], "minimumRole": "primary" },
    { "anyOf": ["sartorius"], "minimumRole": "secondary" },
    { "anyOf": ["gracilis"], "minimumRole": "secondary" }
  ],
  "allowedByRole": {
    "primary": ["medialHamstrings", "bicepsFemoris"],
    "secondary": ["sartorius", "gracilis"],
    "stabilizer": []
  }
}
```

Both migrated hamstring regions are primary in both records. Maeo measured
growth in biceps femoris long head, biceps femoris short head,
semitendinosus, and semimembranosus after both seated and prone training. The
three biarticular heads operated at longer lengths and generally grew more in
the seated condition, while the monoarticular short head did not differ. Those
are posture-dependent adaptations, not evidence that either migrated region
stops being a prime knee flexor.

Sartorius and gracilis are required secondaries because Maeo measured them
directly and describes them as knee-flexion synergists. Sartorius hypertrophy
was greater prone, consistent with its hip-flexor geometry; gracilis grew in
both conditions without a statistically resolved between-posture difference.

`gastrocnemius` is deliberately absent from the two initial records. Maeo did
not report ankle posture or measure calf involvement. Gallucci proves that
this omission cannot be solved by one universal role: maximal knee-flexion
moment was higher with the ankle braced in dorsiflexion than plantarflexion,
and its model attributed the difference to gastrocnemius length. A future
ankle-controlled record may admit gastrocnemius, but activation does not
fabricate the missing posture or transfer a maximal isokinetic result onto two
70%-1RM weight-stack fixtures.

### Rules and exact roster

Required shared axes plus:

```text
pelvisSupport: machinePadAndStrap
ankleMotion: positionHeld
footMotion: positionHeld
kneeMotion: flexes
kneeStartFlexionDegrees: 0
kneeEndFlexionDegrees: 90
movingSegment: lowerLeg
loadInterface: distalShinPad
machineType: leverLegCurl
fixedPath: true
anklePosture: unreported
```

`bodyPosition` admits `seated|prone`; `hipFlexionDegrees` spans 30-to-90 only
to store the exact source fixtures. Reciprocal rules require `seated <-> 90`
and `prone <-> 30`. No intermediate hip angle is admitted by inference.

| Catalog ID | Name and aliases | Posture | Seed | Roles | Evidence |
|---|---|---|---:|---|---|
| `seated-unilateral-machine-leg-curl` | **Seated Unilateral Machine Leg Curl**; `Seated Single-Leg Curl`, `Unilateral Seated Leg Curl` | seated, hip 90 degrees | 20 lb / 10 kg; 10 reps | medialHamstrings P, bicepsFemoris P, sartorius S, gracilis S | Maeo 2021 |
| `prone-unilateral-machine-leg-curl` | **Prone Unilateral Machine Leg Curl**; `Lying Single-Leg Curl`, `Unilateral Prone Leg Curl` | prone, hip 30 degrees | 20 lb / 10 kg; 10 reps | medialHamstrings P, bicepsFemoris P, sartorius S, gracilis S | Maeo 2021 |

Every active alias preserves the evidence-matched unilateral fact. Generic
`Seated Leg Curl` and `Prone Leg Curl` remain unowned so a future reviewed
bilateral branch can claim them without collision or misleading lookup. The
source fixed both pelvises with adjustable straps and trained 0-to-90-degree
knee motion.

Excluded at activation: bilateral and standing leg curls, cable or band curls,
Nordics, razor curls, glute-ham raises, stability-ball curls, sliding curls,
hip-extension tasks, ankle-posture variants, and eccentric-only fixtures.

## Family 3: `ankle-plantarflexion`

### Contract and role policy

The family is a strict closed-chain machine calf raise in which the heel rises
through ankle plantarflexion while the forefoot remains supported and knee,
hip, pelvis, spine, and foot orientation remain held. Its sole prime and
plane-basis action is `ankle.plantarflexion`; group policy is `legs` only.

Exact family evidence refs:

- `arnold-2010-lower-limb` for triceps-surae geometry; and
- `kinoshita-2023-standing-seated-calf-raise` for the direct unilateral
  standing/seated 12-week comparison, 0/90-degree knee positions, machine
  setups, neutral foot posture, and individual gastrocnemius/soleus MRI
  volumes.

Role envelope:

```json
{
  "requirements": [
    { "anyOf": ["soleus"], "minimumRole": "primary" },
    { "anyOf": ["gastrocnemius"], "minimumRole": "secondary" }
  ],
  "allowedByRole": {
    "primary": ["soleus", "gastrocnemius"],
    "secondary": ["gastrocnemius"],
    "stabilizer": []
  }
}
```

Soleus is primary in both records. Its hypertrophy was similar after standing
and seated training (2.1% versus 2.9%). Gastrocnemius is primary with the knee
extended, where medial and lateral heads grew 9.2% and 12.4%, but only
secondary with the knee flexed. The seated condition showed negligible,
non-significant gastrocnemius changes (0.6% and 1.7%); a secondary assignment
acknowledges that the biarticular muscle still crosses and can contribute at
the ankle without giving bent- and straight-knee variants identical credit.

`flexorHallucisLongus` is not authored initially. Its anatomy profile can
produce plantarflexion, but the study measured only gastrocnemius and soleus,
and the technique held the foot neutral rather than using toe flexion to create
the repetition. Future direct evidence may justify a bounded secondary or foot
stabilizer role; capability alone does not force catalog involvement.

### Rules and exact roster

Both records author:

```text
kineticChain: closed
pelvisMotion: positionHeld
spineMotion: positionHeld
hipMotion: positionHeld
kneeMotion: positionHeld
ankleMotion: plantarflexes
footMotion: positionHeld
movingSegment: foot
footOrientation: neutral
forefootSupport: machinePlatform
heelSupport: none
fixedPath: true
lowerBodyContribution: isolatedJointMotion
```

Body position, knee angle, machine type, and load interface are mapped
bidirectionally:

| Fixture | Body | Knee | Machine | Load interface |
|---|---|---:|---|---|
| Standing | `standing` | 0 degrees | `standingCalfRaise` | `shoulderPad` |
| Seated | `seated` | 90 degrees | `seatedCalfRaise` | `distalThighPad` |

Rules also require `gastrocnemius: primary` at 0 degrees and
`gastrocnemius: secondary` at 90 degrees. This makes the posture-dependent
anatomy executable rather than leaving it in prose.

| Catalog ID | Name and aliases | Posture | Seed | Roles | Evidence |
|---|---|---|---:|---|---|
| `standing-unilateral-machine-calf-raise` | **Standing Unilateral Machine Calf Raise**; `Single-Leg Standing Calf Raise`, `Single-Leg Standing Calf Raise Machine` | standing, knee 0 degrees | 20 lb / 10 kg; 10 reps | gastrocnemius P, soleus P | Kinoshita 2023 |
| `seated-unilateral-machine-calf-raise` | **Seated Unilateral Machine Calf Raise**; `Single-Leg Seated Calf Raise`, `Single-Leg Seated Calf Raise Machine` | seated, knee 90 degrees | 20 lb / 10 kg; 10 reps | soleus P, gastrocnemius S | Kinoshita 2023 |

The source used 70% 1RM and ten repetitions, but did not publish a universal
machine-stack seed. The catalog's 20 lb / 10 kg values are conservative product
defaults on clean detents, not conversions of participant loads. The study's
20-degrees-dorsiflexed to 30-degrees-plantarflexed model range explains muscle
operating lengths; it is not promoted into exact user ROM because the paper did
not validate that every training repetition hit those endpoints.

Excluded at activation: bilateral raises, Smith/barbell/dumbbell variants,
leg-press calf presses, donkey raises, bodyweight raises, bent-knee standing
variants, toe-in/toe-out stances, unsupported balance tasks, calf jumps,
partial-ROM training, and any exercise that deliberately flexes the toes.

## Evidence metadata for activation

The following five new IDs must be registered once in `evidence.json`. The
existing `arnold-2010-lower-limb` entry is reused.

| ID | Type | Exact metadata and load-bearing scope |
|---|---|---|
| `larsen-2025-leg-extension-hip-flexion` | `experimentalTrainingStudy` | Stian Larsen, Benjamin Sandvik Kristiansen, Paul Alan Swinton, Milo Wolf, Andrea Bao Fredriksen, Hallvard Nygaard Falch, Roland van den Tillaar, Nordis Østerås Sandberg. “The effects of hip flexion angle on quadriceps femoris muscle hypertrophy in the leg extension exercise.” *Journal of Sports Sciences* 43(2):210–221 (2025; published online 2024-12-19). DOI `10.1080/02640414.2024.2444713`; PMID `39699974`. Direct unilateral 40- versus 90-degree hip-flexion leg-extension training; supports fixture geometry and rectus-femoris versus vastus-lateralis posture response, not unmeasured vasti-head ranking or universal load seeds. |
| `mitsuya-2023-leg-extension-hip-flexion` | `experimentalImagingStudy` | Hiroku Mitsuya, Koichi Nakazato, Takayoshi Hakkaku, Takashi Okada. “Hip flexion angle affects longitudinal muscle activity of the rectus femoris in leg extension exercise.” *European Journal of Applied Physiology* 123(6):1299–1309 (2023). DOI `10.1007/s00421-023-05156-w`; PMID `36795130`. Acute four-set 70%-1RM isotonic machine study with MRI T2 at 0, 40, and 80 degrees; supports regional rectus-femoris hip-angle sensitivity, not long-term hypertrophy or other quadriceps-head roles. |
| `maeo-2021-seated-prone-leg-curl` | `experimentalTrainingStudy` | Sumiaki Maeo, Meng Huang, Yuhang Wu, Hikaru Sakurai, Yuki Kusagawa, Takashi Sugiyama, Hiroaki Kanehisa, Tadao Isaka. “Greater Hamstrings Muscle Hypertrophy but Similar Damage Protection after Training at Long versus Short Muscle Lengths.” *Medicine & Science in Sports & Exercise* 53(4):825–837 (2021). DOI `10.1249/MSS.0000000000002523`; PMID `33009197`. Direct unilateral seated 90-degree versus prone 30-degree hip-flexion leg-curl training through 0–90 degrees knee motion with pelvis straps and individual hamstring, sartorius, and gracilis MRI volumes; ankle posture was not reported and calf involvement was not measured. |
| `gallucci-2002-gastrocnemius-leg-curl` | `biomechanicalModelStudy` | Jason G. Gallucci, John H. Challis. “Examining the Role of the Gastrocnemius During the Leg Curl Exercise.” *Journal of Applied Biomechanics* 18(1):15–27 (2002). DOI `10.1123/jab.18.1.15`; no PMID located. Maximal isokinetic knee flexions with the ankle braced in full dorsiflexion or plantarflexion plus a gastrocnemius model; supports the ankle-posture boundary and greater knee-flexion moment in dorsiflexion, not a categorical role on ankle-unreported weight-stack records. |
| `kinoshita-2023-standing-seated-calf-raise` | `experimentalTrainingStudy` | Momoka Kinoshita, Sumiaki Maeo, Yuuto Kobayashi, Yuuri Eihara, Munetaka Ono, Mauto Sato, Takashi Sugiyama, Hiroaki Kanehisa, Tadao Isaka. “Triceps surae muscle hypertrophy is greater after standing versus seated calf-raise training.” *Frontiers in Physiology* 14:1272106 (2023). DOI `10.3389/fphys.2023.1272106`; PMID `38156065`. Direct unilateral machine standing/knee-extended versus seated/knee-90-degree training with neutral feet and individual gastrocnemius/soleus MRI volumes; supports posture-dependent categorical credit, not a universal machine-stack seed or exact user ROM endpoints. |

`mitsuya-2023-leg-extension-hip-flexion` uses the precise
`experimentalImagingStudy` type because its outcome is acute MRI T2, not an
intervention. The evidence validator accepts descriptive source-type strings;
do not misdescribe it as longitudinal training merely to reuse an older label.

## Activation gates and tests

Activation is atomic only when all of the following pass:

1. the 52-region taxonomy migration and exact lower-body capabilities are
   active;
2. all five evidence IDs above are registered or already present, and each is
   cited by a family or exercise;
3. shared lower-body axis spellings are documented once in
   `families/README.md` and match the hip-isolation contracts;
4. all six names and aliases are globally unique;
5. each enum axis value is exercised by the initial roster and each numeric
   fixture is pinned to an exact reviewed cross-field mapping;
6. every JSON rule has matching and contrasting fixtures, with one mutation
   per assertion and role requirement;
7. posture-role mutation tests prove reclined versus upright rectus-femoris
   credit and straight- versus bent-knee gastrocnemius credit;
8. a mutation cannot add gastrocnemius to either ankle-unreported Maeo leg curl
   or add flexor hallucis longus without widening the reviewed policy;
9. complete forbidden-action mutations reject compound lower-body motion;
10. positive imperial seeds have clean 2.5-kg-grid metric seeds; and
11. catalog validation, exact aggregate counts, evidence coverage, and the app
    build pass.

The tests should assert meaningful fields directly. Do not use a hash over
aliases or movement-definition prose; an opaque golden digest makes a copy edit
fail without showing the changed contract.
