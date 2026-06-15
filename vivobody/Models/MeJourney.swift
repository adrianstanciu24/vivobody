//
//  MeJourney.swift
//  vivobody
//
//  Derived "personal dashboard" data for the Me tab. Pure value
//  types and Array<WorkoutSession> extensions — no SwiftData, no
//  SwiftUI — so every figure stays computed from the live archive
//  (correct after any edit/delete) and stays unit-testable.
//
//  Surfaces:
//    • trainingAgeText — "Training since May 2026 · 13 months"
//    • workoutStreak  — consistency as weeks-in-a-row (current + longest)
//    • personalRecords — progress series ordered by most-recent PR
//    • milestones     — threshold badges across the lifetime totals
//    • monthlyRecap   — the current calendar month's recap
//

import Foundation

// MARK: - Workout streak

/// Consistency expressed as calendar weeks containing at least one
/// workout. Consecutive *days* would reset to 1 on every rest day,
/// which is meaningless for strength training — weeks-in-a-row is how
/// lifters actually think about showing up.
struct WorkoutStreak: Hashable {
    /// Weeks in a row ending at this week (or last week, so the
    /// streak doesn't read as broken before you've trained this week).
    let current: Int
    /// The longest run of consecutive weeks ever recorded.
    let longest: Int

    static let none = WorkoutStreak(current: 0, longest: 0)
}

// MARK: - Milestone

/// One lifetime-progress badge. Either a goal you're climbing toward
/// (`achieved == false`, with a 0…1 `progress` and "84 / 100" text)
/// or a fully-cleared category (`achieved == true`, "Reached").
struct Milestone: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    /// The target this badge represents, e.g. "100 workouts".
    let title: String
    /// Progress readout — "84 / 100" while climbing, "Reached" when maxed.
    let valueText: String
    /// 0…1 fill toward the next threshold (1 when maxed).
    let progress: Double
    /// True once every threshold in the category is cleared.
    let achieved: Bool
}

// MARK: - Monthly recap

/// The current calendar month's training recap.
struct MonthlyRecap: Hashable {
    /// Full month name, e.g. "June".
    let monthLabel: String
    let workouts: Int
    let volume: Double
    let sets: Int
    /// New personal records set during this month.
    let prs: Int

    var isEmpty: Bool { workouts == 0 }
}

// MARK: - ExerciseProgress record helpers

extension ExerciseProgress {
    /// The point at which this exercise's *standing* record was set.
    /// Points are chronological ascending and `isWeightPR` flags each
    /// running-max moment, so the last flagged point is when today's
    /// best was achieved.
    var recordPoint: ExerciseProgressPoint? {
        points.last(where: { $0.isWeightPR })
    }

    /// Date the standing record was set.
    var recordDate: Date? { recordPoint?.date }
}

// MARK: - Journey aggregates

extension Array where Element == WorkoutSession {

    /// Earliest completion across the archive — the first day of the
    /// user's logged training history.
    var trainingSince: Date? {
        compactMap(\.completedAt).min()
    }

    /// "Training since May 2026 · 13 months". Nil when there's no
    /// completed history yet.
    var trainingAgeText: String? {
        guard let since = trainingSince else { return nil }
        let cal = Calendar.current
        let now = Date()
        let sinceLabel = Self.monthYearFormatter.string(from: since)

        let startDay = cal.startOfDay(for: since)
        let nowDay = cal.startOfDay(for: now)
        let months = cal.dateComponents([.month], from: startDay, to: nowDay).month ?? 0

        let age: String
        if months >= 12 {
            let years = months / 12
            let remMonths = months % 12
            age = remMonths == 0
                ? "\(years) \(years == 1 ? "year" : "years")"
                : "\(years)y \(remMonths)mo"
        } else if months >= 1 {
            age = "\(months) \(months == 1 ? "month" : "months")"
        } else {
            let days = cal.dateComponents([.day], from: startDay, to: nowDay).day ?? 0
            age = "\(days) \(days == 1 ? "day" : "days")"
        }
        return "Training since \(sinceLabel) · \(age)"
    }

    /// Consistency as weeks-in-a-row (see `WorkoutStreak`).
    var workoutStreak: WorkoutStreak {
        let cal = Calendar.current
        let weekStarts = Set(compactMap { session -> Date? in
            let date = session.completedAt ?? session.startedAt
            return cal.dateInterval(of: .weekOfYear, for: date)?.start
        }).sorted()

        guard !weekStarts.isEmpty else { return .none }

        // Longest run of consecutive weeks.
        var longest = 1
        var run = 1
        for i in 1..<weekStarts.count {
            if let nextWeek = cal.date(byAdding: .weekOfYear, value: 1, to: weekStarts[i - 1]),
               cal.isDate(nextWeek, inSameDayAs: weekStarts[i]) {
                run += 1
                longest = Swift.max(longest, run)
            } else {
                run = 1
            }
        }

        // Current run: anchored at this week, or last week so the
        // streak survives until the current week elapses.
        let weekSet = Set(weekStarts)
        var current = 0
        if let thisWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start {
            let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeek)
            var anchor: Date?
            if weekSet.contains(thisWeek) {
                anchor = thisWeek
            } else if let lastWeek, weekSet.contains(lastWeek) {
                anchor = lastWeek
            }
            if var cursor = anchor {
                while weekSet.contains(cursor) {
                    current += 1
                    guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
                    cursor = prev
                }
            }
        }

        return WorkoutStreak(current: current, longest: Swift.max(longest, current))
    }

    /// Per-exercise progress ordered by the recency of its standing
    /// record — freshest achievements first. Reuses `progressByExercise`
    /// (≥2 data points), the same source as the lifetime PR count.
    var personalRecords: [ExerciseProgress] {
        progressByExercise.sorted {
            ($0.recordDate ?? .distantPast) > ($1.recordDate ?? .distantPast)
        }
    }

    /// Lifetime milestone badges across four categories. `prCount`
    /// is passed in (callers already compute it for the odometer) so
    /// this stays a single pass per category.
    func milestones(unit: WeightUnit, prCount: Int) -> [Milestone] {
        let workouts = count
        let volume = reduce(0) { $0 + $1.totalVolume }
        let longestStreak = workoutStreak.longest

        return [
            countMilestone(icon: "flame.fill", suffix: "workouts",
                           value: workouts, thresholds: [10, 50, 100, 250, 500, 1000]),
            volumeMilestone(volume: volume, unit: unit),
            countMilestone(icon: "trophy.fill", suffix: "PRs",
                           value: prCount, thresholds: [5, 10, 25, 50, 100]),
            countMilestone(icon: "flame", suffix: "week streak",
                           value: longestStreak, thresholds: [4, 8, 12, 26, 52]),
        ]
    }

    /// Current calendar month's recap. PRs are the records *set this
    /// month* — computed from the full-archive progress series, then
    /// filtered to the month, so the running-max flags stay correct.
    var monthlyRecap: MonthlyRecap {
        let cal = Calendar.current
        let interval = cal.dateInterval(of: .month, for: Date())
        let label = Self.monthFormatter.string(from: Date())

        let monthSessions = filter { session in
            guard let done = session.completedAt, let interval else { return false }
            return done >= interval.start && done < interval.end
        }

        let prs: Int
        if let interval {
            prs = progressByExercise.reduce(0) { acc, prog in
                acc + prog.points.filter {
                    $0.isWeightPR && $0.date >= interval.start && $0.date < interval.end
                }.count
            }
        } else {
            prs = 0
        }

        return MonthlyRecap(
            monthLabel: label,
            workouts: monthSessions.count,
            volume: monthSessions.reduce(0) { $0 + $1.totalVolume },
            sets: monthSessions.reduce(0) { $0 + $1.totalSets },
            prs: prs
        )
    }

    // MARK: - Milestone builders

    private func countMilestone(icon: String, suffix: String, value: Int, thresholds: [Int]) -> Milestone {
        let cleared = thresholds.filter { value >= $0 }
        if let next = thresholds.first(where: { value < $0 }) {
            let floor = cleared.last ?? 0
            let progress = Double(value - floor) / Double(next - floor)
            return Milestone(
                icon: icon,
                title: "\(next) \(suffix)",
                valueText: "\(value) / \(next)",
                progress: Swift.min(1, Swift.max(0, progress)),
                achieved: false
            )
        }
        let top = thresholds.last ?? value
        return Milestone(
            icon: icon,
            title: "\(top) \(suffix)",
            valueText: "Reached",
            progress: 1,
            achieved: true
        )
    }

    private func volumeMilestone(volume: Double, unit: WeightUnit) -> Milestone {
        let thresholds: [Double] = [100_000, 500_000, 1_000_000, 5_000_000]
        let cleared = thresholds.filter { volume >= $0 }
        // Compact display unit-aware: "100k", "1M", "5M".
        func compact(_ lb: Double) -> String {
            let display = WeightFormatter.toDisplay(lb, unit: unit)
            if display >= 1_000_000 {
                let m = display / 1_000_000
                return m.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(m))M" : String(format: "%.1fM", m)
            }
            return WeightFormatter.volumeValue(lb, unit: unit)
        }
        if let next = thresholds.first(where: { volume < $0 }) {
            let floor = cleared.last ?? 0
            let progress = (volume - floor) / (next - floor)
            return Milestone(
                icon: "scalemass.fill",
                title: "\(compact(next)) \(unit.symbol)",
                valueText: "\(compact(volume)) / \(compact(next))",
                progress: Swift.min(1, Swift.max(0, progress)),
                achieved: false
            )
        }
        let top = thresholds.last ?? volume
        return Milestone(
            icon: "scalemass.fill",
            title: "\(compact(top)) \(unit.symbol)",
            valueText: "Reached",
            progress: 1,
            achieved: true
        )
    }

    // MARK: - Formatters

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL"
        return f
    }()
}
