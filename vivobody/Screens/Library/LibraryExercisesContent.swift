//
//  LibraryExercisesContent.swift
//  vivobody
//
//  Exercises segment content for the Library screen. Extracted
//  from LibraryScreen.swift for file size management.
//

import VivoKit
import SwiftUI
import SwiftData

// MARK: - Exercises content

/// Exercises segment — browsable catalog. Tap an exercise row to
/// push its detail screen (no commit CTA in this context). Long-
/// press for Favorite / Edit / Delete via context menu. The filter
/// strip offers equipment scopes plus prominent Favorites and Core
/// shortcuts; favorited rows carry a star next to the name.
struct LibraryExercisesContent: View {
    let searchText: String
    @Binding var segment: LibrarySegment
    @Binding var customExerciseTarget: CatalogEditorTarget?

    /// Owned by LibraryScreen so the selected chip survives segment
    /// switches — this content view is recreated on every switch.
    @Binding var exerciseFilter: LibraryExerciseFilter

    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionAnalytics) private var sessionAnalytics

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

    @State private var pendingDeleteItem: ExerciseCatalogItem? = nil
    @State private var saveError: SaveErrorBox? = nil

    /// Last-instance decorations come from the fingerprint-keyed
    /// SessionAnalytics cache, so the O(sessions) sweep runs at most
    /// once per data change instead of once per row access. The
    /// recompute fallback only serves previews, which don't inject
    /// the cache.
    private var lastInstanceLookup: [String: LastExerciseInstance] {
        sessionAnalytics?.lastInstances ?? completedSessions.lastInstanceByExercise()
    }

    var body: some View {
        let analyticsRequest = sessionAnalytics?.requestKey(
            for: completedSessions
        )
        Group {
            if isSearching {
                searchList
            } else if filteredGroups.isEmpty {
                VStack(spacing: 0) {
                    LibrarySegmentBar(selection: $segment)
                    catalogFilterStrip
                    emptyState
                }
            } else {
                exerciseList
            }
        }
        .task(id: analyticsRequest) {
            sessionAnalytics?.requestCore(for: completedSessions)
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
        .saveErrorAlert($saveError)
    }

    // MARK: - Filter / group

    /// True when the search field has real content — drives the
    /// switch from grouped browse to a flat, relevance-ranked list.
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// History keys for exercises the user has actually logged, used
    /// as the tracked-boost set for `ExerciseSearch`.
    private var trackedKeys: Set<String> {
        Set(lastInstanceLookup.keys)
    }

    /// Catalog narrowed by the selected chip only (no text filter).
    /// Shared by the grouped browse path and the search-ranked path
    /// so Core and equipment scopes behave identically in both modes.
    private var scopedItems: [ExerciseCatalogItem] {
        switch exerciseFilter {
        case .all:
            items
        case .favorites:
            items.filter(\.isFavorite)
        case .core:
            items.filter { $0.group == .core }
        case .equipment(let equipment):
            items.filter { $0.equipment == equipment }
        }
    }

    /// Flat, relevance-ranked results for the active query. The chosen
    /// catalog scope is applied first, then `ExerciseSearch`
    /// tiers and sorts so "pull" surfaces "Pull-Up" before "Lat Pull
    /// Down" instead of respecting muscle-group enum order.
    private var searchResults: [ExerciseCatalogItem] {
        ExerciseSearch.rank(items: scopedItems, query: searchText, trackedKeys: trackedKeys)
    }

    private var filteredGroups: [(group: MuscleGroup, items: [ExerciseCatalogItem])] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        var scope = scopedItems
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

    // MARK: - Catalog filter strip

    /// Favorites is always offered — selecting it with no stars set
    /// lands on an empty state that teaches the long-press gesture.
    @ViewBuilder
    private var catalogFilterStrip: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.md) {
                    HStack(spacing: Space.md) {
                        chip(.all, label: "All")
                        chip(.favorites, label: "Favorites")
                        if items.contains(where: { $0.group == .core }) {
                            chip(.core, label: "Core")
                        }
                        ForEach(Equipment.allCases, id: \.self) { e in
                            if availableEquipment.contains(e) {
                                chip(.equipment(e), label: e.displayName)
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
            }
            // The strip hugs the chips exactly, so the default scroll
            // clip slices off the glass material's soft light-mode
            // shadows — the cropped remainder reads as a hard-edged
            // gray slab behind the chips. The strip is full-bleed, so
            // unclipped overflow just falls off-screen.
            .scrollClipDisabled()
            .padding(.bottom, Space.lg)
        }
    }

    private func chip(_ filter: LibraryExerciseFilter, label: String) -> some View {
        let isSelected = exerciseFilter == filter
        return Button {
            Haptics.selection()
            exerciseFilter = filter
        } label: {
            Text(label)
                .font(Typography.sectionLabel)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .padding(.horizontal, Space.lg)
                .frame(minHeight: Space.tapMin)
                .coloredGlassControl(cornerRadius: Radius.pill, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header scrolls with the catalog so the large title
                // collapses cleanly instead of fighting a pinned bar.
                LibrarySegmentBar(selection: $segment)
                    .padding(.horizontal, -Space.gutter)
                catalogFilterStrip
                    .padding(.horizontal, -Space.gutter)

                LazyVStack(alignment: .leading, spacing: Space.section) {
                    ForEach(Array(filteredGroups.enumerated()), id: \.element.group) { index, section in
                        groupSection(group: section.group, items: section.items)
                            .settleIn(index)
                    }
                }
                .padding(.bottom, Space.xxl + Space.xs)
            }
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    // MARK: - Search list (flat, ranked)

    /// While a search query is active, muscle-group sections are
    /// dropped in favor of one flat, best-match-first list — the
    /// grouped layout can only rank *within* a group, so it can never
    /// put "Pull-Up" (back) above "Cable Pull-Through" (legs) by
    /// relevance. Rows reuse the same `row(_:)` renderer as the
    /// grouped path so the prominent/recent decoration stays
    /// consistent. Empty query keeps the grouped browse (`exerciseList`).
    private var searchList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LibrarySegmentBar(selection: $segment)
                    .padding(.horizontal, -Space.gutter)
                catalogFilterStrip
                    .padding(.horizontal, -Space.gutter)

                if searchResults.isEmpty {
                    emptyState
                        .padding(.top, Space.xxl)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { idx, item in
                            if idx > 0 { insetRowDivider }
                            row(item)
                                .settleIn(idx)
                        }
                    }
                    .contentCard()
                    .padding(.bottom, Space.xxl + Space.xs)
                }
            }
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    /// One muscle group as a ledger block, mirroring History's date
    /// groups: the `SectionHeader` stays on black, the group's rows
    /// sit together inside a single content card with inset
    /// hairlines between them.
    private func groupSection(group: MuscleGroup, items: [ExerciseCatalogItem]) -> some View {
        let trackedCount = items.reduce(into: 0) { acc, item in
            if lastInstance(for: item) != nil { acc += 1 }
        }

        return VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(
                title: group.displayName,
                trailing: sectionSubtitle(total: items.count, tracked: trackedCount)
            )
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { insetRowDivider }
                    row(item)
                }
            }
            .contentCard()
        }
    }

    /// In-card hairline between rows, inset so it never runs into
    /// the card's rounded corners.
    private var insetRowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .padding(.horizontal, Space.lg)
            .accessibilityHidden(true)
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
        let last = lastInstance(for: item)
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
                toggleFavorite(item)
            } label: {
                Label(
                    item.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: item.isFavorite ? "star.slash" : "star"
                )
            }
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

    /// One catalog row inside its muscle-group card, divided from
    /// its neighbours by an inset hairline. Name + sentence-case
    /// meta (which carries the equipment) on the left; on the right
    /// the last session's heaviest set as a monospaced `weight×reps`
    /// numeral (gold when it's an all-time best) over a relative
    /// date, or nothing when the exercise has never been logged.
    /// `prominent` (lifted within 14 days) brightens the name and
    /// enlarges the numeral.
    private func exerciseRow(
        item: ExerciseCatalogItem,
        last: LastExerciseInstance?,
        prominent: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                    Text(item.name)
                        .font(Typography.sectionHeading)
                        .foregroundStyle(prominent ? Ink.primary : Ink.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(Typography.caption)
                            .foregroundStyle(Tint.complete)
                            .accessibilityLabel("Favorite")
                    }
                }
                Text(metaLine(item))
                    .font(Typography.caption)
                    .foregroundStyle(prominent ? Ink.tertiary : Ink.quaternary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: Space.sm)

            rowTrailing(last: last, prominent: prominent)

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: prominent ? 64 : Space.rowMin, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Trailing side is history-only. Never-logged exercises show
    /// nothing here — catalog defaults are input seeds, not numbers
    /// worth displaying as if they were the user's own.
    @ViewBuilder
    private func rowTrailing(
        last: LastExerciseInstance?,
        prominent: Bool
    ) -> some View {
        if let last {
            // Keep the numeral on one line and let it hold its width:
            // a long name should wrap to two lines rather than squeeze
            // "180 × 10" into a wrapped, oversized stack over the date.
            VStack(alignment: .trailing, spacing: 2) {
                Text(last.metricLabel(unit: unit))
                    .font(prominent ? Typography.statValueCompact : Typography.metricInline)
                    .foregroundStyle(last.isAllTimeBest ? Tint.complete : Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(RelativeDate.short(last.sessionDate))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
            .layoutPriority(1)
        }
    }

    private func lastInstance(for item: ExerciseCatalogItem) -> LastExerciseInstance? {
        lastInstanceLookup[item.historyKey] ?? lastInstanceLookup[item.legacyHistoryKey]
    }

    /// Sentence-case meta line shared by both row tiers — same
    /// vocabulary as History's muscle strip: "Barbell · Push" or
    /// "Dumbbell · Isolation".
    private func metaLine(_ item: ExerciseCatalogItem) -> String {
        var parts: [String] = [item.equipment.displayName]
        if item.mechanic == .compound, let movementLabel = item.movementLabel {
            parts.append(movementLabel)
        } else if item.mechanic == .isolation {
            parts.append("Isolation")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Empty state

    /// The Favorites scope gets a teaching empty state (title +
    /// smaller description, no CTA) — creating a new exercise
    /// wouldn't fill it; starring an existing one would.
    @ViewBuilder
    private var emptyState: some View {
        if !isSearching && exerciseFilter == .favorites {
            ContentUnavailableView {
                Label("No favorite exercises yet", systemImage: "dumbbell")
            } description: {
                Text("Long-press an exercise to favorite it.")
            }
        } else {
            ContentUnavailableView {
                Label(emptyMessage, systemImage: "dumbbell")
            } actions: {
                Button {
                    customExerciseTarget = .create
                } label: {
                    Text("Create custom exercise")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var emptyMessage: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return "No exercises match \"\(trimmed)\"."
        }
        switch exerciseFilter {
        case .all, .favorites:
            return "Your catalog is empty."
        case .core:
            return "No Core exercises."
        case .equipment:
            return "No exercises for that equipment."
        }
    }

    // MARK: - Mutations

    private func toggleFavorite(_ item: ExerciseCatalogItem) {
        item.isFavorite.toggle()
        do {
            try modelContext.saveOrRollback()
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.tick()
    }

    private func delete(_ item: ExerciseCatalogItem) {
        let id = item.id
        modelContext.delete(item)
        do {
            try modelContext.saveOrRollback()
            SpotlightIndexer.removeExercise(id: id)
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.soft()
    }
}

/// Mutually-exclusive scopes for the Library exercise catalog and the
/// exercise picker. Favorites and Core sit beside equipment filters as
/// high-value shortcuts, while a single enum prevents contradictory
/// chips being selected.
enum LibraryExerciseFilter: Equatable {
    case all
    case favorites
    case core
    case equipment(Equipment)
}
