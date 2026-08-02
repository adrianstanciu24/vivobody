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
//  Timed (`.duration`) holds, conditioning reps, and mobility drills
//  are excluded, as are incomplete sets and sets logged with zero reps. Pure value type on
//  injected dates, so it's testable on a virtual clock (see
//  `RepRangeMigrationTests`).
//

import Foundation

// MARK: - Verdict

nonisolated enum RepDriftVerdict: Hashable, Sendable {
    case towardStrength
    case stable
    case towardEndurance
}

/// How much evidence supports the fitted rep-range direction.
nonisolated enum RepTrendConfidence: Hashable, Sendable {
    case insufficient
    case emerging
    case established
}

// MARK: - Weekly point

/// One week's average-reps sample on the migration curve.
nonisolated struct RepRangePoint: Identifiable, Hashable, Sendable {
    var id: Date { weekStart }
    /// Calendar week start (Sunday/Monday per current calendar) the
    /// bucket's sets fall into.
    let weekStart: Date
    /// Mean reps per completed `.reps` set that week.
    let averageReps: Double
    /// Number of completed sets the average was drawn from.
    let sets: Int
}

// MARK: - Report

nonisolated struct RepRangeMigrationReport: Sendable {
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
    var hasTrend: Bool { confidence != .insufficient }

    /// `true` when there's at least one weekly sample.
    var hasData: Bool { !points.isEmpty }
}

// MARK: - Aggregation

@MainActor
extension Array where Element == WorkoutSession {
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
        let cancelled = RepRangeMigrationReport(
            points: [],
            slopePerWeek: 0,
            currentAverage: 0,
            earlierAverage: 0,
            verdict: .stable,
            confidence: .insufficient,
            totalSets: 0
        )
        guard !isCancelled() else { return cancelled }

        let calendar = Calendar.current
        guard let window = RepRangeWeekWindow.make(
            weeks: weeks,
            now: now,
            calendar: calendar
        ) else { return cancelled }
        let validWeekStarts = Set(window.weekStarts)

        // Bucket completed `.reps` sets (reps > 0) by week start.
        var totalRepsByWeek: [Date: Int] = [:]
        var setCountByWeek: [Date: Int] = [:]

        for session in sessions {
            guard !isCancelled() else { return cancelled }
            let date = session.date
            guard date >= window.start, date <= now else { continue }
            guard let weekStart = calendar.dateInterval(
                of: .weekOfYear,
                for: date
            )?.start,
                  validWeekStarts.contains(weekStart) else { continue }

            for replay in session.exercises {
                guard !isCancelled() else { return cancelled }
                guard replay.exercise.modality == .dynamicStrength,
                      replay.exercise.trackingMode == .reps else {
                    continue
                }
                for set in replay.exercise.sets {
                    guard !isCancelled() else { return cancelled }
                    guard set.isAnalyticsEligible, set.reps > 0 else {
                        continue
                    }
                    totalRepsByWeek[weekStart, default: 0] += set.reps
                    setCountByWeek[weekStart, default: 0] += 1
                }
            }
        }

        // Build chronological weekly points.
        guard !isCancelled() else { return cancelled }
        let orderedWeeks = window.weekStarts.filter { totalRepsByWeek[$0] != nil }
        var points: [RepRangePoint] = []
        points.reserveCapacity(orderedWeeks.count)
        for weekStart in orderedWeeks {
            guard !isCancelled() else { return cancelled }
            let total = totalRepsByWeek[weekStart, default: 0]
            let count = setCountByWeek[weekStart, default: 0]
            let average = count > 0 ? Double(total) / Double(count) : 0
            points.append(
                RepRangePoint(
                    weekStart: weekStart,
                    averageReps: average,
                    sets: count
                )
            )
        }

        let totalSets = points.reduce(0) { $0 + $1.sets }
        let confidence: RepTrendConfidence
        if points.count >= RepRangeMigrationReport.establishedTrendWeeks,
           totalSets >= RepRangeMigrationReport.establishedTrendSets {
            confidence = .established
        } else if points.count >= RepRangeMigrationReport.minimumTrendWeeks,
                  totalSets >= RepRangeMigrationReport.minimumTrendSets {
            confidence = .emerging
        } else {
            confidence = .insufficient
        }

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

        // Completed-set-weighted least-squares fit on exact calendar
        // week indices. Empty weeks retain their spacing without
        // becoming zero-rep samples.
        let weekIndices = Dictionary(
            uniqueKeysWithValues: window.weekStarts.enumerated().map { ($1, Double($0)) }
        )
        var xs: [Double] = []
        xs.reserveCapacity(points.count)
        for point in points {
            guard !isCancelled() else { return cancelled }
            xs.append(weekIndices[point.weekStart] ?? 0)
        }
        let totalWeight = Double(totalSets)
        var weightedX = 0.0
        var weightedY = 0.0
        for (index, point) in points.enumerated() {
            guard !isCancelled() else { return cancelled }
            let weight = Double(point.sets)
            weightedX += weight * xs[index]
            weightedY += weight * point.averageReps
        }
        let meanX = weightedX / totalWeight
        let meanY = weightedY / totalWeight
        var num = 0.0, den = 0.0
        for (index, point) in points.enumerated() {
            guard !isCancelled() else { return cancelled }
            let weight = Double(point.sets)
            let dx = xs[index] - meanX
            num += weight * dx * (point.averageReps - meanY)
            den += weight * dx * dx
        }
        let slopePerWeek = den > 0 ? num / den : 0

        let verdict: RepDriftVerdict
        if slopePerWeek >= 0.1 {
            verdict = .towardEndurance
        } else if slopePerWeek <= -0.1 {
            verdict = .towardStrength
        } else {
            verdict = .stable
        }

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
}
