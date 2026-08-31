# Default candidate follow-up — August 2026

Status: approved and active as six source-bounded records across five existing
families and one new family owner.

## Decisions

| Catalog ID | Canonical name | Owner |
|---|---|---|
| `single-dumbbell-goblet-squat` | Single-Dumbbell Goblet Squat | `bilateral-squat` |
| `two-dumbbell-stationary-split-squat` | Two-Dumbbell Stationary Split Squat | `split-stance-squat` |
| `two-dumbbell-reverse-lunge` | Two-Dumbbell Reverse Lunge | `dynamic-lunge` |
| `bilateral-dumbbell-shrug` | Bilateral Dumbbell Shrug | `scapular-elevation` |
| `scapular-pull-up` | Scapular Pull-Up | `scapular-pull-up` |
| `high-handle-trap-bar-farmer-carry` | High-Handle Trap-Bar Farmer Carry | `farmer-carry` |

## Evidence and contract decisions

- NASM's exercise-library standard owns the single vertical dumbbell, cupped
  top-head grip, hip-width stance, and parallel-or-deeper goblet endpoint. The
  prior NASM coaching-guide identity remains attached to the kettlebell record.
- Song supplies the stationary floor geometry; USMC supplies paired side-held
  dumbbells and fixed contacts; NSCA supplies two-dumbbell both-side
  programming. Those bounded components do not authorize a generic split-squat
  cross-product.
- Gao supplies the exact paired-dumbbell reverse step-and-return fixture,
  including its distinct 70%-of-ASIS-to-medial-knee landmark, grounded lead
  heel, rear-knee near-floor endpoint, and participant-recorded timing.
- ACE supplies the split-stance simultaneous paired-dumbbell shrug. Upward
  rotation remains the existing family's coupled prime action and is not
  inferred from ACE alone.
- Army and LA County jointly establish a straight-arm suspended repetition
  that moves the scapulae down and back. Because depression is frontal and
  retraction transverse, the record uses a narrow two-plane family rather than
  broadening either single-action scapular owner.
- Lockie and Lazar supply only the high-handle closed dual-height hex-frame
  carry. The pickup and floor return are setup, duration is a product mapping
  from the source's distance task, and low handles or open frames remain out of
  scope.

## Product boundaries

- Every paired-dumbbell record uses `perImplement` and tells the user to log
  one dumbbell. The single goblet dumbbell uses `totalSingleImplement`.
- Scapular Pull-Up is Dynamic Strength/Reps but `nonComparable`: it exposes no
  resistance value, tonnage, estimated one-repetition maximum, or load PR.
- High-Handle Trap-Bar Farmer Carry logs the complete frame plus all plates on
  both sleeves once through `totalBarAndPlates`; it never uses per-side or
  plates-only accounting.
- Stationary versus step-and-return, active hold versus repeated scapular
  cycling, and dumbbell versus trap-bar carry histories remain distinct.

## Activation gates

The active records require exact roster, alias, axis, reciprocal-rule,
negative-cross-product, evidence-scope, generated-runtime, search, load,
Library-discovery, and exercise-detail checks. The canonical non-UI repository
gate and headless Baguette evidence remain the final completion evidence.
