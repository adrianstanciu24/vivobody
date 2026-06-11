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
//  kicker header, a live "3 × 8 @ 135 lb" preview, and a single lime
//  CTA. Nothing is persisted here — the sheet hands a value-type
//  ExerciseDraft back to the builder via `onCommit`, and the builder
//  decides when (and whether) to write it through to SwiftData.
//

import SwiftUI

/// What the configure sheet is operating on. Driven as an
/// Identifiable so the builder can present it via `.sheet(item:)`.
enum ConfigureExerciseTarget: Identifiable {
    /// A fresh catalog pick — defaults seeded from the catalog item.
    case adding(ExerciseCatalogItem)
    /// An existing draft row being revised — fields prefilled.
    case editing(ExerciseDraft)

    var id: String {
        switch self {
        case .adding(let item):   return "add-\(item.id.uuidString)"
        case .editing(let draft): return "edit-\(draft.id.uuidString)"
        }
    }
}

struct ConfigureExerciseSheet: View {
    let target: ConfigureExerciseTarget
    let onCommit: (ExerciseDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var sets: Int
    @State private var reps: Int
    /// Canonical lb — scrubbed in display units, stored as lb.
    @State private var weight: Double
    /// Hold length (seconds) — used only in `.duration` mode.
    @State private var duration: Double

    private let name: String
    private let group: MuscleGroup
    private let mode: TrackingMode
    private let isEditing: Bool
    private let draftID: UUID

    init(target: ConfigureExerciseTarget, onCommit: @escaping (ExerciseDraft) -> Void) {
        self.target = target
        self.onCommit = onCommit
        switch target {
        case .adding(let item):
            name = item.name
            group = item.group
            mode = item.trackingMode
            _sets = State(initialValue: 3)
            _reps = State(initialValue: item.defaultReps)
            _weight = State(initialValue: item.defaultWeight)
            _duration = State(initialValue: item.defaultDuration > 0 ? item.defaultDuration : 45)
            isEditing = false
            draftID = UUID()
        case .editing(let draft):
            name = draft.name
            group = draft.group
            mode = draft.trackingMode
            _sets = State(initialValue: draft.plannedSets)
            _reps = State(initialValue: draft.plannedReps)
            _weight = State(initialValue: draft.plannedWeight)
            _duration = State(initialValue: draft.plannedDuration > 0 ? draft.plannedDuration : 45)
            isEditing = true
            draftID = draft.id
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
                            range: 1...12,
                            step: 1,
                            pointsPerStep: 18,
                            fontSize: 56,
                            numberColor: Ink.primary
                        )
                    }

                    SectionDivider()

                    switch mode {
                    case .reps:
                        valueRow(label: "Target reps") {
                            BareScrubber(
                                value: repsBinding,
                                range: 1...50,
                                step: 1,
                                pointsPerStep: 16,
                                fontSize: 56,
                                numberColor: Ink.primary
                            )
                        }
                    case .duration:
                        valueRow(label: "Hold") {
                            BareScrubber(
                                value: durationBinding,
                                range: DurationFormatter.scrubRange,
                                step: DurationFormatter.scrubStep,
                                pointsPerStep: 10,
                                fontSize: 56,
                                numberColor: Ink.primary,
                                formatter: { DurationFormatter.string($0) }
                            )
                        }
                    }

                    SectionDivider()

                    valueRow(label: mode == .duration ? "Added load" : "Weight") {
                        BareScrubber(
                            value: weightDisplayBinding,
                            range: unit.strengthRange,
                            step: unit.strengthStep,
                            pointsPerStep: 8,
                            fontSize: 56,
                            unit: unit.symbol,
                            unitFontSize: 16,
                            numberColor: Ink.primary,
                            unitColor: Ink.tertiary
                        )
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.lg)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) { commitBar }
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
                .sectionLabelStyle(0.45)
            Text(name)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Value row

    private func valueRow<S: View>(
        label: String,
        @ViewBuilder scrubber: () -> S
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(label)
                .sectionLabelStyle(0.55)
            scrubber()
        }
    }

    // MARK: - Commit bar

    private var commitBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Surface.edge).frame(height: 1)
            VStack(spacing: Space.md) {
                Text(previewLine)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Ink.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PrimaryActionButton(
                    title: isEditing ? "Save Changes" : "Add to Template",
                    subtitle: nil
                ) {
                    onCommit(buildDraft())
                    dismiss()
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.md)
            .padding(.bottom, Space.sm)
        }
        .background(Surface.background.opacity(0.9))
    }

    private var previewLine: String {
        switch mode {
        case .reps:
            return "\(sets) × \(reps) @ \(WeightFormatter.string(weight, unit: unit))"
        case .duration:
            let base = "\(sets) × \(DurationFormatter.string(duration)) hold"
            return weight > 0 ? "\(base) @ \(WeightFormatter.string(weight, unit: unit))" : base
        }
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

    private var weightDisplayBinding: Binding<Double> {
        Binding(
            get: { WeightFormatter.toDisplay(weight, unit: unit) },
            set: { weight = WeightFormatter.toCanonical($0, unit: unit) }
        )
    }

    // MARK: - Draft

    private func buildDraft() -> ExerciseDraft {
        ExerciseDraft(
            id: draftID,
            name: name,
            group: group,
            plannedSets: sets,
            plannedReps: reps,
            plannedWeight: weight,
            trackingMode: mode,
            plannedDuration: duration,
            isPerSet: false,
            sets: []
        )
    }
}
