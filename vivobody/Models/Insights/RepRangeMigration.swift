//
//  RepRangeMigration.swift
//  vivobody
//
//  The rep-range drift instrument for the Insights tab. IntensityMix
//  snapshots the recent low / moderate / high-rep split; this asks the
//  longer, descriptive question: over the last 12 calendar weeks, is
//  the average rep count per completed set moving up or down?
//
//  Completed dynamic-strength `.reps` sets are bucketed by the user's
//  locale-aware week start. Each week's average is weighted in the
//  regression by its completed-set count, so a one-set week cannot
//  pull as hard as a high-volume week. The slope is reported directly
//  in reps/week and mapped to a verdict:
//    • towardEndurance — slope ≥ +0.1 reps/week (sets trending higher-rep)
//    • towardStrength  — slope ≤ -0.1 reps/week (sets trending heavier)
//    • stable          — |slope| < 0.1 reps/week
//
//  Timed (`.duration`) holds, power work, and mismatched tracking pairs
//  are excluded, as are incomplete sets and sets logged with zero reps. Pure value type on
//  injected dates, so it's testable on a virtual clock (see
//  `RepRangeMigrationTests`).
//

import Foundation

// MARK: - Verdict

nonisolated enum RepDriftVerdict: Hashable {
    case towardStrength
    case stable
    case towardEndurance
}

/// How much evidence supports the fitted rep-range direction.
nonisolated enum RepTrendConfidence: Hashable {
    case insufficient
    case emerging
    case established
}

// MARK: - Weekly point

/// One week's average-reps sample on the migration curve.
nonisolated struct RepRangePoint: Identifiable, Hashable {
    var id: Date {
        weekStart
    }

    /// Calendar week start (Sunday/Monday per current calendar) the
    /// bucket's sets fall into.
    let weekStart: Date
    /// Mean reps per completed `.reps` set that week.
    let averageReps: Double
    /// Number of completed sets the average was drawn from.
    let sets: Int
}

// MARK: - Report

nonisolated struct RepRangeMigrationReport {
    static let minimumTrendWeeks = 3
    static let minimumTrendSets = 12
    static let establishedTrendWeeks = 6
    static let establishedTrendSets = 30

    /// Weekly average-reps samples, chronological ascending.
    let points: [RepRangePoint]
    /// Fitted slope in reps per week (0 when there's no trend yet).
    let slopePerWeek: Double
    /// Most recent week's average reps (0 when there are no points).
    let currentAverage: Double
    /// Earliest week's average reps (0 when there are no points).
    let earlierAverage: Double
    /// Direction the average rep count is drifting.
    let verdict: RepDriftVerdict
    /// Evidence tier derived from both active weeks and completed sets.
    let confidence: RepTrendConfidence
    /// Completed sets represented by all weekly points.
    let totalSets: Int
    /// `true` once the minimum active-week and set-count floors are met.
    var hasTrend: Bool {
        confidence != .insufficient
    }

    /// `true` when there's at least one weekly sample.
    var hasData: Bool {
        !points.isEmpty
    }
}

// MARK: - Aggregation

@MainActor
extension [WorkoutSession] {
    /// Average-reps-per-set trend over the trailing `weeks` (default
    /// 12) as of `now`. Buckets completed `.reps` sets by locale-aware
    /// calendar week, fits a set-weighted least-squares line, and
    /// reports its direction and confidence.
    func repRangeMigration(weeks: Int = 12, now: Date = Date()) -> RepRangeMigrationReport {
        AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: self)
        ).repRangeMigration(weeks: weeks, now: now)
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Snapshot-backed rep-range drift used by the background
    /// analytics worker.
    func repRangeMigration(
        weeks: Int = 12,
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> RepRangeMigrationReport {
        let cancelled = Self.cancelledRepRangeReport
        guard !isCancelled() else { return cancelled }

        let calendar = Calendar.current
        guard let window = RepRangeWeekWindow.make(
            weeks: weeks,
            now: now,
            calendar: calendar
        ) else { return cancelled }
        guard let totals = repRangeWeekTotals(
            window: window,
            now: now,
            calendar: calendar,
            isCancelled: isCancelled
        ) else { return cancelled }
        guard let points = Self.repRangePoints(
            weekStarts: window.weekStarts,
            totals: totals,
            isCancelled: isCancelled
        ) else { return cancelled }

        let totalSets = points.reduce(0) { $0 + $1.sets }
        let confidence = Self.repTrendConfidence(points: points, totalSets: totalSets)

        // Thin samples retain their observed weekly averages but do
        // not manufacture a direction.
        guard confidence != .insufficient else {
            return RepRangeMigrationReport(
                points: points,
                slopePerWeek: 0,
                currentAverage: points.last?.averageReps ?? 0,
                earlierAverage: points.first?.averageReps ?? 0,
                verdict: .stable,
                confidence: confidence,
                totalSets: totalSets
            )
        }

        guard let slopePerWeek = Self.weightedSlope(
            points: points,
            weekStarts: window.weekStarts,
            totalSets: totalSets,
            isCancelled: isCancelled
        ) else { return cancelled }
        let verdict = Self.repDriftVerdict(slope: slopePerWeek)

        guard !isCancelled() else { return cancelled }
        return RepRangeMigrationReport(
            points: points,
            slopePerWeek: slopePerWeek,
            currentAverage: points.last?.averageReps ?? 0,
            earlierAverage: points.first?.averageReps ?? 0,
            verdict: verdict,
            confidence: confidence,
            totalSets: totalSets
        )
    }

    private static var cancelledRepRangeReport: RepRangeMigrationReport {
        RepRangeMigrationReport(
            points: [],
            slopePerWeek: 0,
            currentAverage: 0,
            earlierAverage: 0,
            verdict: .stable,
            confidence: .insufficient,
            totalSets: 0
        )
    }

    private func repRangeWeekTotals(
        window: RepRangeWeekWindow,
        now: Date,
        calendar: Calendar,
        isCancelled: @Sendable () -> Bool
    ) -> [Date: RepRangeWeekTotal]? {
        let validWeekStarts = Set(window.weekStarts)
        var totals: [Date: RepRangeWeekTotal] = [:]
        for session in sessions where session.date >= window.start && session.date <= now {
            guard !isCancelled() else { return nil }
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start,
                  validWeekStarts.contains(weekStart)
            else { continue }
            guard accumulateRepRangeTotals(
                session,
                weekStart: weekStart,
                totals: &totals,
                isCancelled: isCancelled
            ) else { return nil }
        }
        return totals
    }

    private func accumulateRepRangeTotals(
        _ session: AnalyticsSessionReplay,
        weekStart: Date,
        totals: inout [Date: RepRangeWeekTotal],
        isCancelled: @Sendable () -> Bool
    ) -> Bool {
        for replay in session.exercises
            where replay.exercise.modality == .dynamicStrength
            && replay.exercise.trackingMode == .reps
        {
            guard !isCancelled() else { return false }
            for set in replay.exercise.sets where set.isAnalyticsEligible && set.reps > 0 {
                guard !isCancelled() else { return false }
                totals[weekStart, default: RepRangeWeekTotal()].totalReps += set.reps
                totals[weekStart, default: RepRangeWeekTotal()].sets += 1
            }
        }
        return true
    }

    private static func repRangePoints(
        weekStarts: [Date],
        totals: [Date: RepRangeWeekTotal],
        isCancelled: @Sendable () -> Bool
    ) -> [RepRangePoint]? {
        var points: [RepRangePoint] = []
        for weekStart in weekStarts {
            guard !isCancelled() else { return nil }
            guard let total = totals[weekStart], total.sets > 0 else { continue }
            points.append(RepRangePoint(
                weekStart: weekStart,
                averageReps: Double(total.totalReps) / Double(total.sets),
                sets: total.sets
            ))
        }
        return points
    }

    private static func repTrendConfidence(
        points: [RepRangePoint],
        totalSets: Int
    ) -> RepTrendConfidence {
        if points.count >= RepRangeMigrationReport.establishedTrendWeeks,
           totalSets >= RepRangeMigrationReport.establishedTrendSets
        {
            return .established
        }
        if points.count >= RepRangeMigrationReport.minimumTrendWeeks,
           totalSets >= RepRangeMigrationReport.minimumTrendSets
        {
            return .emerging
        }
        return .insufficient
    }

    private static func weightedSlope(
        points: [RepRangePoint],
        weekStarts: [Date],
        totalSets: Int,
        isCancelled: @Sendable () -> Bool
    ) -> Double? {
        let weekIndices = Dictionary(uniqueKeysWithValues: weekStarts.enumerated().map { ($1, Double($0)) })
        let xs = points.map { weekIndices[$0.weekStart] ?? 0 }
        let totalWeight = Double(totalSets)
        var weightedX = 0.0
        var weightedY = 0.0
        for (index, point) in points.enumerated() {
            guard !isCancelled() else { return nil }
            let weight = Double(point.sets)
            weightedX += weight * xs[index]
            weightedY += weight * point.averageReps
        }
        return weightedSlope(
            points: points,
            xs: xs,
            meanX: weightedX / totalWeight,
            meanY: weightedY / totalWeight,
            isCancelled: isCancelled
        )
    }

    private static func weightedSlope(
        points: [RepRangePoint],
        xs: [Double],
        meanX: Double,
        meanY: Double,
        isCancelled: @Sendable () -> Bool
    ) -> Double? {
        var numerator = 0.0
        var denominator = 0.0
        for (index, point) in points.enumerated() {
            guard !isCancelled() else { return nil }
            let weight = Double(point.sets)
            let deltaX = xs[index] - meanX
            numerator += weight * deltaX * (point.averageReps - meanY)
            denominator += weight * deltaX * deltaX
        }
        return denominator > 0 ? numerator / denominator : 0
    }

    private static func repDriftVerdict(slope: Double) -> RepDriftVerdict {
        if slope >= 0.1 { return .towardEndurance }
        if slope <= -0.1 { return .towardStrength }
        return .stable
    }
}

private nonisolated struct RepRangeWeekTotal {
    var totalReps = 0
    var sets = 0
}
