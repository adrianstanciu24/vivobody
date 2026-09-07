# Anterior shin catalog coverage

Status: **Active for dorsiflexion and selected tibialis-anterior stabilizers;
resisted all-toe extension remains blocked by fixture evidence.**

## Active decisions

The owner approved this scope on 2026-09-07 after independent biomechanics,
family-boundary, and anatomy/product reviews. The canonical sources are
[ankle dorsiflexion](../families/ankle-dorsiflexion.json),
[bilateral squat](../families/bilateral-squat.json),
[stationary split squat](../families/split-stance-squat.json), and
[ankle plantarflexion](../families/ankle-plantarflexion.json),
[conventional deadlift](../families/conventional-deadlift.json), and
[dynamic lunge](../families/dynamic-lunge.json).

- Seated Band Ankle Dorsiflexion retains its unilateral seated board/band/stop
  fixture and tibialis anterior primary role; `toeExtensors` is secondary.
- Wall-Supported Tibialis Raise is a distinct bilateral fixture in the same
  dorsiflexion family: back against the wall, knees extended, feet ahead of the
  torso, both heels grounded throughout, forefeet lift toward the shins and
  return to the floor. The approved fixture supplies geometry; muscle roles
  are anatomical/mechanical inferences, not measured wall-raise recruitment.
  It credits tibialis anterior primary and `toeExtensors` secondary. Tracking
  is reps with non-comparable resistance and no invented bodyweight fraction.
- Tibialis anterior receives stabilizer credit on the five free bilateral
  squats, all four stationary/rear-foot-elevated split squats, and the
  Wall-Balanced Single-Leg Bodyweight Heel Raise. Their original geometry,
  resistance, primary muscles, and secondary muscles remain unchanged.
- The approved follow-up also credits tibialis anterior as a stabilizer on
  Conventional Barbell Deadlift and all four discrete dynamic lunges:
  bodyweight and paired-dumbbell forward/reverse step-and-return records.
  Hanen measured TA during conventional pulls; Gao measured it in the exact
  paired-dumbbell reverse fixture. The other lunge roles transfer ankle-control
  participation from those observations, Wu's lunge measurements, and existing
  anatomical capabilities. Original sources continue to own every fixture
  detail; there is no claim of equal recruitment or exact measurement across
  all variations.
- Smith and machine calf records receive no new roles. Walking/lateral lunges,
  step-ups, Romanian, single-leg, and other deadlift families are outside this
  follow-up. EDL/EHL remain unassigned to these compound movements.

The old dorsiflexion restriction, which excluded toe extensors solely because
Kjeldsen's study did not measure them, is superseded. The current
[proportional evidence policy](../README.md#proportional-evidence-policy)
permits explicit anatomy-and-mechanics inferences for ordinary categorical
roles. Ankle dorsiflexion is already an authored capability of the grouped
long toe extensors. No anatomical capability, taxonomy, schema, or runtime
credit-policy change is required.

Band and wall variants have separate rules that pin posture, support,
laterality, load interface, and endpoint. The heel-supported wall pivot is
explicitly distinguished from the band's open-chain foot motion. Deliberate
toe extension, ankle inversion/eversion, and calf raises remain outside this
family. Machine omissions are pinned by the selected exercise roster; the
schema has no conditional prohibition of a muscle assignment.

## Evidence ledger

Web research and independent source review: 2026-09-07.

| Source | Supports | Limit |
|---|---|---|
| [Ruiz-Muñoz et al., 2017](https://doi.org/10.1016/j.foot.2016.11.001) | TA, EDL, and EHL activity in resisted isometric ankle dorsiflexion | Dynamic band/wall roles are categorical transfers, not directly measured training stimulus. |
| [DeForest et al., 2014](https://doi.org/10.70252/MXVZ7653) | TA activity in back, stationary split, and rear-leg-elevated split squats | Study stance, depth, support height, and loading do not exactly match every catalog fixture. |
| [Wu et al., 2020](https://doi.org/10.1123/jsr.2018-0182) | TA activity across unloaded and free-loaded squat/lunge conditions | Accessible abstract does not establish exact squat grip or lunge stepping geometry, or relative stimulus. |
| [Hanen et al., 2025](https://doi.org/10.3389/fbioe.2025.1597209) | TA activity in conventional and sumo deadlifts | Conventional role transfers to the current Lee fixture; barefoot, maximal-speed, and dead-stop details are not imported. |
| [Gao et al., 2025](https://doi.org/10.5334/paah.489) | TA activity in the current paired-dumbbell reverse lunge | Bodyweight and forward role assignments are categorical transfers, not identical measured activation. |
| [Sara et al., 2021](https://doi.org/10.1371/journal.pone.0253276) | TA activity during fingertip-balanced single-leg heel raises | The catalog's wall contact and minimum-height endpoint retain the existing Manago source; no machine transfer. |
| [Arnold et al., 2010](https://doi.org/10.1007/s10439-009-9852-5) | Existing ankle-action and stabilization capabilities | A musculoskeletal model supports possible actions, not measured exercise roles. |

No EMG amplitude is converted into force, hypertrophy, or universal muscle
percentages. TA is not promoted to primary/secondary on plantarflexion-dominant
squats or heel raises simply because it is active.

## Blocked candidate: resisted all-toe extension

Candidate: seated, supported foot, ankle held, resistance applied to all five
toes as they extend. Intended role: grouped `toeExtensors` primary. This would
need a separate toe-extension family because deliberate `foot.toeExtension`
is forbidden in ankle dorsiflexion. Great-toe-only or lesser-toe-only variants
would falsely color both current meshes and are not admitted.

[Leitch and Macefield, 2015](https://doi.org/10.1152/jn.00121.2015) supports EHL
and EDL toe-extension actions, but used electrical single-motor-unit stimulation
and small transducer loads. It does not establish a voluntary band exercise.
The [McGraw Hill toe-extension demonstration](https://accessphysiotherapy.mhmedical.com/MultimediaPlayer.aspx?MultimediaID=20666973)
was inaccessible during review. Neither source was added to the active
evidence registry because no active fixture references it.

**Unlock:** inspect an authoritative demonstration, or obtain an owner-defined
fixture, establishing simultaneous all-five-toe contact, band anchor and
resistance direction, forefoot/heel support, and a held ankle. Review that
exact geometry before admitting the family. Do not substitute an unresisted
toe lift or a proprietary apparatus without explicitly reviewing that fixture.

## Product and verification boundary

EDL and EHL remain one `toeExtensors` region with two existing mesh owners.
Both meshes receive the same role. Existing logged workouts and templates
retain stored muscle snapshots; catalog updates do not backfill history.
Current effort-weighted credit remains primary 1.0, secondary 0.5, stabilizer
0.1, distinct from anatomy display intensity.

The compiler generates the bundled resource from the reviewed family sources.
Baguette Library/detail captures verified wall-raise discovery and primary/secondary
labels in dark, light, and Accessibility Large states; the band exercise showed
both roles, and Barbell Back Squat showed tibialis anterior as a stabilizer.
Follow-up captures verified the conventional deadlift in dark appearance and
two-dumbbell reverse lunge in light appearance, including its complete
stabilizer list at Accessibility Large. All three follow-up accessibility
trees confirmed the tibialis anterior stabilizer label.
Screenshots and accessibility trees were inspected. The initial Library
readiness selector timed out; direct Baguette captures and role assertions
succeeded on the same runtime. Catalog mutation/roster tests were updated but
not executed. Broad catalog tests, full builds, and device-only accessibility
validation remain user-run under the current agent verification policy.
