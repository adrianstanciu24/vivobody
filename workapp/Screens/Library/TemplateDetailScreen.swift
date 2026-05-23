//
//  TemplateDetailScreen.swift
//  workapp
//
//  Read-only preview of one saved template — list of exercises with
//  their planned sets × reps × weight — anchored by a large Start
//  Workout button. The nav-bar Edit action hops into TemplateEditor;
//  the trailing "..." overflow houses Delete.
//
//  Tapping Start spawns a fresh WorkoutSession from this template
//  (via AppState), pops back to the Library list, and lets AppRoot's
//  sheet machinery present the active workout screen — same path
//  every other "start workout" entry point uses.
//

import SwiftUI

struct TemplateDetailScreen: View {
    let template: WorkoutTemplate
    @Bindable var appState: AppState

    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    exerciseList
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) {
                startBar
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("Template actions")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )

            if !template.muscleGroups.isEmpty {
                HStack(spacing: 6) {
                    ForEach(template.muscleGroups, id: \.self) { group in
                        Text(group.displayName.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(group.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(group.accent.opacity(0.16))
                            )
                    }
                }
            }
        }
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EXERCISES")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            if template.orderedExercises.isEmpty {
                Text("This template has no exercises yet. Edit to add some.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.40))
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(template.orderedExercises.enumerated()), id: \.element.id) { _, exercise in
                    exerciseRow(exercise)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: TemplateExercise) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // Muscle-group color chip
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(exercise.group.accent)
                .frame(width: 4, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    if exercise.hasPerSetData {
                        Text("PER SET")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
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
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer()

            Text(exercise.group.displayName.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(exercise.group.accent.opacity(0.85))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
        )
    }

    /// Per-set templates show a count + weight range; uniform ones
    /// keep the existing "3 × 8 @ 135 lb" style. Mirrors the editor's
    /// collapsed-row summary so the two surfaces read consistently.
    /// All weight values route through WeightFormatter so the unit
    /// (lb / kg) follows the user's Preferences setting.
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
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
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
                dismiss()  // pop back to Library; sheet machinery presents the workout
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .disabled(template.orderedExercises.isEmpty)
            .opacity(template.orderedExercises.isEmpty ? 0.4 : 1)
        }
        .background(Color.black.opacity(0.85))
    }
}
