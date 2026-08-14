//
//  StrengthOutlook.swift
//  vivobody
//
//  The confidence-gated engine behind each Exercise Detail strength
//  curve, Today's guidance, and the Strength widget. It asks whether
//  estimated strength is actually going up, and when it might revisit
//  its all-time high.
//
//  It works off `progressByExercise`, the same per-lift series the Me
//  tab charts, and reads each session's estimated 1-rep max (Epley)
//  rather than raw top weight — e1RM absorbs rep changes, so a 5×5
//  and a 8×3 sit on one comparable strength curve.
//
//  For every lift with enough history across a real time span it fits a
//  line to the recent, confidence-eligible e1RM points and reports:
//    • trend — climbing, plateaued, or slipping.
//    • daysToE1RMHigh — for established climbing lifts, when the trend
//      line crosses the all-time e1RM high relative to today, capped at
//      a sane horizon.
//    • weeksSinceBest — for stalled lifts, how long the e1RM high has stood.
//
//  Unresolved/non-comparable movements and lifts with too few points
//  are dropped — a couple of sessions isn't a trend. Pure value type on
//  injected dates, so it's testable on a virtual clock (see tests).
//

import Foundation

// MARK: - Trend

nonisolated enum PRTrend: Hashable {
    case climbing
    case plateaued
    case slipping
}

/// A minimum viable trend is still called out as an early read until it
/// spans enough sessions and time to support a projected e1RM-high date.
nonisolated enum StrengthTrendConfidence: Hashable {
    case developing
    case established
}

// MARK: - Per-lift stat

nonisolated struct StrengthOutlookStat: Identifiable, Hashable {
    /// The same stable identity used by `ExerciseProgress`: bundled
    /// catalog ID or the custom item's UUID plus full performance
    /// signature, with a normalized-name key only when neither exists.
    let historyKey: String
    var id: String {
        historyKey
    }

    let catalogID: String?
    let exercise: String
    let group: MuscleGroup
    /// Most recent estimated 1-rep max (lb).
    let currentE1RM: Double
    /// All-time estimated 1-rep max high (lb).
    let bestE1RM: Double
    /// Recent strength trend in e1RM lb per week.
    let slopePerWeek: Double
    let trend: PRTrend
    let confidence: StrengthTrendConfidence
    let sampleCount: Int
    let spanDays: Int
    /// Projected days until the trend line reaches a new best.
    /// Established climbing lifts only, measured from `now`, and only
    /// when the projected crossing still lies ahead within the horizon.
    let daysToE1RMHigh: Int?
    /// The latest eligible estimate set a new all-time e1RM high.
    let isLatestE1RMHigh: Bool
    /// That high was also logged recently enough to read as current.
    let isRecentE1RMHigh: Bool
    /// Whole weeks since the e1RM high was set — context for a stall.
    let weeksSinceBest: Int?
    /// Recency of the last confidence-eligible e1RM estimate.
    let daysSinceLastEstimate: Int?
    /// Recency of any training on the lift, including a later session
    /// whose load or rep range could not produce a comparable estimate.
    let daysSinceLastTrained: Int?

    /// Compatibility for widget/report call sites. It now means a
    /// genuinely recent e1RM high, never merely "latest point is best."
    var isFreshPR: Bool {
        isRecentE1RMHigh
    }

    /// Compatibility for older summary call sites. Strength presents
    /// this as an e1RM-high estimate rather than a generic personal record.
    var daysToPR: Int? {
        daysToE1RMHigh
    }

    /// How close the latest estimate sits to the all-time best, `0...1`.
    var fractionOfBest: Double {
        guard bestE1RM > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, currentE1RM / bestE1RM))
    }
}

// MARK: - Board

nonisolated struct StrengthOutlookBoard {
    /// A lift needs at least this many e1RM points to earn a trend.
    static let minPoints = 4
    /// Points must span at least two weeks; four workouts compressed
    /// into a few days are not presented as a durable direction.
    static let minimumSpanDays = 14
    /// The trend line is fit to the most recent this-many points.
    static let recentWindow = 6
    /// A precise e1RM-high projection needs a full recent window over at least
    /// four weeks. Earlier reads still show direction with a confidence cue.
    static let establishedPoints = 6
    static let establishedSpanDays = 28
    /// e1RM lb/week above which a lift reads as climbing (and below
    /// its negation as slipping).
    static let climbPerWeek = 0.5
    /// "Recent e1RM high" presentation expires; the standing all-time
    /// high itself remains available without being called new forever.
    static let recentHighDays = 7
    /// Don't project an e1RM high further out than this.
    static let horizonDays = 180

    /// Every tracked lift, ordered for display by estimate recency, then
    /// training recency and trend. Exercise identity is the final
    /// tie-breaker so the featured lift never changes arbitrarily.
    let stats: [StrengthOutlookStat]

    var hasAny: Bool {
        !stats.isEmpty
    }

    var climbingCount: Int {
        stats.lazy.count(where: { $0.trend == .climbing })
    }

    var plateauedCount: Int {
        stats.lazy.count(where: { $0.trend == .plateaued })
    }

    var slippingCount: Int {
        stats.lazy.count(where: { $0.trend == .slipping })
    }

    /// The actionable climbing lift with the soonest projected e1RM high.
    /// A high already set is an outcome, not a remaining forecast.
    var nearestE1RMHigh: StrengthOutlookStat? {
        stats
            .filter {
                $0.trend == .climbing
                    && $0.daysToE1RMHigh != nil
            }
            .min(by: Self.isCloserToE1RMHigh)
    }

    /// Compatibility for Today/widget call sites that still use the old
    /// generic PR vocabulary.
    var nearestPR: StrengthOutlookStat? {
        nearestE1RMHigh
    }

    func stat(forHistoryKey historyKey: String) -> StrengthOutlookStat? {
        stats.first { $0.historyKey == historyKey }
    }
}

// MARK: - Aggregation

@MainActor
extension [WorkoutSession] {
    /// Fit a strength trend to every weighted lift in the archive and
    /// rank them by current strength outlook as of `now`.
    func strengthOutlook(
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> StrengthOutlookBoard {
        strengthOutlook(
            progress: AnalyticsAccumulator.history(
                AnalyticsSnapshot(sessions: self)
            ).progressByExercise(isCancelled: isCancelled),
            now: now,
            isCancelled: isCancelled
        )
    }

    /// Fit outlook from a progress series already built by the shared
    /// analytics cache.
    func strengthOutlook(
        progress: [ExerciseProgress],
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> StrengthOutlookBoard {
        StrengthOutlookBoard.compute(
            progress: progress,
            now: now,
            isCancelled: isCancelled
        )
    }
}

nonisolated extension StrengthOutlookBoard {
    /// Pure outlook construction from the progress series already
    /// produced by the shared analytics replay.
    static func compute(
        progress: [ExerciseProgress],
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> StrengthOutlookBoard {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var stats: [StrengthOutlookStat] = []

        for exerciseProgress in progress {
            guard !isCancelled() else { return StrengthOutlookBoard(stats: []) }
            guard exerciseProgress.trackingMode == .reps else { continue }

            var points: [ExerciseProgressPoint] = []
            points.reserveCapacity(exerciseProgress.points.count)
            for point in exerciseProgress.points {
                guard !isCancelled() else { return StrengthOutlookBoard(stats: []) }
                if point.date <= now, point.estimated1RM > 0 {
                    points.append(point)
                }
            }
            guard points.count >= StrengthOutlookBoard.minPoints else { continue }

            // Confidence follows the same recent window as the fit. A
            // long archive cannot make six compressed workouts look mature.
            let window = points.suffix(StrengthOutlookBoard.recentWindow)
            let firstDate = window.first!.date
            let lastDate = window.last!.date
            let spanDays = Swift.max(
                0,
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: firstDate),
                    to: calendar.startOfDay(for: lastDate)
                ).day ?? 0
            )
            guard spanDays >= StrengthOutlookBoard.minimumSpanDays else { continue }

            // Recent-window least-squares fit on (days, e1RM).
            let t0 = window.first!.date
            let xs = window.map { $0.date.timeIntervalSince(t0) / 86400 }
            let ys = window.map(\.estimated1RM)
            let n = Double(xs.count)
            let meanX = xs.reduce(0, +) / n
            let meanY = ys.reduce(0, +) / n
            var num = 0.0, den = 0.0
            for i in xs.indices {
                guard !isCancelled() else { return StrengthOutlookBoard(stats: []) }
                num += (xs[i] - meanX) * (ys[i] - meanY)
                den += (xs[i] - meanX) * (xs[i] - meanX)
            }
            let slopePerDay = den > 0 ? num / den : 0
            let intercept = meanY - slopePerDay * meanX
            let slopePerWeek = slopePerDay * 7

            // e1RM highs, current level, and recency. This is explicitly
            // separate from the app's load-then-reps strength-record axis.
            let best = points.max { $0.estimated1RM < $1.estimated1RM }!
            let bestE1RM = best.estimated1RM
            let current = points.last!
            let currentE1RM = current.estimated1RM
            var priorBest = 0.0
            for point in points.dropLast() {
                guard !isCancelled() else { return StrengthOutlookBoard(stats: []) }
                priorBest = Swift.max(priorBest, point.estimated1RM)
            }
            let isLatestE1RMHigh = currentE1RM > priorBest + 1e-6

            let daysSinceLastEstimate = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: current.date),
                to: today
            ).day.map { Swift.max(0, $0) }
            let isRecentE1RMHigh = isLatestE1RMHigh
                && (daysSinceLastEstimate ?? Int.max) <= StrengthOutlookBoard.recentHighDays

            let confidence: StrengthTrendConfidence =
                window.count >= StrengthOutlookBoard.establishedPoints
                    && spanDays >= StrengthOutlookBoard.establishedSpanDays
                    ? .established
                    : .developing

            let trend: PRTrend = if slopePerWeek >= StrengthOutlookBoard.climbPerWeek {
                .climbing
            } else if slopePerWeek <= -StrengthOutlookBoard.climbPerWeek {
                .slipping
            } else {
                .plateaued
            }

            // Absolute trend-line crossing, converted back to a remaining
            // interval from `now`. A projection that has already passed is
            // stale evidence, not the same ETA repeated forever.
            var daysToE1RMHigh: Int?
            if trend == .climbing,
               confidence == .established,
               !isLatestE1RMHigh,
               slopePerDay > 0
            {
                let crossingX = (bestE1RM - intercept) / slopePerDay
                let crossingDate = t0.addingTimeInterval(crossingX * 86400)
                let remaining = crossingDate.timeIntervalSince(now) / 86400
                if remaining.isFinite,
                   remaining > 0,
                   remaining <= Double(StrengthOutlookBoard.horizonDays)
                {
                    daysToE1RMHigh = Swift.max(1, Int(remaining.rounded(.up)))
                }
            }

            let weeksSinceBest = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: best.date),
                to: today
            ).day.map { Swift.max(0, $0) / 7 }

            // Strength math uses the latest comparable e1RM point, but
            // training recency must include a later session whose
            // bodyweight-dependent load or rep range could not be resolved.
            let latestTrainedDate = exerciseProgress.points
                .last(where: { $0.date <= now })?.date ?? current.date
            let daysSince = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: latestTrainedDate),
                to: today
            ).day.map { Swift.max(0, $0) }

            stats.append(
                StrengthOutlookStat(
                    historyKey: exerciseProgress.id,
                    catalogID: exerciseProgress.catalogID,
                    exercise: exerciseProgress.name,
                    group: exerciseProgress.group,
                    currentE1RM: currentE1RM,
                    bestE1RM: bestE1RM,
                    slopePerWeek: slopePerWeek,
                    trend: trend,
                    confidence: confidence,
                    sampleCount: window.count,
                    spanDays: spanDays,
                    daysToE1RMHigh: daysToE1RMHigh,
                    isLatestE1RMHigh: isLatestE1RMHigh,
                    isRecentE1RMHigh: isRecentE1RMHigh,
                    weeksSinceBest: weeksSinceBest,
                    daysSinceLastEstimate: daysSinceLastEstimate,
                    daysSinceLastTrained: daysSince
                )
            )
        }

        guard !isCancelled() else { return StrengthOutlookBoard(stats: []) }
        stats.sort(by: Self.isOrderedBefore)

        return StrengthOutlookBoard(stats: stats)
    }

    private static func isOrderedBefore(
        _ lhs: StrengthOutlookStat,
        _ rhs: StrengthOutlookStat
    ) -> Bool {
        let lhsEstimateAge = lhs.daysSinceLastEstimate ?? Int.max
        let rhsEstimateAge = rhs.daysSinceLastEstimate ?? Int.max
        if lhsEstimateAge != rhsEstimateAge {
            return lhsEstimateAge < rhsEstimateAge
        }

        let lhsTrainingAge = lhs.daysSinceLastTrained ?? Int.max
        let rhsTrainingAge = rhs.daysSinceLastTrained ?? Int.max
        if lhsTrainingAge != rhsTrainingAge {
            return lhsTrainingAge < rhsTrainingAge
        }
        if lhs.isRecentE1RMHigh != rhs.isRecentE1RMHigh {
            return lhs.isRecentE1RMHigh
        }

        let lhsTrend = trendRank(lhs.trend)
        let rhsTrend = trendRank(rhs.trend)
        if lhsTrend != rhsTrend { return lhsTrend < rhsTrend }

        let lhsName = lhs.exercise.exerciseIdentityName
        let rhsName = rhs.exercise.exerciseIdentityName
        if lhsName != rhsName { return lhsName < rhsName }
        return lhs.historyKey < rhs.historyKey
    }

    private static func trendRank(_ trend: PRTrend) -> Int {
        switch trend {
        case .climbing: 0
        case .plateaued: 1
        case .slipping: 2
        }
    }

    private static func isCloserToE1RMHigh(
        _ lhs: StrengthOutlookStat,
        _ rhs: StrengthOutlookStat
    ) -> Bool {
        let lhsDays = lhs.daysToE1RMHigh ?? Int.max
        let rhsDays = rhs.daysToE1RMHigh ?? Int.max
        if lhsDays != rhsDays { return lhsDays < rhsDays }
        if lhs.daysSinceLastEstimate != rhs.daysSinceLastEstimate {
            return (lhs.daysSinceLastEstimate ?? Int.max)
                < (rhs.daysSinceLastEstimate ?? Int.max)
        }
        if lhs.exercise.exerciseIdentityName != rhs.exercise.exerciseIdentityName {
            return lhs.exercise.exerciseIdentityName < rhs.exercise.exerciseIdentityName
        }
        return lhs.historyKey < rhs.historyKey
    }
}
