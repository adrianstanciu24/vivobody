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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                Section {
                    statsCard
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 22, bottom: 4, trailing: 22))

                    if !template.muscleGroups.isEmpty {
                        muscleGroupChips
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 22, bottom: 8, trailing: 22))
                    }
                }

                exerciseSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
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
            try? modelContext.save()
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
    }

    // MARK: - Stats card

    private var statsCard: some View {
        HStack(spacing: 14) {
            stat(value: "\(template.orderedExercises.count)", label: "EXERCISES")
            statDivider
            stat(value: "\(template.totalPlannedSets)", label: "SETS")
            if !template.muscleGroups.isEmpty {
                statDivider
                stat(value: "\(template.muscleGroups.count)", label: "GROUPS")
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var muscleGroupChips: some View {
        HStack(spacing: 6) {
            ForEach(template.muscleGroups, id: \.self) { group in
                Text(group.displayName.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(group.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(group.accent.opacity(0.16))
                    )
            }
        }
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
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 22, bottom: 4, trailing: 22))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteExercise(exercise)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("EXERCISES")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.leading, 22)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets())
                    .background(Color.black)
            }
        }
    }

    private var emptyExercisesPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.30))
            Text("No exercises yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text("Tap the + above to add one.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.40))
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 0.5, dash: [4]))
        )
    }

    private func exerciseRow(_ exercise: TemplateExercise) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(exercise.group.accent)
                .frame(width: 4, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    if exercise.hasPerSetData {
                        Text("PER SET")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(
                                    Color(.sRGB, red: 1.0, green: 0.78, blue: 0.30, opacity: 1.0)
                                )
                            )
                    }
                }
                Text(exerciseSummary(exercise))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Text(exercise.group.displayName.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(exercise.group.accent.opacity(0.85))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }

    private func exerciseSummary(_ exercise: TemplateExercise) -> String {
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
    }

    // MARK: - Stat helpers

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.50))
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.5, height: 32)
    }

    // MARK: - Start bar

    private var startBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.08))
            PrimaryActionButton(
                title: "Start Workout",
                subtitle: nil
            ) {
                appState.startWorkoutFromTemplate(template)
                dismiss()
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .disabled(template.orderedExercises.isEmpty)
            .opacity(template.orderedExercises.isEmpty ? 0.4 : 1)
        }
        .background(Color.black.opacity(0.85))
    }

    // MARK: - Mutations

    /// Add a TemplateExercise from a catalog pick. Uniform mode with
    /// catalog defaults; the new row appears at the end of the list.
    private func appendExercise(from item: ExerciseCatalogItem) {
        let new = TemplateExercise(
            name: item.name,
            group: item.group,
            plannedSets: 3,
            plannedReps: item.defaultReps,
            plannedWeight: item.defaultWeight,
            sortOrder: template.exercises.count
        )
        template.exercises.append(new)
        try? modelContext.save()
        Haptics.soft()
    }

    /// Single-row delete (used by swipe-actions and the rendered
    /// minus button in Edit mode if iOS routes it here).
    private func deleteExercise(_ exercise: TemplateExercise) {
        if let idx = template.exercises.firstIndex(where: { $0.id == exercise.id }) {
            template.exercises.remove(at: idx)
        }
        repackSortOrder()
        try? modelContext.save()
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
