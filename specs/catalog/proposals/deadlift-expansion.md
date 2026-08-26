# Deadlift expansion record

Status: approved and activated as three new source-bounded families containing
six exercises. The enforceable contracts are `families/sumo-deadlift.json`,
`families/trap-bar-deadlift.json`, and `families/single-leg-deadlift.json`.
This record extends `deadlift-activation.md`; it does not change the existing
conventional or Romanian/stiff-leg families. It supersedes that record's sumo,
trap-bar, and true-single-leg deferrals while leaving its B-stance deferral in
force.

## Outcome

| Family | Activated records | Direct fixture evidence |
|---|---|---|
| `sumo-deadlift` | `barefoot-dead-stop-sumo-barbell-deadlift` | `hanen-2025-conventional-sumo-deadlift` |
| `trap-bar-deadlift` | `low-handle-trap-bar-deadlift`; `high-handle-trap-bar-deadlift` | `lake-2017-low-handle-hex-bar-deadlift`; `lockie-2018-high-handle-hex-bar-deadlift` |
| `single-leg-deadlift` | `barbell-single-leg-deadlift`; `dumbbell-single-leg-romanian-deadlift-ipsilateral-load`; `dumbbell-single-leg-romanian-deadlift-contralateral-load` | `diamant-2021-barbell-single-leg-deadlift`; `mo-2023-single-leg-romanian-loading-position` |

The six canonical names are:

- **Barefoot Dead-Stop Sumo Barbell Deadlift**;
- **Low-Handle Trap-Bar Deadlift**;
- **High-Handle Trap-Bar Deadlift**;
- **Barbell Single-Leg Deadlift**;
- **Ipsilateral-Load Dumbbell Single-Leg Romanian Deadlift**; and
- **Contralateral-Load Dumbbell Single-Leg Romanian Deadlift**.

## Why these are separate families

Sumo remains a bilateral straight-bar floor pull, but its wide toe-out stance,
arms-inside-knees topology, dead-stop fixture, and measured multiplanar lower-
limb demands cannot be admitted by changing conventional stance width.

Trap-bar lifting places the athlete inside a frame with parallel handles beside
the legs. Handle height, load line, and hand position are exercise identity,
not straight-bar aliases. `trapBar` is therefore a first-class equipment value
through the schema, generated runtime, and Swift domain model; it must not be
stored or filtered as `barbell`.

True single-leg hinges use one working leg while the free leg balances without
propulsion. Their unilateral pelvis and trunk control, one- versus two-hand
loading, and hip-dominant signature differ from both bilateral floor pulls and
the staggered support of a B-stance exercise.

The sumo and trap-bar families share `hip.extension`, `knee.extension`, and
`ankle.plantarflexion` as dynamic primes. The single-leg family has only
`hip.extension` as a dynamic prime and resists `spine.flexion`. Keeping these
contracts separate prevents required actions, laterality, roles, and equipment
geometry from becoming optional variants.

## Activated source boundaries

### Sumo

Hanen tested three barefoot repetitions at 85 percent of an adjusted one-
repetition maximum. The bar began on the floor; participants used a self-
selected wide toe-out stance, both hands inside the knees, individualized
double-overhand grip width, maximal concentric-speed intent, a short
unquantified inter-repetition pause, and a dead stop.

The adjusted maximum was based on a preferred or non-preferred technique by
cohort assignment, not a guaranteed sumo-specific maximum. Stance width,
toe-out angle, grip width, pause duration, spinal kinematics, and descent were
not standardized. The catalog adds controlled lowering to repeat the measured
floor-start ascent and holds the elbows extended as disclosed product coaching
adaptations. Measured hip adduction/external-rotation and knee/ankle
multiplanar behavior remain control demands, not extra training primes or
numeric muscle rankings.

### Trap bar

Lake's low-handle fixture used a closed Pullum Sports frame whose published
figure places the unraised handles at the sleeve axis. Participants stood
barefoot inside the frame, used a parallel palms-facing grip, and performed
three separate singles at 90 percent of the low-handle fixture's tested one-
repetition maximum with at least two minutes between attempts.

Lockie's high-handle fixture used the high handles of an American Barbell
dual-height frame. The high-handle centers were 10 centimeters above the low-
handle centers and 64 centimeters apart. Participants used consistent self-
selected footwear on an Olympic platform and performed maximal-force one-
repetition-maximum attempts with three minutes between attempts. Absolute
handle-to-floor height was not reported.

Both active sources measured ascent from a resting floor position and omitted
an eccentric prescription. Controlled lowering, a floor reset, and extended-
elbow coaching are explicit product adaptations. Handle heights are not
interchangeable, and no arbitrary high/low/open-frame trap bar is admitted.

`swinton-2011-straight-hex-bar-biomechanics` supports the shared hip, knee, and
ankle mechanics, while `camara-2016-straight-hex-bar-emg` supports conservative
vasti, hamstring, and erector involvement. Neither reports handle geometry,
so neither supplies fixture values or proves a high-versus-low-handle effect.

### True single leg

Diamant's barbell fixture used a standard 20-kilogram Olympic bar, an individual
eight-repetition-maximum load, a barefoot working foot centered before the
bar, a straight free leg extending behind, and a bilateral shoulder-width
pronated grip. The bar traveled close to the working knee/body from the floor
to full hip extension and returned to the floor. The free foot could touch
briefly at the top. Five recorded repetitions followed a four-second total
cycle including an approximately two-second inter-repetition pause; no
concentric/eccentric split was reported.

Mo's two dumbbell fixtures used the dominant working leg with an instructed
approximately 15-degree knee angle and a bottom trunk posture approximately
parallel to the ground. Six continuous repetitions used maximal concentric and
eccentric intent at an individually matched metronome pace. One dumbbell was
held below either the working-side shoulder (`ipsilateral`) or opposite
shoulder (`contralateral`). The selected load was the greatest six-repetition
load that preserved technique and matched a paired flywheel condition's mean
velocity; it was not a universal percentage or flywheel equivalence.

Mo standardized but did not report foot and grip dimensions, grip orientation,
support surface, footwear, free-leg trajectory, or whether the dumbbell cycle
entered at the top or bottom. Entering at the reported bottom posture is a
disclosed catalog instruction. Diamant measured only the right working side
and Mo only the dominant side; allowing either working side is an explicit
product mirror. No source authorizes arbitrary load side, two dumbbells,
external support, flywheel, unstable-surface, kettlebell, cable, or machine
variants.

## Product defaults are not evidence loads

The sumo, both trap-bar records, and barbell single-leg record initialize at
45 lb / 20 kg. The two dumbbell records initialize at 25 lb / 12.5 kg. Repetition
defaults are three for sumo, one for each trap-bar single, five for the barbell
single-leg record, and six for each dumbbell record. These are logging seeds;
they do not replace Hanen's mixed-basis 85-percent load, Lake's fixture-specific
90 percent, Lockie's tested maximum, Diamant's eight-repetition maximum, or
Mo's velocity-matched six-repetition load.

## B-stance remains deferred

`mooney-2026-staggered-stance-romanian-deadlift` confirms that participants
performed three sets of six barbell staggered-stance Romanian deadlifts per
lead side, with the rear toe tip aligned to the lead heel. It does not report
rear-foot contact or load sharing, stance width, knee behavior, grip, bar path,
range endpoint or floor relationship, cadence, or exercise-specific muscle
activity. Those are defining fixture facts, not optional polish.

The nine-week intervention also combined the staggered exercise with Nordic
hamstring work, ordinary team training, and matches, without a non-intervention
control. Its outcomes cannot be attributed to the B-stance deadlift alone.
The evidence remains registered as family-boundary context, but B-stance,
kickstand, and staggered-stance records stay absent until a source resolves the
support, load, and range contract.

## Evidence and verification expectations

1. Keep exactly the three family IDs and six catalog IDs listed above, with
   global ID, canonical-name, and alias uniqueness. B-stance must remain absent.
2. Preserve the eight exercise/boundary evidence IDs named in this record.
   Direct exercise refs must not borrow fixture facts from supporting or
   boundary-only sources, and every registered source must remain covered.
3. Keep `trapBar` distinct from `barbell` in schema validation, runtime
   generation, Swift decoding, filtering, display formatting, and mutation
   tests. Low- and high-handle geometry must not collapse into one axis value.
4. Mutation-test every source-exact action, role, and required variant axis:
   especially sumo stance/grip/barefoot/dead-stop facts; trap-bar frame,
   handle, load, and single-attempt topology; and single-leg support, load side,
   grip, range, cadence, and inter-repetition behavior.
5. Keep each product adaptation and unreported source field visible in the
   family definition, typed variants, execution copy, and evidence scopes.
   EMG must remain categorical support, not numeric contribution, hypertrophy,
   safety, or equipment-equivalence evidence.
6. Regenerate runtime and the Xcode input list only through
   `Scripts/catalog.py --emit-runtime`; then run the catalog test suite,
   `Scripts/check.sh`, and `git diff --check`.
7. For user-visible verification, pin all six canonical names and the Sumo
   Deadlift alias, then inspect Library/detail anatomy and authored execution
   semantics for one representative from each family. Use `--static-body` for
   deterministic anatomy captures and record anything the harness cannot
   observe as manual verification.
