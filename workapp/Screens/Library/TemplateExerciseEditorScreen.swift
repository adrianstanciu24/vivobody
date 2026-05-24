//
//  TemplateExerciseEditorScreen.swift
//  workapp
//
//  Edits a single TemplateExercise using the app's native gesture-
//  based scrubbers — the same NumberScrubber / WeightScrubber atoms
//  the active workout card uses. Drag up to increase, down to
//  decrease; haptic tick on every step; rubber-band at the range
//  walls. All values bind directly to the @Model via @Bindable +
//  modelContext.save() on change, so edits flow straight back to
//  the parent list summary.
//
//  Why scrubbers, not iOS Form Steppers: the active workout sets
//  the app's visual + interaction language. The template editor
//  has to match — otherwise template-side editing feels like a
//  different app from workout-side editing. The atoms exist
//  precisely so editing weight/reps/sets feels the same everywhere.
//

import SwiftUI
import SwiftData

struct TemplateExerciseEditorScreen: View {
    @Bindable var exercise: TemplateExercise

    @Environment(\.modelContext) private var modelContext

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header

                    NumberScrubber(
                        value: setsBinding,
                        range: 1...12,
                        step: 1,
                        pointsPerStep: 18,
                        unit: setsUnit,
                        label: nil,
                        valueFontSize: 40,
                        verticalPadding: 16
                    )

                    NumberScrubber(
                        value: repsBinding,
                        range: 1...50,
                        step: 1,
                        pointsPerStep: 16,
                        unit: repsUnit,
                        label: nil,
                        valueFontSize: 40,
                        verticalPadding: 16
                    )

                    WeightScrubber(
                        canonicalWeight: $exercise.plannedWeight,
                        purpose: .strength,
                        label: nil,
                        pointsPerStep: 8,
                        valueFontSize: 44,
                        verticalPadding: 18
                    )

                    if exercise.hasPerSetData {
                        perSetNotice
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        // Persist on every step. SwiftData writes are cheap and
        // this keeps the parent list summary fresh as soon as the
        // user finishes a drag.
        .onChange(of: exercise.plannedSets) { _, _ in save() }
        .onChange(of: exercise.plannedReps) { _, _ in save() }
        .onChange(of: exercise.plannedWeight) { _, _ in save() }
    }

    // MARK: - Header

    /// Identifies which exercise is being edited. Matches the
    /// stripe + group-label visual used on the TemplateDetailScreen
    /// rows so the push doesn't feel like a context switch.
    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(exercise.group.accent)
                .frame(width: 4, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Text(exercise.group.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(exercise.group.accent.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }

    // MARK: - Per-set notice

    /// Surfaces when the template has explicit pyramid/wave rows.
    /// The Sets/Reps/Weight scrubbers above act as fallback values
    /// in that mode — the per-set rows are the source of truth at
    /// runtime. Per-set editing UI is future work.
    private var perSetNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 13, weight: .semibold))
                Text("Per-set programming")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.85))

            Text("This exercise uses pyramid / wave programming with \(exercise.orderedSets.count) explicit set rows. The values above are fallbacks — the per-set rows are the source of truth at runtime.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Bindings

    /// NumberScrubber scrubs Double — bridge from / to the model's
    /// Int storage. Conversion happens at the binding boundary so
    /// the rest of the app never sees a Double set count.
    private var setsBinding: Binding<Double> {
        Binding(
            get: { Double(exercise.plannedSets) },
            set: { exercise.plannedSets = Int($0) }
        )
    }

    private var repsBinding: Binding<Double> {
        Binding(
            get: { Double(exercise.plannedReps) },
            set: { exercise.plannedReps = Int($0) }
        )
    }

    // MARK: - Label helpers

    /// Pluralised label that follows the scrubbed value. "1 set"
    /// vs "3 sets" — small detail but it's the difference between
    /// "feels native" and "feels coded by a robot."
    private var setsUnit: String {
        exercise.plannedSets == 1 ? "set" : "sets"
    }

    private var repsUnit: String {
        exercise.plannedReps == 1 ? "rep" : "reps"
    }

    // MARK: - Persistence

    private func save() {
        try? modelContext.save()
    }
}
