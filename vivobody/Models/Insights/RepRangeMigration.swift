//
//  RepRangeMigration.swift
//  vivobody
//
//  The rep-range drift instrument for the Insights tab. IntensityMix
//  snapshots how today's sets split across strength / hypertrophy /
//  endurance zones; this asks the longer question: over the last
//  ~12 weeks, is the AVERAGE rep count per working set creeping up
//  (drifting toward endurance volume) or sinking down (drifting
//  toward heavy strength work)? It's the lens that catches a quiet
//  program shift the lifter might not have noticed — a hypertrophy
//  block sneaking into "everything is 8s" or a strength block pulling
//  sets back toward triples without a deliberate reset.
//
//  Completed dynamic-strength `.reps` sets are bucketed by ISO week
//  start, each week's average reps = totalReps / completedSetCount, and a least-squares
//  line is fit to the weekly points (x = days since the first point,
//  y = averageReps) — the same fit math as `StrengthOutlook`. The
//  slope is reported in reps/week and mapped to a verdict:
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
    /// `true` when at least 3 weeks carry data — the floor for a
    /// trustworthy slope.
    var hasTrend: Bool { points.count >= 3 }

    /// `true` when there's at least one weekly sample.
    var hasData: Bool { !points.isEmpty }
}

// MARK: - Aggregation

@MainActor
extension Array where Element == WorkoutSession {
    /// Average-reps-per-set trend over the trailing `weeks` (default
    /// 12) as of `now`. Buckets completed `.reps` sets by ISO week
    /// start, fits a least-squares line to the weekly averages, and
    /// reports the drift verdict.
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
            verdict: .stable
        )
        guard !isCancelled() else { return cancelled }

        let calendar = Calendar.current
        let cutoff = now.addingTimeInterval(-Double(weeks) * 7 * 86_400)

        // Bucket completed `.reps` sets (reps > 0) by week start.
        var totalRepsByWeek: [Date: Int] = [:]
        var setCountByWeek: [Date: Int] = [:]

        for session in sessions {
            guard !isCancelled() else { return cancelled }
            let date = session.date
            guard date >= cutoff else { continue }
            guard let weekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            ) else { continue }

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
        let orderedWeeks = totalRepsByWeek.keys.sorted()
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

        // Not enough weeks for a trustworthy slope — return what we
        // have with a stable verdict and zero slope.
        guard points.count >= 3 else {
            return RepRangeMigrationReport(
                points: points,
                slopePerWeek: 0,
                currentAverage: points.last?.averageReps ?? 0,
                earlierAverage: points.first?.averageReps ?? 0,
                verdict: .stable
            )
        }

        // Least-squares fit on (days since first point, averageReps),
        // same shape as `StrengthOutlook`.
        let t0 = points.first!.weekStart
        var xs: [Double] = []
        var ys: [Double] = []
        xs.reserveCapacity(points.count)
        ys.reserveCapacity(points.count)
        for point in points {
            guard !isCancelled() else { return cancelled }
            xs.append(point.weekStart.timeIntervalSince(t0) / 86_400)
            ys.append(point.averageReps)
        }
        let n = Double(xs.count)
        var sumX = 0.0
        var sumY = 0.0
        for i in xs.indices {
            guard !isCancelled() else { return cancelled }
            sumX += xs[i]
            sumY += ys[i]
        }
        let meanX = sumX / n
        let meanY = sumY / n
        var num = 0.0, den = 0.0
        for i in xs.indices {
            guard !isCancelled() else { return cancelled }
            num += (xs[i] - meanX) * (ys[i] - meanY)
            den += (xs[i] - meanX) * (xs[i] - meanX)
        }
        let slopePerDay = den > 0 ? num / den : 0
        let slopePerWeek = slopePerDay * 7

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
            verdict: verdict
        )
    }
}
