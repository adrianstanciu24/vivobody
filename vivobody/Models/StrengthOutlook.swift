//
//  StrengthOutlook.swift
//  vivobody
//
//  The strength-axis instrument for the Insights tab. The muscle
//  trilogy (balance, momentum, forecast) all read the development
//  model — how worked / adapting / decaying each muscle is. This asks
//  a different question entirely: is the LOAD on the bar actually
//  going up, and when will the next personal record land?
//
//  It works off `progressByExercise`, the same per-lift series the Me
//  tab charts, and reads each session's estimated 1-rep max (Epley)
//  rather than raw top weight — e1RM absorbs rep changes, so a 5×5
//  and a 8×3 sit on one comparable strength curve.
//
//  For every lift with enough history it fits a line to the recent
//  e1RM points and reports:
//    • trend — climbing, plateaued, or slipping.
//    • daysToPR — for climbing lifts, when the trend line crosses the
//      all-time best (a projected new PR), capped at a sane horizon.
//    • weeksSinceBest — for stalled lifts, how long the record's stood.
//
//  Bodyweight-only movements (e1RM 0) and lifts with too few points
//  are dropped — a couple of sessions isn't a trend. Pure value type
//  on injected dates, so it's testable on a virtual clock (see
//  `StrengthOutlookTests`).
//

import Foundation

// MARK: - Trend

nonisolated enum PRTrend: Hashable {
    case climbing
    case plateaued
    case slipping
}

// MARK: - Per-lift stat

nonisolated struct StrengthOutlookStat: Identifiable, Hashable {
    var id: String { exercise }
    let exercise: String
    let group: MuscleGroup
    /// Most recent estimated 1-rep max (lb).
    let currentE1RM: Double
    /// All-time best estimated 1-rep max (lb) — the record to beat.
    let bestE1RM: Double
    /// Recent strength trend in e1RM lb per week.
    let slopePerWeek: Double
    let trend: PRTrend
    /// Projected days until the trend line reaches a new best.
    /// Climbing lifts only, and only when within the horizon.
    let daysToPR: Int?
    /// The latest session is itself an all-time best.
    let isFreshPR: Bool
    /// Whole weeks since the record was set — context for a stall.
    let weeksSinceBest: Int?
    let daysSinceLastTrained: Int?

    /// How close the latest estimate sits to the all-time best, `0...1`.
    var fractionOfBest: Double {
        guard bestE1RM > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, currentE1RM / bestE1RM))
    }
}

// MARK: - Board

nonisolated struct StrengthOutlookBoard {
    /// A lift needs at least this many e1RM points to earn a trend.
    static let minPoints = 3
    /// The trend line is fit to the most recent this-many points.
    static let recentWindow = 6
    /// e1RM lb/week above which a lift reads as climbing (and below
    /// its negation as slipping).
    static let climbPerWeek = 0.5
    /// Don't project a PR further out than this.
    static let horizonDays = 180

    /// Every tracked lift, ordered for display: climbing first (fresh
    /// PRs, then soonest projected PR), then the longest stalls, then
    /// the steepest slides.
    let stats: [StrengthOutlookStat]

    var hasAny: Bool { !stats.isEmpty }
    var climbingCount: Int { stats.lazy.filter { $0.trend == .climbing }.count }
    var plateauedCount: Int { stats.lazy.filter { $0.trend == .plateaued }.count }
    var slippingCount: Int { stats.lazy.filter { $0.trend == .slipping }.count }

    /// The climbing lift projected to PR soonest (a fresh PR ranks
    /// ahead of any projection). Drives the headline.
    var nearestPR: StrengthOutlookStat? {
        stats.first { $0.trend == .climbing }
    }

    func stat(for exercise: String) -> StrengthOutlookStat? {
        stats.first { $0.exercise.caseInsensitiveCompare(exercise) == .orderedSame }
    }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Fit a strength trend to every weighted lift in the archive and
    /// rank them by PR outlook as of `now`.
    func strengthOutlook(now: Date = Date()) -> StrengthOutlookBoard {
        let calendar = Calendar.current
        var stats: [StrengthOutlookStat] = []

        for progress in progressByExercise {
            guard progress.trackingMode == .reps else { continue }

            let points = progress.points.filter { $0.estimated1RM > 0 }
            guard points.count >= StrengthOutlookBoard.minPoints else { continue }

            // Recent-window least-squares fit on (days, e1RM).
            let window = points.suffix(StrengthOutlookBoard.recentWindow)
            let t0 = window.first!.date
            let xs = window.map { $0.date.timeIntervalSince(t0) / 86_400 }
            let ys = window.map { $0.estimated1RM }
            let n = Double(xs.count)
            let meanX = xs.reduce(0, +) / n
            let meanY = ys.reduce(0, +) / n
            var num = 0.0, den = 0.0
            for i in xs.indices {
                num += (xs[i] - meanX) * (ys[i] - meanY)
                den += (xs[i] - meanX) * (xs[i] - meanX)
            }
            let slopePerDay = den > 0 ? num / den : 0
            let intercept = meanY - slopePerDay * meanX
            let slopePerWeek = slopePerDay * 7

            // Records, current level, and recency.
            let best = points.max { $0.estimated1RM < $1.estimated1RM }!
            let bestE1RM = best.estimated1RM
            let current = points.last!
            let currentE1RM = current.estimated1RM
            // A fresh PR means the latest session strictly beat every
            // prior one — not merely tied a long-standing best (which
            // a flat program would do every single session).
            let priorBest = points.dropLast().map(\.estimated1RM).max() ?? 0
            let isFreshPR = currentE1RM > priorBest + 1e-6

            let trend: PRTrend
            if isFreshPR || slopePerWeek >= StrengthOutlookBoard.climbPerWeek {
                trend = .climbing
            } else if slopePerWeek <= -StrengthOutlookBoard.climbPerWeek {
                trend = .slipping
            } else {
                trend = .plateaued
            }

            // Projected days to a new PR (climbing, not already there).
            var daysToPR: Int?
            if trend == .climbing, !isFreshPR, slopePerDay > 0 {
                let xLast = current.date.timeIntervalSince(t0) / 86_400
                let fittedNow = intercept + slopePerDay * xLast
                if bestE1RM > fittedNow {
                    let d = (bestE1RM - fittedNow) / slopePerDay
                    if d.isFinite, d <= Double(StrengthOutlookBoard.horizonDays) {
                        daysToPR = Swift.max(1, Int(d.rounded(.up)))
                    }
                }
            }

            let weeksSinceBest = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: best.date),
                to: calendar.startOfDay(for: now)
            ).day.map { Swift.max(0, $0) / 7 }

            let daysSince = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: current.date),
                to: calendar.startOfDay(for: now)
            ).day

            stats.append(
                StrengthOutlookStat(
                    exercise: progress.name,
                    group: progress.group,
                    currentE1RM: currentE1RM,
                    bestE1RM: bestE1RM,
                    slopePerWeek: slopePerWeek,
                    trend: trend,
                    daysToPR: daysToPR,
                    isFreshPR: isFreshPR,
                    weeksSinceBest: weeksSinceBest,
                    daysSinceLastTrained: daysSince
                )
            )
        }

        stats.sort { lhs, rhs in
            let a = Self.sortKey(lhs)
            let b = Self.sortKey(rhs)
            return a.0 != b.0 ? a.0 < b.0 : a.1 < b.1
        }

        return StrengthOutlookBoard(stats: stats)
    }

    /// Display ordering: climbing (fresh PR, then soonest projected
    /// PR) → plateaued (longest stall) → slipping (steepest slide).
    private static func sortKey(_ s: StrengthOutlookStat) -> (Int, Double) {
        switch s.trend {
        case .climbing:
            return (0, s.isFreshPR ? -1 : Double(s.daysToPR ?? 9_999))
        case .plateaued:
            return (1, -Double(s.weeksSinceBest ?? 0))
        case .slipping:
            return (2, s.slopePerWeek)
        }
    }
}
