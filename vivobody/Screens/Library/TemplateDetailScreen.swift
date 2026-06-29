//
//  TemplateDetailScreen.swift
//  vivobody
//
//  Single source of truth for shaping a workout template. Native-
//  iOS interaction model end-to-end:
//
//    • Rename the template — tap the large system navigation title.
//      SwiftUI's `navigationTitle($binding)` API hands the rename UI
//      to iOS itself, same surface Notes / Reminders / Files use.
//      No custom pencil icons.
//
//    • Add an exercise — tap the "+" toolbar button → picker sheet.
//
//    • Edit an exercise's plan — tap its row → push to
//      TemplateExerciseEditorScreen (sets / reps / weight with
//      native Stepper + scrubber sheet).
//
//    • Delete an exercise — swipe-left on the row OR enter Edit
//      mode (toolbar EditButton) for batch delete + drag-reorder.
//
//    • Reorder exercises — Edit mode, then drag the grip handles.
//
//  Deleting the entire template happens from the Library list
//  (swipe on its card), not here.
//

import SwiftUI
import SwiftData

struct TemplateDetailScreen: View {
    @Bindable var template: WorkoutTemplate
    @Bindable var appState: AppState

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var showPicker: Bool = false
    @State private var saveError: SaveErrorBox? = nil

    var body: some View {
        ZStack {
            Surface.background.ignoresSafeArea()

            List {
                Section {
                    statsCard
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Space.sm, leading: Space.gutter, bottom: Space.xs, trailing: Space.gutter))

                    if !template.muscleGroups.isEmpty {
                        muscleGroupChips
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.gutter, bottom: Space.md, trailing: Space.gutter))
                    }
                }

                exerciseSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaBar(edge: .bottom) {
                startBar
            }
        }
        // The system-native editable title. iOS owns the rename UI
        // — tapping the title surfaces the rename affordance and
        // writes back through the binding. No custom alert, no
        // pencil icon, no inline TextField. Pure iOS.
        .navigationTitle($template.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarTitleMenu {
            // The system rename action — populates the title's
            // dropdown menu so users discover the gesture.
            RenameButton()
        }
        .onChange(of: template.name) { _, _ in
            do {
                try modelContext.saveOrRollback()
                WidgetSnapshotWriter.writeAll(in: modelContext)
            } catch {
                saveError = SaveErrorBox(error)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPicker = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("Add exercise")
            }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerSheet { item in
                appendExercise(from: item)
            }
        }
        .saveErrorAlert($saveError)
    }

    // MARK: - Stats

    private var statsCard: some View {
        StatStrip(stats: statStats, valueFont: Typography.statValue)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statStats: [Stat] {
        var stats = [
            Stat(value: "\(template.orderedExercises.count)", label: "Exercises"),
            Stat(value: "\(template.totalPlannedSets)", label: "Sets"),
        ]
        if !template.muscleGroups.isEmpty {
            stats.append(Stat(value: "\(template.muscleGroups.count)", label: "Groups"))
        }
        return stats
    }

    private var muscleGroupChips: some View {
        Text(template.muscleGroups.map(\.displayName).joined(separator: " · "))
            .font(Typography.caption)
            .foregroundStyle(Ink.tertiary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Exercise list

    @ViewBuilder
    private var exerciseSection: some View {
        if template.orderedExercises.isEmpty {
            Section {
                emptyExercisesPrompt
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 16, leading: 22, bottom: 16, trailing: 22))
            }
        } else {
            Section {
                ForEach(template.orderedExercises) { exercise in
                    // Closure-based NavigationLink — bypasses value
                    // routing entirely. With SwiftData @Model
                    // objects, value-based NavigationLink + remote
                    // navigationDestination can mis-resolve due to
                    // identity quirks in the relationship graph.
                    // Closure form pushes the literal destination
                    // and is deterministic.
                    NavigationLink {
                        TemplateExerciseEditorScreen(exercise: exercise)
                    } label: {
                        exerciseRow(exercise)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Surface.edge)
                    .listRowInsets(EdgeInsets(top: 0, leading: Space.gutter, bottom: 0, trailing: Space.gutter))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteExercise(exercise)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Exercises")
                    .sectionLabelStyle(Opacity.medium)
                    .padding(.leading, Space.gutter)
                    .padding(.top, Space.sm)
                    .padding(.bottom, Space.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets())
                    .background(Surface.background)
            }
        }
    }

    private var emptyExercisesPrompt: some View {
        ContentUnavailableView(
            "No exercises yet",
            systemImage: "list.bullet",
            description: Text("Tap + above to add one.")
        )
    }

    private func exerciseRow(_ exercise: TemplateExercise) -> some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Space.sm) {
                    Text(exercise.name)
                        .font(Typography.title)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                    if exercise.hasPerSetData {
                        Text("Per set")
                            .font(Typography.caption)
                            .foregroundStyle(Tint.inProgress)
                    }
                }
                Text(exerciseSummary(exercise))
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
            }

            Spacer(minLength: Space.sm)

            Text(exercise.group.displayName)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
        .frame(minHeight: Space.rowMin)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func exerciseSummary(_ exercise: TemplateExercise) -> String {
        switch exercise.trackingMode {
        case .reps:
            if exercise.hasPerSetData {
                let sets = exercise.orderedSets
                let weights = sets.map(\.weight)
                guard let lo = weights.min(), let hi = weights.max() else { return "" }
                if lo == hi, let first = sets.first {
                    return "\(sets.count) × \(first.reps) @ \(WeightFormatter.string(lo, unit: unit))"
                }
                let loStr = WeightFormatter.string(lo, unit: unit, includeUnit: false)
                let hiStr = WeightFormatter.string(hi, unit: unit)
                return "\(sets.count) sets · \(loStr)–\(hiStr)"
            }
            return "\(exercise.plannedSets) × \(exercise.plannedReps) @ \(WeightFormatter.string(exercise.plannedWeight, unit: unit))"

        case .duration:
            if exercise.hasPerSetData {
                let sets = exercise.orderedSets
                let durations = sets.map(\.duration)
                guard let lo = durations.min(), let hi = durations.max() else { return "" }
                if lo == hi {
                    return "\(sets.count) × \(DurationFormatter.string(lo)) hold"
                }
                return "\(sets.count) sets · \(DurationFormatter.string(lo))–\(DurationFormatter.string(hi))"
            }
            let base = "\(exercise.plannedSets) × \(DurationFormatter.string(exercise.plannedDuration)) hold"
            return exercise.plannedWeight > 0
                ? "\(base) @ \(WeightFormatter.string(exercise.plannedWeight, unit: unit))"
                : base
        }
    }

    // MARK: - Start bar

    private var startBar: some View {
        PrimaryActionButton(
            title: "Start Workout",
            subtitle: nil,
            inputLabels: ["Start Workout", "Start", "Begin"]
        ) {
            appState.startWorkoutFromTemplate(template)
            dismiss()
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .disabled(template.orderedExercises.isEmpty)
        .opacity(template.orderedExercises.isEmpty ? 0.4 : 1)
        .accessibilityHint(template.orderedExercises.isEmpty ? "Add exercises first to start a workout" : "")
    }

    // MARK: - Mutations

    /// Add a TemplateExercise from a catalog pick. Uniform mode with
    /// catalog defaults; the new row appears at the end of the list.
    private func appendExercise(from item: ExerciseCatalogItem) {
        let new = TemplateExercise(from: item, sortOrder: template.exercises.count)
        template.exercises.append(new)
        do {
            try modelContext.saveOrRollback()
            WidgetSnapshotWriter.writeAll(in: modelContext)
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.soft()
    }

    /// Single-row delete (used by swipe-actions and the rendered
    /// minus button in Edit mode if iOS routes it here).
    private func deleteExercise(_ exercise: TemplateExercise) {
        if let idx = template.exercises.firstIndex(where: { $0.id == exercise.id }) {
            template.exercises.remove(at: idx)
            modelContext.delete(exercise)
        }
        repackSortOrder()
        do {
            try modelContext.saveOrRollback()
            WidgetSnapshotWriter.writeAll(in: modelContext)
        } catch {
            saveError = SaveErrorBox(error)
            return
        }
        Haptics.soft()
    }

    /// Re-pack sortOrder so the next append lands at the right
    /// index after a delete.
    private func repackSortOrder() {
        for (i, remaining) in template.orderedExercises.enumerated() {
            remaining.sortOrder = i
        }
    }
}
