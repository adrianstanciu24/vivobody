//
//  LibraryScreen.swift
//  vivobody
//
//  Two-segment browser for everything reusable in the app:
//    • Exercises — the bundled exercise catalog plus user-created entries
//    • Templates — the user's saved workout plans
//
//  Why a segmented control instead of a tab: both surfaces serve
//  the same mental model ("reusable workout content") and live at
//  the same level of importance. Tab-count stays at four (Today /
//  History / Library / Me). Matches Notes / Reminders / Music
//  patterns where collections + items share one tab.
//
//  The create "+" is contextual and lives in the top toolbar:
//    • Templates segment → opens the manual template editor.
//    • Exercises segment → opens CustomExerciseEditorSheet in
//      .create mode → adds a new entry to the catalog.
//
//  Search uses the native .searchable navigation-bar drawer below
//  the Library title. The field stays visible. SwiftUI owns text
//  clearing, focus, and search cancellation. Each segment owns
//  its search results and empty states.
//
//  Both segments speak the same ledger-block language as History:
//  content cards on black, monospaced numerals, orange reserved for
//  live selections and today's schedule, gold for an all-time best.
//  Templates render as a stack of cards — today's plan on the bright
//  surface with an inline Start, each pinned schedule drawn as a
//  mini ember week strip. The Exercises catalog groups by muscle
//  under sentence-case headers ("12 exercises · 5 tracked"), each
//  group's rows inside one shared card with inset hairlines, and
//  splits rows by recency — anything lifted in the last 14 days
//  reads prominent with a larger weight×reps numeral, the rest
//  tighter. An all-time best renders its numeral in gold. The
//  segmented control is a Liquid Glass track with a sliding orange
//  thumb.
//

import SwiftData
import SwiftUI
import UIKit
import VivoKit

struct LibraryScreen: View {
    @Bindable var appState: AppState

    @Environment(\.modelContext) private var modelContext

    /// Count-only mirror of the templates store, used solely to decide
    /// whether the toolbar "+" is redundant. On the empty Templates
    /// screen the centered "Create Template" CTA is the single create
    /// path, so the toolbar "+" is suppressed — two create buttons for
    /// one action read as clutter.
    @Query private var allTemplates: [WorkoutTemplate]

    @State private var segment: LibrarySegment = .exercises
    @State private var searchText: String = ""

    /// Catalog chip selection for the Exercises segment. Lives here
    /// (not in LibraryExercisesContent) because the segment switch
    /// recreates the content views — hoisting it keeps the selected
    /// chip stable across Templates ↔ Exercises round-trips.
    @State private var exerciseFilter: ExerciseCatalogFilter = .all

    /// Template builder sheet target. `.new` for the "+" toolbar /
    /// empty-state CTA; `.edit(template)` when a row is tapped. The
    /// builder owns a value-type draft and only writes through to
    /// SwiftData on Save, so there are no stub rows to clean up.
    @State private var templateEditorTarget: TemplateEditorTarget? = nil

    /// Automatic strength-routine planning stays compiled but hidden from the
    /// product UI. DEBUG verification may open it directly so its behavior and
    /// accessibility remain covered while the feature is not publicly exposed.
    @State private var showsStrengthRoutineBuilder = {
        #if DEBUG
            UITestSupport.opensStrengthRoutineBuilder
        #else
            false
        #endif
    }()

    /// Custom-exercise editor sheet target. `.create` for the "+"
    /// toolbar on the Exercises segment; `.edit(item)` for context
    /// menu Edit on a row.
    @State private var customExerciseTarget: CatalogEditorTarget? = {
        #if DEBUG
            UITestSupport.opensCustomExerciseEditor ? .create : nil
        #else
            nil
        #endif
    }()

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
                    templateEditorTarget: $templateEditorTarget,
                    onCreateTemplate: { presentNewTemplate() }
                )
            case .exercises:
                LibraryExercisesContent(
                    searchText: searchText,
                    segment: $segment,
                    customExerciseTarget: $customExerciseTarget,
                    exerciseFilter: $exerciseFilter
                )
            }
        }
        .screenBackground()
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(searchPrompt)
        )
        // The contextual "+" stays in the top navigation bar.
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
        .background {
            LibraryNavigationLayout()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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
        .sheet(isPresented: $showsStrengthRoutineBuilder) {
            StrengthRoutineBuilderScreen(appState: appState)
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
            presentNewTemplate()
        case .exercises:
            customExerciseTarget = .create
        }
    }

    private func presentNewTemplate() {
        let descriptor = FetchDescriptor<WorkoutTemplate>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        templateEditorTarget = .new(sortOrder: count)
        Haptics.soft()
    }

    private var plusAccessibilityLabel: String {
        switch segment {
        case .templates: "New template"
        case .exercises: "Create custom exercise"
        }
    }

    // MARK: - Search prompt

    /// Search field placeholder switches per segment so the user
    /// knows what's being searched. Subtle but reduces "what does
    /// this search?" friction.
    private var searchPrompt: String {
        switch segment {
        case .templates: "Search templates"
        case .exercises: "Search exercises"
        }
    }
}

// MARK: - Initial native navigation layout

/// On iOS 27, an always-visible search drawer can omit the large-title area
/// from the first navigation-bar layout. Re-entering the tab fixes its height.
/// Refresh that native presentation before first appearance only when UIKit's
/// own size calculation reports a taller bar. UIKit owns all frames and search
/// behavior; subsequent appearances retain the user's scroll position.
private struct LibraryNavigationLayout: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_: Controller, context _: Context) {}

    final class Controller: UIViewController {
        private var hasPreparedBar = false

        override func loadView() {
            view = UIView(frame: .zero)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)

            guard #available(iOS 27.0, *),
                  !hasPreparedBar,
                  let navigationController,
                  !navigationController.isNavigationBarHidden,
                  let item = navigationController.topViewController?.navigationItem,
                  item.largeTitleDisplayMode == .always,
                  !item.hidesSearchBarWhenScrolling,
                  let searchController = item.searchController,
                  !searchController.isActive
            else { return }

            hasPreparedBar = true
            let bar = navigationController.navigationBar
            guard bar.prefersLargeTitles,
                  bar.sizeThatFits(bar.bounds.size).height > bar.bounds.height
            else { return }

            navigationController.setNavigationBarHidden(true, animated: false)
            navigationController.setNavigationBarHidden(false, animated: false)
        }
    }
}

// MARK: - Segment enum

enum LibrarySegment: String, CaseIterable, Identifiable {
    case exercises
    case templates
    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .templates: "Templates"
        case .exercises: "Exercises"
        }
    }
}

#Preview("Exercises") {
    NavigationStack {
        LibraryScreen(appState: AppState())
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
    }
    .preferredColorScheme(.dark)
}
