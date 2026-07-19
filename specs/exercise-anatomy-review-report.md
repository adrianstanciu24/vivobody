# Exercise Anatomy Review Report

> Historical audit artifact. Its 20-muscle vocabulary and numeric
> `1.0`/`0.7`/`0.4`/`0.2` tiers describe the pre-remediation catalog and must
> not be used as the current data contract. The implemented contract is
> `specs/exercise-data-contract.md`: categorical primary/secondary/stabilizer
> roles, separate glute max and glute med regions, and distinct external
> rotator, teres major, and subscapularis regions. The generated catalog and
> its validation tests are authoritative.

Reviewer: Codex  
Started: 2026-06-27  
Catalog: `vivobody/Resources/catalog.json`  
Tracking: `specs/exercise-anatomy-review.csv`

## Source Policy

This review uses the app's existing 20-muscle vocabulary only. Exact exercise
sources are preferred. When exact evidence is not available for a named variant,
the mapping is inferred from a mechanically close reviewed movement and the CSV
notes call that out.

Primary source types:

- ExRx movement profiles for target, synergist, dynamic stabilizer, and
  stabilizer roles.
- Peer-reviewed EMG or systematic-review evidence for activation patterns.
- Reputable kinesiology/biomechanics references for movement-family mechanics.

## Sources Used

- ExRx, bodyweight squat: quadriceps target, gluteus maximus/adductor
  magnus/soleus as synergists, hamstrings/gastrocnemius as dynamic stabilizers.
  https://exrx.net/WeightExercises/Quadriceps/BWSquat
- ExRx, front squat: front-loaded squat profile with quadriceps target,
  lower-body synergists/dynamic stabilizers, trunk bracing, and upper-body rack
  stabilizers. https://exrx.net/WeightExercises/Quadriceps/BBFrontSquat
- Schoenfeld BJ, "Squatting Kinematics and Kinetics and Their Application to
  Exercise Performance", Journal of Strength and Conditioning Research, 2010.
  Used for squat-family mechanics and trunk/lower-limb loading context.
  https://pubmed.ncbi.nlm.nih.gov/20182386/
- NASM, "The Biomechanics of the Squat": identifies gluteal/quadriceps agonists,
  hamstrings/erector spinae/adductors/calf synergists, and core stabilizers.
  https://blog.nasm.org/biomechanics-of-the-squat
- Ben-Mansour et al., "Analysis of muscle activation during different leg press
  exercises at submaximum effort levels: A systematic review", 2020. Used for
  leg-press family quadriceps dominance and activity of gluteus maximus, biceps
  femoris, gastrocnemius, and tibialis anterior across leg-press variations.
  https://www.mdpi.com/1660-4601/17/13/4626
- "Lower limb muscle activities during full squats in females with different
  meniscal conditions" (PMC). Used only to support meaningful tibialis anterior
  and gastrocnemius activity during squat phases, not to grade hypertrophy
  magnitude. https://pmc.ncbi.nlm.nih.gov/articles/PMC4305574/
- ExRx, barbell deadlift: erector spinae target; gluteus maximus, quadriceps, adductor magnus, and soleus as synergists; hamstrings/gastrocnemius as dynamic stabilizers; traps/rhomboids/abs/obliques and other trunk or shoulder-girdle muscles as stabilizers. https://exrx.net/WeightExercises/ErectorSpinae/BBDeadlift
- ExRx, barbell straight-leg deadlift: hamstring-focused hinge profile used for RDL/stiff-leg/good-morning inference. https://exrx.net/WeightExercises/Hamstrings/BBStraightLegDeadlift
- ExRx, barbell hip thrust: gluteus maximus target with hamstrings/adductor magnus as synergists and quadriceps/erector spinae/trunk stabilizers. https://exrx.net/WeightExercises/GluteusMaximus/BBHipThrust
- ExRx, power clean and snatch movement profiles: used for Olympic-pull triple extension, shrug, catch, and overhead-stability mappings. https://exrx.net/WeightExercises/OlympicLifts/PowerClean and https://exrx.net/WeightExercises/OlympicLifts/Snatch
- Rodriguez-Ridao et al., deadlift systematic review, International Journal of Environmental Research and Public Health, 2022. Used for deadlift-variant muscle activation comparisons and variant-specific inference. https://www.mdpi.com/1660-4601/19/3/1903
- Neto et al., "Barbell Hip Thrust, Muscular Activation and Performance: A Systematic Review", Journal of Sports Science & Medicine, 2019. Used to keep glute contribution primary and hamstrings/quadriceps secondary in hip-thrust/bridge variants. https://www.jssm.org/jssm-18-198.xml-Fulltext
- McGill and Marshall, kettlebell swing/snatch EMG and spine-load analysis, Journal of Strength and Conditioning Research, 2012. Used for kettlebell swing posterior-chain, trunk, grip, and shoulder-girdle stabilization. https://www.backfitpro.com/medical-scientific-articles/2012/%5B63%5DMcGill%2CS.%282012%29Kettlebell-swing-snatch-and-bottoms-up-carry%5BJ.Strength-Condit.Res.%5D.pdf
- Bourne et al., hamstring exercise selection and activation evidence for Nordic curl mapping. Used for Nordic hamstring primary role and knee-flexion synergist inference. https://pubmed.ncbi.nlm.nih.gov/24978835/

- ExRx, dumbbell bench press: pectoralis major target, anterior deltoid and triceps as synergists, and biceps short head as a dynamic stabilizer for flat press inference. https://exrx.net/WeightExercises/PectoralSternal/DBBenchPress
- ExRx, incline bench press: clavicular pectoralis target with sternal pectoralis, anterior deltoid, and triceps as synergists; used for incline press variants and decline-push-up inference. https://exrx.net/WeightExercises/PectoralClavicular/BBInclineBenchPress
- ExRx, decline bench press: sternal pectoralis target with clavicular pectoralis, anterior deltoid, and triceps as synergists; used for decline press variants. https://exrx.net/WeightExercises/PectoralSternal/BBDeclineBenchPress
- ExRx, push-up and close-grip push-up: pectorals/triceps/deltoids as movers, serratus anterior, rectus abdominis, obliques, quadriceps, erector spinae, and biceps roles for push-up stabilization and close-grip triceps emphasis. https://exrx.net/WeightExercises/PectoralSternal/BWPushup and https://exrx.net/WeightExercises/Triceps/BWCloseGripPushup
- Martin-Fuentes et al., bench-inclination EMG study, 2020. Used to support increased anterior-deltoid involvement as bench angle rises and continued triceps involvement across incline angles. https://pmc.ncbi.nlm.nih.gov/articles/PMC7579505/
- De Araújo et al., push-up-plus/scapular-stabilizer activation review. Used to support serratus anterior inclusion in push-up/scapular-protraction variants. https://pmc.ncbi.nlm.nih.gov/articles/PMC6863690/
- McKenzie et al., "Bench, Bar, and Ring Dips: Do Kinematics and Muscle
  Activity Differ?", 2022. Used for dip-family differences across bench, bar,
  and ring variations, including triceps, pectorals, anterior deltoid,
  latissimus dorsi, trapezius, serratus, and trunk involvement.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC9603242/
- ExRx, barbell military/overhead press: anterior deltoid target, clavicular pectorals/triceps/lateral deltoid/traps/serratus as synergists, biceps as dynamic stabilizer, and upper traps/levator as stabilizers. https://exrx.net/WeightExercises/DeltoidAnterior/BBMilitaryPress
- Coratella et al., "Front vs Back and Barbell vs Machine Overhead Press", Frontiers in Physiology, 2022. Used for deltoid, pectoralis major, upper trapezius, and triceps activation differences across overhead press variants. https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2022.825880/full
- Blazkiewicz and Hadamus, overhead press surface EMG with kettlebell/dumbbell, Sensors, 2022. Used for anterior/posterior deltoid, upper/lower trapezius, serratus anterior, and spinal erector involvement in dumbbell/kettlebell overhead press variants. https://www.mdpi.com/1424-8220/22/24/9762
- ExRx, push press: dynamic hip, knee, ankle, shoulder, scapular, and elbow actions used for push press, jerk, and squat/lunge-to-press inference. https://exrx.net/WeightExercises/OlympicLifts/PushPress
- ExRx, barbell bent-over row: back-general target with traps/rhomboids/lats/teres/posterior deltoids/forearms/pectorals as synergists, biceps and triceps long head as dynamic stabilizers, and lower body/trunk stabilizers. https://exrx.net/WeightExercises/BackGeneral/BBBentOverRow
- ExRx, cable seated row: row profile with erector spinae, traps, rhomboids, lats, teres, posterior deltoids, elbow flexors, pectorals, biceps/triceps dynamic stabilizers, and lower-body stabilizers. https://exrx.net/WeightExercises/BackGeneral/CBSeatedRow
- NASM, lat pulldown biomechanics and grip research: used for pulldown, pull-up, chin-up, and wide/underhand grip rules for lats, teres, rhomboids, traps, biceps/forearms, triceps, pectorals, and trunk bracing. https://blog.nasm.org/biomechanics-of-the-lat-pulldown
- Youdas et al., inverted row/pull-up/push-up EMG comparison. Used for bodyweight row and closed-chain pull-up core/scapular stabilization inference. https://pubmed.ncbi.nlm.nih.gov/21068680/
- ExRx, barbell lunge: quadriceps target; gluteus maximus, adductor magnus, and soleus as synergists; hamstrings/gastrocnemius as dynamic stabilizers; erector spinae, tibialis anterior, gluteus medius/minimus, quadratus lumborum, and obliques as stabilizers. https://exrx.net/WeightExercises/Quadriceps/BBLunge
- ExRx, dumbbell step-up: quadriceps target; gluteus maximus, adductor magnus, soleus/gastrocnemius as synergists; hamstrings/gastrocnemius dynamic stabilizers; erector spinae, traps, glute med/min, quadratus lumborum, obliques, and abs as stabilizers. https://exrx.net/WeightExercises/Quadriceps/DBStepUp
- Muyor et al., PLOS ONE 2020 EMG comparison of monopodal squat, forward lunge, and lateral step-up. Used for quads/glutes/hamstrings emphasis and unilateral lower-body inference. https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0230841
- MDPI, "Effects of Step Length and Stride Variation During Forward Lunges on Lower-Extremity Muscle Activity", 2025. Used for lunge stride/step-length sensitivity across quadriceps, hamstrings, gastrocnemius, hip adductors, gluteus maximus, and gluteus medius. https://www.mdpi.com/2411-5142/10/1/42
- Coratella et al., biceps curl EMG across forearm positions, 2023. Used for biceps, brachioradialis/forearm, and anterior-deltoid stabilization in curl variants. https://pmc.ncbi.nlm.nih.gov/articles/PMC10054060/
- Hussain et al., triceps pushdown fatigue/EMG study, 2020. Used for triceps pushdown as triceps-primary with handle/grip and posture stabilization. https://pmc.ncbi.nlm.nih.gov/articles/PMC7047337/
- Maeo et al., overhead vs neutral-arm cable elbow extension training, 2022. Used to distinguish overhead triceps-extension long-head position while keeping all triceps rows within the app triceps bucket. https://pubmed.ncbi.nlm.nih.gov/35819335/
- NCBI Bookshelf, triceps anatomy and function: elbow extension plus long-head shoulder role. Used for extension/kickback/overhead-extension inference. https://www.ncbi.nlm.nih.gov/books/NBK536996/
- NCBI Bookshelf, forearm muscles and wrist extensor anatomy. Used for
  wrist/finger flexion, extension, pronation/supination, and grip tasks in
  forearm-isolation rows. https://www.ncbi.nlm.nih.gov/books/NBK536975/ and
  https://www.ncbi.nlm.nih.gov/books/NBK534805/
- ExRx, dumbbell fly: pectoralis target, clavicular pectoralis/anterior deltoid/biceps short head as synergists, and biceps/brachialis/triceps/wrist flexors as stabilizers. https://exrx.net/WeightExercises/PectoralSternal/DBFly
- Reinold et al./lateral-raise EMG evidence summarized in PMC: used for deltoid primary role and trapezius/serratus scapular assistance in lateral/front raise variants. https://pmc.ncbi.nlm.nih.gov/articles/PMC7503819/
- McAllister et al., grip-width effects in upright row EMG: used for deltoid/trapezius dominance, biceps contribution, and upright/high-pull inference. https://pubmed.ncbi.nlm.nih.gov/22362088/
- NCBI Bookshelf, rotator cuff anatomy: infraspinatus and teres minor externally rotate the shoulder; subscapularis internally rotates. Used to remap external/internal rotation rows into the closest available app buckets. https://www.ncbi.nlm.nih.gov/books/NBK441844/
- Escamilla et al./trunk exercise EMG evidence for abdominal and hip-flexor activation in crunch, plank, leg raise, and rollout families. Used for abs/obliques/hipFlexors/lowerBack grading. https://pubmed.ncbi.nlm.nih.gov/30856100/
- Comparison of abdominal and lower-limb muscle activities during leg raise and eccentric sit-up exercises (PMC). Used to keep hipFlexors major in leg raise/sit-up patterns. https://pmc.ncbi.nlm.nih.gov/articles/PMC4792997/
- ExRx-style core movement profiles and standard kinesiology anatomy for oblique rotation/anti-rotation, plank bracing, and loaded carries; exact named variants are inferred by mechanical similarity when no exact EMG exists.
- Residual leg rows reuse prior squat, lunge, leg-press, deadlift, and overhead-press sources for compound lower-body mechanics; exact long-tail variations are inferred by matching knee/hip/ankle actions.
- NCBI/standard kinesiology anatomy for knee extension/flexion, hip abduction/adduction, plantarflexion, and dorsiflexion; used for leg extension, leg curl, calf raise, hip machine, and tibialis rows. https://www.ncbi.nlm.nih.gov/books/NBK538511/
- ExRx and EMG sources already cited for squat, lunge, step-up, leg press, and overhead press support the jump, thruster, wall-ball, and loaded-carry inferences in this batch.
- Final back accessory rows reuse cited row, pullover, back-extension, rotator-cuff, and core lever/plank sources; exact gymnastic/scapular variations are inferred from matched shoulder-extension, retraction, and prone-extension mechanics.
## Batch 1: Squat And Leg-Press Family

Date: 2026-06-27  
Status: complete for the 24 exercises listed in the CSV as `done`.

Reviewed records:

- Barbell Full Squat
- Barbell Hack Squats
- Belt Squat
- Bodyweight Squat HD
- Box squat
- Double Kettlebell Front Squat
- Dumbbell Front Squat
- Dumbbell Goblet Squat
- Front Squats
- Hack Squats
- Landmine Squat
- Leg Press
- Leg Press on Hackenschmidt Machine
- Leg Presses (narrow)
- Leg Presses (wide)
- Low Box Squat - Wide Stance
- Overhead Squat
- Pause Hack Squats
- Pendular hack
- Pendulum Squat
- Pin Squat
- Smith machine squat
- Squats
- Sumo Squats

Mapping rules applied:

- Standard loaded squat variants: quadriceps remain `1.0`; glutes/adductors are
  scaled to `0.7`; hamstrings are `0.4` as dynamic stabilizers rather than prime
  movers; calf complex, trunk bracing, and shins are included where supported.
- Front-loaded variants: same lower-body base, with higher abdominal bracing and
  trace rack/shoulder-girdle stabilizers where the implement demands it.
- Overhead squat: lower-body squat base plus deltoids/traps/serratus for
  overhead/scapular stabilization.
- Hack/pendulum and leg-press variants: reduced trunk loading because machine
  support changes stabilization demand; calf complex is retained because ExRx
  and leg-press EMG evidence support soleus/gastrocnemius involvement.
- `shins:0.2` was added only as trace ankle-position/dorsiflexion control; it is
  not treated as a prime mover in squat or leg-press patterns.

Severity counts for this batch:

- Critical: 0
- Major: 24
- Minor: 0

Rationale for severity: each changed record had at least one missing synergist
or a non-trivial weight correction, most commonly adductors/calf complex added,
hamstrings demoted from major to minor/dynamic stabilizer, or glute contribution
scaled from prime to major based on squat/leg-press role rather than listed as
co-prime by default.

## Batch 2: Deadlift, Hinge, Hip-Thrust, Back-Extension, And Olympic-Pull Family

Date: 2026-06-27  
Status: complete for the 49 exercises listed in the CSV as `done`.

Reviewed records:

- 2 Handed Kettlebell Swing
- Back bridge
- Banded Single Leg Hip Thrusts
- Barbell Hip Thrust
- Barbell Romanian Deadlift (RDL)
- Cable pull through
- Clean
- Deadlifts
- Deficit Deadlift
- Dumbbell Deadlift
- Dumbbell Frog Press
- Dumbbell Hang Power Cleans
- Dumbbell Hip Thrust
- Dumbbell Romanian Deadlift
- Dumbbell sumo deadlift
- Glute Bridge
- Glute Drive
- Good Mornings
- Hinge with Broomstick
- Hip Bridge
- Hip Raise, Lying
- Hip Thrust
- Hip hinge
- Hyperextensions
- Kettlebell One Legged Deadlift
- Kettlebell RDL (warm-up)
- Kettlebell Swings
- Kettlebell deadlifts
- Kickstand RDL
- Landmine Single Leg RDL
- Lower Back Extensions
- Nordic Curl
- Power Clean
- Rack Deadlift
- Reverse Hyperextension
- Reverse Nordic Curl
- Romanian Deadlift
- Single Leg Glute Bridge
- Single Leg Hip Thrusts (warm-up)
- Single Leg RDL
- Single-Leg Deadlift with Dumbbell
- Snatch OL
- Speed Deadlift
- Stiff-legged Deadlifts
- Sumo Deadlift
- Trap Bar Deadlift
- Unilateral Hip Thrust
- dumbbell snatch
- kettlebell sumo deadlift

Mapping rules applied:

- Deadlift variants: glutes and lowerBack remain highest for conventional pulls; hamstrings/quads/adductors/calf complex are added or reweighted based on floor position, stance, and variant, with forearms and trunk/shoulder stabilizers included where load handling demands it.
- RDL, stiff-leg, good-morning, and single-leg hinge variants: hamstrings stay primary; glutes and lowerBack are major contributors; unilateral variants add adductors, calves, abs, and obliques for pelvic and stance control.
- Hip thrusts and bridges: glutes stay `1.0`; hamstrings are generally `0.4` rather than `0.7` because knee flexion reduces their hip-extension role; quads/lowerBack/trunk stabilizers are included at trace-to-minor levels.
- Kettlebell swings: ballistic hip extension keeps glutes/hamstrings primary, with lowerBack/trunk bracing, grip, shoulder-girdle stabilization, and trace knee/ankle contribution.
- Back extensions and reverse hypers: posterior-chain roles are kept, with abs added as antagonist/trunk bracing where missing.
- Olympic pulls/snatches: triple-extension and catch/overhead demands add calves, trunk bracing, grip, and shoulder/scapular stabilizers that were missing from several catalog rows.
- Nordic and reverse Nordic curls: primary knee flexor/extensor mappings were retained; small stabilizers were added or reweighted for hip/trunk control.

Severity counts for this batch:

- Critical: 0
- Major: 43
- Minor: 6

Rationale for severity: no record in this batch was missing its main named movement target, so critical count is zero. Major changes are mostly missing synergists, wrong co-primary weights, or omitted grip/trunk/stance stabilizers in compound hinge patterns. Minor changes are rows where the primary and major synergists were already present and the edit only added or tuned trace stabilizers.

## Batch 3: Horizontal Press, Push-Up, And Dip Family

Date: 2026-06-27  
Status: complete for the 74 exercises listed in the CSV as `done`.

Reviewed records:

- Bench Dips On Floor HD
- Bench Press
- Bench Press Narrow Grip
- Benchpress Dumbbells
- Burpees
- Cable Chest Press - Decline
- Cable Chest Press - Incline
- Cable Press Around
- Chair dips
- Chest Press
- Clap Push-UP
- Close-Grip Bench Press
- Close-grip Press-ups
- DB Underhand bench press
- Decline Bench Press Barbell
- Decline Bench Press Dumbbell
- Decline Pushups
- Deficit Push ups
- Diamond push ups
- Dips
- Dips Between Two Benches
- Dumbbell Floor Press
- Dumbbell Hex Press
- Dumbbell Push-Up
- Dumbbell close grip bench press
- Elbows Tucked DB Bench Press
- Finger Pushup
- Flat Machine Press
- Floor dips
- Glute Bridge Single-Arm Press
- Hammerstrength Decline Chest Press
- High-Incline Smith Machine Press
- Incline Bench Press - Barbell
- Incline Bench Press - Dumbbell
- Incline Bench Press - MP
- Incline Chest Press DB
- Incline Close Grip Barbell Bench Press
- Incline Dumbbell Press
- Incline Push up
- Incline Shoulder Press Up
- Incline Smith Press
- Isometric 3-Sec Wall Holds
- Isometric Wipers
- JM Press
- KB Press-Ups with Bands
- Larsen Press
- Legend Chest Press
- Legend Incline Bench Press
- Leverage Machine Chest Press
- Machine Chest Press
- Machine Chest Press Exercise
- Medicine Ball Punch Throw
- No Leg Drive Dumbbell Chest Press
- One armed push-ups
- Pause Bench
- Pin Bench Press BB
- Push-Up
- Push-Ups | Decline
- Push-Ups | Incline
- Push-Ups | Parallettes
- Push-up rotations
- Ring Dips
- SMITH MACHINE SLIGHT INCLINE PRESS
- Seated Bench Press
- Side to Side Push Ups
- Smith Machine Close-grip Bench Press
- Strict Press-Ups
- Supine Med Ball Chest Pass
- TRX dips
- Triceps Dips (Assisted)
- Wall Pushup
- Weighted push-ups
- Wide Push-Up
- knee push-ups

Mapping rules applied:

- Flat bench/chest press variants: pectorals stay `1.0`; triceps are `0.7`, anterior deltoids `0.4`, and biceps is retained as `0.2` only where ExRx lists it as a dynamic stabilizer.
- Incline presses: pectorals remain primary, anterior deltoids rise to `0.7`, and triceps were corrected to `0.7` rather than trace because elbow extension remains a major contributor.
- Decline presses: pectorals remain primary with triceps/anterior deltoids as synergists; lats were not added because ExRx notes low lat involvement on decline bench.
- Close-grip bench and close-grip/diamond push-ups: triceps are primary, pectorals major, anterior deltoids minor, with push-up variants adding serratus and trunk/plank stabilizers.
- Standard push-ups: serratus anterior, abs, obliques, quadriceps, lowerBack, and trace biceps were added from the ExRx push-up stabilizer/dynamic-stabilizer profile; hand/foot variations adjust deltoid, triceps, core, or forearm weights by mechanics.
- Dips: chest-oriented dips keep pectorals/triceps co-primary; bench/triceps dips keep triceps primary. Lats/traps/serratus/trunk stabilizers were added at trace levels, with ring/TRX variants adding instability demands.
- Medicine-ball, cable press-around, burpee, and glute-bridge press hybrids use the reviewed press pattern plus documented rotational, protraction, squat, or bridge demands.

Severity counts for this batch:

- Critical: 0
- Major: 20
- Minor: 54

Rationale for severity: critical count is zero because named prime movers were generally present. Major changes are incline/trx/ring/cable/medicine-ball/burpee/hybrid cases where a meaningful synergist or cross-pattern contribution was missing or underweighted. Minor changes are primarily added stabilizers such as serratus, biceps, trunk, lats/traps, or small push-up/dip weight adjustments.

## Batch 4: Vertical Press, Landmine Press, And Clean/Press Family

Date: 2026-06-27  
Status: complete for the 35 exercises listed in the CSV as `done`.

Reviewed records:

- Arnold Shoulder Press
- Barbell Clean and press
- Clean and Jerk OL
- Clean and Press
- Devil’s Press
- Diagonal Shoulder Press
- Double Kettlebell Clean and Press
- Dumbbell Bradford press
- Goblet Squat to Press
- Handstand Push Up
- Hindu Pushups
- Incline OHP DB
- Jerk OL
- Kreis Press DB
- Landmine Punch
- Landmine Squat to Press
- Landmine press
- Lunge + Overhead Press (warm-up)
- Military Press mit SZ-Bar
- Overhead Barbell Press
- Overhead Press
- Pike Push Ups
- Pin OHP
- Pseudo Planche Push-up
- Push OHP
- Push Press
- Shoulder Press, Barbell
- Shoulder Press, Dumbbells
- Shoulder Press, on Machine
- Shoulder Press, on Multi Press
- Single-arm dumbbell shoulder press
- Smith Press
- Tuck planche
- ½ Kneeling Dumbbell Press
- ½ Kneeling Landmine Press

Mapping rules applied:

- Strict overhead presses: deltoids stay `1.0`, triceps `0.7`, with pectorals, traps, serratus, trunk bracing, and trace biceps added from ExRx and overhead-press EMG evidence.
- Machine/Smith variants: same shoulder/scapular pattern but reduced trunk demand because the machine constrains the load path.
- Unilateral and half-kneeling presses: obliques rise to `0.4` for anti-rotation/anti-lateral-flexion, with serratus and trunk bracing retained.
- Landmine presses/punches: treated as an angled vertical-horizontal press, so pectorals and serratus are higher than in a strict vertical press and obliques/forearms stabilize the unilateral bar path.
- Push press, jerk, clean-and-press, and clean-and-jerk: combine reviewed Olympic-pull, squat/leg-drive, and overhead-press rules; calves, forearms, posterior chain, serratus, and trunk stabilizers were added where missing.
- Pike, handstand, Hindu, and planche-style bodyweight presses: combine overhead-press and push-up-plus evidence, emphasizing deltoids/triceps with serratus and trunk stabilization.
- Squat/lunge-to-press hybrids: combine the reviewed lower-body squat/lunge pattern with the overhead-press pattern rather than treating them as shoulder-only rows.

Severity counts for this batch:

- Critical: 0
- Major: 34
- Minor: 1

Rationale for severity: critical count is zero because shoulder/deltoid prime movers were present. Nearly every row required a major correction because serratus, pectoral/clavicular contribution, trunk bracing, biceps dynamic stabilization, leg drive, or clean/pull contributions were omitted or materially underweighted. The minor case was a landmine punch whose major protraction/rotation pattern was already mostly represented.

## Batch 5: Pull-Up, Pulldown, Row, And Compound Back-Pull Family

Date: 2026-06-27  
Status: complete for the 75 exercises listed in the CSV as `done`.

Reviewed records:

- 1-Arm Half-Kneeling Lat Pulldown
- Alternating High Cable Row
- Alternative DB Gorilla rows
- Archer Pull Up
- Assisted Pull-Up
- Assisted chin-ups
- Australian pull-ups
- Barbell Row (Overhand)
- Barbell Row (Underhand)
- Bent Over Dumbbell Rows
- Bent Over Rowing
- Bent Over Rowing Reverse
- Biceps Close Grip Pull Down
- Chin-ups
- Close-grip Lat Pull Down
- Dumbbell Underhand Dead Row
- Front Pull narrow
- Front lever pull-up
- Front pull wide
- Helms Row
- High Row
- Horizontal traction isometry
- Incline Chest-Supported Dumbbell Row
- Incline Dumbbell Row
- Inverted Lat Pull Down
- Inverted Rows
- KB/DB Drags
- Kettlebell Row and Rotate
- Kroc Row
- L-Sit Pull-ups
- Lat Pull DB
- Lat Pull Down
- Lat Pull Down (Leaning Back)
- Lat Pull Down (Straight Back)
- Lat Pulldown - Cross Body Single Arm
- Leverage Machine Iso Row
- Long-Pulley (low Row)
- Long-Pulley, Narrow
- Meadows Row
- Muscle up
- Neutral Grip Lat Pulldown
- Neutral-grip pull-ups or TRX rows
- One Arm Bent Row
- One-Arm Heavy Row
- Pendelay Rows
- Pull Ups on Machine
- Pull-Ups (Neutral Grip)
- Pull-Ups (Wide Grip)
- Pull-up Isometric Hold
- Pull-ups
- Pullover Machine
- Pullup on fingerboard
- Renegade Row
- Rope Pullover/row
- Rowing seated, narrow grip
- Rowing with TRX band
- Rowing, Lying on Bench
- Seated Cable Rows
- Seated Row (Machine)
- Seated V-Grip Row
- Shotgun Row
- Side Straight-Arm Pulldown (Cable)
- Single Arm Plank to Row
- Single arm row
- Straight-Arm Pulldown (Cable)
- T-Bar row
- TRX Rows
- Typewriter Pull-ups
- Underhand Lat Pull Down
- Unilateral Cable row
- Upper Back
- V-Bar Pulldown
- Wide Pull Up
- Wide-grip Pulldown
- commando pull-ups

Mapping rules applied:

- Free bent-over rows: kept lats/rhomboids primary, raised or retained traps/biceps, added posterior deltoid/forearm/teres contributions plus ExRx-listed pectoral/triceps dynamic stabilizers and lower-body/trunk bracing.
- Supported, machine, and cable rows: removed most lower-body bracing where the chest/machine supports the torso, but added posterior deltoid, forearms, pectorals, triceps, and lowerBack where ExRx row profiles support them.
- Inverted/TRX/bodyweight rows: combined the row pattern with plank-body stabilization, adding abs, obliques, lowerBack, and glutes where the bodyline must be held.
- Pulldowns and pull-ups: lats stay primary; teres, biceps/forearms, rhomboids, traps, posterior deltoids, pectorals, triceps long head, and trunk bracing are graded by NASM pull-down/pull-up mechanics and grip research.
- Supinated/close-grip pulls: biceps are elevated to co-primary only where the movement name or grip materially emphasizes elbow flexion; wide pulls reduce biceps to minor while keeping lats/teres high.
- Hybrids such as front-lever pull-ups, muscle-ups, renegade rows, and rope pullover/row combine the reviewed pull pattern with core, dip/press, or straight-arm shoulder-extension demands.

Severity counts for this batch:

- Critical: 0
- Major: 70
- Minor: 5

Rationale for severity: critical count is zero because lats/rhomboids/biceps targets were generally present. Most changes are major because the original pull rows systematically omitted posterior deltoid/forearm, pectoral/triceps dynamic stabilizers, trunk/lower-body stabilizers, or grip-specific biceps/teres changes. Minor rows were mostly generic upper-back or pullover entries that already had the main target pattern and only needed small stabilizer confirmation.

## Batch 6: Lunge, Split-Squat, Step-Up, And Unilateral Lower-Body Family

Date: 2026-06-27  
Status: complete for the 32 exercises listed in the CSV as `done`.

Reviewed records:

- Alternate back lunges
- Altitude Landings to Lateral Shuffle
- Barbell Lunges Standing
- Barbell Lunges Walking
- Barbell Step Back Lunge
- Bodyweight lunge HD
- Bulgarian Squat with Dumbbells
- Cossack squat
- Dumbbell Lunges Standing
- Dumbbell Lunges Walking
- Dumbbell Rear Lunge
- Dumbbell Side Squat
- Dumbbell Split Squat
- Goblet Reverse Lunge
- Goblet Reverse Lunge with Knee Raise
- Goblet Split Squat
- Ice Skaters
- Ice Skaters to Vertical Hop
- Ice Skaters with Medicine Ball
- Landmine Reverse Lunge with Knee Raise
- Lateral Push Off
- Lunge Matrix
- Lunges
- Pistol Squat
- Reverse lunges
- Single-Leg Lunge with Kettlebell:
- Sliding Lateral Lunge
- Smith Machine Split Squat
- Step-ups
- Unilateral Lunges
- Walking Lunges
- Weighted Step-ups

Mapping rules applied:

- Standard lunges: quadriceps stay `1.0`; glutes and adductors are `0.7`; hamstrings and calves are `0.4`; lowerBack, obliques, abs, and shins capture ExRx-listed trunk, frontal-plane, and ankle stabilizers.
- Loaded lunges and split squats: same lower-body base with higher trunk bracing and trace grip/trap stabilization depending on dumbbell, kettlebell, goblet, Smith, or barbell setup.
- Lateral/Cossack patterns: adductors rise to `1.0` alongside quadriceps because frontal-plane hip control and adductor loading are central to the movement.
- Pistol/monopodal squat: quads stay primary, shins rise to `0.4` for deep dorsiflexion/balance, and hipFlexors are trace for the held free leg.
- Step-ups: quads stay primary with glutes/adductors/calves/hamstrings assisting, matching ExRx and PLOS lateral-step-up evidence.
- Skater/lateral-shuffle patterns: glutes are primary for lateral propulsion, with quads/adductors/calves major and trunk stabilizers added for landing/push-off control.
- Knee-raise variants: reviewed lunge base plus `hipFlexors:0.7` for the active drive phase.

Severity counts for this batch:

- Critical: 0
- Major: 32
- Minor: 0

Rationale for severity: critical count is zero because quadriceps/glute targets were present. All rows are major because hamstrings were commonly overstated as major, adductors/calves/shins/core stabilizers were missing or underweighted, and lateral or knee-raise variants needed materially different emphasis.

## Batch 7: Arm Isolation, Grip, And Arm-Accessory Family

Date: 2026-06-27  
Status: complete for the 93 exercises listed in the CSV as `done`.

Reviewed records:

- Alternating Biceps Curls With Dumbbell
- Alternating bicep curls
- Alternating dumbbell hammer curl
- Barbell Reverse Wrist Curl
- Barbell Triceps Extension
- Barbell Wrist Curl
- Bayesian Curl
- Biceps Curl Machine
- Biceps Curl With Cable
- Biceps Curls With Barbell
- Biceps Curls With Dumbbell
- Biceps Curls With SZ-bar
- Biceps with TRX
- Bizeps Curls Trifecta
- Bodyweight Biceps Curl
- Cable Concentration Curl
- Cable Curls
- Cable Tri Extension - Internal Rotation
- Cable Tricep Kickback
- Cable Triceps Press
- Curl  - With Shoulder Elevated
- Curl with kettlebell two hands
- DB Cross Body Hammer Curls
- DB Wrist Extension
- Deadhang
- Drag Pushdown
- Dumbbell Cheat Curl
- Dumbbell Concentration Curl
- Dumbbell Curl
- Dumbbell Incline Curl
- Dumbbell Triceps Extension
- Dumbbell bicep curl to press
- Dumbbell drag curls
- Dumbbell wide bicep curls
- Dumbbells on Scott Machine
- Dumbell Tate Press
- Fingerboard 20 mm edge
- Floor Skull Crusher
- Forearm Curls (underhand grip)
- Hammer Curls
- Hammercurls on Cable
- Hand Grip
- High-Cable Cross Tricep Extention - NB
- Incline Skull Crush
- Lying Dumbbell Curls
- Lying Triceps Extensions
- Lying Triceps Kickback
- One Arm Overhead Cable Tricep Extension
- One Arm Triceps Extensions on Cable
- Overhand Cable Curl
- Overhead Cable Tricep Extension
- Overhead Triceps Extension
- Plate Pinch Hold
- Preacher Curl - Externally Rotated
- Preacher Curl - Internally Rotated
- Preacher Curls
- Reverse Bar Curl
- Reverse Curl
- Reverse EZ Bar Cable Curls
- Reverse Grip Barbell Curls
- Reverse Preacher Curl (Close Grip)
- Rocking Triceps Pushdown
- Seated Dumbbell Curls
- Seated Triceps Press
- Seated W Curl
- Shoulder width three-point push-up
- Shrugs, Barbells
- Shrugs, Dumbbells
- Single-arm Preacher Curl
- Single-arm cable pushdown
- Skullcrusher Dumbbells
- Skullcrusher SZ-bar
- Sloper hanging
- Spider Curl
- Standing Bicep Curl
- Standing Rope Forearm
- Straight Bar Cable Curls
- TRX Tricep Extension
- TRX gorilla biceps curl
- TRX hammer curl
- Tricep Dumbbell Kickback
- Tricep Pushdown on Cable
- Tricep Rope Pushdowns
- Triceps Extensions on Cable
- Triceps Extensions on Cable With Bar
- Triceps Overhead (Dumbbell)
- Triceps Pushdown
- Triceps on Machine
- Trx Single Arm Bicep Curl
- Wrist curl, cable
- Wrist curl, dumbbells
- Zottman curl
- one-handed kettlebell curls

Mapping rules applied:

- Supinated curl variants: biceps stay `1.0`; forearms are `0.4` for brachioradialis and wrist stabilization, reduced to `0.2` on highly supported machine/concentration curls.
- Hammer curls: biceps stay `1.0` because the app's biceps bucket includes brachialis; forearms stay `0.7` for brachioradialis/neutral-grip emphasis.
- Reverse/pronated and Zottman curls: forearms rise to `1.0`; biceps are `0.7` or `1.0` depending on whether the movement also contains a supinated curl phase.
- Triceps pushdowns/extensions/skull crushers/kickbacks: triceps stay `1.0`; forearms, deltoids, traps, abs, or lowerBack are added only as trace stabilizers demanded by cable posture, overhead shoulder position, lying setup, or bent-over kickback position.
- TRX/bodyweight arm isolations: add deltoid/serratus/trunk stabilizers because the body is supported through the arms rather than by a bench or machine.
- Wrist curls, reverse wrist curls, pinch holds, hand grips, and rope forearm work remain pure `forearms:1.0` rows.
- Hangs/fingerboard rows: forearms are primary, with lats/teres/scapular stabilizers and abs added for shoulder/body-position control.
- Curl-to-press and three-point push-up hybrids combine the already-reviewed curl/press/push-up patterns instead of remaining sparse arm-only rows.

Severity counts for this batch:

- Critical: 0
- Major: 10
- Minor: 40

Rationale for severity: critical count is zero because arm prime movers were present. Major rows are grip-dominant, reverse/Zottman, TRX/bodyweight, or hybrid rows where the old mapping materially misweighted the main elbow-flexor/forearm split or omitted the non-arm pattern. Minor rows mostly added trace stabilizers. Forty-three reviewed isolation rows already matched the source-backed mapping and are marked done without counting as changed.

## Batch 8: Chest Fly, Shoulder Raise, Rotator-Cuff, Shrug, And Upper-Back Accessory Family

Date: 2026-06-27  
Status: complete for the 95 exercises listed in the CSV as `done`.

Reviewed records:

- 45° lateral raises
- BUS DRIVERS
- Band pull-apart with external rotation
- Banded External Rotations
- Banded Shadow Box
- Barbell Silverback Shrug
- Behind the Back Cable Lateral Raise
- Bent High Pulls
- Bent over Cable Flye
- Bent over row to external rotation
- Bent-over Lateral Raises
- Butterfly
- Butterfly Narrow Grip
- Butterfly Reverse
- Cable Cross-over
- Cable External Rotation
- Cable Fly
- Cable Fly Lower Chest
- Cable Fly Middle Chest
- Cable Fly Upper Chest
- Cable Front Raise with a small bar
- Cable Lateral Raises (Single Arm)
- Cable Rear Delt Fly
- Cable Rear-Delt Fly (single arm)
- Cable Shrug-In
- Chest-Supported Rear Delt Raise
- Cross-Bench Dumbbell Pullovers
- Cross-Body Cable Y-Raise
- Dumbbell Bent Over Face Pull
- Dumbbell Scaption
- Dumbbell Shrug
- Dumbbell rear delt row
- Face pulls with yellow/green band
- Facepull
- Fly With Cable
- Fly With Dumbbells
- Fly With Dumbbells, Decline Bench
- Front Plate Raise
- Front Raise (Cable)
- Front Raises
- Front Raises with Plates
- High Pull
- High plank
- High-Cable Lateral Raise
- Incline Bench Reverse Fly
- Incline DB Y-Raise
- Incline Dumbbell Fly
- Incline Static Hold
- Kettlebell sumo high pull
- Lateral Raises
- Lateral Rows on Cable, One Armed
- Lateral-to-Front Raises
- Low Pulley Cable Fly
- Low-Cable Cross-Over - NB
- Lying Rotator Cuff Exercise
- Machine Side Lateral Raises
- Machine chest fly
- No push-up burpees
- Omni Cable Cross-over
- Pec Deck
- Pec deck rear delt fly
- Perpendicular Unilateral Landmine Row
- Prone Banded Press
- Punch Iso Holds
- Rear Delt Raise
- Reverse Cable Flye
- Reverse Fly Standing
- Reverse Grip Bench Press
- Ring Support Hold
- SEATED CABLE MID TRAP SHRUG
- Schoulder Raise (Dumbbell)
- Seated Cable chest fly
- Seated Dumbbell Side Lateral
- Seated rear delt rise
- Shoulder Dumbbell Pendular Exercise
- Shoulder External Rotation (Cable)
- Shoulder External Rotation with Dumbbell
- Shoulder Internal Rotation (Cable)
- Shoulder Raise Side and Front DB
- Shoulder Shrug
- Shoulder Y-pull cable
- Shrugs on Multipress
- Side Lateral Raise (Cable)
- Side lateral raise - Back (Cable)
- Side lateral raise - Front (Cable)
- Side-laying interior rotation
- Side-lying External Rotation
- Straight Bar Cable Front Raise
- Suspended crossess
- Trap press
- Trap-3 Raise
- Upright Row w/ Dumbbells
- Upright Row, SZ-bar
- Upright Row, on Multi Press
- unilateral cross body cable pull down

Mapping rules applied:

- Chest fly/crossover rows: pectorals stay primary; deltoids assist; biceps/triceps/forearms are added only where ExRx lists shoulder/elbow/grip stabilization. Machine fly variants omit forearm grip.
- Pullovers and straight-arm shoulder-extension variants: lats become primary where the movement is a pullover/lat pull, with pectorals, teres, serratus, triceps, and abs assisting.
- Rear-delt fly, face-pull, and external-rotation patterns: deltoids remain primary for rear-delt rows, but teres rises to major/primary for rotator-cuff external rotation, with rhomboids/traps stabilizing scapulae.
- Internal-rotation rows: the true subscapularis target has no app bucket, so available pectoral/lats/teres internal-rotation contributors are used and deltoids are demoted.
- Lateral/front/scaption raises: deltoids are primary; traps/serratus support upward rotation; forearms and abs provide trace standing/cable stabilization.
- Shrugs and trap/Y raises: traps stay primary, with rhomboids/serratus/forearms/lowerBack added according to loaded posture and scapular-control demand.
- Upright rows/high pulls: upright rows keep deltoids/traps co-primary; high pulls add lower-body drive and posterior-chain bracing.
- Shadow-box, punch-hold, ring support, high plank, and no-push-up burpee hybrids combine the reviewed push/core/squat support patterns.

Severity counts for changed rows in this batch:

- Critical: 8
- Major: 35
- Minor: 52

Rationale for severity: critical rows were rotator-cuff/internal-rotation exercises where the prior primary mover was anatomically wrong in the 20-muscle vocabulary. Major rows changed the dominant pattern or added substantial cross-pattern demand. Minor rows mostly added trace stabilizers or confirmed accessory mappings.

## Batch 9: Core Flexion, Plank, Leg-Raise, Rotation, Carry, And Conditioning Family

Date: 2026-06-27  
Status: complete for the 116 exercises listed in the CSV as `done`.

Reviewed records:

- Ab wheel
- Abdominal Crunch
- Abdominal Stabilization
- Bag training
- Ball Slams
- Ball crunches
- Banded Pallof Split Jerks
- Banded Rotations
- Barbell Ab Rollout
- Battle Ropes
- Bear crawl pull through
- Bird Dog
- Black Widow Knee Slides
- Butterfly Sit Up
- Cable Woodchoppers
- Clamshell
- Core Rotation
- Crunches
- Crunches With Cable
- Crunches With Legs Up
- Crunches on Machine
- Deadbug
- Decline Bench Leg Raise
- Double-Leg Abdominal Press
- Dragon-flag
- Dumbbell Crunches
- Dumbbell Side Bend
- Dynamic Planche
- Dynamic side hold
- Flutter Kicks
- Frog stand
- Front Lever
- Front Wood Chop
- Full Sit Outs
- Hanging Leg Raises
- Heel Touches
- High Knee Jumps
- High knees
- Hollow Hold
- Incline Crunches
- Incline Plank With Alternate Floor Touch
- Jump rope: basic jumps
- Jumping Jack HD
- Knee Raises
- Kneeling Pallof Iso Holds
- Kneeling Rotational Throws
- L-Sit (Foot Supported)
- L-sit
- Landmine Rotation
- Lateral Plank Walk
- Lateral Shuffle to MB Throw
- Leg Lowers with 2-Sec Pause
- Leg Raise
- Leg Raises, Standing
- Leg raises pull up bar
- Lying Leg Raise
- Manual Iso Holds
- Medicine ball booklet crunch
- Medicine ball twist
- Mountain climbers
- PALLOF PRESS
- Pallof Wall Iso Holds
- Plank
- Plank Clockface with Bands (warm-up)
- Plank Holds with Elevated Hands
- Plank Jacks
- Plank Reach
- Plank Row with Toe Touch (warm-up)
- Plank Shoulder Taps
- Plank with Alternating Leg Lift
- Plank-to-Elbow Extension
- Reverse Plank
- Reverse Wood Chops
- Reverse crunch
- Roman Chair Crunch
- Rotary Torso Machine
- Rotational Med Ball Slams (warm-up)
- Rotational Plank
- Russian Twist
- Seated Corkscrew
- Seated Knee Tuck
- Side Bends on Machine
- Side Crunch
- Side Dumbbell Trunk Flexion
- Side Plank
- Single Arm MB Holds
- Sit Up Elbow Thrust
- Sit-ups
- Sled Push
- Splinter Sit-ups
- Split Stance Rotational Throws
- Standing Plate Rotations
- Standing Side Crunches
- Step Jack
- Straddle L-Sit
- Straight Arm Straight Leg Sit Ups
- Straight Leg Sit Ups with Med Ball
- Suitcase Carry
- Supine Core Holds with Weight
- Swiss Ball Plank Circles
- TORSO TWIST
- TRX Obliques
- TRX Rollouts
- TRX roll out
- Toe Taps
- Toes to bar
- Trunk Rotation With Cable
- Tuck L-sit
- Turkish Get-Up
- Weighted Crunch
- Weighted Leg Lowers
- Weighted ½ Deadbugs (warm-up)
- Windshield Wipers
- bicycle crunches
- box jumps
- ½ Kneeling Rotational Med Ball Throws

Mapping rules applied:

- Crunch/flexion rows: abs stay primary; obliques assist. Hip flexors are added only when the movement is a sit-up, leg raise, knee raise, or L-sit/lever pattern.
- Leg-raise and hanging-core rows: abs stay primary, hipFlexors are major, and hanging variants add forearms/lats/teres for grip and shoulder depression.
- Plank/anti-extension rows: abs and obliques brace the trunk; lowerBack, glutes, deltoids, serratus, triceps, and quads are included when bodyweight support requires them.
- Rollouts: abs are primary with lats/serratus/deltoids/triceps controlling the shoulder path and lowerBack/obliques resisting extension.
- Rotation, woodchop, Pallof, and side-bend rows: obliques are primary with abs/lowerBack and implement-control muscles graded by movement direction.
- Throws, slams, bag work, ropes, jumps, carries, and Turkish get-ups combine core bracing with reviewed push/pull/squat/carry mechanics.

Severity counts for changed rows in this batch:

- Critical: 0
- Major: 44
- Minor: 58

Rationale for severity: core rows rarely missed the named target, so critical count is zero. Major changes are hybrid or whole-body conditioning rows with substantial missing support muscles. Minor changes are mostly flexion/rotation rows whose primary target was already present and needed stabilizer or hip-flexor adjustment.

## Batch 10: Remaining Leg Isolation, Squat, Jump, Carry, And Thruster Family

Date: 2026-06-27  
Status: complete for the 74 exercises listed in the CSV as `done`.

Reviewed records:

- 1 Leg Box Squat
- Abduction while standing
- Ali Shuffle
- Altitude Landings
- Altitude Landings to Jump
- Banded 1.5 Squats
- Banded Accentuated CMJ
- Banded Side Clams
- Banded Side Walks
- Braced Squat
- CMJ with Hands on Hips
- Calf Press Using Leg Press Machine
- Calf Raise using Hack Squat Machine
- Calf Raises on Hackenschmitt Machine
- Calf raises, one legged
- Copenhagen Adduction Exercise
- Criss Cross Jump
- Double Leg Calf Raise
- Dragon squat
- Dumbbell CMJ (2 kg each hand)
- Dumbbell Thruster
- Dumbbell farmer's carry
- Exercise Band Dorsiflexion
- Exercise Band Plantarflexion
- Falling CMJ
- Fast Pogos
- Fire Hydrants
- Glute Kickback (Machine)
- Hamstring Kicks
- High Knee Skips HD
- Hindu Squats
- Hop + Hold
- Horse Stance (Side Splits)
- Isometric Squat to Failure
- Jumping Jacks
- Kneeling kickbacks
- Leg Curl
- Leg Curls (laying)
- Leg Curls (sitting)
- Leg Curls (standing)
- Leg Extension
- Leg Press Toe Press
- Leg curl with elastic
- Machine Hip Abduction
- Marching High Knees
- Pogos
- Prisoner Squat
- Prisoner Squats with Overhead Reach
- Quadruped Hip Abduction
- Quadruped Hip Extensions
- Seated Dumbbell Calf Raise
- Seated Hip Abduction
- Seated Hip Adduction
- Shrimp Squad
- Side Lying Hip Abduction
- Side Slides + Squats
- Single Leg Clockface
- Single Leg Extension
- Single-leg side glute press
- Sitting Calf Raises
- Slow Hands, Fast Feet
- Slow Squat
- Squat Jumps
- Squat Thrust
- Squats on Multipress
- Standing Adduction (Cable)
- Standing Calf Raises
- Supine Hip Abduction
- Thruster
- Tibialis raises
- Trap Bar Squat
- Wall balls
- Wall-sit
- rubber band glute kickback

Mapping rules applied:

- Residual squat/single-leg squat rows use the reviewed squat and lunge rules, with shins/trunk/balance stabilizers added where appropriate.
- Jump, CMJ, pogo, quick-feet, and landing rows emphasize calves when ankle spring dominates and otherwise combine squat takeoff/landing mechanics with shins and trunk stabilization.
- Hip abduction/adduction rows isolate the app's glutes or adductors bucket, adding only trace trunk/hip-flexor stabilization where needed.
- Leg curls/extensions, calf raises, plantarflexion, and tibialis/dorsiflexion rows remain isolation mappings unless posture adds a small stabilizer.
- Thrusters and wall balls combine reviewed squat and overhead-press mechanics.
- Carries keep forearms/traps primary with trunk and gait stabilizers.

Severity counts for changed rows in this batch:

- Critical: 0
- Major: 34
- Minor: 27

Rationale for severity: critical count is zero because the primary lower-body targets were present. Major rows are residual compound/jump/hybrid patterns with materially missing stabilizers or wrong emphasis. Minor rows are isolation entries with small stabilizer or no-change confirmations.

## Batch 11: Final Back Lever, Scapular Retraction, Superman, And Pullover Family

Date: 2026-06-27  
Status: complete for the final 20 exercises listed in the CSV as `done`.

Reviewed records:

- Back Lever
- Band pull-aparts
- Banded Scapular Retraction
- Butterfly Superman
- Dumbbell Pullover
- Front lever tuck
- Hyper Y W Combo
- Kneeling Superman
- LYING DUMBBELL ROW SS SEATED SHRUG
- PULL OVER POLEA ALTA
- Prone Scapular Retraction - Arms at Side
- Quadriped Arm and Leg Raise
- Reverse Snow Angel
- Scapula Pulls
- Skydiver with arms in T-position
- Straight-arm Pull Down (bar Attachment)
- Straight-arm Pull Down (rope Attachment)
- Superman
- Towel Superman
- YWTs

Mapping rules applied:

- Lever holds combine lats, trunk anti-extension, grip, biceps, teres, serratus, and pectoral shoulder stabilization.
- Pull-aparts and scapular retraction rows keep rhomboids/traps high, with rear delts, teres, and forearms added where missing.
- Superman/YWT/back-extension rows retain lowerBack primary with glutes/hamstrings and upper-back/scapular assistance.
- Pullovers and straight-arm pulldowns use the reviewed lat-pullover mapping.
- The lying row/shrug and scapula-pull rows combine reviewed row, shrug, and scapular-depression rules.

Severity counts for changed rows in this batch:

- Critical: 0
- Major: 5
- Minor: 15

Rationale for severity: critical count is zero because no final row was missing its visible prime mover. Major rows changed lever, scapular-pull, or hybrid emphasis; minor rows mostly added stabilizers or confirmed already-reasonable accessory mappings.

## Running Totals

- Exercises reviewed: 687 / 687
- Exercises changed: 617
- Critical changes: 8
- Major changes: 351
- Minor changes: 258
- Remaining pending: 0
