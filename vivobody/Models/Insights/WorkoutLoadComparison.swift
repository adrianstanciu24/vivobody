//
//  WorkoutLoadComparison.swift
//  vivobody
//
//  Pure normalized-progress semantics for comparing one workout's cumulative
//  comparable volume with the cached average shape of archived workouts.
//

import Foundation

nonisolated struct WorkoutLoadPoint: Hashable, Identifiable {
    let progress: Double
    let value: Double

    var id: Double {
        progress
    }
}

/// Comparable load from ordered completed sets. Progress is normalized because
/// sets do not carry completion timestamps and workouts have different lengths.
nonisolated struct WorkoutLoadTrace: Hashable {
    let setLoads: [Double]
    let availability: ComparableTonnageAvailability

    var total: Double {
        setLoads.reduce(0, +)
    }

    var points: [WorkoutLoadPoint] {
        guard !setLoads.isEmpty else { return [] }
        var cumulative = 0.0
        var result = [WorkoutLoadPoint(progress: 0, value: 0)]
        result.reserveCapacity(setLoads.count + 1)
        for (index, load) in setLoads.enumerated() {
            cumulative += load
            result.append(WorkoutLoadPoint(
                progress: Double(index + 1) / Double(setLoads.count),
                value: cumulative
            ))
        }
        return result
    }

    init(
        setLoads: [Double],
        availability: ComparableTonnageAvailability = .complete
    ) {
        self.setLoads = setLoads.map { value in
            value.isFinite ? max(0, value) : 0
        }
        self.availability = availability
    }

    @MainActor
    init(session: WorkoutSession) {
        var loads: [Double] = []
        var hasMissingLoad = false

        for exercise in session.orderedExercises where exercise.modality.supportsComparableTonnage(
            for: exercise.trackingMode,
            loadMode: exercise.loadMode
        ) {
            for set in exercise.orderedSets where set.isAnalyticsEligible && set.reps > 0 {
                guard let load = exercise.effectiveLoad(loggedWeight: set.weight) else {
                    hasMissingLoad = true
                    continue
                }
                loads.append(max(0, load) * Double(set.reps))
            }
        }

        setLoads = loads
        availability = Self.availability(hasMissingLoad: hasMissingLoad, loads: loads)
    }

    init(snapshot: AnalyticsSessionSnapshot) {
        var loads: [Double] = []
        var hasMissingLoad = false

        for exercise in snapshot.exercises where exercise.modality.supportsComparableTonnage(
            for: exercise.trackingMode,
            loadMode: exercise.loadMode
        ) {
            for set in exercise.sets where set.isAnalyticsEligible && set.reps > 0 {
                guard let load = exercise.effectiveLoad(loggedWeight: set.weight) else {
                    hasMissingLoad = true
                    continue
                }
                loads.append(max(0, load) * Double(set.reps))
            }
        }

        setLoads = loads
        availability = Self.availability(hasMissingLoad: hasMissingLoad, loads: loads)
    }

    func value(at progress: Double) -> Double {
        guard !setLoads.isEmpty else { return 0 }
        let bounded = min(1, max(0, progress))
        let position = bounded * Double(setLoads.count)
        let completedCount = min(setLoads.count, Int(position.rounded(.down)))
        let completed = setLoads.prefix(completedCount).reduce(0, +)
        guard completedCount < setLoads.count else { return completed }
        let fractional = position - Double(completedCount)
        return completed + setLoads[completedCount] * fractional
    }

    private static func availability(
        hasMissingLoad: Bool,
        loads: [Double]
    ) -> ComparableTonnageAvailability {
        guard hasMissingLoad else { return .complete }
        return loads.isEmpty ? .unavailable : .partial
    }
}

/// Archive-owned benchmark, built once with the other core analytics reports.
nonisolated struct WorkoutLoadBaseline: Hashable {
    static let empty = WorkoutLoadBaseline(points: [], workoutCount: 0)
    static let sampleCount = 12

    let points: [WorkoutLoadPoint]
    let workoutCount: Int

    var averageTotal: Double {
        points.last?.value ?? 0
    }

    static func make(from sessions: [AnalyticsSessionReplay]) -> WorkoutLoadBaseline {
        make(traces: sessions.compactMap { replay in
            guard replay.isCompleted else { return nil }
            return WorkoutLoadTrace(snapshot: replay.session)
        })
    }

    static func make(traces: [WorkoutLoadTrace]) -> WorkoutLoadBaseline {
        let comparable = traces.filter {
            $0.availability == .complete && $0.total > 0
        }
        guard !comparable.isEmpty else { return .empty }

        let points = (0 ... sampleCount).map { index in
            let progress = Double(index) / Double(sampleCount)
            let total = comparable.reduce(0) { sum, trace in
                sum + trace.value(at: progress)
            }
            return WorkoutLoadPoint(
                progress: progress,
                value: total / Double(comparable.count)
            )
        }
        return WorkoutLoadBaseline(points: points, workoutCount: comparable.count)
    }
}

nonisolated struct WorkoutLoadComparison: Hashable {
    let currentPoints: [WorkoutLoadPoint]
    let averagePoints: [WorkoutLoadPoint]
    let currentTotal: Double
    let averageTotal: Double
    let averageWorkoutCount: Int
    let scaleMaximum: Double

    static func make(
        current: WorkoutLoadTrace,
        baseline: WorkoutLoadBaseline
    ) -> WorkoutLoadComparison? {
        guard current.availability == .complete,
              current.total > 0,
              baseline.workoutCount > 0,
              !baseline.points.isEmpty
        else {
            return nil
        }

        let maximum = max(current.total, baseline.averageTotal, 1)
        return WorkoutLoadComparison(
            currentPoints: current.points,
            averagePoints: baseline.points,
            currentTotal: current.total,
            averageTotal: baseline.averageTotal,
            averageWorkoutCount: baseline.workoutCount,
            scaleMaximum: maximum * 1.08
        )
    }
}
