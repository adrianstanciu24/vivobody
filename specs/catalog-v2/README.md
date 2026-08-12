# Clean-slate catalog foundation

This directory is the source for Vivobody's clean-slate, family-first exercise
catalog. It is intentionally isolated from `Scripts/curate.py`, the legacy
review CSVs, and the currently shipped `catalog.json`. No v2 source may import,
decode, compare against, or preserve identities from the legacy roster.

The foundation and reviewed family sources remain isolated while the catalog is
rebuilt one family at a time. The app keeps using its current runtime catalog
until a later atomic cutover.

`catalog-v2` is only a temporary development namespace. At cutover this work
becomes the canonical `catalog`, and the temporary version suffix disappears.

## Source files

- `taxonomy.json` defines exactly 41 muscle regions, their coarse app group,
  display names, and exactly 62 uniquely owned `BodyModel.scn` mesh base names
  where the model has a surface mesh. An unvisualized muscle must carry an
  explicit reason.
- `joint-actions.json` defines exactly 44 joint actions and is an independent
  anatomical capability map. It lets the
  validator challenge a family's muscle assignments rather than merely checking
  them against another list written in the same family file.
- `evidence.json` tracks the primary musculoskeletal sources supporting those
  capability profiles. A citation supports a rule; it does not turn EMG or a
  model estimate into a universal numeric contribution.
- `family.schema.json` documents the strict JSON shape for one family and its
  explicitly reviewed exercises.
- `fixtures/valid-family.json` is synthetic validator input. It is never emitted
  into the app catalog.
- `proposals/` holds evidence-backed contract-discovery records. Each document
  states whether its decisions are pending or already activated; proposal files
  themselves are never validator input.
- `families/` holds one reviewed source file per real movement family.

## Authored muscle semantics

Exercise involvement remains categorical:

- `primary`: a dynamic contributor that the exercise principally emphasizes.
- `secondary`: a meaningful dynamic agonist or synergist that is not the
  exercise's dominant training emphasis. Secondary does not mean inactive or
  anatomically incapable of producing the movement.
- `stabilizer`: a contributor used principally to control a declared joint or
  segment rather than produce the exercise's prime actions.

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

An exercise also cannot repeat a family prime action in
`additionalPrimeActions`. That would let a conditioned family silently broaden
its contract by redeclaring the same action without the condition (or under a
different condition). Additional prime actions are strictly additional joint
actions; changing the semantics of a family action requires editing and
reviewing the family contract itself.

## Family contract

Each family separates:

- `fixed`: inherited mechanic, movement pattern, direction, and one or more
  app-facing anatomical planes. The only plane values are `sagittal`,
  `frontal`, and `transverse`.
- `allowed`: equipment, modality, tracking, load, and laterality choices an
  exercise may select.
- `movementSignature`: required prime joint actions, optional
  `forbiddenPrimeActions`, one to three `planeBasisActions`, and stability
  regions. A forbidden action cannot be added by an exercise variant even when
  an assigned muscle is anatomically capable of producing it in some position.
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
  stabilizing muscle remains independently mandatory for every declared
  stability region.
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
mechanics.
They are deferred until a hand-spacing axis and its thresholds are reviewed;
no grip width may be inferred from aliases. A close-grip press becomes a
separate triceps-emphasis family only if a later evidence review deliberately
assigns triceps as primary under a different muscle contract.

`diagonal` is a push/pull direction, not an anatomical plane. The clean-slate
taxonomy retains exactly the three cardinal planes while allowing a family to
declare more than one. These changes remain isolated from the current Swift
runtime; the atomic catalog cutover must replace its singular stored plane with
plane components, add the diagonal direction case, and remove the legacy rule
that classifies every compound press as sagittal.

## Validation

Run from the repository root:

```bash
python3 Scripts/catalog_v2.py --check
python3 -m unittest discover -s Scripts/tests -p 'test_catalog_v2.py'
```

The validator uses only Python's standard library. It decodes the binary
SceneKit property list directly and proves every declared mesh has both `_L`
and `_R` nodes, all 62 mesh-base owners are unique, the taxonomy contains
exactly its 41 canonical muscles, the capability map contains exactly 44 joint
actions, all muscles have evidence-backed action profiles, family
prime actions have capable movers, and stability demands have capable assigned
muscles.
