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
/// press for Edit / Delete via context menu. Equipment filter strip
/// at the top mirrors the picker's chips so the two surfaces feel
/// continuous.
struct LibraryExercisesContent: View {
    let searchText: String
    @Binding var segment: LibrarySegment
    @Binding var customExerciseTarget: CatalogEditorTarget?

    /// Owned by LibraryScreen so the selected chip survives segment
    /// switches — this content view is recreated on every switch.
    @Binding var equipmentFilter: Equipment?

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
        let _ = sessionAnalytics?.update(for: completedSessions)
        Group {
            if isSearching {
                searchList
            } else if filteredGroups.isEmpty {
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

    /// Catalog narrowed by the equipment chip only (no text filter).
    /// Shared by the grouped browse path and the search-ranked path
    /// so the equipment lens behaves identically in both modes.
    private var scopedItems: [ExerciseCatalogItem] {
        var scope = items
        if let filter = equipmentFilter {
            scope = scope.filter { $0.equipment == filter }
        }
        return scope
    }

    /// Flat, relevance-ranked results for the active query. Equipment
    /// filter is applied first (via `scopedItems`), then `ExerciseSearch`
    /// tiers and sorts so "pull" surfaces "Pull-ups" before "Lat Pull
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

    // MARK: - Equipment filter strip

    @ViewBuilder
    private var equipmentFilterStrip: some View {
        if availableEquipment.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.md) {
                    HStack(spacing: Space.md) {
                        chip(nil, label: "All")
                        ForEach(Equipment.allCases, id: \.self) { e in
                            if availableEquipment.contains(e) {
                                chip(e, label: e.displayName)
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
            }
            .padding(.bottom, Space.lg)
        }
    }

    private func chip(_ value: Equipment?, label: String) -> some View {
        let isSelected = equipmentFilter == value
        return Button {
            Haptics.selection()
            equipmentFilter = value
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
                equipmentFilterStrip
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
    /// put "Pull-ups" (back) above "Cable pull through" (legs) by
    /// relevance. Rows reuse the same `row(_:)` renderer as the
    /// grouped path so the prominent/recent decoration stays
    /// consistent. Empty query keeps the grouped browse (`exerciseList`).
    private var searchList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LibrarySegmentBar(selection: $segment)
                    .padding(.horizontal, -Space.gutter)
                equipmentFilterStrip
                    .padding(.horizontal, -Space.gutter)

                if searchResults.isEmpty {
                    emptyState
                        .padding(.top, Space.xxl)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { idx, item in
                            if idx > 0 { SectionDivider() }
                            row(item)
                                .settleIn(idx)
                        }
                    }
                    .padding(.bottom, Space.xxl + Space.xs)
                }
            }
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(metaLine(item))
                    .font(Typography.caption)
                    .foregroundStyle(prominent ? Ink.tertiary : Ink.quaternary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: Space.sm)

            rowTrailing(item: item, last: last, prominent: prominent)

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: prominent ? 64 : Space.rowMin, alignment: .leading)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func rowTrailing(
        item: ExerciseCatalogItem,
        last: LastExerciseInstance?,
        prominent: Bool
    ) -> some View {
        if let last {
            // Keep the numeral on one line and let it hold its width:
            // a long name should wrap to two lines rather than squeeze
            // "180 × 10" into a wrapped, oversized stack over the date.
            VStack(alignment: .trailing, spacing: 2) {
                Text(last.metricLabel(unit: unit))
                    .font(prominent ? Typography.statValue : Typography.metricInline)
                    .foregroundStyle(last.isAllTimeBest ? Tint.complete : Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(RelativeDate.short(last.sessionDate))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
            .layoutPriority(1)
        } else {
            Text(catalogDefaultLabel(item))
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
    }

    private func lastInstance(for item: ExerciseCatalogItem) -> LastExerciseInstance? {
        lastInstanceLookup[item.historyKey] ?? lastInstanceLookup[item.legacyHistoryKey]
    }

    /// Mode-aware right-side default for an exercise with no history —
    /// "135 lb · 8 reps" for strength; timed work is labelled from its
    /// modality (hold, interval, or time).
    private func catalogDefaultLabel(_ item: ExerciseCatalogItem) -> String {
        let seed = item.defaultWeight(forUnit: unit)
        switch item.trackingMode {
        case .reps:
            let load = item.loadMode.summaryLoadLabel(seed, unit: unit)
            return load.map { "\($0) · \(item.defaultReps) reps" } ?? "\(item.defaultReps) reps"
        case .duration:
            let base = "\(DurationFormatter.string(item.defaultDuration)) \(item.modality.durationLabelLowercased)"
            guard let load = item.loadMode.summaryLoadLabel(seed, unit: unit) else { return base }
            return "\(load) · \(base)"
        }
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

    private var emptyState: some View {
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
