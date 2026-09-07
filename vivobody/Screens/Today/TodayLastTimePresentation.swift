//
//  TodayLastTimePresentation.swift
//  vivobody
//
//  Compact, factual workout preparation from the shared history index.
//  Matches exact performance semantics and displays completed sets only.
//

import Foundation

nonisolated struct TodayLastTimePresentation: Equatable {
    let exerciseName: String
    let dateText: String
    let setsText: String
    let accessibilityLabel: String

    @MainActor
    static func make(
        template: WorkoutTemplate,
        history: [String: ExerciseHistorySummary],
        unit: WeightUnit
    ) -> Self? {
        for exercise in template.orderedExercises {
            guard let instance = history[exercise.historyKey]?.mostRecentInstance(
                matching: exercise.performanceSignature
            ), !instance.completedSetPrescription.isEmpty else { continue }
            return Self(exerciseName: exercise.name, instance: instance, unit: unit)
        }
        return nil
    }

    init(exerciseName: String, instance: ExerciseHistoryInstance, unit: WeightUnit) {
        self.exerciseName = exerciseName
        dateText = instance.date.formatted(.dateTime.month(.abbreviated).day().year())
        let sets = instance.completedSetPrescription
        let visible = Array(sets.prefix(5))
        let sameWeight = Set(visible.map(\.weight)).count == 1
        let values = visible.map { set in
            let value = instance.trackingMode == .reps
                ? "\(set.reps)"
                : DurationFormatter.string(set.duration)
            guard !sameWeight,
                  let load = instance.loadMode.summaryLoadLabel(set.weight, unit: unit)
            else { return value }
            return "\(load) × \(value)"
        }.joined(separator: " / ")
        let suffix = instance.trackingMode == .reps ? " reps" : ""
        let load = sameWeight ? visible.first.flatMap {
            instance.loadMode.summaryLoadLabel($0.weight, unit: unit)
        } : nil
        let overflow = sets.count > visible.count ? " · +\(sets.count - visible.count) sets" : ""
        setsText = [load, values + suffix].compactMap(\.self).joined(separator: " · ") + overflow
        accessibilityLabel = "Last time, \(dateText), \(exerciseName), \(setsText)"
    }
}
