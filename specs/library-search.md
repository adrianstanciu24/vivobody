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
