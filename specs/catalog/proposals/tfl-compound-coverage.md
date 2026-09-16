# TFL compound-exercise coverage

- Status: Implemented; independent evidence, contract and seed reviews approved
- Reviewed: 2026-09-16
- Scope: Existing fixtures only; saved-history refresh is outside this correction

## Outcome and gates

TFL is already mapped to bilateral `Tensor_Fascia_Latae` scene nodes. The current
catalog previously credited seven isolation/stepping fixtures. This correction appends TFL to
20 existing compound records; there are no new exercises or aliases. Independent
biomechanics and contract discovery accepted the bounded roles below. Local
whitelists and requirements change; shared taxonomy, anatomical capabilities,
schema, movement actions, phases, planes, axes, geometry, load and identity do not.

| Family and exact existing IDs | TFL addition |
|---|---|
| Single-leg deadlift: `barbell-single-leg-deadlift`, `dumbbell-single-leg-romanian-deadlift-ipsilateral-load`, `dumbbell-single-leg-romanian-deadlift-contralateral-load` | Stabilizer |
| Split stance: `barbell-split-squat`, `two-dumbbell-stationary-split-squat`, `barbell-rear-foot-elevated-split-squat`, `two-dumbbell-rear-foot-elevated-split-squat` | Stabilizer |
| Discrete lunges: `bodyweight-forward-lunge`, `bodyweight-reverse-lunge`, `two-dumbbell-forward-lunge`, `two-dumbbell-reverse-lunge` | Stabilizer |
| Walking lunge: `two-dumbbell-continuous-walking-lunge` | Stabilizer |
| Forward step-up: `bodyweight-forward-step-up-21cm`, `two-dumbbell-forward-step-up` | Stabilizer |
| Free squats: `barbell-back-squat`, `barbell-front-squat`, `kettlebell-goblet-squat`, `single-dumbbell-goblet-squat`, `bodyweight-floor-squat-100-degrees` | Stabilizer |
| Lateral lunge: `bodyweight-lateral-lunge-60-percent-height` | Secondary for its existing hip-abduction step phase |

TFL is a distinct hip/pelvic-control contributor in the supported stance tasks.
Its presence is not a hip-extension contribution or permission to author dynamic
hip flexion in a sagittal squat/hinge. Its central internal-rotation capability
retains the exact 90-degree condition. Stabilizers keep the existing faint anatomy
projection and effort-weighted training-credit projection; no role is promoted to
brighten the model. The lateral-lunge secondary role follows existing abduction
mechanics, not an EMG ranking.

## Evidence ledger

Current primary literature reviewed online on 2026-09-16. Exact geometry still
comes from each fixture's original sources. All transfers below are categorical;
none establish exact-fixture force, equal recruitment, adaptation or medical benefit.

| Primary source | Support and boundary |
|---|---|
| [Selkowitz, Beneck and Powers, 2013](https://pubmed.ncbi.nlm.nih.gov/23160432/) | Fine-wire TFL recordings in unloaded squat, forward lunge and forward step-up. Squat activity was low. Catalog loads, widths, foot orientation, depths, cadence and heights differ; posture/control roles transfer through existing anatomy. |
| [Collings et al., 2023](https://pubmed.ncbi.nlm.nih.gov/36918403/) | TFL was among recorded surface channels in hip-focused tasks including related split squat and single-leg Romanian deadlift. Published outcomes modeled gluteal forces; they do not supply TFL force or a published TFL ranking. Load side, floor start, rear support and exact execution transfer are explicit. |
| [Bouillon et al., 2012](https://pmc.ncbi.nlm.nih.gov/articles/PMC3537460/) | Surface TFL measurements in bodyweight forward and side-step lunges. Source leg-length stride and shoulder-width start differ from the catalog lateral fixture. Reverse, loaded and walking fixtures are anatomy/mechanics transfers. |
| [Besomi et al., 2025](https://pubmed.ncbi.nlm.nih.gov/41172796/) | Surface/fine-wire TFL recordings during step tasks; electrode and normalization affected signals. Does not establish catalog height, paired loading, propulsion restrictions, contact sequence or a portable magnitude. |

The four active source registrations supplement the existing Arnold capability
map. Only active referenced sources are registered. Current supported Smith,
leg-press, bilateral-deadlift and unrelated fixture rosters are unchanged.
Their exclusion from this evidence slice does not establish absent TFL recruitment.

## The -years fixture and Today

The scheme enables `-years`, which uses `DebugYearsSeeder`. It creates sessions
from current catalog records, then retains their role snapshots under deterministic
calendar-date IDs. Its fifth workout included hip abduction as its fifth exercise.
Five-workout weeks occur at week indices 2, 5 and 8 in a 12-week cycle; all have
`week % 3 == 2`, so that slot's `4 + (week + slot) % 3` count is always four.
The original seed therefore never selected its only already-credited TFL exercise.

Offset the four-to-six exercise prefix by the 12-week block number:
`4 + (week + slot + week / 12) % 3`. Late entries are then sampled across training
blocks, including hip abduction and hanging knee raises. The correction also
credits the seed's repeated back squat, front squat and lateral lunge. Counts stay
within four to six; weights, progressions and seed session IDs retain their contract.
The additive seeder does not rewrite previously saved sessions, and this correction
performs no reset or historical backfill.

A DEBUG-only `--ui-test-tfl-development` step reuses the actual first three
`-years` workouts with three unique verification IDs and recent dates. It saves
fresh catalog-backed completed exercises through the same seed constructor; no
roles or renderer colors are hardcoded. This verifies the seed/snapshot/analytics
path while preserving existing history, rather than exercising user completion taps.

Bundled Library entries reconcile to the new fingerprint. Existing templates and
workout snapshots remain frozen, including already-seeded `-years` sessions.
Reselect an affected template exercise for new workout credit. Fresh `-years`
seeding uses the corrected catalog; rerunning it over existing date IDs leaves
those earlier snapshots intact.

## Verification

- Catalog generation and parity passed with 277 evidence sources and 237 records.
- All 61 focused catalog checks passed, including exact rosters, role removal and
  promotion mutations, guided-fixture exclusions, and existing family boundaries.
- Independent authored-draft biomechanics, local-contract and `-years` reviews
  approved all 20 additions and their transfer boundaries. A before/after runtime
  comparison preserved all 237 identities and every other field; existing evidence
  entries were unchanged.
- Independent seed enumeration found zero hip-abduction selections in the old
  104-week sample versus 17 with the corrected prefix (16 in a recent anchored
  104-week sample). The first four exercises remain present in every session.
- The focused `Scripts/verify.sh` incremental app build passed. Naming,
  architecture and source-size checks passed.
- Today light-mode checks reached the TFL credit assertion, but the initial run
  timed out dismissing its report. A focused follow-up dismissed it successfully
  and captured the front and side models. The dark-mode clone completed the
  full scenario, including dismissal. Its accessible TFL row reports Low,
  1.9 effective sets in 14 days, and contributions from lateral lunge, back squat
  and front squat. Inspected side views show the expected faint warm TFL tint.
  This verifies real catalog snapshots through seed, analytics and rendering;
  it does not prove a user-completed workout or refresh frozen histories.
- Evidence: [dark TFL report](../../../.verify/scenarios/catalog-tfl-compound-development-dark/tfl-credit-dark.jpg),
  [dark side model](../../../.verify/scenarios/catalog-tfl-compound-development-dark/today-side-dark.jpg),
  [light side model](../../../.verify/scenarios/catalog-tfl-compound-development/today-side-light.jpg).
  Artifacts are local and ignored by Git.
- The focused light-mode lateral-lunge Library/detail scenario passed at
  Accessibility Large, including TFL's secondary role and exclusion from primary
  or stabilizer roles. Screenshot and accessibility tree were inspected:
  [larger-text detail](../../../.verify/scenarios/catalog-tfl-lateral-detail/tfl-role-accessibility-light.jpg).
  The previously documented Today report issue at Accessibility XXXL remains
  outside this catalog correction; see the forearm correction's verification notes.
