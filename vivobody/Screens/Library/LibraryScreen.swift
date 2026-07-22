//
//  LibraryScreen.swift
//  vivobody
//
//  Two-segment browser for everything reusable in the app:
//    • Templates — the user's saved workout plans
//    • Exercises — the full exercise catalog (90 stock + customs)
//
//  Why a segmented control instead of a tab: both surfaces serve
//  the same mental model ("reusable workout content") and live at
//  the same level of importance. Tab-count stays at four (Today /
//  History / Library / Me). Matches Notes / Reminders / Music
//  patterns where collections + items share one tab.
//
//  The create "+" is contextual and lives in the bottom toolbar:
//    • Templates segment → opens the template builder → creates a
//      blank template; user enters its detail to add exercises.
//    • Exercises segment → opens CustomExerciseEditorSheet in
//      .create mode → adds a new entry to the catalog.
//
//  Search uses the native .searchable modifier with .toolbar
//  placement and .searchToolbarBehavior(.minimize) — the search
//  field lives in the bottom toolbar and collapses to a compact
//  button on scroll-down, expanding on tap. This replaces the
//  previous custom pill, eliminating a redundant chrome layer so
//  search, MiniBar, and tab bar share one unified Liquid Glass
//  surface. The system also provides the "no results" state
//  automatically.
//
//  Both segments speak the same instrument language as the rest of
//  the app: no cards or carved glass — full-width hairline rows on
//  black, monospaced numerals, two accents (lime for the live
//  selection, gold for an all-time best). The segmented control is a
//  pair of words with a sliding lime underline; the Exercises catalog
//  groups by muscle under sentence-case headers ("12 exercises · 5
//  tracked") and splits rows by recency — anything lifted in the last
//  14 days reads prominent with a larger weight×reps numeral, the
//  rest tighter. An all-time best renders its numeral in gold.
//

import VivoKit
import SwiftUI
import SwiftData

struct LibraryScreen: View {
    @Bindable var appState: AppState

    @Environment(\.modelContext) private var modelContext

    /// Count-only mirror of the templates store, used solely to decide
    /// whether the toolbar "+" is redundant. On the empty Templates
    /// screen the centered "Create Template" CTA is the single create
    /// path, so the toolbar "+" is suppressed — two create buttons for
    /// one action read as clutter.
    @Query private var allTemplates: [WorkoutTemplate]

    @State private var segment: LibrarySegment = .templates
    @State private var searchText: String = ""

    /// Equipment chip selection for the Exercises segment. Lives here
    /// (not in LibraryExercisesContent) because the segment switch
    /// recreates the content views — hoisting it keeps the selected
    /// chip stable across Templates ↔ Exercises round-trips.
    @State private var equipmentFilter: Equipment? = nil

    /// Template builder sheet target. `.new` for the "+" toolbar /
    /// empty-state CTA; `.edit(template)` when a row is tapped. The
    /// builder owns a value-type draft and only writes through to
    /// SwiftData on Save, so there are no stub rows to clean up.
    @State private var templateEditorTarget: TemplateEditorTarget? = nil

    /// Custom-exercise editor sheet target. `.create` for the "+"
    /// toolbar on the Exercises segment; `.edit(item)` for context
    /// menu Edit on a row.
    @State private var customExerciseTarget: CatalogEditorTarget? = nil

    var body: some View {
        // Each content view owns its own SwiftData query + filter
        // state and hosts the segmented control as the FIRST element
        // inside its own scroll view. That keeps the scroll view the
        // direct content under the navigation bar, so the large
        // "Library" title collapses correctly on scroll and the
        // segment scrolls away with the content instead of staying
        // pinned and colliding with the title.
        Group {
            switch segment {
            case .templates:
                LibraryTemplatesContent(
                    appState: appState,
                    searchText: searchText,
                    segment: $segment,
                    templateEditorTarget: $templateEditorTarget
                )
            case .exercises:
                LibraryExercisesContent(
                    searchText: searchText,
                    segment: $segment,
                    customExerciseTarget: $customExerciseTarget,
                    equipmentFilter: $equipmentFilter
                )
            }
        }
        .forgeBackground()
        // Native search in the bottom toolbar with minimize-on-scroll:
        // the field collapses to a compact button when inactive and
        // scrolling, expanding on tap — the same behavior the custom
        // pill had, but now sharing the tab bar's Liquid Glass surface
        // instead of stacking an extra safeAreaInset layer.
        .searchable(text: $searchText, placement: .toolbar, prompt: Text(searchPrompt))
        .searchToolbarBehavior(.minimize)
        // The contextual "+" lives in the top navigation bar so it's
        // always visible, independent of the search field's minimize
        // state in the bottom toolbar.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !suppressesPlus {
                    Button(action: handlePlus) {
                        Image(systemName: "plus")
                            .font(Typography.headline)
                            .foregroundStyle(Tint.primary)
                    }
                    .accessibilityLabel(plusAccessibilityLabel)
                }
            }
        }
        // Switching segments swaps in a fresh scroll view at the top,
        // so the search prompt should update to reflect the new scope.
        // Create + edit both run through the same modal builder: a
        // name field, a configured-exercise list, and an "Add
        // exercise" flow that picks from the catalog then drops into
        // a configure sheet. Nothing persists until Save.
        .sheet(item: $templateEditorTarget) { target in
            TemplateEditorScreen(target: target)
        }
        .sheet(item: $customExerciseTarget) { target in
            CustomExerciseEditorSheet(target: target)
        }
    }

    // MARK: - Create action

    /// Hide the create "+" only on the empty Templates screen, where
    /// the centered CTA already owns the create action.
    private var suppressesPlus: Bool {
        segment == .templates && allTemplates.isEmpty
    }

    private func handlePlus() {
        switch segment {
        case .templates:
            let descriptor = FetchDescriptor<WorkoutTemplate>()
            let count = (try? modelContext.fetchCount(descriptor)) ?? 0
            // The free tier includes ProGate.freeTemplateLimit
            // templates; creating the next one presents the paywall
            // instead of the editor. Existing templates always stay
            // editable, startable, and deletable — only creation gates.
            guard ProGate.canCreateTemplate(existingCount: count, status: appState.pro.status) else {
                appState.pro.requestUnlock(context: .templateLimit)
                return
            }
            templateEditorTarget = .new(sortOrder: count)
            Haptics.soft()
        case .exercises:
            customExerciseTarget = .create
        }
    }

    private var plusAccessibilityLabel: String {
        switch segment {
        case .templates: return "New template"
        case .exercises: return "Create custom exercise"
        }
    }

    // MARK: - Search prompt

    /// Search field placeholder switches per segment so the user
    /// knows what's being searched. Subtle but reduces "what does
    /// this search?" friction.
    private var searchPrompt: String {
        switch segment {
        case .templates: return "Search templates"
        case .exercises: return "Search exercises"
        }
    }

}

// MARK: - Segment enum

enum LibrarySegment: String, CaseIterable, Identifiable {
    case templates
    case exercises
    var id: String { rawValue }
    var label: String {
        switch self {
        case .templates: return "Templates"
        case .exercises: return "Exercises"
        }
    }
}

#Preview("Templates") {
    NavigationStack {
        LibraryScreen(appState: AppState())
            .navigationTitle("Library")
    }
    .preferredColorScheme(.dark)
}
