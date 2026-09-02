# Current work

Goal: remove the strongest Exercise Picker / Library exercise-list duplication
without merging their distinct navigation, row hierarchy, or purpose behavior.

Progress:

- Added `ExerciseCatalogBrowserSnapshot`, shared filter-strip semantics, cached
  history queries, and one persisted favorite/delete/action contract.
- Migrated Library and picker rendering while retaining their separate tap,
  navigation, hierarchy, and empty-state behavior.
- Routine pickers now derive equipment chips from eligible items and expose no
  catalog mutation or custom-exercise CTA.
- Exercise names retain the compact two-line layout at standard sizes and
  expand fully at accessibility Dynamic Type sizes in Library and pickers.
- Focused unit tests, `Scripts/check.sh`, dark Library/picker/routine scenarios,
  context-menu semantics, and light Accessibility Large Type evidence pass.

Next: none; ready for review.

User steering: proceed with the agreed refactor; preserve the two surfaces'
distinct UX and handle the identified routine-picker inconsistencies explicitly.
