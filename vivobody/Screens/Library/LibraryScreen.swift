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
//  The create "+" is contextual and lives beside the search pill at
//  the bottom (not the nav bar):
//    • Templates segment → opens the template builder → creates a
//      blank template; user enters its detail to add exercises.
//    • Exercises segment → opens CustomExerciseEditorSheet in
//      .create mode → adds a new entry to the catalog.
//
//  Search is a floating Liquid-Glass pill pinned just above the tab
//  bar (the same safeAreaInset treatment Today gives its Start
//  button) — always reachable, never a top drawer that collapses the
//  large title. It filters whichever segment is active: templates
//  match by name; exercises match by name or alias. The contextual
//  "+" rides beside it as its own glass capsule (two separated
//  capsules, echoing the iOS 26 Mail bottom bar). The pill also
//  minimizes on scroll the same way the tab bar does — collapsing to
//  a small left glass circle on scroll-down and snapping back to full
//  width only once the scroll reaches the top, or on tap (which also
//  focuses it).
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

    /// Drives focus for the pinned search pill so submitting the
    /// query (or tapping Clear) can dismiss the keyboard.
    @FocusState private var searchFocused: Bool

    /// When true the search pill collapses to a small left capsule —
    /// the same minimize-on-scroll-down gesture the iOS 26 tab bar
    /// uses. Driven by each segment's scroll position; reset to false
    /// (full width) at the top, on tap, and on segment change.
    @State private var searchMinimized: Bool = false

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
                    templateEditorTarget: $templateEditorTarget,
                    searchMinimized: $searchMinimized,
                    canMinimize: canMinimizeSearch
                )
            case .exercises:
                LibraryExercisesContent(
                    searchText: searchText,
                    segment: $segment,
                    customExerciseTarget: $customExerciseTarget,
                    searchMinimized: $searchMinimized,
                    canMinimize: canMinimizeSearch
                )
            }
        }
        .forgeBackground()
        // Switching segments swaps in a fresh scroll view at the top,
        // so the pill should read as expanded again.
        .onChange(of: segment) { _, _ in
            guard searchMinimized else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                searchMinimized = false
            }
        }
        // Search + create are pinned to the bottom as floating glass —
        // always reachable, mirroring Today's pinned Start button —
        // rather than a top nav-bar drawer that collapses the title.
        // The "+" rides beside the pill instead of the nav bar so both
        // primary affordances live in one thumb-reachable cluster.
        .safeAreaInset(edge: .bottom, spacing: 0) { pinnedSearchBar }
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

    /// Scroll only minimizes the pill when the user isn't actively
    /// searching — keep it expanded (and the query visible) while the
    /// field is focused or holds text.
    private var canMinimizeSearch: Bool {
        !searchFocused && searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Tapping the collapsed pill restores full width and drops the
    /// keyboard in, so one tap goes straight to typing — matching the
    /// tab bar's tap-to-expand feel.
    private func expandSearch() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            searchMinimized = false
        }
        DispatchQueue.main.async { searchFocused = true }
    }

    // MARK: - Pinned search

    /// The floating bottom cluster pinned just above the tab bar via
    /// `safeAreaInset` — the same treatment Today gives its Start
    /// button, so both search and create are always reachable without
    /// a top drawer collapsing the large title. The search field
    /// stretches to fill; the contextual "+" rides beside it as its
    /// own glass capsule (two separated capsules, à la the iOS 26
    /// Mail bottom bar) and hides on the empty Templates screen where
    /// the centered CTA already owns creation.
    private var pinnedSearchBar: some View {
        HStack(spacing: Space.sm) {
            searchField
            // Collapsed, the field shrinks to a left circle; this
            // spacer fills the gap so the "+" stays pinned right
            // (expanded, the field already fills the width).
            if searchMinimized {
                Spacer(minLength: 0)
            }
            if !suppressesPlus {
                createButton
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .softElevation(radius: 16, y: 8, opacity: 0.4)
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.sm)
        .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: suppressesPlus)
    }

    /// The search capsule. Expanded it stretches to fill — leading
    /// glyph, the live-filtering field bound to `searchText`, and a
    /// trailing clear button. Collapsed (minimize-on-scroll) it
    /// shrinks to a 50pt glass circle showing just the glyph, with a
    /// transparent overlay button that taps back to full width.
    private var searchField: some View {
        HStack(spacing: searchMinimized ? 0 : Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: searchMinimized ? 18 : 16, weight: .semibold))
                .foregroundStyle(searchMinimized ? Ink.secondary : Ink.tertiary)
                .frame(maxWidth: searchMinimized ? .infinity : nil)

            if !searchMinimized {
                TextField(searchPrompt, text: $searchText)
                    .font(Typography.body)
                    .foregroundStyle(Ink.primary)
                    .tint(Tint.primary)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { searchFocused = false }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Haptics.selection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Ink.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, searchMinimized ? 0 : Space.lg)
        .frame(maxWidth: searchMinimized ? 50 : .infinity)
        .frame(height: 50)
        .glassPill()
        .overlay {
            // Only intercept taps when collapsed — expanded, the
            // TextField itself owns the tap to focus.
            if searchMinimized {
                Button(action: expandSearch) {
                    Color.clear.contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Expand search")
            }
        }
    }

    /// The contextual create button, relocated from the nav bar to
    /// sit beside the search pill. A 50pt glass circle with the
    /// electric-orange "+"; its action + label switch per segment.
    private var createButton: some View {
        Button(action: handlePlus) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Tint.primary)
                .frame(width: 50, height: 50)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassPill()
        .accessibilityLabel(plusAccessibilityLabel)
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

// MARK: - Segmented control

/// A full-width frosted-capsule segmented control. A subtle glass
/// track holds both labels; the active segment rides a solid-orange
/// pill that slides between them via `matchedGeometryEffect`. Selected
/// text is black for maximum contrast on the accent, the inactive
/// label stays dim white on the track, and selection fires the same
/// `Haptics.selection()` tick as the equipment chips below — whose
/// orange-fill / stroked-capsule language this control deliberately
/// echoes so the screen reads as one system.
private struct SegmentedControl: View {
    @Binding var selection: LibrarySegment
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LibrarySegment.allCases) { segment in
                segmentButton(segment)
            }
        }
        .padding(4)
        .background(Capsule().fill(Surface.cardTint))
        .overlay(Capsule().strokeBorder(Surface.edge, lineWidth: 0.5))
    }

    private func segmentButton(_ segment: LibrarySegment) -> some View {
        let isSelected = selection == segment
        return Button {
            guard selection != segment else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selection = segment
            }
            Haptics.selection()
        } label: {
            Text(segment.label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Tint.inProgress)
                            .matchedGeometryEffect(id: "thumb", in: thumb)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(segment.label)
    }
}

// MARK: - Segment bar

/// The segmented control wrapped with the screen's standard header
/// padding. Hosted as the first element inside each segment's scroll
/// view so it scrolls away with the content (and lets the large
/// navigation title collapse normally) rather than staying pinned.
private struct LibrarySegmentBar: View {
    @Binding var selection: LibrarySegment

    var body: some View {
        SegmentedControl(selection: $selection)
            .accessibilityLabel("Library segment")
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.lg)
    }
}

// MARK: - Templates content

/// Templates segment — list of saved workout plans. Tap a row to
/// edit it in the modal builder; swipe-right (or long-press) to
/// start a workout from it; swipe-left to delete. Empty state offers
/// an inline create button. Inherits search text from the parent and
/// filters by name.
private struct LibraryTemplatesContent: View {
    @Bindable var appState: AppState
    let searchText: String
    @Binding var segment: LibrarySegment
    @Binding var templateEditorTarget: TemplateEditorTarget?
    @Binding var searchMinimized: Bool
    let canMinimize: Bool

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutTemplate.sortOrder)])
    private var templates: [WorkoutTemplate]

    @State private var deletingTemplate: WorkoutTemplate? = nil

    private var filtered: [WorkoutTemplate] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return templates }
        return templates.filter { $0.name.lowercased().contains(trimmed) }
    }

    var body: some View {
        Group {
            if templates.isEmpty {
                VStack(spacing: 0) {
                    LibrarySegmentBar(selection: $segment)
                    emptyState
                }
            } else if filtered.isEmpty {
                VStack(spacing: 0) {
                    LibrarySegmentBar(selection: $segment)
                    noMatchesState
                }
            } else {
                list
            }
        }
        .alert(
            "Delete this template?",
            isPresented: deleteAlertBinding,
            presenting: deletingTemplate
        ) { template in
            Button("Delete", role: .destructive) {
                deleteTemplate(template)
            }
            Button("Cancel", role: .cancel) { }
        } message: { template in
            Text("\(template.name) · \(template.orderedExercises.count) exercises. This can't be undone.")
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            // First scrolling row — the segment moves up with the
            // content on scroll, so the large title collapses cleanly.
            SegmentedControl(selection: $segment)
                .accessibilityLabel("Library segment")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Space.sm, leading: Space.gutter, bottom: Space.lg, trailing: Space.gutter))

            ForEach(filtered) { template in
                Button {
                    templateEditorTarget = .edit(template)
                } label: {
                    TemplateCard(template: template)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Surface.edge)
                .listRowInsets(EdgeInsets(top: 0, leading: Space.gutter, bottom: 0, trailing: Space.gutter))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        startWorkout(from: template)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .tint(Tint.inProgress)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deletingTemplate = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    // Force red: the app's global lime .tint would
                    // otherwise override the destructive role's color.
                    .tint(.red)
                }
                .contextMenu {
                    Button {
                        startWorkout(from: template)
                    } label: {
                        Label("Start workout", systemImage: "play.fill")
                    }
                    Button {
                        templateEditorTarget = .edit(template)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deletingTemplate = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .minimizesSearchOnScroll(isMinimized: $searchMinimized, enabled: canMinimize)
    }

    // MARK: - Empty states

    /// Type-forward empty state — a quiet heading, one line of
    /// guidance, and the single lime action. No ghost, no card.
    private var emptyState: some View {
        VStack(spacing: Space.xl) {
            Spacer()

            VStack(spacing: Space.sm) {
                Text("No templates yet")
                    .sectionHeadingStyle()

                Text("Build a reusable workout — pick exercises, set target reps and weight. Start any time from here.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Button {
                templateEditorTarget = .new(sortOrder: templates.count)
                Haptics.soft()
            } label: {
                Text("Create Template")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Tint.onAccent)
                    .frame(maxWidth: 220)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(Tint.inProgress)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, Space.xs)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.gutter)
    }

    private var noMatchesState: some View {
        VStack(spacing: Space.md) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Ink.tertiary)
            Text("No templates match \"\(searchText)\".")
                .font(Typography.body)
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.gutter)
    }

    // MARK: - Plumbing

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingTemplate != nil },
            set: { if !$0 { deletingTemplate = nil } }
        )
    }

    private func deleteTemplate(_ template: WorkoutTemplate) {
        modelContext.delete(template)
        try? modelContext.save()
        for (i, t) in templates.enumerated() {
            t.sortOrder = i
        }
        try? modelContext.save()
        Haptics.soft()
        deletingTemplate = nil
    }

    /// Start a workout from a template without leaving Library — the
    /// same entry point Today exposes. AppState swaps in the active
    /// session; the app shell surfaces the live workout.
    private func startWorkout(from template: WorkoutTemplate) {
        Haptics.soft()
        appState.startWorkoutFromTemplate(template)
    }
}

// MARK: - Exercises content

/// Exercises segment — browsable catalog. Tap an exercise row to
/// push its detail screen (no commit CTA in this context). Long-
/// press for Edit / Delete via context menu. Equipment filter strip
/// at the top mirrors the picker's chips so the two surfaces feel
/// continuous.
private struct LibraryExercisesContent: View {
    let searchText: String
    @Binding var segment: LibrarySegment
    @Binding var customExerciseTarget: CatalogEditorTarget?
    @Binding var searchMinimized: Bool
    let canMinimize: Bool

    @Environment(\.modelContext) private var modelContext

    @Query private var items: [ExerciseCatalogItem]

    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: \WorkoutSession.completedAt,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var equipmentFilter: Equipment? = nil
    @State private var pendingDeleteItem: ExerciseCatalogItem? = nil

    private var lastInstanceLookup: [String: LastExerciseInstance] {
        completedSessions.lastInstanceByExercise()
    }

    var body: some View {
        Group {
            if filteredGroups.isEmpty {
                VStack(spacing: 0) {
                    LibrarySegmentBar(selection: $segment)
                    equipmentFilterStrip
                    emptyState
                }
            } else {
                exerciseList
            }
        }
        .alert(
            "Delete \"\(pendingDeleteItem?.name ?? "exercise")\"?",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let item = pendingDeleteItem {
                    delete(item)
                }
                pendingDeleteItem = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: {
            Text("This removes the exercise from the catalog. Templates and history that already reference it stay intact.")
        }
    }

    // MARK: - Filter / group

    private var filteredGroups: [(group: MuscleGroup, items: [ExerciseCatalogItem])] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        var scope = items
        if let filter = equipmentFilter {
            scope = scope.filter { $0.equipment == filter }
        }
        if !trimmed.isEmpty {
            scope = scope.filter { item in
                if item.name.lowercased().contains(trimmed) { return true }
                return item.aliases.contains { $0.lowercased().contains(trimmed) }
            }
        }
        return scope.groupedByMuscle
    }

    private var availableEquipment: Set<Equipment> {
        Set(items.map(\.equipment))
    }

    // MARK: - Equipment filter strip

    @ViewBuilder
    private var equipmentFilterStrip: some View {
        if availableEquipment.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    chip(nil, label: "All")
                    ForEach(Equipment.allCases, id: \.self) { e in
                        if availableEquipment.contains(e) {
                            chip(e, label: e.displayName)
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
            }
            .padding(.bottom, 14)
        }
    }

    private func chip(_ value: Equipment?, label: String) -> some View {
        let isSelected = equipmentFilter == value
        return Button {
            Haptics.selection()
            equipmentFilter = value
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .padding(.horizontal, Space.lg)
                .frame(minHeight: 38)
                .background {
                    if isSelected {
                        Capsule().fill(Tint.inProgress)
                    }
                }
                .overlay {
                    if !isSelected {
                        Capsule().stroke(Surface.edge, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header scrolls with the catalog so the large title
                // collapses cleanly instead of fighting a pinned bar.
                LibrarySegmentBar(selection: $segment)
                equipmentFilterStrip

                LazyVStack(alignment: .leading, spacing: Space.section) {
                    ForEach(Array(filteredGroups.enumerated()), id: \.element.group) { index, section in
                        groupSection(group: section.group, items: section.items)
                            .settleIn(index)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxl + Space.xs)
            }
        }
        .minimizesSearchOnScroll(isMinimized: $searchMinimized, enabled: canMinimize)
    }

    private func groupSection(group: MuscleGroup, items: [ExerciseCatalogItem]) -> some View {
        let trackedCount = items.reduce(into: 0) { acc, item in
            if lastInstanceLookup[item.name.lowercased()] != nil { acc += 1 }
        }

        return VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(
                title: group.displayName,
                trailing: sectionSubtitle(total: items.count, tracked: trackedCount)
            )
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { SectionDivider() }
                    row(item)
                }
            }
        }
    }

    private func sectionSubtitle(total: Int, tracked: Int) -> String {
        let exercises = total == 1 ? "1 exercise" : "\(total) exercises"
        guard tracked > 0 else { return exercises }
        return "\(exercises) · \(tracked) tracked"
    }

    /// Row classifier: an exercise lifted within the last 14 days
    /// reads prominent (brighter name, larger weight×reps numeral);
    /// everything else stays tighter. Mirrors the History list's
    /// elevated-recent / quiet-older split, keyed on the exercise's
    /// last-performed date.
    private func row(_ item: ExerciseCatalogItem) -> some View {
        let last = lastInstanceLookup[item.name.lowercased()]
        let isRecent: Bool = {
            guard let last else { return false }
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: last.sessionDate),
                to: Calendar.current.startOfDay(for: Date())
            ).day ?? .max
            return days <= 14
        }()

        return rowLink(item: item) {
            exerciseRow(item: item, last: last, prominent: last != nil && isRecent)
        }
    }

    /// Detail screen receives no onPickAndDismiss callback — in the
    /// Library context there's nothing to "pick into," so the
    /// detail's bottom CTA hides automatically. Extracted so both
    /// row tiers share one navigation site + one context menu.
    private func rowLink<Content: View>(
        item: ExerciseCatalogItem,
        @ViewBuilder label: () -> Content
    ) -> some View {
        NavigationLink {
            ExerciseDetailScreen(item: item, onPickAndDismiss: nil)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                customExerciseTarget = .edit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDeleteItem = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: Exercise row

    /// One catalog row — full-width, card-free, divided from its
    /// neighbours by a hairline. Name + sentence-case meta (which
    /// carries the equipment) on the left; on the right either the last session's
    /// heaviest set as a monospaced `weight×reps` numeral (gold when
    /// it's an all-time best) over a relative date, or — when the
    /// exercise has never been logged — the quiet catalog default.
    /// `prominent` (lifted within 14 days) brightens the name and
    /// enlarges the numeral.
    private func exerciseRow(
        item: ExerciseCatalogItem,
        last: LastExerciseInstance?,
        prominent: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(prominent ? Ink.primary : Ink.secondary)
                    .lineLimit(1)
                Text(metaLine(item))
                    .font(Typography.caption)
                    .foregroundStyle(prominent ? Ink.tertiary : Ink.quaternary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.sm)

            rowTrailing(item: item, last: last, prominent: prominent)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.quaternary)
        }
        .frame(minHeight: prominent ? 64 : Space.rowMin, alignment: .leading)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func rowTrailing(
        item: ExerciseCatalogItem,
        last: LastExerciseInstance?,
        prominent: Bool
    ) -> some View {
        if let last {
            VStack(alignment: .trailing, spacing: 2) {
                Text(last.metricLabel(unit: unit))
                    .font(.system(size: prominent ? 20 : 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(last.isAllTimeBest ? Tint.complete : Ink.primary)
                    .monospacedDigit()
                Text(RelativeDate.short(last.sessionDate))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
        } else {
            Text(catalogDefaultLabel(item))
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
    }

    /// Mode-aware right-side default for an exercise with no history —
    /// "135 lb · 8 reps" for strength, "0:45 hold" for a timed hold.
    private func catalogDefaultLabel(_ item: ExerciseCatalogItem) -> String {
        switch item.trackingMode {
        case .reps:
            return "\(WeightFormatter.string(item.defaultWeight, unit: unit)) · \(item.defaultReps) reps"
        case .duration:
            let base = "\(DurationFormatter.string(item.defaultDuration)) hold"
            return item.defaultWeight > 0
                ? "\(WeightFormatter.string(item.defaultWeight, unit: unit)) · \(base)"
                : base
        }
    }

    /// Sentence-case meta line shared by both row tiers — same
    /// vocabulary as History's muscle strip: "Barbell · Push" or
    /// "Dumbbell · Isolation".
    private func metaLine(_ item: ExerciseCatalogItem) -> String {
        var parts: [String] = [item.equipment.displayName]
        if item.mechanic == .compound, let pattern = item.pattern {
            parts.append(pattern.displayName)
        } else if item.mechanic == .isolation {
            parts.append("Isolation")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Space.lg) {
            Spacer()
            Text(emptyMessage)
                .font(Typography.body)
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
            Button {
                customExerciseTarget = .create
            } label: {
                Text("Create custom exercise")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Tint.onAccent)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Tint.inProgress))
            }
            .buttonStyle(.plain)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.gutter)
    }

    private var emptyMessage: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return "No exercises match \"\(trimmed)\"."
        }
        if equipmentFilter != nil {
            return "No exercises for that equipment."
        }
        return "Your catalog is empty."
    }

    // MARK: - Mutations

    private func delete(_ item: ExerciseCatalogItem) {
        modelContext.delete(item)
        try? modelContext.save()
        Haptics.soft()
    }
}

// MARK: - Template row

/// A saved plan as a full-width hairline row — no card. Name and a
/// sentence-case meta line on the left ("4 ex · 16 sets · Chest ·
/// Back"); the relative last-used date and a faint chevron on the
/// right. The List that hosts it draws the separators.
private struct TemplateCard: View {
    let template: WorkoutTemplate

    var body: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.sm)

            if let used = template.lastUsedAt {
                Text(Self.relative.localizedString(for: used, relativeTo: Date()))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
        }
        .frame(minHeight: Space.rowMin)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        let count = template.orderedExercises.count
        let base = "\(count) ex · \(template.totalPlannedSets) sets"
        let groups = template.muscleGroups.prefix(3).map(\.displayName).joined(separator: " · ")
        return groups.isEmpty ? base : "\(base) · \(groups)"
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

// MARK: - Minimize-on-scroll

private extension View {
    /// Drives the pinned search pill's minimize state from a scroll
    /// view's position, mirroring the iOS 26 tab bar's
    /// `.tabBarMinimizeBehavior(.onScrollDown)`: collapse on scroll
    /// down and only snap back to full width once the scroll reaches
    /// the top — scrolling up partway holds the collapsed state.
    /// `distance` is measured from the resting top (offset + top
    /// inset) so a collapsing large title doesn't skew the reading. A
    /// small dead-band filters out bounce jitter. No-op while
    /// `enabled` is false (active search).
    func minimizesSearchOnScroll(isMinimized: Binding<Bool>, enabled: Bool) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { oldDistance, newDistance in
            guard enabled else { return }
            let target: Bool
            if newDistance <= 4 {
                target = false
            } else if newDistance > oldDistance + 2 {
                target = true
            } else {
                return
            }
            guard target != isMinimized.wrappedValue else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isMinimized.wrappedValue = target
            }
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
