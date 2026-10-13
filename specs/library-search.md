# Library search

Status: Active product contract. Source-audit date: [spec index](index.md).

Library opens with a large navigation title on the first visit. The native
title collapses as the content scrolls. Library uses SwiftUI's native search
field below the title. The empty field is visible when browsing Exercises or
Templates. Its prompt names the selected segment. Search text filters that
segment as the user types.

- The small clear button clears the text and keeps search active.
- The native Close action clears the text, ends search, and dismisses the
  keyboard with one tap. The empty search field remains visible.
- Clearing or closing search restores the current segment's unsearched
  content. The selected exercise category filter remains selected.
- Search remains a native `searchable` control. SwiftUI owns clearing, focus,
  and cancellation; Library does not supply custom close buttons or reset logic.

## Matching

Library and the exercise pickers share one ranker,
[ExerciseSearch](../vivobody/Models/Domain/ExerciseSearch.swift). Every query
word must match the exercise name or an alias. Word order does not change a
match.

- When no exercise matches every word of a query of two or more words, the
  results are the closest matches: exercises that miss one word. An exercise
  that misses a common word ranks above one that misses a rare word, so
  "split leg squat" finds split squats before single-leg squats. The results
  start with "No exact matches. Showing closest results." An exercise never
  misses two words.

- Case, accents, hyphens, and spaces do not change a match. "single leg",
  "single-leg", and "singleleg" find the same exercises.
- Plural and singular forms match, for example "squats" and "squat".
- The [search vocabulary](../vivobody/Models/Domain/ExerciseSearchVocabulary.swift)
  holds phrases that apply to many exercises, such as "single leg" = "one leg"
  = "SL" and "DB" = "dumbbell". A query with one phrase also searches for the
  others. A match through a synonym ranks just below a literal match. Broad
  terms are one-way: "unilateral" finds single-leg and single-arm exercises,
  but "single leg" does not find single-arm exercises. A name for one exercise
  belongs in its catalog aliases, not in this vocabulary.
- An exact name or alias ranks first.
- Typo correction applies only to a word that no catalog word or synonym
  contains. It replaces the word with the closest catalog word: one edit for
  words of 4 to 7 letters, and two edits for 8 letters or more. A swap of two
  adjacent letters is one edit. Words of three letters or fewer, and words
  with digits, stay as typed. When a correction changes the query, the results
  start with "Results for" and the corrected query, or with "Closest results
  for" when the results are also closest matches. A correction never changes
  the results silently.

The selected filter limits the results. When the filter hides every match, a
card below the filters names the filter. Its one button shows the number of
matches in All and selects All. The card stays above the keyboard at large
text sizes.

The title mode is set by [AppRoot](../vivobody/App/AppRoot.swift). Search is in
[LibraryScreen](../vivobody/Screens/Library/LibraryScreen.swift). Exercise
filtering is owned by
[ExerciseCatalogBrowser](../vivobody/Screens/Library/ExerciseCatalogBrowser.swift),
and template filtering is owned by
[LibraryTemplatesContent](../vivobody/Screens/Library/LibraryTemplatesContent.swift).

On iOS 27, the first native bar layout can omit the large-title area even when
large-title mode is enabled and the content is at the top. The private
`LibraryNavigationLayout` adapter refreshes the native navigation controller
before first appearance if UIKit calculates a taller bar than the current bar.
This is a layout workaround. It does not manage search text, focus, or
cancellation. UIKit owns the bar's frames. Later appearances preserve scrolling.

The first-visit captures are
[dark](../Scripts/verify_scenarios/library-first-visit-dark.json) and
[light with large text](../Scripts/verify_scenarios/library-first-visit-accessibility-light.json).
Inspect their screenshots to verify the title size. Accessibility heading
semantics alone do not distinguish a large title from a small title.

The search checks are
[dark cancellation](../Scripts/verify_scenarios/library-search-cancellation-dark.json)
and [light cancellation with large text](../Scripts/verify_scenarios/library-search-cancellation-accessibility-light.json).
