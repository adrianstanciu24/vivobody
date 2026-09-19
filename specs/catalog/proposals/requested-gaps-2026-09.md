# Requested exercise gaps

Status: active as eight reviewed catalog additions.

Reviewed and searched on 2026-09-18 using the repository exercise-addition
workflow, two independent evidence/product slices, and a separate boundary
review. All eight exact fixtures were absent. No shared schema, taxonomy or
anatomical capability changes were needed.

| Added fixture | Ownership | Exact admission |
|---|---|---|
| Band-Assisted Pull-Up | [vertical-pull](../families/vertical-pull.json) | Strict shoulder-width overhand pull-up with a foot in an elastic loop hung from the bar |
| Bodyweight Split Squat | [split-stance-squat](../families/split-stance-squat.json) | Stationary floor split, hands on hips, no implement |
| Bodyweight Bulgarian Split Squat | split-stance-squat | Rear top-of-foot bench support, hands on hips, upright torso |
| Standing Cable Hip Abduction | [hip-abduction](../families/hip-abduction.json) | Unsupported upright sideward leg raise, far-ankle cuff, lowest lateral pulley |
| Dumbbell Triceps Kickback | [elbow-extension](../families/elbow-extension.json) | Single-arm split stance, opposite hand on thigh, upper arm held beside inclined torso |
| EZ-Bar Skull Crusher | elbow-extension | Simultaneous two-arm extension on flat bench, inside angled grips, no forehead contact |
| Cable Pull-Through | [cable-pull-through](../families/cable-pull-through.json) | Bilateral low-rope cable hinge facing away, cable between legs, upright finish |
| Pike Push-Up | [pike-push-up](../families/pike-push-up.json) | Hands and feet on floor, held inverted-V posture, head near floor, return short of elbow lockout |

The unloaded split and cable abduction variants retain their movement family
identities so substitutions preserve same-family similarity. Implement-control
requirements now apply only to loaded splits. A bench-fixture discriminator
preserves the original loaded bench posture separately from the unloaded one.
The cable hinge does not inherit the good morning's measured spinal extension;
the floor pike does not inherit wall-handstand apparatus or numeric inclination.

## Evidence ledger

| Fixture claim | Primary technical source | Support and limit |
|---|---|---|
| Foot-loop band assistance | [CrossFit Journal, Assistance for Bodyweight Exercises](https://library.crossfit.com/free/pdf/24_04_Assist_Bodywt_Exerc.pdf), page 10 | Exact band contact; strict muscle roles transfer from existing pull-up anatomy. First publication 2004, PDF reprint 2008. |
| Unloaded stationary split | [Stastny et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC4640053/) | Explicit unloaded warmups; detailed floor geometry transfers from the family's reviewed split protocols. Loaded analysis does not measure unloaded muscle forces. |
| Unloaded Bulgarian | [NASM Bulgarian Split Squat](https://www.nasm.org/resource-center/exercise-library/bulgarian-split-squat) | Numbered technique steps explicitly admit hands on hips and bench support; unrelated FAQ and medical claims are excluded. |
| Standing cable abduction | [ACE Certified News, August/September 2009](https://contentcdn.eacefitness.com/cp/pdfs/CertifiedNews/AugSept09Cert.pdf), pages 7–8 | Exact illustrated cable geometry. Neutral rotation, held posture, controlled return and pelvic-control endpoint are authored technique targets. |
| Kickback | [ACE triceps protocol](https://contentcdn.eacefitness.com/certifiednews/images/article/pdfs/ACETricepsStudy.pdf) | Exact split stance, thigh support and held upper arm. EMG summaries do not establish universal rankings or growth. |
| EZ-bar fixture | [NSCA Strength Training, 2007](https://studylib.net/doc/25824661/nsca---brown---strength-training), pages 200–201 | Original textbook content accessed through a third-party mirror; inside angled grip and supported near-forehead path. |
| Bilateral cable hinge | [University of Sussex Sport](https://www.sussex.ac.uk/sport/documents/cable-pull-throughs.pdf) | Low rope, cable between legs, slight knee bending and hip-driven upright return. Braced spine and passive arms are technique targets, not measured kinematics. |
| Floor pike | [NASM Pike Push-Up](https://www.nasm.org/resource-center/exercise-library/pike-push-up) | Exact floor support, head endpoint and short-of-lockout return. Shoulder/scapular roles transfer from existing anatomical evidence. |

Muscle roles are categorical anatomy-and-mechanics inferences. No new exact
EMG, muscle-force, regional ranking, bodyweight percentage or adaptation claim
is introduced. Standing ankle control and lower-limb posture control receive
bounded stabilizer roles. Existing unvisualized anatomy remains explicit in
exercise-detail text without substituting a different painted region.

Band assistance and both unloaded splits plus the floor pike use rep tracking
with non-comparable resistance and zero seed weight. Cable loads compare only
within the same station and attachment. The kickback logs its working dumbbell;
the EZ fixture logs total bar-and-plate mass. The existing unspecified-bar
lying extension remains a separate identity.

## Integration and verification

The compiler generated runtime JSON, fingerprint and Xcode input allowlist;
the inventory generator refreshed the catalog and scenario directories.
All 252 preexisting compiled runtime records remain unchanged. Existing saved
template and workout snapshots are not migrated.

The focused requested-gap tests cover exact ownership, unquantified loads,
prior runtime preservation, neighbor exclusions, new-family axis domains and
introduced rule assertions, presence, muscle and stability mutations. Eighteen
affected existing roster/contract tests also pass after reviewed expectation
updates. Catalog validation, documentation parity and diff hygiene pass.

The `catalog-requested-gaps` Baguette scenario covers Library discovery and
detail for the pike fixture in dark, light and Accessibility XXXL states.
Additional native-search captures verify discovery, anatomy semantics and
instructions for every new fixture under `.verify/catalog-requested-search/`.

Broader catalog and app suites remain user-run. Existing unrelated checks have
known drift: the older batch6 evidence-count pin, three old instruction-jargon
records, and three missing core-family entries in a training-role expectation.
Those failures do not involve these eight fixtures and were not hidden or
weakened. The EZ textbook mirror and categorical anatomy transfer remain source
limitations; they do not block the exact fixture admissions.
