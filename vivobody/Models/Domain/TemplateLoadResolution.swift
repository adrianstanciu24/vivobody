//
//  TemplateLoadResolution.swift
//  vivobody
//
//  Resolves remembered template loads independently of workout structure.
//  Preview and startup share the same set-by-set values and exact history match.
//

import Foundation

nonisolated enum TemplateLoadPolicy: String, CaseIterable, Hashable {
    case lastWorkout
    case fixed

    var title: String {
        switch self {
        case .lastWorkout: "Use last workout"
        case .fixed: "Fixed load"
        }
    }
}

nonisolated struct TemplateLoadResolution: Equatable {
    let weights: [Double]?
    let source: String
    let date: Date?

    func summary(loadMode: ExerciseLoadMode, unit: WeightUnit) -> String {
        guard let weights, !weights.isEmpty else { return "Set starting load" }
        let labels = weights.map { loadMode.summaryLoadLabel($0, unit: unit) ?? (loadMode == .nonComparable ? "Not set" : WeightFormatter.string($0, unit: unit, includeUnit: true)) }
        let values = Set(labels).count == 1
            ? labels[0]
            : labels.prefix(5).enumerated().map { "Set \($0.offset + 1): \($0.element)" }.joined(separator: " · ")
            + (labels.count > 5 ? " · +\(labels.count - 5) sets" : "")
        let stamp = date.map { " · \($0.formatted(.dateTime.month(.abbreviated).day().year()))" } ?? ""
        return "\(source): \(values)\(stamp)"
    }

    static func resolve(
        policy: TemplateLoadPolicy,
        setCount: Int,
        startingWeight: Double?,
        lastWeights: [Double],
        lastDate: Date?
    ) -> Self {
        if policy == .lastWorkout, !lastWeights.isEmpty {
            return Self(
                weights: (0 ..< max(0, setCount)).map { lastWeights[min($0, lastWeights.count - 1)] },
                source: "Last used",
                date: lastDate
            )
        }
        return Self(
            weights: startingWeight.map { Array(repeating: $0, count: max(0, setCount)) },
            source: policy == .fixed ? "Fixed" : "Starting load",
            date: nil
        )
    }
}

extension TemplateExercise {
    func resolveLoad(history: ExerciseHistorySummary?) -> TemplateLoadResolution {
        if hasPerSetData {
            return TemplateLoadResolution(weights: orderedSets.map { trackedWeight($0.weight) }, source: "Fixed", date: nil)
        }
        let last = history?.mostRecentInstance(matching: performanceSignature)
        return TemplateLoadResolution.resolve(
            policy: loadPolicy,
            setCount: plannedSets,
            startingWeight: hasStartingLoad || !tracksResistance ? trackedWeight(plannedWeight) : nil,
            lastWeights: last?.completedSetPrescription.map { trackedWeight($0.weight) } ?? [],
            lastDate: last?.date
        )
    }
}

struct TemplateStartingLoadRequired: LocalizedError {
    let exerciseName: String

    var errorDescription: String? {
        "Set a starting load for \(exerciseName) in the template before starting this workout."
    }
}
