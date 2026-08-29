# Exercise catalog foundation

This directory is the canonical source for Vivobody's family-first exercise
catalog. `Scripts/catalog.py` validates these foundations and reviewed families
and is the sole writer of the bundled `vivobody/Resources/catalog.json`.

## Source files

- `taxonomy.json` defines exactly 58 muscle regions, their coarse app group,
  display names, and exactly 60 uniquely owned trainable `BodyModel.scn` mesh
  base names where the model has a truthful surface. The two posterior-serratus
  mesh bases are explicitly non-trainable rather than serving as lumbar-muscle
  proxies. An unvisualized muscle must carry an explicit reason.
- `joint-actions.json` defines exactly 44 joint actions, their central
  opposition map, and an independent anatomical capability map. It lets the
  validator challenge a family's muscle assignments rather than merely checking
  them against another list written in the same family file.
- `evidence.json` tracks exactly 224 primary musculoskeletal sources and
  authoritative technical standards supporting capability profiles and exact
  fixtures. A citation supports a rule; it does not turn EMG, a model estimate,
  or coaching guidance into a universal numeric contribution.
- `family.schema.json` documents the strict JSON shape for one family and its
  explicitly reviewed exercises.
- `fixtures/valid-family.json` is synthetic validator input. It is never emitted
  into the app catalog.
- `proposals/` holds evidence-backed contract-discovery records. Each document
  states whether its decisions are pending or already activated; proposal files
  themselves are never validator input.
- `families/` holds one reviewed source file per real movement family.

## Taxonomy naming and product display

`id`, `displayName`, `anatomicalName`, and `group` serve different layers:

- `id` is the stable compiler and analytics identity;
- `displayName` is the concise exact-region label for anatomy views, exercise
  detail, editors, and other surfaces where the specific credited region
  matters;
- `anatomicalName` names the anatomical structure or genuine subdivision. It
  must not carry asset or capability caveats. Capability or aggregation limits
  belong in the matching `joint-actions.json` profile `notes`; absence of a
  scene surface belongs in the taxonomy record's `unvisualizedReason`; and
- `group` is the glanceable roll-up for summaries, history, library grouping,
  and training-signature presentation.

The lower-body taxonomy intentionally creates more exact, sometimes clinical
region labels such as `Vasti`, `Pectineus`, and `Fibularis Tertius`. The app
must not flatten those back into false `Quads`, `Calves`, or `Hip Flexors`
region identities. The runtime uses all 58 stable IDs, display names, groups,
and mesh owners together; the six existing groups remain the coarse glanceable
roll-up. `MuscleMappingTests` pins that runtime mapping. Product copy may provide
contextual descriptions, but it must not create a second anatomical taxonomy.

## Authored muscle semantics

Exercise involvement remains categorical:

- `primary`: a contributor that the exercise principally emphasizes, either by
  producing a prime action or by opposing a declared resisted or yielding
  action.
- `secondary`: a meaningful dynamic agonist, synergist, resisted-action
  opponent, or eccentric controller that is not the exercise's dominant
  training emphasis. Secondary
  does not mean inactive or anatomically incapable of producing or opposing
  the training-defining action.
- `stabilizer`: a contributor used principally to control a declared joint or
  segment rather than produce or oppose the exercise's training-defining
  actions.

For press exercises, `scapularTranslation` describes only whether external
posterior support limits translation along the thorax. `supportConstrained`
does not mean the scapula is pinned and does not classify upward/downward
rotation or anterior/posterior tilt. In the reviewed chest-press families, a
bench, floor, or machine pad with that value does not select one scapular
stabilizer over another: both `serratus` and `trapeziusMiddle` are recorded as
stabilizers. That role rule is family-specific and must not be copied when a
different family declares a scapular action as prime. Serratus becomes a
dynamic contributor when an action it produces, such as protraction or upward
rotation, is explicitly declared; support type alone never implies that
action.

Regional excitation differences may support a role decision, but EMG rank by
itself does not redefine a muscle's anatomical actions. Each family must make
the practical training-emphasis judgment explicit and evidence-backed.

`movementSignature.stabilityDemands` describes every materially active,
training-relevant joint or segment that the authored contributors control.
Incidental implement contact alone does not create a demand, and the roster is
not an exhaustive map of passive tissue loading. Passive fixture geometry may
be recorded in the family definition and variant axes without inventing a
muscle role, tissue benefit, or medical claim. The field does not require a
separate `role: stabilizer`
entry for each region: validation is intentionally role-agnostic at this step,
so any
assigned primary, secondary, or stabilizer whose anatomy profile can stabilize
the region may cover the demand. `allowedByRole.stabilizer` is therefore a
whitelist for contributors whose principal exercise role is control rather
than prime-action production—not a list of every muscle allowed to help hold a
joint. A family authors an explicit stabilizer only when the reviewed setup
needs a distinct contributor or its existing movers leave a demand uncovered.
External support may reduce the required roster, but it never satisfies an
internal demand by itself.

## Proportional evidence policy

An authoritative technical standard may establish conventional fixture
geometry, setup, and endpoints. Existing primary anatomy, moment-arm, and
musculoskeletal-model evidence may then support transparent categorical
action and stabilizer inferences for that exact fixture. Exact
exercise-specific EMG is required when adding a new anatomical capability or
making a quantitative, ranked, comparative, medical, or otherwise surprising
claim; its absence alone does not block an ordinary exercise. Duplicate,
family-boundary, tracking/load, and unsupported-claim gates remain strict.

Continuous `0...1` involvement weights are not accepted. Visualization
intensity, volume credit, and test comparison ranks remain separate derived
product policies.

## Position-dependent actions

An unconditional muscle capability is authored as an action ID. When a muscle
can produce an action only from a particular joint position, `produces` uses a
conditional object instead:

```json
{
  "action": "shoulder.extension",
  "condition": "fromFlexedPosition"
}
```

Conditions are declared centrally in `joint-actions.json`. A conditional
capability satisfies only a family action carrying the same condition; it
cannot satisfy an unrestricted action. An unconditional capability can satisfy
either form. In particular, brachioradialis returning a pronated or supinated
forearm toward neutral cannot satisfy an unconditional forearm-pronation or
forearm-supination requirement.

Position conditions are added only with reviewed action-capability evidence;
symmetry of naming is not evidence of symmetry of function.
`fromExtendedPosition` is active only for shoulder flexion that starts behind
anatomical neutral and returns toward neutral. The sternocostal pectoralis-major
profile carries that conditioned capability but still has no unconditional
shoulder-flexion capability. The dip is its only active family consumer.

That decision is an explicitly triangulated, exercise-specific inference:
sternocostal-site concentric EMG during parallel-bar dips is combined with
separately measured bar-and-ring dip kinematics. It is not presented as a
direct sternocostal flexion-torque measurement, a pectoral-head ranking, or
permission to credit flexion that starts at or in front of neutral. The ring
role is a mechanics transfer across the same reviewed action and apparatus
comparison; its clinical case evidence corroborates tissue loading only. Any
future family that wants to consume the condition needs its own exercise review.

An exercise also cannot repeat a family prime action in
`additionalPrimeActions`. That would let a conditioned family silently broaden
its contract by redeclaring the same action without the condition (or under a
different condition). Additional prime actions are strictly additional joint
actions; changing the semantics of a family action requires editing and
reviewing the family contract itself.

## Resisted-action semantics

`movementSignature.resistedActions` names an externally imposed joint-action
tendency that the athlete opposes. It does not claim that the resisted action
occurs, and it must not be replaced with a fabricated dynamic prime action. An
isometric anti-extension hold therefore resists `spine.extension`; it does not
declare dynamic `spine.flexion` merely because the abdominal wall supplies the
opposing capacity.

`joint-actions.json` pairs every action with its anatomical opposite. The map
is total and symmetric, and validation requires at least one assigned primary
or secondary muscle capable of producing the opposite of every resisted
action. The direction-aggregated `spine.lateralFlexion` and `spine.rotation`
actions are their own opposition entries because the visible regions and
action IDs do not encode left versus right. That self-pair does not mean one
side's fibers resist their own same-direction torque. Active unilateral
lateral-flexion and carry records prescribe both body or load sides; the
spine-rotation record prescribes both rotation directions. Each retains the
aggregation limitation explicitly.

A family must declare at least one direct prime or resisted action, or a Power
family or controlled-yield Dynamic Strength family may declare two or more
ordered movement phases. The same action cannot
occupy conflicting modes. `planeBasisActions` selects from the reviewed action
union, including yielding actions when ordered phases are present.
Resisted actions are family-level invariants. If two exercises resist different
tendencies or use different basis planes, they belong in separate contracts;
exercise-level resisted-action exceptions are deliberately unsupported.

## Ordered movement-phase semantics

A power repetition with a catch or receiving phase, or a Dynamic Strength
repetition defined by a controlled yielding phase and an active return, cannot
flatten all joint motion into one concentric action set. Such a family leaves its direct
`primeActions` empty and declares two or more ordered `movementPhases` instead.
Each phase distinguishes three action modes:

- `primeActions`: joint motion produced by the assigned movers;
- `resistedActions`: an external tendency opposed without that motion
  occurring; and
- `yieldingActions`: externally driven joint motion that does occur while
  muscles capable of the centrally mapped opposite action control it
  eccentrically.

The validator unions those phase actions only for capability coverage while
retaining their authored order and mode. Yielding actions require matching
stability demands and an assigned primary or secondary muscle capable of the
opposite action. Ordered phases are restricted to `power`, or to
`dynamicStrength` contracts containing both produced and yielding actions with
no resisted actions. They cannot be silently broadened through exercise-level
`additionalPrimeActions`.

## Lower-body region boundaries

The lower-body foundation does not let a visually convenient aggregate grant
every constituent the union of its actions. The SceneKit asset has distinct
bilateral meshes for rectus femoris versus the three vasti, gastrocnemius
versus soleus versus flexor hallucis longus, iliopsoas versus sartorius, the
individual adductor surfaces, and the anterior/lateral lower-leg surfaces.
Accordingly, the old `quads`, `calves`, `hipFlexors`, `adductors`, and `shins`
regions are replaced by action-compatible owners of those exact meshes.

The former `hamstrings` region is also narrowed. `medialHamstrings` owns
semitendinosus and semimembranosus and may produce both hip extension and knee
flexion. The SceneKit node named `Biceps_femoris` does not identify long and
short heads, so `bicepsFemoris` receives only their shared knee-flexion
capability. It deliberately does not inherit hip extension from the long head.
This avoids false credit to the short head, at the cost of under-crediting the
unseparated long head during hip-extension exercises.

Several other visible regions are deliberately conservative. The single
gluteus-medius mesh retains the fiber regions' shared hip-abduction capability
but not the opposing internal/external-rotation capabilities of its modeled
paths. The single adductor-magnus mesh retains hip adduction but not the
different sagittal-plane directions of its subdivisions. The combined
adductor-longus/brevis region and pectineus also retain only hip adduction:
their modeled sagittal moment direction changes or approaches zero as hip
flexion deepens, and the current action vocabulary has no reviewed
hip-position condition with which to bound flexion credit. These omissions are
explicit representational or condition-model limits, not claims that the
omitted anatomical contributors are inactive.

The lower-body split changed neither the 44-action vocabulary nor the then-62
owned mesh bases; the later lumbar split deliberately reduced trainable
ownership to 60 by excluding the two posterior-serratus bases. Arnold et al.'s
lower-limb model is the capability source: it
represents the relevant muscles as distinct paths and reports moment-generating
behavior over joint position. A model capability permits a categorical role;
it does not determine that role in any exercise without family-specific
evidence and review.

`foot.toeFlexion` intentionally remains a generic anatomical action. Flexor
hallucis longus is its only authored producer today, but the body asset also
contains unowned intrinsic great- and lesser-toe flexor surfaces. Narrowing the
action to the great toe would make the ontology reflect an incomplete roster,
not anatomy. Any future toe-flexion family must first audit and assign the
relevant intrinsic meshes; current coverage is explicitly incomplete.

## Family contract

Each family separates:

- `fixed`: inherited mechanic, training role, compound movement pattern,
  direction, and one or more app-facing anatomical planes. `trainingRole` is
  an authored programming convention (`push|pull|legs|core|other`) used for
  cross-mechanic discovery and mechanic-separated analysis; it is not inferred
  from anatomy or treated as a literal load direction. The only plane values
  are `sagittal`, `frontal`, and `transverse`.
- `allowed`: equipment, modality, tracking, load, and laterality choices an
  exercise may select.
- `movementSignature`: direct prime and/or resisted joint actions, or ordered
  phase actions for a multi-phase power repetition; optional
  `forbiddenPrimeActions`; one to three `planeBasisActions`; and stability
  regions. A forbidden prime action
  cannot be added by an exercise variant even when an assigned muscle is
  anatomically capable of producing it in some position.
  Basis-action cardinal planes must match the family's declared plane set
  exactly. Multiple basis actions must describe the same joint region and each
  must contribute a distinct plane. The validator therefore rejects using
  sagittal elbow extension to make a transverse shoulder press appear
  multi-plane. Every other prime action at that same basis joint—including an
  exercise's `additionalPrimeActions`—must also remain inside the declared
  plane set. Actions at other joints retain their own normal planes.
- `musclePolicy`: role-aware requirements and allowed muscle/role combinations.
- `variantAxes`: typed axes declared by that family and populated by each
  exercise; arbitrary name parsing is never used as biomechanics. A required
  boolean axis may declare `fixedValue` when one truth value is a family
  invariant. The validator enforces it directly, avoiding an always-true
  exercise rule that could never have a contrasting roster fixture.
- `exerciseRules`: declarative cross-field invariants. These connect equipment,
  load semantics, kinetic chain, support, and variant axes so individually
  valid values cannot form an impossible combination. A rule can also use
  `requireAdditionalStabilityDemands` to require named regions in an exercise's
  `additionalStabilityDemands`, or `requireMuscleRequirements` to conditionally
  require one of several muscles at a minimum role. Assigning a capable
  muscle remains independently mandatory for every declared stability region;
  that provider may be authored at any role when its central profile lists the
  region under `stabilizes`.
- `recommended`: soft programming guidance. Defaults outside these ranges emit
  warnings and do not invalidate family membership.

Family IDs name the feature that distinguishes neighboring contracts. Use the
movement direction or inclination when that separates the family, as in
`horizontal-press`, `incline-press`, or `vertical-pull`. When multiple families
share the same direction, use the distinguishing humeral action, as in
`shoulder-extension-row` versus `shoulder-horizontal-abduction-row`. The
app-facing `name` may remain conventional—“Horizontal Row”—while the stable ID
keeps the biomechanical boundary explicit.

The reviewed chest-press families share `fixedPath` and `machineType` with the
same meaning. `fixedPath` answers only whether machine rails or a lever constrain
the external load path; it is independent of `kineticChain`, so a closed-chain
push-up still has `fixedPath: false`. Machine presses require `fixedPath: true`
and a mechanism, while every non-machine press requires `fixedPath: false` and
must omit `machineType`.

Vertical pull deliberately does not reuse `fixedPath`: an assisted pull-up has
no external load path for its guided platform to constrain. Its required
`pathConstraint` axis instead distinguishes `free`, `leverGuided`, and
`assistancePlatformGuided`, keeping guided external resistance separate from a
guided body path. `kineticChain` independently records whether the hands or the
implement move.

Shoulder-extension row reuses the external-load meaning of `fixedPath` for
Smith rails and lever-row machines while keeping a fixed-bar inverted row
`fixedPath: false`; distal hand fixation is still expressed by
`kineticChain: closed`. Its family plane remains sagittal because
`shoulder.extension` is the shoulder basis action. The transverse
`scapula.retraction` prime action occurs at a different joint and does not add
a transverse shoulder plane.

Shoulder-horizontal-abduction row owns the strict flared shoulder-height row:
its transverse family plane comes from the shoulder basis action
`shoulder.horizontalAbduction`, while scapular retraction and elbow flexion are
required actions at other joints. It pins `upperArmElevationDegrees` to 90 as
an auditable canonical-position convention. A 60-degree row remains deferred
because the reviewed studies do not provide the three-dimensional action
decomposition needed to place that mixed path honestly in either row family.
Lever-row machine records in both row families declare
`leverArmConfiguration`; linked levers are bilateral and unilateral variants
use independent arms. Smith rails are not lever arms and omit the axis.

Families that declare `relativeGripWidth` share one ordinal vocabulary:
`narrow|shoulderWidth|medium|wide`. A family may admit only a subset, but it
must not redefine one value to mean another; in particular, a close-grip
attachment is `narrow`, not `shoulderWidth`.

They also share `pressInclinationDegrees`, a required signed axis for the
canonical torso-relative pressing inclination. Zero is horizontal, positive
values move toward overhead, and negative values move toward decline. A
supported free-weight press uses its backrest angle as the practical proxy.
The current reviewed bands are decline `-30...-10`, horizontal `0`, incline
`15...45`, and vertical `75...90`; unclaimed intervals remain visible
instead of being hidden behind family-specific angle names.

## Deferred press scope

Incline and decline press currently admit only bilateral, supported barbell,
dumbbell, and machine exercises. Cable, unilateral, and bodyweight variants
require an explicit future contract review; the generator must not infer them
from an exercise name.

Elevated push-up ownership follows the resistance direction relative to the
torso rather than the conventional exercise label:

| Future exercise | Owning family |
|---|---|
| Feet-elevated “decline push-up” | Incline press |
| Hands-elevated “incline push-up” | Decline press |

Neither angled family currently admits a closed kinetic chain, bodyweight load,
free scapular translation, or a body-angle/elevated-segment axis, so these are
ownership decisions rather than authored exercises. Standard and knee push-ups
remain horizontal press variants.

`narrow`, `shoulderWidth`, and `wide` grip variants remain horizontal-press
mechanics. One narrow barbell condition is active using its source-defined
latissimus-to-triceps landmark spacing; generic narrow, shoulder-width, and
wide variants remain deferred until their hand-spacing thresholds are
reviewed, and no grip width may be inferred from aliases. A close-grip press
becomes a separate triceps-emphasis family only if a later evidence review
deliberately assigns triceps as primary under a different muscle contract.

`diagonal` is a push/pull direction, not an anatomical plane. The family-first
taxonomy retains exactly the three cardinal planes while allowing a family to
declare more than one. The runtime stores those plane components in canonical
`sagittal|frontal|transverse` order, supports diagonal direction directly, and
does not apply the retired rule that classified every compound press as
sagittal.

Direction still requires an athlete-relative reviewed fixture. The active
`diagonal-pull` record preserves Lorenzetti's source-defined 45-degree
extended-arm start and chest-contact endpoint without converting the label into
a universal numeric angle band. A room-space cable angle or commercial “high
row” name cannot establish diagonal ownership by itself.

## Validation

Run from the repository root:

```bash
python3 Scripts/catalog.py --check
python3 Scripts/catalog.py --emit-runtime
python3 -m unittest discover -s Scripts/tests -p 'test_catalog.py'
```

`--check` is non-writing and also proves that the checked-in runtime catalog is
byte-for-byte compiler output. `--emit-runtime` performs an atomic replacement
after full validation. Explicit `--family PATH` values are supplemental
validation inputs only and can never enter the runtime projection.

The validator/compiler uses only Python's standard library. It decodes the binary
SceneKit property list directly and proves every declared mesh has both `_L`
and `_R` nodes, all 60 trainable mesh-base owners are unique, the taxonomy
contains exactly its 58 canonical muscle regions, the capability map contains
exactly 44 joint actions, all muscles have evidence-backed action profiles,
family prime actions have capable movers, and stability demands have capable
assigned muscles. The two posterior-serratus mesh bases are explicitly pinned
as non-trainable scene surfaces rather than lumbar proxies. The runtime
projection is pinned to exactly 84 active families and 202 exercises.
