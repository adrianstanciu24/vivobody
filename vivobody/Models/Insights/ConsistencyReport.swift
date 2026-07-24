//
//  ConsistencyReport.swift
//  vivobody
//
//  The adherence instrument for the Insights tab. Where the other
//  sections ask what the training did to the body, this asks whether
//  the training is actually HAPPENING — and how hard. It folds three
//  consistency signals into one view:
//
//    • Rhythm — sessions per week over the recent weeks, and the run
//      of consecutive weeks trained (the streak that survives a
//      not-yet-started current week).
//    • Effort — average reps-in-reserve across logged sets: are they
//      being pushed close enough to failure to drive adaptation?
//    • A contribution heatmap — six months of days as a GitHub-style
//      grid, each cell shaded by that day's set volume, so a glance
//      reads the whole arc of work.
//
//  Pure value type on injected dates, so the grid math and rollups
//  are testable on a virtual clock (see `ConsistencyReportTests`).
//

import Foundation

// MARK: - Heatmap day

nonisolated struct ConsistencyDay: Hashable, Sendable {
    let date: Date
    /// Completed sets logged that calendar day (summed across sessions).
    let sets: Int
    /// `true` for days on or before today (future days in the current
    /// week render as faint placeholders).
    let isInRange: Bool
    let isToday: Bool
    /// Shade bucket, `0` (none) … `4` (a big day).
    let level: Int
}

// MARK: - Report

nonisolated struct ConsistencyReport: Sendable {
    /// How many weeks of history the heatmap spans (~6 months).
    static let windowWeeks = 26
    /// Trailing window for the rhythm + effort rollups.
    static let recentDays = 28
    /// Reps-in-reserve below this reads as grinding near failure;
    /// above the high mark, too much left in the tank.
    static let targetRIRLow = 1.0
    static let targetRIRHigh = 3.0

    /// Heatmap columns, oldest → newest; each column is 7 days
    /// (Sunday … Saturday).
    let weeks: [[ConsistencyDay]]
    let sessionsPerWeek: Double
    let weekStreak: Int
    /// Mean reps-in-reserve over recent reps-sets; `nil` if none logged.
    let averageRIR: Double?
    let recentSessions: Int
    let daysTrainedInWindow: Int

    var hasActivity: Bool { daysTrainedInWindow > 0 }

    /// Shade bucket for a day's set count. Internal so tests can pin
    /// the thresholds directly.
    static func level(forSets sets: Int) -> Int {
        switch sets {
        case ..<1:    return 0
        case 1...5:   return 1
        case 6...11:  return 2
        case 12...17: return 3
        default:      return 4
        }
    }
}

// MARK: - Aggregation

@MainActor
extension Array where Element == WorkoutSession {
    /// Build the consistency report as of `now`.
    func consistency(now: Date = Date()) -> ConsistencyReport {
        AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: self)
        ).consistency(now: now)
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Build the consistency report from immutable session snapshots.
    func consistency(
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> ConsistencyReport {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var completed: [AnalyticsSessionReplay] = []
        completed.reserveCapacity(sessions.count)
        for session in sessions {
            guard !isCancelled() else { break }
            if session.session.completedAt != nil {
                completed.append(session)
            }
        }

        // Completed sets per calendar day.
        var setsByDay: [Date: Int] = [:]
        for session in completed {
            guard !isCancelled() else { break }
            let snapshot = session.session
            let day = calendar.startOfDay(
                for: snapshot.completedAt ?? snapshot.startedAt
            )
            setsByDay[day, default: 0] += snapshot.totalCompletedSets
        }

        // Grid aligned so the rightmost column is the current week.
        // Uses the calendar's locale-aware week interval so
        // Monday-first locales get correct column boundaries.
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let gridStart = calendar.date(
            byAdding: .day,
            value: -7 * (ConsistencyReport.windowWeeks - 1),
            to: currentWeekStart
        ) ?? today

        var weeks: [[ConsistencyDay]] = []
        var daysTrained = 0
        weekLoop: for w in 0..<ConsistencyReport.windowWeeks {
            guard !isCancelled() else { break }
            var column: [ConsistencyDay] = []
            for d in 0..<7 {
                guard !isCancelled() else { break weekLoop }
                let date = calendar.date(byAdding: .day, value: w * 7 + d, to: gridStart) ?? gridStart
                let sets = setsByDay[date] ?? 0
                let inRange = date <= today
                if inRange && sets > 0 { daysTrained += 1 }
                column.append(
                    ConsistencyDay(
                        date: date,
                        sets: sets,
                        isInRange: inRange,
                        isToday: calendar.isDate(date, inSameDayAs: today),
                        level: ConsistencyReport.level(forSets: sets)
                    )
                )
            }
            weeks.append(column)
        }

        // Recent rhythm + effort.
        let recentCutoff = calendar.date(
            byAdding: .day,
            value: -ConsistencyReport.recentDays,
            to: today
        ) ?? today
        var recentSessions = 0
        var rirSum = 0
        var rirCount = 0
        recentSessionLoop: for session in completed {
            guard !isCancelled() else { break }
            let snapshot = session.session
            let day = calendar.startOfDay(
                for: snapshot.completedAt ?? snapshot.startedAt
            )
            guard day >= recentCutoff else { continue }
            recentSessions += 1
            for replay in session.exercises
            where replay.exercise.modality == .dynamicStrength
                && replay.exercise.trackingMode == .reps {
                guard !isCancelled() else { break recentSessionLoop }
                for set in replay.exercise.sets
                where set.isAnalyticsEligible && set.reps > 0 && set.rirLogged {
                    guard !isCancelled() else { break recentSessionLoop }
                    rirSum += set.repsInReserve
                    rirCount += 1
                }
            }
        }
        let weeksElapsed = Double(ConsistencyReport.recentDays) / 7.0
        let sessionsPerWeek = Double(recentSessions) / weeksElapsed
        let averageRIR = rirCount > 0 ? Double(rirSum) / Double(rirCount) : nil

        let weekStreak = Self.weekStreak(in: weeks)

        return ConsistencyReport(
            weeks: weeks,
            sessionsPerWeek: sessionsPerWeek,
            weekStreak: weekStreak,
            averageRIR: averageRIR,
            recentSessions: recentSessions,
            daysTrainedInWindow: daysTrained
        )
    }

    /// Consecutive weeks with at least one trained day, counting back
    /// from the current week. A current week that hasn't been started
    /// yet doesn't break the prior run.
    private static func weekStreak(in weeks: [[ConsistencyDay]]) -> Int {
        var streak = 0
        var started = false
        for column in weeks.reversed() {
            let trained = column.contains { $0.isInRange && $0.sets > 0 }
            let isCurrentWeek = column.contains { !$0.isInRange }
            if trained {
                streak += 1
                started = true
            } else if isCurrentWeek && !started {
                continue          // not started this week yet — keep looking
            } else {
                break
            }
        }
        return streak
    }
}
