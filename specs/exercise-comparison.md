# Exercise Comparison

Status: **Implemented.**

A Pro-only side-by-side comparison of two catalog exercises, entered from
the exercise detail screen. It answers the questions a lifter has while
deciding whether a movement deserves a slot:

- How is this different from the exercise I already do?
- Am I adding useful variety or duplicating the same stimulus?
- Why does this count as diagonal instead of vertical?
- Which one is easier to track progressively?

The feature is built entirely from authored catalog data — muscle roles,
classification, modality/tracking/load semantics, and execution
instructions — so it works on day one with zero logged history and never
touches session analytics. It lives in Library (catalog exploration), not
Insights (personal history analytics): the architectural split recorded in
ARCHITECTURE.md is preserved, and `ExerciseComparison` is a pure domain
model under `Models/Domain/`, not an insight.

## Placement and flow

1. `ExerciseDetailScreen` gains a "Compare with another exercise" row beside
   the how-to-perform drill-out, plus a toolbar-menu twin for parity with
   the other row actions.
2. Free users are attempt-gated at that entry into the screen's local
   paywall sheet (the template-creation pattern). Pro users get
   `ExercisePickerSheet` retitled "Compare With" in direct-pick mode, with
   the anchor exercise excluded from every list and the same catalog filter
   set as Library Exercises, including Core when an eligible core exercise
   exists.
   The active-workout add picker uses a separate purpose that hides both
   comparison entries, preserving the no-premium-interruption workout rule.
3. The pick chains through the sheet's `onDismiss` into
   `ExerciseComparisonScreen`, presented as a sheet with its own
   `NavigationStack` so it works from every detail-screen host (picker,
   Library, Spotlight) without value-based navigation over `@Model`
   objects, which the codebase deliberately avoids.

## Interaction and visual hierarchy

The screen behaves as an instrument, not a long report:

- **Persistent control deck** — the two exercise names and a three-mode
  selector stay pinned below the navigation bar. Letters and names carry
  identity; orange and blue only reinforce it. Switching modes returns the
  focused panel to its top.
- **Muscles** — the default mode first shows whether each exercise is eligible
  for hard-set training volume, then renders every relevant muscle as a bold
  mirrored beam. Exercise A pulls left and B pulls right on one fixed role
  scale; full, partial, and absent credit are visible without reading a table.
  The **Volume / All roles** control switches the same beams between effective
  hard-set credit and authored anatomical involvement, including stabilizers
  and non-volume modalities. It uses the exact `SetStimulus` gate:
  dynamic-strength reps and isometric-strength holds qualify; power,
  and mismatched tracking do not.
- **Anatomy** — remains inside Muscles, after the comparison beams. One
  selected exercise is shown at a time, switchable between A and B, and it
  offers its own Volume / All roles scope so changing the figure never moves
  the comparison beams or their controls. Separate maps prevent a stronger
  role or tint from hiding the other exercise. Unvisualized muscles remain
  explicit text and never borrow a substitute mesh.
- **Movement** — two large direction dials lead, followed by a compact
  head-to-head board for training role, mechanic, planes, laterality, and
  equipment. The longer direction-versus-plane explanation is collapsed
  behind “Why this direction?” until requested.
- **Tracking** — two large record-format dials lead, followed by a compact
  board for modality, measurement, and load semantics. A progression note is
  collapsed behind “How tracking differs” and the panel never selects a
  winner.
- **How to perform** — lives at the bottom of Movement as two large,
  A/B-attributed drill-outs. Starting position, support, posture, movement,
  and compensations remain in each exercise's existing instruction screen;
  comparison does not repeat them as another prose section.

## Color

`MuscleMapChannels` gains a `tint` dimension (`MuscleMapTint`): `.accent`
(the default, preserving every existing map) and `.compare` (cool steel blue,
opposite the accent on the dark stage). Both ramps run through the same OKLab
interpolation and per-theme endpoint discipline as the established development
ramp; default-tinted channels resolve to byte-identical colors. The comparison
UI never relies on these tints without an A/B or role label. Small A/B text and
selected controls use a separate `ExerciseComparisonPalette` whose light/dark
label pairings clear WCAG AA and whose selected-control pairings clear 7:1;
mesh-oriented colors are never reused as text colors.

## Gating

Pro, at the entry point, per `free-with-pro-iap.md`'s split: raw catalog
facts stay free on the detail screen; the synthesized "what it means for
your choices" layer is Pro. The paywall feature list names the feature.
The comparison screen itself carries no gate UI because the picker is the
only path to it.

## Edge cases

- Custom exercises compare fully: classification, load semantics, and any
  authored instructions/roles; without authored anatomy they contribute no
  figure muscles, and without instructions the how-to drill-out hides for
  that side.
- Isolation exercises say that a compound movement pattern is not applicable;
  missing authored catalog facts say "Not authored" instead of presenting an
  ambiguous dash or inventing a classification.
- An exercise can never be compared with itself (picker exclusion).
- Comparing an exercise to a structurally identical one is allowed and
  reads honestly: no role changes, shared rows everywhere.
- Mixed-history states are irrelevant: the screen reads no session data.

## Accessibility

- The pinned key exposes one full "Comparing <A> with <B>" label while its
  visible A/B marks remain on-screen. The mode selector exposes selected
  state. Every fact lane and muscle beam composes a VoiceOver label with both
  full exercise names, values, roles, and effective volume status.
- Anatomy exercise and scope controls expose selected state, and the figure
  names the selected exercise and scope. Role intensity is explained in
  text, so color and tint strength never carry meaning alone.
- Harness identifiers: `exercise-compare`, `comparison-done`, mode controls
  `comparison-panel-muscles` / `comparison-panel-movement` /
  `comparison-panel-tracking`, section IDs `comparison-stimulus` /
  `comparison-movement` / `comparison-tracking` / `comparison-anatomy` /
  `comparison-muscles`, disclosures `comparison-direction-explanation` /
  `comparison-tracking-explanation`, muscle-scope controls
  `comparison-muscle-scope-volume` / `comparison-muscle-scope-all`, and
  anatomy controls
  `comparison-anatomy-side-a` /
  `comparison-anatomy-side-b` / `comparison-anatomy-scope-volume` /
  `comparison-anatomy-scope-all`.

## Testing

- `vivobodyTests/ExerciseComparisonTests.swift`: the exact hard-set gate,
  power and mismatched-tracking exclusions, overlap/emphasis,
  separate anatomy scopes, authored direction, delta classification,
  movement/tracking facts, progression notes, and tint-ramp regressions.
- Semantic scenarios: `exercise-comparison` (Pro flow through the picker
  into the comparison sheet), `exercise-comparison-locked` (free flow opens
  the paywall; no picker, no comparison), and
  `exercise-comparison-active-workout-hidden` (the live-session add flow has
  no comparison or comparison paywall entry).
  `exercise-comparison-picker-filters` and its light/Accessibility variants
  verify the Compare With picker keeps Library Exercises' All, Favorites,
  Push, Pull, and Core shortcuts without compromising the filter-strip layout.

## Files

| File | Change |
|---|---|
| `specs/exercise-comparison.md` | This doc |
| `vivobody/Models/Domain/ExerciseComparison.swift` | New — pure comparison model |
| `vivobody/Models/Domain/ExerciseComparisonPalette.swift` | Contrast-safe A/B label and selected-control colors |
| `vivobody/Models/Domain/MuscleColor.swift` | `MuscleMapTint` + a `.compare` ramp for Exercise B |
| `vivobody/Screens/Library/ExerciseComparisonScreen.swift` | New — comparison sheet and the detail-screen entry row |
| `vivobody/Screens/Library/ExerciseComparisonMusclePanel.swift` | Mirrored muscle beams and scoped anatomy instrument |
| `vivobody/Screens/Library/ExerciseComparisonSections.swift` | Movement, tracking, and technique instruments |
| `vivobody/Screens/Library/ExerciseDetailScreen.swift` | Compare entry (row + menu), picker sheet, chained comparison sheet, Pro gate |
| `vivobody/Screens/Library/ExercisePickerPurpose.swift` | Typed caller contract, including active-workout suppression and comparison behavior |
| `vivobody/Screens/Library/ExercisePickerSheet.swift` | Typed `ExercisePickerPurpose.compare(anchorID:anchorName:)`, anchor exclusion, compare affordance and hint |
| `vivobody/Store/PaywallSheet.swift` | Feature list names exercise comparison |
| `vivobodyTests/ExerciseComparisonTests.swift` | New |
| `Scripts/verify_scenarios/exercise-comparison*.json` | Pro and locked semantic scenarios |

## Out of scope

- Three-way comparison. The current A/B identity, fact rows, and selectable
  anatomy are deliberately pairwise; a third side needs its own readable
  interaction design before it ships.
- History-derived rows (your PRs side by side, per-exercise volume). Those
  read `SessionAnalytics` and can layer onto the tracking card later
  without moving the screen.
- Mid-workout comparison during exercise swap. The active-workout surface
  stays glanceable per `workout-app-principles.md`; a stripped swap-time
  diff hint would be its own design.
- Comparative verdicts or scores. The screen states differences and lets
  the lifter decide.
