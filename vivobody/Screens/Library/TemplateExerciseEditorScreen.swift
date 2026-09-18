//
//  TemplateExerciseEditorScreen.swift
//  vivobody
//
//  Edits one persisted template exercise's targets and starting-load policy.
//  Scrubber controls reuse the workout's input language. Each meaningful change
//  saves with rollback/error handling; fixed per-set programming stays intact.
//

import SwiftData
import SwiftUI
import VivoKit

struct TemplateExerciseEditorScreen: View {
    @Bindable var exercise: TemplateExercise
    @Bindable var appState: AppState

    @Environment(\.modelContext) private var modelContext

    @State private var saveError: SaveErrorBox? = nil

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header

                valueRow(label: "Sets") {
                    BareScrubber(
                        value: setsBinding,
                        range: 1 ... 12,
                        step: 1,
                        pointsPerStep: 18,
                        fontSize: 64,
                        numberColor: Ink.primary,
                        accessibilityLabel: "Sets"
                    )
                }

                SectionDivider()

                switch exercise.trackingMode {
                case .reps:
                    valueRow(label: "Reps") {
                        BareScrubber(
                            value: repsBinding,
                            range: 1 ... 50,
                            step: 1,
                            pointsPerStep: 16,
                            fontSize: 64,
                            numberColor: Ink.primary,
                            accessibilityLabel: "Reps"
                        )
                    }
                case .duration:
                    valueRow(label: exercise.modality.durationLabel) {
                        BareScrubber(
                            value: durationBinding,
                            range: DurationFormatter.scrubRange,
                            step: DurationFormatter.scrubStep,
                            pointsPerStep: 10,
                            fontSize: 64,
                            numberColor: Ink.primary,
                            formatter: { DurationFormatter.string($0) },
                            accessibilityLabel: exercise.modality.durationLabel
                        )
                    }
                }

                if exercise.tracksResistance {
                    SectionDivider()
                    if exercise.hasPerSetData {
                        Text("Fixed per-set plan")
                            .font(Typography.sectionHeading)
                        Text(ExerciseDraft(from: exercise).summary(unit: unit))
                            .font(Typography.body)
                            .foregroundStyle(Ink.secondary)
                    } else {
                        TemplateLoadControls(policy: $exercise.loadPolicy, weight: $exercise.plannedWeight,
                                             hasStartingLoad: $exercise.hasStartingLoad, loadMode: exercise.loadMode, unit: unit,
                                             lastWeights: last?.completedSetPrescription.map(\.weight) ?? [], lastDate: last?.date)
                    }
                }
            }
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
        // Persist on every step. SwiftData writes are cheap and
        // this keeps the parent list summary fresh as soon as the
        // user finishes a drag.
        .onChange(of: exercise.plannedSets) { _, _ in save() }
        .onChange(of: exercise.plannedReps) { _, _ in save() }
        .onChange(of: exercise.plannedWeight) { _, _ in save() }
        .onChange(of: exercise.loadPolicyRaw) { _, _ in save() }
        .onChange(of: exercise.hasStartingLoad) { _, _ in save() }
        .onChange(of: exercise.plannedDuration) { _, _ in save() }
        .onAppear { normalizeUntrackedResistance() }
        .saveErrorAlert($saveError)
    }

    private var last: ExerciseHistoryInstance? {
        appState.analytics.exerciseHistorySummaries[exercise.historyKey]?.mostRecentInstance(matching: exercise.performanceSignature)
    }

    // MARK: - Header

    /// Type-forward identity: the muscle group as a quiet kicker, the
    /// exercise name as the title. No stripe, no card — the name
    /// carries the screen.
    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(exercise.group.displayName)
                .sectionLabelStyle(Opacity.soft)
            Text(exercise.name)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Value row

    /// A small sentence-case label above a bare scrubbing numeral.
    /// The numeral is the control; the label just names what it sets.
    private func valueRow(
        label: String,
        @ViewBuilder scrubber: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(label)
                .sectionLabelStyle(Opacity.medium)
            scrubber()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Bindings

    /// BareScrubber scrubs Double — bridge from / to the model's Int
    /// storage. Conversion happens at the binding boundary so the
    /// rest of the app never sees a Double set count.
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

    private var durationBinding: Binding<Double> {
        Binding(
            get: { exercise.plannedDuration },
            set: { exercise.plannedDuration = $0 }
        )
    }

    // MARK: - Persistence

    private func save() {
        do {
            try modelContext.saveOrRollback()
            WidgetSnapshotWriter.writeAll(in: modelContext)
        } catch {
            saveError = SaveErrorBox(error)
        }
    }

    private func normalizeUntrackedResistance() {
        guard !exercise.tracksResistance else { return }
        var changed = false
        if exercise.plannedWeight != 0 {
            exercise.plannedWeight = 0
            changed = true
        }
        for set in exercise.sets where set.weight != 0 {
            set.weight = 0
            changed = true
        }
        if changed { save() }
    }
}
