//
//  ActiveExerciseInstrumentInput.swift
//  vivobody
//
//  Immutable, model-free presentation input for one active exercise card.
//  The assembler owns phase, set-status, resistance, modality, and primary-
//  action decisions so focused SwiftUI leaves do not reach into a session.
//

import Foundation

nonisolated struct ActiveExerciseSetSnapshot: Equatable {
    let id: UUID
    let weight: Double
    let reps: Int
    let duration: TimeInterval
    let isCompleted: Bool
}

nonisolated enum ActiveSetIndicatorStatus: Equatable {
    case completed
    case current
    case pending
}

nonisolated struct ActiveSetIndicatorInput: Equatable, Identifiable {
    let id: UUID
    let number: Int
    let status: ActiveSetIndicatorStatus
    let completedValue: String?
    let visibleReading: String?
    let canRemove: Bool

    var accessibilityValue: String {
        switch status {
        case .completed:
            "Completed, \(completedValue ?? "")"
        case .current:
            "Current"
        case .pending:
            "Pending"
        }
    }
}

nonisolated struct ActiveExerciseIdentityInput: Equatable {
    let name: String
    let supersetTag: String?
    let sets: [ActiveSetIndicatorInput]
}

nonisolated struct ActiveWeightIncrementInput: Equatable {
    let selected: Double
    let options: [Double]
    let unit: WeightUnit

    var label: String {
        selected.formatted(
            .number.precision(.fractionLength(0 ... 2))
        ) + " \(unit.symbol)"
    }

    func next() -> Double {
        let index = options.firstIndex(of: selected) ?? 0
        return options[(index + 1) % options.count]
    }
}

nonisolated struct ActiveExerciseConfigurationInput: Equatable {
    let setCount: Int
    let removableSetID: UUID?
    let weightIncrement: ActiveWeightIncrementInput?

    var setLegend: String {
        setCount == 1 ? "SET" : "SETS"
    }
}

nonisolated enum ActiveResistanceInstrumentStyle: Equatable {
    case unloaded
    case bodyweightAdded
    case enteredLoad
}

nonisolated struct ActiveExerciseInstrumentInput: Equatable {
    let modality: ExerciseModality
    let loadMode: ExerciseLoadMode
    let tracksResistance: Bool
    let unit: WeightUnit
    let weightStep: Double
    let isActivePage: Bool
    let scrubCancellationID: Int

    var resistanceStyle: ActiveResistanceInstrumentStyle {
        if !tracksResistance { return .unloaded }
        return loadMode == .bodyweightAdded ? .bodyweightAdded : .enteredLoad
    }

    var loadInputLabel: String {
        loadMode.inputLabel
    }

    var showsAssistanceDirection: Bool {
        loadMode == .assistanceSubtracted
    }

    func loadUnit(for displayedWeight: Double) -> String {
        if loadMode == .nonComparable, displayedWeight <= 0 { return "" }
        return unit.symbol
    }

    func loadText(for displayedWeight: Double) -> String? {
        guard loadMode == .nonComparable else { return nil }
        guard displayedWeight > 0 else { return "Not set" }
        return displayedWeight.formatted(
            .number.precision(.fractionLength(0 ... 2))
        )
    }

    func resistanceAccessibilityValue(for displayedWeight: Double) -> String {
        let number = loadText(for: displayedWeight) ?? ""
        let unit = loadUnit(for: displayedWeight)
        return number + (unit.isEmpty ? "" : " \(unit)")
    }
}

nonisolated struct ActiveCompletedRepsInput: Equatable {
    let isUnloaded: Bool
    let weightText: String
    let repsText: String
}

nonisolated struct ActiveRepsInstrumentInput: Equatable {
    enum Phase: Equatable {
        case active
        case completed(ActiveCompletedRepsInput)
    }

    let instrument: ActiveExerciseInstrumentInput
    let phase: Phase
}

nonisolated struct ActiveCompletedDurationInput: Equatable {
    let durationLabel: String
    let timeText: String
    let loadText: String?
    let accessibilityLabel: String
}

nonisolated struct ActiveDurationInstrumentInput: Equatable {
    enum Phase: Equatable {
        case active
        case completed(ActiveCompletedDurationInput)
    }

    let instrument: ActiveExerciseInstrumentInput
    let phase: Phase
}

nonisolated enum ActiveExerciseMetricInput: Equatable {
    case empty
    case reps(ActiveRepsInstrumentInput)
    case duration(ActiveDurationInstrumentInput)
}

nonisolated struct ActiveSetCompletionButtonInput: Equatable {
    let setID: UUID
    let reps: Int
    let weight: Double
    let loadMode: ExerciseLoadMode
    let isPending: Bool
    let isLastSet: Bool
    let title: String
    let accessibilityLabelOverride: String?
}

nonisolated enum ActiveExercisePrimaryActionInput: Equatable {
    case addFirstSet
    case complete(ActiveSetCompletionButtonInput)
    case exerciseComplete
}

nonisolated struct ActiveExerciseEffortActionInput: Equatable {
    let showsRIRControl: Bool
    let primaryAction: ActiveExercisePrimaryActionInput
}

nonisolated struct ActiveExerciseCardInput: Equatable {
    let identity: ActiveExerciseIdentityInput
    let configuration: ActiveExerciseConfigurationInput
    let metric: ActiveExerciseMetricInput
    let effortAction: ActiveExerciseEffortActionInput
}

nonisolated struct ActiveExerciseCardSource: Equatable {
    let name: String
    let supersetTag: String?
    let trackingMode: TrackingMode
    let modality: ExerciseModality
    let loadMode: ExerciseLoadMode
    let tracksResistance: Bool
    let unit: WeightUnit
    let weightStep: Double
    let isActivePage: Bool
    let scrubCancellationID: Int
    let orderedSets: [ActiveExerciseSetSnapshot]
    let activeSetID: UUID?
    let pendingCompletionSetID: UUID?

    func makeInput() -> ActiveExerciseCardInput {
        let activeIndex = activeSetID.flatMap { id in
            orderedSets.firstIndex(where: { $0.id == id })
        }
        let activeSet = activeIndex.map { orderedSets[$0] }
        let newestCompletedID = orderedSets.last(where: \.isCompleted)?.id
        let indicators = orderedSets.enumerated().map { index, set in
            let completedValue = set.isCompleted ? setLabel(for: set) : nil
            return ActiveSetIndicatorInput(
                id: set.id,
                number: index + 1,
                status: set.isCompleted
                    ? .completed
                    : (set.id == activeSetID ? .current : .pending),
                completedValue: completedValue,
                visibleReading: set.id == newestCompletedID ? completedValue : nil,
                canRemove: !set.isCompleted && orderedSets.count > 1
            )
        }
        let removableSetID = orderedSets.count > 1
            ? orderedSets.last(where: { !$0.isCompleted })?.id
            : nil
        let instrument = ActiveExerciseInstrumentInput(
            modality: modality,
            loadMode: loadMode,
            tracksResistance: tracksResistance,
            unit: unit,
            weightStep: weightStep,
            isActivePage: isActivePage,
            scrubCancellationID: scrubCancellationID
        )
        let configuration = ActiveExerciseConfigurationInput(
            setCount: orderedSets.count,
            removableSetID: removableSetID,
            weightIncrement: activeSet != nil && trackingMode == .reps && tracksResistance
                ? ActiveWeightIncrementInput(
                    selected: weightStep,
                    options: unit.strengthStepOptions,
                    unit: unit
                )
                : nil
        )
        let metric = makeMetricInput(instrument: instrument, activeSet: activeSet)
        let action = makePrimaryAction(activeSet: activeSet, activeIndex: activeIndex)
        return ActiveExerciseCardInput(
            identity: ActiveExerciseIdentityInput(
                name: name,
                supersetTag: supersetTag,
                sets: indicators
            ),
            configuration: configuration,
            metric: metric,
            effortAction: ActiveExerciseEffortActionInput(
                showsRIRControl: activeSet != nil
                    && trackingMode == .reps
                    && modality == .dynamicStrength,
                primaryAction: action
            )
        )
    }

    private func makeMetricInput(
        instrument: ActiveExerciseInstrumentInput,
        activeSet: ActiveExerciseSetSnapshot?
    ) -> ActiveExerciseMetricInput {
        guard !orderedSets.isEmpty else { return .empty }
        let top = orderedSets.last(where: \.isCompleted) ?? orderedSets.last
        switch trackingMode {
        case .reps:
            let phase: ActiveRepsInstrumentInput.Phase
            if activeSet != nil {
                phase = .active
            } else {
                let repsText = top.map { "\($0.reps)" } ?? "—"
                let weightText = top.flatMap {
                    loadMode.summaryLoadLabel($0.weight, unit: unit)
                } ?? "—"
                phase = .completed(
                    ActiveCompletedRepsInput(
                        isUnloaded: !tracksResistance,
                        weightText: weightText,
                        repsText: repsText
                    )
                )
            }
            return .reps(ActiveRepsInstrumentInput(instrument: instrument, phase: phase))
        case .duration:
            let phase: ActiveDurationInstrumentInput.Phase
            if activeSet != nil {
                phase = .active
            } else {
                let timeText = top.map { DurationFormatter.string($0.duration) } ?? "—"
                let loadText = top.flatMap {
                    loadMode.summaryLoadLabel($0.weight, unit: unit)
                }
                let accessibilityLoad = top.flatMap {
                    loadMode.accessibilityLoadDescription($0.weight, unit: unit)
                }
                let accessibilityLabel = "\(modality.durationLabel) \(timeText)"
                    + (accessibilityLoad.map { ", \($0)" } ?? "")
                phase = .completed(
                    ActiveCompletedDurationInput(
                        durationLabel: modality.durationLabel,
                        timeText: timeText,
                        loadText: loadText,
                        accessibilityLabel: accessibilityLabel
                    )
                )
            }
            return .duration(
                ActiveDurationInstrumentInput(instrument: instrument, phase: phase)
            )
        }
    }

    private func makePrimaryAction(
        activeSet: ActiveExerciseSetSnapshot?,
        activeIndex: Int?
    ) -> ActiveExercisePrimaryActionInput {
        guard !orderedSets.isEmpty else { return .addFirstSet }
        guard let activeSet, let activeIndex else { return .exerciseComplete }
        let isLastSet = activeIndex == orderedSets.count - 1
        let accessibilityLabel: String? = if trackingMode == .duration {
            "\(modality.durationLabel) \(DurationFormatter.string(activeSet.duration))"
                + (loadMode.accessibilityLoadDescription(activeSet.weight, unit: unit)
                    .map { ", \($0)" } ?? "")
        } else {
            nil
        }
        return .complete(
            ActiveSetCompletionButtonInput(
                setID: activeSet.id,
                reps: activeSet.reps,
                weight: activeSet.weight,
                loadMode: loadMode,
                isPending: pendingCompletionSetID == activeSet.id,
                isLastSet: isLastSet,
                title: completionTitle(isLastSet: isLastSet),
                accessibilityLabelOverride: accessibilityLabel
            )
        )
    }

    private func completionTitle(isLastSet: Bool) -> String {
        if trackingMode == .duration {
            let verb = isLastSet ? "Finish" : "Complete"
            return "\(verb) \(modality.durationLabelLowercased)"
        }
        return isLastSet ? "Finish exercise" : "Complete set"
    }

    private func setLabel(for set: ActiveExerciseSetSnapshot) -> String {
        SetSpecFormatter.format(
            weight: set.weight,
            reps: set.reps,
            duration: set.duration,
            trackingMode: trackingMode,
            loadMode: loadMode,
            unit: unit
        )
    }
}
