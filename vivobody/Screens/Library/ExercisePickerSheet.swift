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
//

import SwiftUI
import SwiftData

struct ExercisePickerSheet: View {
    let onPick: (ExerciseCatalogItem) -> Void

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
                Color.black.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        equipmentFilterStrip
                        ForEach(filteredGroups, id: \.group) { section in
                            groupSection(group: section.group, items: section.items)
                        }
                        if filteredGroups.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
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
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
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
                HStack(spacing: 8) {
                    equipmentFilterChip(nil, label: "All", symbol: nil)
                    ForEach(Equipment.allCases, id: \.self) { e in
                        if availableEquipment.contains(e) {
                            equipmentFilterChip(e, label: e.displayName, symbol: e.symbol)
                        }
                    }
                }
                // Bleed past the LazyVStack horizontal padding so the
                // strip can scroll edge-to-edge.
                .padding(.horizontal, 2)
            }
            // Counter the LazyVStack's padding so the chips align
            // with the screen edges, not the content insets.
            .padding(.horizontal, -22)
            .padding(.horizontal, 22)
        }
    }

    /// All distinct equipment values represented in the visible
    /// catalog (post text-search, pre equipment-filter). Hides chips
    /// for equipment with no entries so the strip stays honest.
    private var availableEquipment: Set<Equipment> {
        Set(items.map(\.equipment))
    }

    private func equipmentFilterChip(_ value: Equipment?, label: String, symbol: String?) -> some View {
        let isSelected = equipmentFilter == value
        return Button {
            Haptics.selection()
            equipmentFilter = value
        } label: {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
            .padding(.horizontal, 14)
            .frame(minHeight: 32)
            .background(
                Capsule().fill(isSelected ? Tint.primary : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.10),
                    lineWidth: 0.5
                )
            )
            .shadow(
                color: isSelected ? Tint.primary.opacity(0.35) : .clear,
                radius: 10, y: 2
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Sections / rows

    private func groupSection(group: MuscleGroup, items: [ExerciseCatalogItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(group.accent).frame(width: 7, height: 7)
                Text(group.displayName)
                    .sectionLabelStyle(0.60)
            }
            VStack(spacing: 6) {
                ForEach(items) { item in
                    pickerRow(item)
                }
            }
        }
    }

    private func pickerRow(_ item: ExerciseCatalogItem) -> some View {
        let last = lastInstanceLookup[item.name.lowercased()]

        // Row taps navigate to detail instead of immediately picking;
        // the user commits via the "Add to Workout" CTA on the detail
        // screen. Long-press still surfaces Edit / Delete via the
        // attached contextMenu — that gesture is unchanged.
        return NavigationLink(value: item) {
            HStack(spacing: 10) {
                // Equipment glyph — small, dim, telegraphs the gear
                // before the user reads the name. Helps scan a long
                // back day for "any dumbbell rows in here?"
                Image(systemName: item.equipment.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    // Subtitle line — equipment label and pattern
                    // (or "Isolation") as a tiny disambiguator for
                    // exercises with similar names ("Bench Press"
                    // barbell vs. "Bench Press" dumbbell).
                    Text(rowSubtitle(item))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer(minLength: 8)

                // Right side flips between "default" (never lifted)
                // and "last" (have history). Last-side is the high-
                // value variant — it answers "what should I aim to
                // beat?" while the picker is still open.
                rowRightSide(item: item, last: last)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassChip(cornerRadius: 14)
        }
        .buttonStyle(.plain)
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
                HStack(spacing: 4) {
                    if last.isAllTimeBest {
                        Text("PR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Tint.primary))
                    }
                    Text("\(WeightFormatter.string(last.topWeight, unit: unit, includeUnit: false)) × \(last.topReps)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(RelativeDate.short(last.sessionDate))
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
        } else {
            Text("\(WeightFormatter.string(item.defaultWeight, unit: unit)) · \(item.defaultReps) reps")
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.45))
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
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Tint.primary.opacity(0.10))
                    .frame(width: 110, height: 110)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Tint.primary.opacity(0.85))
            }
            Text(emptyStateMessage)
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
            Button {
                editorTarget = .create
            } label: {
                Label("Create custom exercise", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Tint.primary))
                    .primaryGlow(Tint.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
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
