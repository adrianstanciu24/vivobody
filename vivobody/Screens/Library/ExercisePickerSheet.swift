//
//  ExercisePickerSheet.swift
//  vivobody
//
//  Modal browser for the exercise catalog. Presented from the
//  TemplateEditorScreen ("Add Exercise") and from the active workout
//  Summary card ("Add Exercise" mid-workout). Returns a single picked
//  item via callback and dismisses; the caller decides what to do
//  with it.
//
//  Catalog is SwiftData-backed (see ExerciseCatalogItem.swift), so
//  users can extend it inline:
//    • Toolbar "+" — create a new custom exercise.
//    • Long-press on any row — context menu with Edit and Delete.
//      Edit opens the same CustomExerciseEditorSheet in edit mode;
//      Delete asks for confirmation, then removes the row.
//
//  Sectioned by muscle group, searchable across the full list.
//  Search uses .searchable(placement: .toolbar) +
//  .searchToolbarBehavior(.minimize) — the field lives in the
//  bottom toolbar and collapses on scroll, matching Library's
//  house style.
//

import SwiftUI
import SwiftData

struct ExercisePickerSheet: View {
    let onPick: (ExerciseCatalogItem) -> Void

    /// When true, tapping a row commits the pick immediately (lime
    /// "+" affordance) and dismisses — used by the template builder,
    /// where selection flows straight into the configure sheet. When
    /// false (default), rows push to ExerciseDetailScreen and the
    /// user commits from the detail CTA — the active-workout add path.
    var picksOnTap: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var items: [ExerciseCatalogItem]

    /// Archived sessions — drives the "last-used" decoration on each
    /// row. Filtering to completedAt != nil at the query level means
    /// the in-flight session never contributes (it would otherwise
    /// surface a "LAST" line for a set you're still doing).
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: \WorkoutSession.completedAt,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var query: String = ""
    @State private var editorTarget: CatalogEditorTarget?
    @State private var pendingDeleteItem: ExerciseCatalogItem?

    /// Optional equipment filter. Nil means "all equipment." Chip
    /// strip at the top of the picker toggles between this and the
    /// individual Equipment cases.
    @State private var equipmentFilter: Equipment? = nil

    /// One-time-per-render lookup of "what did you last do for this
    /// exercise?" keyed by lowercased name. Rebuilt whenever the
    /// underlying completed sessions list changes — SwiftUI handles
    /// that via the @Query observation. Single O(N) sweep over
    /// history; picker rows do O(1) lookups.
    private var lastInstanceLookup: [String: LastExerciseInstance] {
        completedSessions.lastInstanceByExercise()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Surface.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.section) {
                        equipmentFilterStrip
                        ForEach(filteredGroups, id: \.group) { section in
                            groupSection(group: section.group, items: section.items)
                        }
                        if filteredGroups.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.top, Space.md)
                    .padding(.bottom, Space.xxl)
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorTarget = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create custom exercise")
                }
            }
            .navigationDestination(for: ExerciseCatalogItem.self) { destination in
                ExerciseDetailScreen(
                    item: destination,
                    // CTA on the detail picks the exercise and
                    // dismisses the entire picker sheet — same
                    // commit point the old tap-to-pick row had.
                    onPickAndDismiss: { picked in
                        onPick(picked)
                        dismiss()
                    }
                )
            }
            .searchable(text: $query, placement: .toolbar, prompt: Text("Search exercises"))
            .searchToolbarBehavior(.minimize)
            .sheet(item: $editorTarget) { target in
                CustomExerciseEditorSheet(target: target)
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
                Text("This removes the exercise from the picker. Templates and history that already reference it stay intact.")
            }
        }
    }

    // MARK: - Filtering / grouping

    private var filteredGroups: [(group: MuscleGroup, items: [ExerciseCatalogItem])] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()

        // First narrow by equipment filter — the chip strip toggles
        // a global "show only this equipment" lens. Nil = all.
        var scope = items
        if let filter = equipmentFilter {
            scope = scope.filter { $0.equipment == filter }
        }

        // Then narrow by search query — matches against name OR any
        // alias. Aliases let "BP" find "Bench Press"; case-insensitive
        // substring keeps the matching forgiving.
        if !trimmed.isEmpty {
            scope = scope.filter { item in
                if item.name.lowercased().contains(trimmed) { return true }
                return item.aliases.contains { $0.lowercased().contains(trimmed) }
            }
        }
        return scope.groupedByMuscle
    }

    // MARK: - Equipment filter strip

    /// Horizontal chip strip at the top of the picker. "All" + one
    /// chip per Equipment case. Wraps the existing list so users can
    /// narrow by gear before scrolling. Hidden when no items would
    /// be filtered anyway (e.g., catalog has only one equipment
    /// type — unusual but cleanly handled).
    @ViewBuilder
    private var equipmentFilterStrip: some View {
        if availableEquipment.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        equipmentFilterChip(nil, label: "All")
                        ForEach(Equipment.allCases, id: \.self) { e in
                            if availableEquipment.contains(e) {
                                equipmentFilterChip(e, label: e.displayName)
                            }
                        }
                    }
                }
                // Bleed past the LazyVStack horizontal padding so the
                // strip can scroll edge-to-edge.
                .padding(.horizontal, 2)
            }
            // Counter the LazyVStack's padding so the chips align
            // with the screen edges, not the content insets.
            .padding(.horizontal, -Space.gutter)
            .padding(.horizontal, Space.gutter)
        }
    }

    /// All distinct equipment values represented in the visible
    /// catalog (post text-search, pre equipment-filter). Hides chips
    /// for equipment with no entries so the strip stays honest.
    private var availableEquipment: Set<Equipment> {
        Set(items.map(\.equipment))
    }

    private func equipmentFilterChip(_ value: Equipment?, label: String) -> some View {
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
    }

    // MARK: - Sections / rows

    private func groupSection(group: MuscleGroup, items: [ExerciseCatalogItem]) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: group.displayName)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { SectionDivider() }
                    pickerRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private func pickerRow(_ item: ExerciseCatalogItem) -> some View {
        let last = lastInstanceLookup[item.name.lowercased()]

        Group {
            if picksOnTap {
                // Direct-pick: tap commits and dismisses. The lime
                // "+" glyph signals "adds straight to the template"
                // rather than "drills into detail."
                Button {
                    Haptics.soft()
                    onPick(item)
                    dismiss()
                } label: {
                    rowBody(item: item, last: last, trailingSymbol: "plus")
                }
                .buttonStyle(.plain)
            } else {
                // Row taps navigate to detail instead of immediately
                // picking; the user commits via the "Add to Workout"
                // CTA on the detail screen.
                NavigationLink(value: item) {
                    rowBody(item: item, last: last, trailingSymbol: "chevron.right")
                }
                .buttonStyle(.plain)
            }
        }
        // Long-press still surfaces Edit / Delete in both modes —
        // that gesture is unchanged.
        .contextMenu {
            Button {
                editorTarget = .edit(item)
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

    private func rowBody(
        item: ExerciseCatalogItem,
        last: LastExerciseInstance?,
        trailingSymbol: String
    ) -> some View {
        let isAdd = trailingSymbol == "plus"
        return HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                Text(rowSubtitle(item))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.sm)

            // Right side flips between "default" (never lifted)
            // and "last" (have history). Last-side is the high-
            // value variant — it answers "what should I aim to
            // beat?" while the picker is still open.
            rowRightSide(item: item, last: last)

            Image(systemName: trailingSymbol)
                .font(isAdd ? Typography.headline : Typography.caption)
                .foregroundStyle(isAdd ? Tint.inProgress : Ink.quaternary)
        }
        .frame(minHeight: Space.rowMin)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Right-side rendering of a picker row. Branches on whether
    /// we have a recent log of this exercise:
    ///   • No history → show the catalog's default (`135 lb · 8 reps`)
    ///     so brand-new users still see useful starting numbers.
    ///   • Has history → show `LAST · 145 lb × 8` plus the relative
    ///     date below in dim mono. If that last top set is also the
    ///     all-time best, mark it with a small "PR" pill so the
    ///     user knows their last bench WAS their PR.
    @ViewBuilder
    private func rowRightSide(item: ExerciseCatalogItem, last: LastExerciseInstance?) -> some View {
        if let last {
            VStack(alignment: .trailing, spacing: 2) {
                Text(last.metricLabel(unit: unit))
                    .font(Typography.metricInline)
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

    /// Right-side default for an exercise the user has never logged.
    /// Mode-aware: a strength lift reads "135 lb · 8 reps"; a timed
    /// hold reads "0:45 hold" (with optional load).
    private func catalogDefaultLabel(_ item: ExerciseCatalogItem) -> String {
        let seed = item.defaultWeight(forUnit: unit)
        switch item.trackingMode {
        case .reps:
            return "\(WeightFormatter.string(seed, unit: unit)) · \(item.defaultReps) reps"
        case .duration:
            let base = "\(DurationFormatter.string(item.defaultDuration)) hold"
            return seed > 0
                ? "\(WeightFormatter.string(seed, unit: unit)) · \(base)"
                : base
        }
    }

    /// Subtitle line for a picker row. Equipment first, then mechanic
    /// label (compound lifts get their pattern, isolation lifts get
    /// "Isolation"). Uppercased mono for the "metadata strip" feel
    /// shared with the rest of the app.
    private func rowSubtitle(_ item: ExerciseCatalogItem) -> String {
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
        ContentUnavailableView {
            Label(emptyStateMessage, systemImage: "dumbbell")
        } actions: {
            Button {
                editorTarget = .create
            } label: {
                Text("Create custom exercise")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var emptyStateMessage: String {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "Your catalog is empty.\nTap below to add an exercise."
        }
        return "No exercises match \"\(trimmed)\"."
    }

    // MARK: - Mutations

    private func delete(_ item: ExerciseCatalogItem) {
        modelContext.delete(item)
        try? modelContext.save()
        Haptics.soft()
    }
}
