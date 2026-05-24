//
//  WeeklyStats.swift
//  vivobody
//
//  Computes "this week vs last week" rollups across an archive of
//  WorkoutSessions. Training programs naturally slice into weeks, so
//  this is the most legible cadence for a "are you doing the work?"
//  glance card.
//
//  Week boundaries follow the user's locale Calendar — for most US
//  users Sunday-starting, for most European users Monday-starting.
//  ISO weeks could be cleaner across regions but matching the rest
//  of the OS's expectations beats consistency-for-consistency's-sake.
//

import Foundation

/// One week's rollup of training totals. Volume is canonical lb so
/// the display layer can route it through `WeightFormatter`.
struct WeeklyTotals: Hashable {
    var workouts: Int = 0
    var sets: Int = 0
    var volume: Double = 0

    static let zero = WeeklyTotals()
}

/// Pair of weekly totals — current week + the immediately prior
/// calendar week. The detail-screen UX needs both side-by-side to
/// render direction-of-change indicators.
struct WeeklyComparison: Hashable {
    let thisWeek: WeeklyTotals
    let lastWeek: WeeklyTotals

    /// Workout-count delta. Positive = more workouts than last week.
    var workoutsDelta: Int { thisWeek.workouts - lastWeek.workouts }

    /// Set-count delta.
    var setsDelta: Int { thisWeek.sets - lastWeek.sets }

    /// Volume delta in canonical lb. Caller routes through
    /// WeightFormatter for display in the user's unit.
    var volumeDelta: Double { thisWeek.volume - lastWeek.volume }

    /// Convenience: was anything logged at all in either window?
    /// Empty state on the Me-tab card defers to this so a brand-new
    /// user doesn't see a "0 vs 0" row with confusing arrows.
    var hasAnyActivity: Bool {
        thisWeek.workouts > 0 || lastWeek.workouts > 0
    }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Slice the archive into the current and prior calendar weeks
    /// (relative to `now`) and roll each into a `WeeklyTotals`. Only
    /// archived sessions (with `completedAt != nil`) contribute —
    /// in-flight sessions don't count until they're saved.
    func weeklyComparison(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyComparison {
        guard
            let thisWeekRange = calendar.dateInterval(of: .weekOfYear, for: now),
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekRange.start),
            let lastWeekRange = calendar.dateInterval(of: .weekOfYear, for: lastWeekStart)
        else {
            return WeeklyComparison(thisWeek: .zero, lastWeek: .zero)
        }

        var thisWeek = WeeklyTotals.zero
        var lastWeek = WeeklyTotals.zero

        for session in self {
            guard let completed = session.completedAt else { continue }
            if thisWeekRange.contains(completed) {
                thisWeek.workouts += 1
                thisWeek.sets += session.totalSets
                thisWeek.volume += session.totalVolume
            } else if lastWeekRange.contains(completed) {
                lastWeek.workouts += 1
                lastWeek.sets += session.totalSets
                lastWeek.volume += session.totalVolume
            }
        }

        return WeeklyComparison(thisWeek: thisWeek, lastWeek: lastWeek)
    }
}
