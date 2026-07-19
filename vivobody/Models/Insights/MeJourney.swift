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

/// One lifetime-progress badge showing the user's standing against
/// the next threshold. The progress value always matches the visible
/// ratio, so "84 / 100" renders as 84% filled.
struct Milestone: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    /// Silkscreen category legend — "Workouts", "Volume", "PRs".
    let legend: String
    /// Current standing, the tile's big numeral — "84", "39.8k".
    let valueLabel: String
    /// Next threshold — "100", "45.4k kg". Nil once every tier is cleared.
    let targetLabel: String?
    /// 0…1 ratio of the standing value to the visible next threshold.
    let targetProgress: Double
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
    let volumeAvailability: ComparableTonnageAvailability
    let sets: Int
    /// New personal records set during this month.
    let prs: Int

    var isEmpty: Bool { workouts == 0 }
}

// MARK: - ExerciseProgress record helpers

extension ExerciseProgress {
    /// The point at which this exercise's *standing* record was set.
    /// Points are chronological ascending and `isStrengthPR` flags each
    /// running-max moment, so the last flagged point is when today's
    /// best was achieved.
    var recordPoint: ExerciseProgressPoint? {
        points.last(where: { $0.isStrengthPR })
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
        progressByExercise.filter { $0.recordDate != nil }.sorted {
            ($0.recordDate ?? .distantPast) > ($1.recordDate ?? .distantPast)
        }
    }

    /// Lifetime milestone badges across four categories. `prCount`
    /// is passed in (callers already compute it for the odometer) so
    /// this stays a single pass per category.
    func milestones(unit: WeightUnit, prCount: Int) -> [Milestone] {
        let workouts = count
        let tonnage = comparableTonnageSummary
        let longestStreak = workoutStreak.longest

        return [
            countMilestone(icon: "flame.fill", legend: "Workouts",
                           value: workouts, thresholds: [10, 50, 100, 250, 500, 1000]),
            volumeMilestone(tonnage: tonnage, unit: unit),
            countMilestone(icon: "trophy.fill", legend: "PRs",
                           value: prCount, thresholds: [5, 10, 25, 50, 100]),
            countMilestone(icon: "calendar", legend: "Week streak",
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
                    $0.isStrengthPR && $0.date >= interval.start && $0.date < interval.end
                }.count
            }
        } else {
            prs = 0
        }

        let tonnage = monthSessions.comparableTonnageSummary
        return MonthlyRecap(
            monthLabel: label,
            workouts: monthSessions.count,
            volume: tonnage.knownSubtotal,
            volumeAvailability: tonnage.availability,
            sets: monthSessions.reduce(0) { $0 + $1.totalSets },
            prs: prs
        )
    }

    // MARK: - Milestone builders

    private func countMilestone(icon: String, legend: String, value: Int, thresholds: [Int]) -> Milestone {
        if let next = thresholds.first(where: { value < $0 }) {
            return Milestone(
                icon: icon,
                legend: legend,
                valueLabel: "\(value)",
                targetLabel: "\(next)",
                targetProgress: Swift.min(1, Swift.max(0, Double(value) / Double(next))),
                achieved: false
            )
        }
        return Milestone(
            icon: icon,
            legend: legend,
            valueLabel: "\(value)",
            targetLabel: nil,
            targetProgress: 1,
            achieved: true
        )
    }

    private func volumeMilestone(
        tonnage: ComparableTonnageSummary,
        unit: WeightUnit
    ) -> Milestone {
        let thresholds: [Double] = [100_000, 500_000, 1_000_000, 5_000_000]
        // Compact display unit-aware: "100k", "1M", "5M".
        func compact(_ lb: Double) -> String {
            let display = WeightFormatter.toDisplay(lb, unit: unit)
            if display >= 1_000_000 {
                let m = display / 1_000_000
                return m.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(m))M" : String(format: "%.1fM", m)
            }
            return WeightFormatter.volumeValue(lb, unit: unit)
        }
        guard tonnage.availability != .unavailable else {
            return Milestone(
                icon: "scalemass.fill",
                legend: "Volume unavailable",
                valueLabel: "—",
                targetLabel: nil,
                targetProgress: 0,
                achieved: false
            )
        }
        let volume = tonnage.knownSubtotal
        let valueSuffix = tonnage.availability == .partial ? "+" : ""
        if let next = thresholds.first(where: { volume < $0 }) {
            return Milestone(
                icon: "scalemass.fill",
                legend: tonnage.availability == .partial ? "Known volume" : "Volume",
                valueLabel: compact(volume) + valueSuffix,
                targetLabel: "\(compact(next)) \(unit.symbol)",
                targetProgress: Swift.min(1, Swift.max(0, volume / next)),
                achieved: false
            )
        }
        return Milestone(
            icon: "scalemass.fill",
            legend: tonnage.availability == .partial ? "Known volume" : "Volume",
            valueLabel: compact(volume) + valueSuffix,
            targetLabel: nil,
            targetProgress: 1,
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
