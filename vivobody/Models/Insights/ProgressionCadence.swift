//
//  ProgressionCadence.swift
//  vivobody
//
//  Personal load-progression rhythm for one exercise: how often the
//  lifter's top effective load steps above its running max. Built as
//  a pure walk over an exercise's chronological progress points —
//  the baseline session establishes the starting level, every
//  running-max step-up is an "increase," and the median gap between
//  consecutive events is the cadence. Median (not mean) so a single
//  vacation gap cannot distort the rhythm.
//
//  Only comparable-load work has a cadence: bodyweight-dependent
//  points with no recoverable absolute load are skipped rather than
//  letting raw assistance values fake a progression.
//

import Foundation

/// The computed rhythm read for an exercise's load progression.
struct ProgressionCadence: Hashable {
    /// One progression event: the baseline session or a session whose
    /// top effective load exceeded everything before it.
    struct Event: Hashable {
        let date: Date
        /// Top effective load (canonical lb) established at this event.
        let load: Double
    }

    /// First session with a known effective load — the starting level.
    let baseline: Event

    /// Every running-max step-up after the baseline, chronological.
    let increases: [Event]

    /// Median calendar days between consecutive progression events
    /// (baseline included). Each gap is clamped to at least one day so
    /// two same-day sessions cannot read as "every 0 days."
    let medianGapDays: Int

    /// Whole calendar days from the most recent increase to `now`.
    let daysSinceLastIncrease: Int

    /// All progression events, baseline first. Convenience for the
    /// rhythm-strip renderer.
    var events: [Event] { [baseline] + increases }

    /// True when the current gap has outrun the usual rhythm — the
    /// lifter is past the point where they would typically add load.
    var isPastUsualRhythm: Bool { daysSinceLastIncrease > medianGapDays }

    /// Minimum number of recorded increases before a cadence exists.
    /// One increase is a single data point, not a rhythm.
    static let minimumIncreases = 2

    /// Compute the cadence from an exercise's chronological progress
    /// series. Nil when the exercise doesn't compare load, when no
    /// point has a recoverable effective load, or when there are
    /// fewer than `minimumIncreases` recorded step-ups.
    static func compute(
        points: [ExerciseProgressPoint],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProgressionCadence? {
        let loaded = points
            .filter { $0.performanceSemanticKind.comparesLoad }
            .compactMap { point -> (date: Date, load: Double)? in
                guard let load = point.effectiveTopLoad else { return nil }
                return (point.date, load)
            }
            .sorted { $0.date < $1.date }

        guard let first = loaded.first else { return nil }

        let baseline = Event(date: first.date, load: first.load)
        var runningMax = first.load
        var increases: [Event] = []
        for entry in loaded.dropFirst() where entry.load > runningMax {
            runningMax = entry.load
            increases.append(Event(date: entry.date, load: entry.load))
        }

        guard increases.count >= minimumIncreases else { return nil }

        let eventDates = ([baseline] + increases).map(\.date)
        let gaps = zip(eventDates, eventDates.dropFirst()).map { earlier, later in
            max(1, wholeDays(from: earlier, to: later, calendar: calendar))
        }

        guard let median = median(of: gaps),
              let lastIncrease = increases.last else { return nil }

        return ProgressionCadence(
            baseline: baseline,
            increases: increases,
            medianGapDays: median,
            daysSinceLastIncrease: max(0, wholeDays(from: lastIncrease.date, to: now, calendar: calendar))
        )
    }

    private static func wholeDays(
        from earlier: Date,
        to later: Date,
        calendar: Calendar
    ) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: earlier),
            to: calendar.startOfDay(for: later)
        ).day ?? 0
    }

    /// Median of integer day gaps; even counts round the midpoint
    /// average to the nearest whole day.
    private static func median(of gaps: [Int]) -> Int? {
        guard !gaps.isEmpty else { return nil }
        let sorted = gaps.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 1 {
            return sorted[mid]
        }
        let average = Double(sorted[mid - 1] + sorted[mid]) / 2
        return max(1, Int(average.rounded()))
    }
}
