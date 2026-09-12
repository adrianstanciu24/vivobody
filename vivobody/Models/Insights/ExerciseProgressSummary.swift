//
//  ExerciseProgressSummary.swift
//  vivobody
//
//  Precomputed full-series records plus binary date-window lookup for one
//  chronological ExerciseProgress series.
//

import Foundation

nonisolated struct ExerciseProgressSummary: Hashable {
    let bestWeightPoint: ExerciseProgressPoint?
    let bestDurationPoint: ExerciseProgressPoint?
    let bestRepsPoint: ExerciseProgressPoint?
    let bestE1RMPoint: ExerciseProgressPoint?
    let latestStrengthPRPoint: ExerciseProgressPoint?
    let strengthPRPointIDs: Set<UUID>
    let e1RMRecordPointIDs: Set<UUID>
    let evaluableCount: Int
    let lastRecordIndex: Int
    let standingPerformance: StrengthPerformance?

    init(points: [ExerciseProgressPoint]) {
        var bestWeight: ExerciseProgressPoint?
        var bestDuration: ExerciseProgressPoint?
        var bestReps: ExerciseProgressPoint?
        var bestE1RM: ExerciseProgressPoint?
        var latestStrengthPR: ExerciseProgressPoint?
        var strengthPRIDs: Set<UUID> = []
        var e1RMRecordIDs: Set<UUID> = []
        var runningE1RM = -Double.infinity
        var runningPerformance: StrengthPerformance?
        var evaluated = 0
        var lastRecord = -1

        for point in points {
            if let load = point.historyTopLoad,
               bestWeight?.historyTopLoad.map({ load > $0 }) ?? true
            {
                bestWeight = point
            }
            if bestDuration.map({ point.topDuration > $0.topDuration }) ?? true {
                bestDuration = point
            }
            if bestReps.map({ point.topReps > $0.topReps }) ?? true {
                bestReps = point
            }
            let estimate = point.estimated1RM
            if estimate > 0,
               bestE1RM.map({ estimate > $0.estimated1RM }) ?? true
            {
                bestE1RM = point
            }
            if point.isStrengthPR {
                latestStrengthPR = point
                strengthPRIDs.insert(point.id)
            }
            if estimate > 0, estimate > runningE1RM {
                runningE1RM = estimate
                e1RMRecordIDs.insert(point.id)
            }
            if let performance = point.strengthPerformance {
                if performance.advancement(over: runningPerformance) != nil {
                    runningPerformance = performance
                    lastRecord = evaluated
                }
                evaluated += 1
            }
        }

        bestWeightPoint = bestWeight
        bestDurationPoint = bestDuration
        bestRepsPoint = bestReps
        bestE1RMPoint = bestE1RM
        latestStrengthPRPoint = latestStrengthPR
        strengthPRPointIDs = strengthPRIDs
        e1RMRecordPointIDs = e1RMRecordIDs
        evaluableCount = evaluated
        lastRecordIndex = lastRecord
        standingPerformance = runningPerformance
    }
}

nonisolated extension ExerciseProgress {
    var bestWeightPoint: ExerciseProgressPoint? {
        summary.bestWeightPoint
    }

    var bestWeight: Double {
        bestWeightPoint?.historyTopLoad ?? 0
    }

    var weightDelta: Double? {
        guard points.count >= 2,
              let latest = points[points.count - 1].historyTopLoad,
              let previous = points[points.count - 2].historyTopLoad
        else { return nil }
        return latest - previous
    }

    var durationDelta: TimeInterval? {
        guard points.count >= 2 else { return nil }
        return points[points.count - 1].topDuration
            - points[points.count - 2].topDuration
    }

    var bestE1RM: Double {
        summary.bestE1RMPoint?.estimated1RM ?? 0
    }

    var bestE1RMPoint: ExerciseProgressPoint? {
        summary.bestE1RMPoint
    }

    var bestDurationPoint: ExerciseProgressPoint? {
        summary.bestDurationPoint
    }

    var bestRepsPoint: ExerciseProgressPoint? {
        summary.bestRepsPoint
    }

    var latestStrengthPRPoint: ExerciseProgressPoint? {
        summary.latestStrengthPRPoint
    }

    var strengthPRPointIDs: Set<UUID> {
        summary.strengthPRPointIDs
    }

    var e1RMRecordPointIDs: Set<UUID> {
        summary.e1RMRecordPointIDs
    }

    func plateauStatus(threshold: Int) -> PlateauStatus? {
        guard performanceSemanticKind.supportsRecord,
              summary.evaluableCount > threshold,
              summary.lastRecordIndex >= 0,
              let runningBest = summary.standingPerformance else { return nil }
        let stale = (summary.evaluableCount - 1) - summary.lastRecordIndex
        guard stale >= threshold else { return nil }
        return PlateauStatus(sessions: stale, performance: runningBest)
    }

    /// Both bounds use binary search, making a range change
    /// O(log H + visiblePoints) instead of O(H).
    func points(
        from cutoff: Date?,
        through end: Date
    ) -> ArraySlice<ExerciseProgressPoint> {
        let lower = cutoff.map(lowerBound(for:)) ?? points.startIndex
        let upper = upperBound(for: end)
        guard lower < upper else {
            return points[points.startIndex ..< points.startIndex]
        }
        return points[lower ..< upper]
    }

    func frequencyPerWeek(now: Date) -> Double? {
        let end = upperBound(for: now)
        guard end >= 2 else { return nil }
        let spanDays = now.timeIntervalSince(points[0].date) / 86400
        guard spanDays >= ExerciseFrequency.minimumSpanDays else { return nil }
        let window = min(ExerciseFrequency.windowDays, spanDays)
        let cutoff = now.addingTimeInterval(-window * 86400)
        return Double(end - lowerBound(for: cutoff)) / (window / 7)
    }

    private func lowerBound(for date: Date) -> Int {
        var lower = points.startIndex
        var upper = points.endIndex
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if points[middle].date < date {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func upperBound(for date: Date) -> Int {
        var lower = points.startIndex
        var upper = points.endIndex
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if points[middle].date <= date {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }
}
