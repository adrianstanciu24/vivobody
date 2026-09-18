//
//  ConfigureExerciseSheet.swift
//  vivobody
//
//  Bottom sheet that configures one exercise's plan — Sets, Target
//  reps, and Weight — before it lands in a template. Presented from
//  the template builder: either after picking a new exercise from
//  the catalog (.adding) or by tapping an already-configured row to
//  revise it (.editing).
//
//  Same instrument language as the rest of the app: huge monospaced
//  numerals you scrub with a vertical drag (BareScrubber), a quiet
//  kicker header, starting-load controls, a target preview, and a single lime
//  CTA. Nothing is persisted here — the sheet hands a value-type
//  ExerciseDraft back to the builder via `onCommit`, and the builder
//  decides when (and whether) to write it through to SwiftData.
//

import SwiftUI
import VivoKit

/// What the configure sheet is operating on. Driven as an
/// Identifiable so the builder can present it via `.sheet(item:)`.
enum ConfigureExerciseTarget: Identifiable {
    /// A fresh catalog pick — targets from the catalog, load from history or explicit entry.
    case adding(ExerciseCatalogItem)
    /// An existing draft row being revised — fields prefilled.
    case editing(ExerciseDraft)

    var id: String {
        switch self {
        case let .adding(item): "add-\(item.id.uuidString)"
        case let .editing(draft): "edit-\(draft.id.uuidString)"
        }
    }
}

struct ConfigureExerciseSheet: View {
    let target: ConfigureExerciseTarget
    let onCommit: (ExerciseDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    @State private var sets: Int
    @State private var reps: Int
    /// Canonical lb — scrubbed in display units, stored as lb.
    @State private var weight: Double
    @State private var loadPolicy: TemplateLoadPolicy
    @State private var hasStartingLoad: Bool
    private let lastWeights: [Double]
    private let lastDate: Date?
    /// Hold length (seconds) — used only in `.duration` mode.
    @State private var duration: Double

    private let name: String
    private let catalogItemID: UUID?
    private let catalogID: String?
    private let familyID: String?
    private let group: MuscleGroup
    private let muscleInvolvement: Muscle.Involvement
    private let classification: ExerciseClassification?
    private let mode: TrackingMode
    private let modality: ExerciseModality
    private let loadMode: ExerciseLoadMode
    private let bodyweightFraction: Double
    private let isEditing: Bool
    private let draftID: UUID
    private let originalDraft: ExerciseDraft?

    private var tracksResistance: Bool {
        ExerciseResistanceCapability.tracksResistance(
            loadMode: loadMode,
            equipment: classification?.equipment
        )
    }

    init(target: ConfigureExerciseTarget, history: ExerciseHistorySummary? = nil, onCommit: @escaping (ExerciseDraft) -> Void) {
        self.target = target
        self.onCommit = onCommit
        let signature: ExercisePerformanceSignature = switch target {
        case let .adding(item): item.performanceSignature
        case let .editing(draft):
            ExercisePerformanceSignature(modality: draft.modality, trackingMode: draft.trackingMode,
                                         loadMode: draft.loadMode, bodyweightFraction: draft.bodyweightFraction, tracksResistance: draft.tracksResistance)
        }
        let last = history?.mostRecentInstance(matching: signature)
        lastWeights = last?.completedSetPrescription.map(\.weight) ?? []
        lastDate = last?.date
        switch target {
        case let .adding(item):
            name = item.name
            catalogItemID = item.id
            catalogID = item.catalogID
            familyID = item.familyID
            group = item.group
            muscleInvolvement = item.muscleInvolvement
            classification = item.classification
            mode = item.trackingMode
            modality = item.modality
            loadMode = item.loadMode
            bodyweightFraction = item.bodyweightFraction
            _sets = State(initialValue: 3)
            _reps = State(initialValue: item.defaultReps)
            _weight = State(initialValue: lastWeights.first ?? 0)
            _loadPolicy = State(initialValue: .lastWorkout)
            _hasStartingLoad = State(initialValue: !lastWeights.isEmpty)
            _duration = State(initialValue: item.defaultDuration > 0 ? item.defaultDuration : 45)
            isEditing = false
            draftID = UUID()
            originalDraft = nil
        case let .editing(draft):
            name = draft.name
            catalogItemID = draft.catalogItemID
            catalogID = draft.catalogID
            familyID = draft.familyID
            group = draft.group
            muscleInvolvement = Muscle.Involvement(snapshot: draft.muscleInvolvementSnapshot)
            classification = draft.classification
            mode = draft.trackingMode
            modality = draft.modality
            loadMode = draft.loadMode
            bodyweightFraction = draft.bodyweightFraction
            _sets = State(initialValue: draft.plannedSets)
            _reps = State(initialValue: draft.plannedReps)
            _weight = State(initialValue: draft.plannedWeight)
            _loadPolicy = State(initialValue: draft.loadPolicy)
            _hasStartingLoad = State(initialValue: draft.hasStartingLoad)
            _duration = State(initialValue: draft.plannedDuration > 0 ? draft.plannedDuration : 45)
            isEditing = true
            draftID = draft.id
            originalDraft = draft
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    header

                    valueRow(label: "Sets") {
                        BareScrubber(
                            value: setsBinding,
                            range: 1 ... 12,
                            step: 1,
                            pointsPerStep: 18,
                            fontSize: 56,
                            numberColor: Ink.primary,
                            accessibilityLabel: "Sets"
                        )
                    }

                    SectionDivider()

                    switch mode {
                    case .reps:
                        valueRow(label: "Target reps") {
                            BareScrubber(
                                value: repsBinding,
                                range: 1 ... 50,
                                step: 1,
                                pointsPerStep: 16,
                                fontSize: 56,
                                numberColor: Ink.primary,
                                accessibilityLabel: "Target reps"
                            )
                        }
                    case .duration:
                        valueRow(label: modality.durationLabel) {
                            BareScrubber(
                                value: durationBinding,
                                range: DurationFormatter.scrubRange,
                                step: DurationFormatter.scrubStep,
                                pointsPerStep: 10,
                                fontSize: 56,
                                numberColor: Ink.primary,
                                formatter: { DurationFormatter.string($0) },
                                accessibilityLabel: modality.durationLabel
                            )
                        }
                    }

                    if tracksResistance {
                        SectionDivider()
                        TemplateLoadControls(policy: $loadPolicy, weight: $weight, hasStartingLoad: $hasStartingLoad,
                                             loadMode: loadMode, unit: unit, lastWeights: lastWeights, lastDate: lastDate)
                    }
                }
                .padding(.top, Space.lg)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .screenBackground()
            .safeAreaBar(edge: .bottom) { commitBar }
            .navigationTitle(isEditing ? "Edit Exercise" : "Configure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(group.displayName)
                .sectionLabelStyle(Opacity.soft)
            Text(name)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Value row

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

    // MARK: - Commit bar

    private var commitBar: some View {
        VStack(spacing: Space.md) {
            Text(previewLine)
                .font(Typography.metricInline)
                .foregroundStyle(Ink.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryActionButton(
                title: isEditing ? "Save Changes" : "Add to Template",
                subtitle: nil,
                inputLabels: isEditing
                    ? ["Save Changes", "Save", "Done"]
                    : ["Add to Template", "Add", "Save"]
            ) {
                onCommit(buildDraft())
                dismiss()
            }
            .disabled(tracksResistance && !hasStartingLoad && (loadPolicy == .fixed || lastWeights.isEmpty))
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.md)
        .padding(.bottom, Space.sm)
    }

    private var previewLine: String {
        mode == .reps ? "\(sets) × \(reps)"
            : "\(sets) × \(DurationFormatter.string(duration)) \(modality.durationLabelLowercased)"
    }

    // MARK: - Bindings

    private var setsBinding: Binding<Double> {
        Binding(
            get: { Double(sets) },
            set: { sets = Int($0) }
        )
    }

    private var repsBinding: Binding<Double> {
        Binding(
            get: { Double(reps) },
            set: { reps = Int($0) }
        )
    }

    private var durationBinding: Binding<Double> {
        Binding(
            get: { duration },
            set: { duration = $0 }
        )
    }

    // MARK: - Draft

    private func buildDraft() -> ExerciseDraft {
        if let originalDraft, originalDraft.isPerSet {
            return ExerciseDraft(
                id: draftID,
                name: name,
                catalogItemID: originalDraft.catalogItemID,
                catalogID: originalDraft.catalogID,
                familyID: originalDraft.familyID,
                group: group,
                plannedSets: originalDraft.plannedSets,
                plannedReps: originalDraft.plannedReps,
                plannedWeight: originalDraft.plannedWeight,
                loadPolicy: .fixed,
                hasStartingLoad: originalDraft.hasStartingLoad,
                muscleInvolvement: Muscle.Involvement(snapshot: originalDraft.muscleInvolvementSnapshot),
                classification: originalDraft.classification,
                trackingMode: mode,
                modality: originalDraft.modality,
                loadMode: originalDraft.loadMode,
                bodyweightFraction: originalDraft.bodyweightFraction,
                plannedDuration: originalDraft.plannedDuration,
                isPerSet: true,
                sets: originalDraft.sets
            )
        }

        return ExerciseDraft(
            id: draftID,
            name: name,
            catalogItemID: catalogItemID,
            catalogID: catalogID,
            familyID: familyID,
            group: group,
            plannedSets: sets,
            plannedReps: reps,
            plannedWeight: tracksResistance ? weight : 0,
            loadPolicy: loadPolicy,
            hasStartingLoad: hasStartingLoad,
            muscleInvolvement: muscleInvolvement,
            classification: classification,
            trackingMode: mode,
            modality: modality,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction,
            plannedDuration: duration,
            isPerSet: false,
            sets: []
        )
    }
}
