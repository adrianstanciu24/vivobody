# TFL and hip-flexor coverage

Status: active. The owner approved this four-item expansion on 8 September
2026. Canonical family JSON and the generated inventory define the current
roster. This record explains the reviewed decisions and their evidence limits.

## Activated changes

| Exercise | Family | Decision |
|---|---|---|
| Bodyweight Active Straight-Leg Raise | [hip-flexion](../families/hip-flexion.json) | Add TFL secondary; preserve the original supine fixture |
| Supported Standing Cable Hip Flexion | [hip-flexion](../families/hip-flexion.json) | Add a supported straight-knee cable branch; iliopsoas primary, rectus femoris and TFL secondary |
| Bodyweight Side-Lying Hip Abduction | [hip-abduction](../families/hip-abduction.json) | Add unloaded floor geometry; glute med primary and TFL secondary |
| Ankle-Band Lateral Walk | [lateral-band-walk](../families/lateral-band-walk.json) | Add a separate lateral-stepping family; glute med primary and TFL secondary |

The three new fixtures are not aliases of the existing pressure-feedback
cuff raise, seated machine abduction, or supine active raise. Familiar aliases
are attached to the new records. Existing exercise IDs remain stable.

## Evidence and inference

Reviewed online on 8 September 2026:

- [Yamane et al., 2019](https://doi.org/10.2490/prm.20190007) recorded TFL
  during held supine straight-leg raises, alongside psoas, iliacus and other
  hip flexors. Secondary TFL credit in the dynamic supine and standing cable
  fixtures is an explicit anatomy-and-mechanics transfer, not a direct
  measurement of either complete repetition. The original Okubo protocol
  remains the source for the supine exercise's setup and active end range.
- [ACE side-lying hip abduction](https://www.acefitness.org/resources/everyone/exercise-library/38/side-lying-hip-abduction/)
  establishes the unloaded floor fixture, extended stacked legs, neutral
  rotation, and pelvis-control endpoint. Glute-med/TFL roles transfer from the
  existing Arnold anatomical capabilities and McBeth side-lying research.
  No universal numeric hip-abduction limit is adopted.
- [Speediance standing cable hip flexion](https://www.speediance.com/pages/standing-single-cable-hip-flexion)
  establishes the low pulley behind the athlete, ankle cuff, straight knee,
  and thigh-horizontal or earlier form-limited endpoint. The admitted branch
  requires the source's optional light hand support. This manufacturer source
  anchors technical geometry only; it is not physiological evidence. The
  bent-knee PROHIP knee-drive protocol is a different fixture and is excluded.
- [Berry et al., 2015](https://doi.org/10.2519/jospt.2015.5888) measured
  glute-med, glute-max and TFL activity during ankle-band side stepping.
  The squat branch retains self-selected depth and approximately 30 cm foot
  spacing and leading steps. The lead hip abducts against resistance; the
  trailing hip adducts under band tension with eccentric abductor control.
  Both stance and moving limbs contribute. No concentric adductor or hip
  rotation role is inferred from the inward step.

The band walk's glute-max, vasti, abdominal, oblique and soleus stabilizer
roles describe maintained squat, trunk and stance control. They are bounded
anatomical inferences, not an EMG-derived hierarchy. Its `isolation` mechanic
identifies the defining resisted hip action; it does not claim zero motion
at other joints. A held squat does not make each lateral step a squat
repetition, so this family has no compound movement pattern.

No TFL primary promotion, shared taxonomy, joint-action capability, anatomy
mesh mapping, or training-credit weighting changed.

## Contract and logging boundaries

Hip-flexion rules pin the supine and standing support, resistance, range and
load-mode combinations. Standing pelvic control requires glute-med stabilizer
credit. This supersedes the earlier blanket TFL exclusion in the
[hip-isolation discovery record](batch-4-hip-isolations.md), while retaining
its supine protocol limitations and other excluded fixtures.

Hip-abduction rules partition equipment into cuff, machine and bodyweight
branches. The cuff and machine still require their numeric endpoints; the
floor branch forbids that field and uses pelvic control as its endpoint.
This extends the [hip-abduction discovery record](batch-6-hip-abduction-adduction.md)
without generalizing the existing machine or laboratory fixtures.

The band walk counts one leading step plus one following step as one rep;
complete equal repetitions in each direction. Band and bodyweight loads are
non-comparable, with no invented effective bodyweight fraction. Cable load
comparison is meaningful only on the same machine and setup. All three new
records are unilateral, rep-tracked dynamic strength.

## Review and verification

Independent biomechanics, catalog-boundary and product reviews accepted the
fixtures and categorical roles. Review caught and corrected an abduction
branch that could otherwise mix seated-machine equipment with floor posture.
Catalog generation validates the authored families and writes the runtime
resource and Xcode input list. Regression fixtures cover the changed rosters,
role requirements, branch hybrids, controlled band return and neighboring
family exclusions.

The focused `catalog-tfl-coverage` Baguette scenario passed using the existing
headless runtime and incremental build. Additional focused Baguette checks
verified floor abduction in light appearance, the band walk in dark appearance
including repetition counting and equal-direction instructions, and cable hip
flexion with accessibility text sizing. Screenshots and accessibility trees
were inspected under `.verify/scenarios/catalog-tfl-coverage/` and
`.verify/tfl-review/`. Catalog generation and its family validation passed.
The cable title and muscle roles remain readable at accessibility text sizing;
the review also found awkward wrapping in the shared Movement panel's narrow
field labels. A subsequent UI fix stacks the diagram and full-width label/value
pairs at accessibility sizes, following the
[Movement presentation contract](../../exercise-data-contract.md#movement-panel-presentation).
The focused `catalog-tfl-coverage` Baguette scenario passed after the fix.
Movement screenshots and full-summary accessibility assertions for the supine
raise are recorded under `.verify/movement-wrap/`, including standard dark
and light appearances and Accessibility Large.
The user runs the remaining catalog Python suite and broader validation;
authored regression tests are not a claim that they ran.
