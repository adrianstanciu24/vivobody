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
//      TemplateExerciseEditorScreen (target scrubbers and starting-load policy).
//
//    • Delete an exercise — swipe-left on the row OR enter Edit
//      mode (toolbar EditButton) for batch delete + drag-reorder.
//
//    • Reorder exercises — Edit mode, then drag the grip handles.
//
//  Deleting the entire template happens from the Library list
//  (swipe on its card), not here.
//

import SwiftData
import SwiftUI
import VivoKit

struct TemplateDetailScreen: View {
    @Bindable var template: WorkoutTemplate
    @Bindable var appState: AppState

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    @State private var pendingPick: ExerciseCatalogItem?
    @State private var configureTarget: ConfigureExerciseTarget?
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
        .sheet(isPresented: $showPicker, onDismiss: {
            if let item = pendingPick {
                _ = appState.analytics.resolvedExerciseHistory(in: modelContext)
                configureTarget = .adding(item)
                pendingPick = nil
            }
        }) {
            ExercisePickerSheet(purpose: .addToTemplate) { item in
                pendingPick = item
                showPicker = false
            }
        }
        .sheet(item: $configureTarget) { target in
            ConfigureExerciseSheet(target: target, history: configureHistory(target)) { draft in
                appendExercise(draft)
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
                        TemplateExerciseEditorScreen(exercise: exercise, appState: appState)
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
                        .fixedSize(horizontal: false, vertical: true)
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
        let target = ExerciseDraft(from: exercise).targetSummary
        guard exercise.tracksResistance else { return target }
        let resolution = exercise.resolveLoad(history: appState.analytics.exerciseHistorySummaries[exercise.historyKey])
        return "\(target) · \(resolution.summary(loadMode: exercise.loadMode, unit: unit))"
    }

    private func configureHistory(_ target: ConfigureExerciseTarget) -> ExerciseHistorySummary? {
        guard case let .adding(item) = target else { return nil }
        return appState.analytics.exerciseHistorySummaries[item.historyKey]
    }

    // MARK: - Start bar

    private var startBar: some View {
        PrimaryActionButton(
            title: "Start Workout",
            subtitle: nil,
            inputLabels: ["Start Workout", "Start", "Begin"],
            sound: .commit
        ) {
            appState.workout.startWorkoutFromTemplate(template)
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

    /// Persist a configured exercise with its load policy and initial fallback.
    /// The new row appears at the end of the list.
    private func appendExercise(_ draft: ExerciseDraft) {
        let new = draft.makeTemplateExercise(sortOrder: template.exercises.count)
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
