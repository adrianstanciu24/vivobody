//
//  TodayUpNextPresentation.swift
//  vivobody
//
//  Immutable presentation for Today's scheduled-workout preview. A narrow
//  MainActor adapter snapshots SwiftData templates and strength outlook into
//  primitive values; all formatting, preview limits, and accessibility copy
//  are then derived without store, environment, or UserDefaults access.
//

import Foundation

nonisolated struct TodayUpNextPresentation: Equatable {
    nonisolated struct Source: Equatable {
        nonisolated struct Exercise: Equatable {
            nonisolated struct SetPlan: Equatable {
                let reps: Int
                let duration: TimeInterval
                let weight: Double
            }

            let id: UUID
            let name: String
            let groupName: String
            let historyKey: String
            let trackingModeRaw: String
            let durationLabel: String
            let loadModeRaw: String
            let plannedSets: Int
            let plannedReps: Int
            let plannedDuration: TimeInterval
            let plannedWeight: Double
            let sets: [SetPlan]

            var effectiveSetCount: Int {
                sets.isEmpty ? plannedSets : sets.count
            }
        }

        nonisolated struct NearestPR: Equatable {
            let historyKey: String
            let exerciseName: String
            let currentE1RM: Double
            let bestE1RM: Double
            let isFresh: Bool
        }

        let templateName: String
        let daysUntil: Int
        let otherScheduledCount: Int
        let shouldEaseOff: Bool
        let exercises: [Exercise]
        let nearestPR: NearestPR?
    }

    nonisolated struct Scheme: Equatable {
        let count: String
        let load: String?
        let loadUnit: String?

        var accessibilityText: String {
            [count, load, loadUnit]
                .compactMap(\.self)
                .joined(separator: " ")
        }
    }

    nonisolated struct ExerciseRow: Equatable, Identifiable {
        let id: UUID
        let name: String
        let scheme: Scheme

        var accessibilityLabel: String {
            "\(name), \(scheme.accessibilityText)"
        }
    }

    nonisolated struct Preview: Equatable {
        let rows: [ExerciseRow]
        let remainingCount: Int
    }

    nonisolated struct LoadGuidance: Equatable {
        let text: String
        let accessibilityLabel: String
    }

    let templateName: String
    let scheduleText: String
    let metadata: String
    let durationEstimate: String?
    let muscleSummary: String
    let exerciseRows: [ExerciseRow]
    let prProximityText: String?
    let loadGuidance: LoadGuidance?

    init(
        source: Source,
        unit: WeightUnit,
        defaultRestSeconds: Int
    ) {
        templateName = source.templateName
        scheduleText = Self.scheduleText(daysUntil: source.daysUntil)
        durationEstimate = Self.durationEstimate(
            exercises: source.exercises,
            defaultRestSeconds: defaultRestSeconds
        )
        metadata = Self.metadata(
            exerciseCount: source.exercises.count,
            durationEstimate: durationEstimate,
            otherScheduledCount: source.otherScheduledCount
        )
        muscleSummary = Self.muscleSummary(source.exercises)
        exerciseRows = source.exercises.map { exercise in
            ExerciseRow(
                id: exercise.id,
                name: exercise.name,
                scheme: Self.scheme(for: exercise, unit: unit)
            )
        }
        prProximityText = Self.prProximityText(
            source.nearestPR,
            exercises: source.exercises,
            unit: unit
        )
        loadGuidance = source.shouldEaseOff
            ? LoadGuidance(
                text: "High load, keep this session lighter",
                accessibilityLabel: "High training load, keep this session lighter"
            )
            : nil
    }

    func preview(accessibilityLayout: Bool) -> Preview {
        let limit = accessibilityLayout ? 3 : 5
        let rows = Array(exerciseRows.prefix(limit))
        return Preview(
            rows: rows,
            remainingCount: exerciseRows.count - rows.count
        )
    }

    static func scheduleText(daysUntil: Int) -> String {
        switch daysUntil {
        case 0: "Today"
        case 1: "Tomorrow"
        default: "in \(daysUntil) days"
        }
    }

    private static func durationEstimate(
        exercises: [Source.Exercise],
        defaultRestSeconds: Int
    ) -> String? {
        let sets = exercises.reduce(0) { $0 + $1.effectiveSetCount }
        guard sets > 0 else { return nil }
        let rest = defaultRestSeconds > 0
            ? defaultRestSeconds
            : SettingsDefaults.defaultRestSeconds
        let workSecondsPerSet = 45.0
        let total = Double(sets) * (Double(rest) + workSecondsPerSet)
        let minutes = max(5, Int((total / 60 / 5).rounded()) * 5)
        return "~\(minutes) min"
    }

    private static func metadata(
        exerciseCount: Int,
        durationEstimate: String?,
        otherScheduledCount: Int
    ) -> String {
        var parts = ["\(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises")"]
        if let durationEstimate {
            parts.append(durationEstimate)
        }
        let base = parts.joined(separator: "  ·  ")
        return otherScheduledCount > 0
            ? "\(base)  ·  +\(otherScheduledCount) more"
            : base
    }

    private static func muscleSummary(_ exercises: [Source.Exercise]) -> String {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for exercise in exercises {
            if counts[exercise.groupName] == nil {
                order.append(exercise.groupName)
            }
            counts[exercise.groupName, default: 0] += exercise.effectiveSetCount
        }
        return order
            .map { groupName in
                let sets = counts[groupName] ?? 0
                return "\(groupName) · \(sets) \(sets == 1 ? "set" : "sets")"
            }
            .joined(separator: "   ")
    }

    private static func scheme(
        for exercise: Source.Exercise,
        unit: WeightUnit
    ) -> Scheme {
        let trackingMode = TrackingMode(rawValue: exercise.trackingModeRaw) ?? .reps
        switch trackingMode {
        case .reps:
            return repsScheme(for: exercise, unit: unit)
        case .duration:
            return durationScheme(for: exercise, unit: unit)
        }
    }

    private static func repsScheme(
        for exercise: Source.Exercise,
        unit: WeightUnit
    ) -> Scheme {
        let loadMode = ExerciseLoadMode(rawValue: exercise.loadModeRaw) ?? .external
        guard !exercise.sets.isEmpty else {
            return Scheme(
                count: "\(exercise.plannedSets) × \(exercise.plannedReps)",
                load: loadMode.summaryLoadLabel(exercise.plannedWeight, unit: unit),
                loadUnit: nil
            )
        }

        let reps = exercise.sets.map(\.reps)
        let weights = exercise.sets.map(\.weight)
        guard let lowerReps = reps.min(), let upperReps = reps.max(),
              let lowerWeight = weights.min(), let upperWeight = weights.max()
        else {
            return Scheme(count: "\(exercise.sets.count) sets", load: nil, loadUnit: nil)
        }
        let count = lowerReps == upperReps
            ? "\(exercise.sets.count) × \(lowerReps)"
            : "\(exercise.sets.count) × \(lowerReps)–\(upperReps)"
        let load = lowerWeight == upperWeight
            ? loadMode.summaryLoadLabel(lowerWeight, unit: unit)
            : loadMode.summaryLoadRangeLabel(lowerWeight, upperWeight, unit: unit)
        return Scheme(count: count, load: load, loadUnit: nil)
    }

    private static func durationScheme(
        for exercise: Source.Exercise,
        unit: WeightUnit
    ) -> Scheme {
        let loadMode = ExerciseLoadMode(rawValue: exercise.loadModeRaw) ?? .external
        let count: String
        let duration: String
        let weights: [Double]

        if exercise.sets.isEmpty {
            count = "\(exercise.plannedSets) ×"
            duration = DurationFormatter.string(exercise.plannedDuration)
            weights = [exercise.plannedWeight]
        } else {
            count = "\(exercise.sets.count) ×"
            let durations = exercise.sets.map(\.duration)
            guard let lower = durations.min(), let upper = durations.max() else {
                return Scheme(count: "\(exercise.sets.count) sets", load: nil, loadUnit: nil)
            }
            duration = lower == upper
                ? DurationFormatter.string(lower)
                : "\(DurationFormatter.string(lower))–\(DurationFormatter.string(upper))"
            weights = exercise.sets.map(\.weight)
        }

        let load: String? = if let lower = weights.min(), let upper = weights.max() {
            lower == upper
                ? loadMode.summaryLoadLabel(lower, unit: unit)
                : loadMode.summaryLoadRangeLabel(lower, upper, unit: unit)
        } else {
            nil
        }
        let details = ([exercise.durationLabel] + (load.map { ["·", $0] } ?? []))
            .joined(separator: " ")
        return Scheme(count: count, load: duration, loadUnit: details)
    }

    private static func prProximityText(
        _ nearestPR: Source.NearestPR?,
        exercises: [Source.Exercise],
        unit: WeightUnit
    ) -> String? {
        guard let nearestPR, !nearestPR.isFresh else { return nil }
        let gap = nearestPR.bestE1RM - nearestPR.currentE1RM
        guard gap >= 1 else { return nil }
        guard exercises.contains(where: { $0.historyKey == nearestPR.historyKey }) else {
            return nil
        }
        let value = WeightFormatter.string(gap, unit: unit, includeUnit: false)
        return "\(value) \(unit.symbol) from \(article(for: nearestPR.exerciseName)) \(nearestPR.exerciseName) PR"
    }

    static func article(for name: String) -> String {
        guard let first = name.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }
}

extension TodayUpNextPresentation.Source {
    @MainActor
    init(
        template: WorkoutTemplate,
        daysUntil: Int,
        otherScheduledCount: Int,
        shouldEaseOff: Bool,
        outlook: StrengthOutlookBoard
    ) {
        let exercises = template.orderedExercises.map { exercise in
            Exercise(
                id: exercise.id,
                name: exercise.name,
                groupName: exercise.group.displayName,
                historyKey: exercise.historyKey,
                trackingModeRaw: exercise.trackingMode.rawValue,
                durationLabel: exercise.modality.durationLabelLowercased,
                loadModeRaw: exercise.loadMode.rawValue,
                plannedSets: exercise.plannedSets,
                plannedReps: exercise.plannedReps,
                plannedDuration: exercise.plannedDuration,
                plannedWeight: exercise.trackedWeight(exercise.plannedWeight),
                sets: exercise.orderedSets.map { set in
                    Exercise.SetPlan(
                        reps: set.reps,
                        duration: set.duration,
                        weight: exercise.trackedWeight(set.weight)
                    )
                }
            )
        }
        let nearestPR = outlook.nearestPR.map { stat in
            NearestPR(
                historyKey: stat.historyKey,
                exerciseName: stat.exercise,
                currentE1RM: stat.currentE1RM,
                bestE1RM: stat.bestE1RM,
                isFresh: stat.isFreshPR
            )
        }
        self.init(
            templateName: template.name,
            daysUntil: daysUntil,
            otherScheduledCount: otherScheduledCount,
            shouldEaseOff: shouldEaseOff,
            exercises: exercises,
            nearestPR: nearestPR
        )
    }
}
