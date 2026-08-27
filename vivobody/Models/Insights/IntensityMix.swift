//
//  IntensityMix.swift
//  vivobody
//
//  How completed, rep-tracked strength sets split across three plain
//  rep ranges. The buckets describe what was logged without claiming
//  a training adaptation from rep count alone:
//    • low reps      — 1–5
//    • moderate reps — 6–12
//    • high reps     — 13+
//
//  Counts completed dynamic-strength `.reps` sets over a rolling
//  window (28 days by default, to read current emphasis). Timed holds,
//  power work, and mismatched tracking pairs are excluded. Pure value-
//  type computation on injected dates (see `IntensityMixTests`).
//

import Foundation

// MARK: - Zone

nonisolated enum IntensityZone: Hashable, CaseIterable {
    case strength
    case hypertrophy
    case endurance

    /// Bucket a completed set's rep count. Reps ≤ 0 should be filtered
    /// by the caller (an unlogged set), but guard anyway.
    static func zone(forReps reps: Int) -> IntensityZone {
        switch reps {
        case ...5: .strength
        case 6 ... 12: .hypertrophy
        default: .endurance
        }
    }

    var label: String {
        switch self {
        case .strength: "Low reps"
        case .hypertrophy: "Moderate reps"
        case .endurance: "High reps"
        }
    }

    var repRange: String {
        switch self {
        case .strength: "1–5"
        case .hypertrophy: "6–12"
        case .endurance: "13+"
        }
    }
}

// MARK: - Mix

nonisolated struct IntensityMix: Hashable {
    /// Below this sample size the UI labels the distribution as an
    /// early read instead of presenting a tiny sample as settled.
    static let minimumClearSampleSets = 6

    let strengthSets: Int
    let hypertrophySets: Int
    let enduranceSets: Int

    var total: Int {
        strengthSets + hypertrophySets + enduranceSets
    }

    var hasData: Bool {
        total > 0
    }

    var hasSparseSample: Bool {
        hasData && total < Self.minimumClearSampleSets
    }

    func count(_ zone: IntensityZone) -> Int {
        switch zone {
        case .strength: strengthSets
        case .hypertrophy: hypertrophySets
        case .endurance: enduranceSets
        }
    }

    /// Fraction (0…1) of eligible completed sets in a zone.
    func share(_ zone: IntensityZone) -> Double {
        total > 0 ? Double(count(zone)) / Double(total) : 0
    }

    /// The zone carrying the most sets, or nil when there's no data.
    /// Ties resolve toward the heavier end (strength → hypertrophy →
    /// endurance) so a tie never reads as "high-rep heavy".
    var dominant: IntensityZone? {
        guard hasData else { return nil }
        return IntensityZone.allCases.max { count($0) < count($1) }
    }
}

// MARK: - Weekly breakdown

/// One calendar week's rep-range counts. The aggregator returns every
/// week in the requested window, including zero-set weeks, so gaps are
/// explicit and the horizontal scale never stretches sparse data. The
/// current calendar week is marked as partial.
nonisolated struct IntensityWeek: Identifiable, Hashable {
    var id: Date {
        weekStart
    }

    let weekStart: Date
    let strengthSets: Int
    let hypertrophySets: Int
    let enduranceSets: Int
    let isCurrentWeek: Bool

    var total: Int {
        strengthSets + hypertrophySets + enduranceSets
    }

    func count(_ zone: IntensityZone) -> Int {
        switch zone {
        case .strength: strengthSets
        case .hypertrophy: hypertrophySets
        case .endurance: enduranceSets
        }
    }
}

// MARK: - Shared calendar window

/// The exact locale-aware calendar-week window shared by the stacked
/// chart and regression. A 12-week request always means the current
/// partial week plus the previous 11 calendar weeks — never 13 buckets
/// caused by rounding an 84-day instant cutoff back to a week start.
nonisolated struct RepRangeWeekWindow {
    let weekStarts: [Date]
    let start: Date
    let currentWeekStart: Date

    static func make(
        weeks: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> RepRangeWeekWindow? {
        guard weeks > 0,
              let currentWeekStart = calendar.dateInterval(
                  of: .weekOfYear,
                  for: now
              )?.start,
              let start = calendar.date(
                  byAdding: .weekOfYear,
                  value: -(weeks - 1),
                  to: currentWeekStart
              )
        else {
            return nil
        }

        let starts = (0 ..< weeks).compactMap {
            calendar.date(byAdding: .weekOfYear, value: $0, to: start)
        }
        guard starts.count == weeks else { return nil }
        return RepRangeWeekWindow(
            weekStarts: starts,
            start: start,
            currentWeekStart: currentWeekStart
        )
    }
}

// MARK: - Aggregation

@MainActor
extension [WorkoutSession] {
    /// Rep-range distribution of completed `.reps` sets over the
    /// trailing `window` (default 28 days) as of `now`.
    func intensityMix(
        window: TimeInterval = 28 * 86400,
        now: Date = Date()
    ) -> IntensityMix {
        AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: self)
        ).intensityMix(window: window, now: now)
    }

    /// Zone counts for exactly `weeks` calendar weeks (default 12),
    /// including the current partial week, chronological ascending.
    func weeklyIntensity(weeks: Int = 12, now: Date = Date()) -> [IntensityWeek] {
        AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: self)
        ).weeklyIntensity(weeks: weeks, now: now)
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Snapshot-backed rep-range distribution used by the background
    /// analytics worker.
    func intensityMix(
        window: TimeInterval = 28 * 86400,
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> IntensityMix {
        let cancelled = IntensityMix(
            strengthSets: 0,
            hypertrophySets: 0,
            enduranceSets: 0
        )
        guard !isCancelled() else { return cancelled }

        let cutoff = now.addingTimeInterval(-window)
        var strength = 0, hypertrophy = 0, endurance = 0

        for session in sessions {
            guard !isCancelled() else { return cancelled }
            let date = session.date
            guard date >= cutoff, date <= now else { continue }
            for replay in session.exercises {
                guard !isCancelled() else { return cancelled }
                guard replay.exercise.modality == .dynamicStrength,
                      replay.exercise.trackingMode == .reps
                else {
                    continue
                }
                for set in replay.exercise.sets {
                    guard !isCancelled() else { return cancelled }
                    guard set.isAnalyticsEligible, set.reps > 0 else {
                        continue
                    }
                    switch IntensityZone.zone(forReps: set.reps) {
                    case .strength: strength += 1
                    case .hypertrophy: hypertrophy += 1
                    case .endurance: endurance += 1
                    }
                }
            }
        }

        guard !isCancelled() else { return cancelled }
        return IntensityMix(
            strengthSets: strength,
            hypertrophySets: hypertrophy,
            enduranceSets: endurance
        )
    }

    /// Buckets by the same locale-aware week start
    /// `repRangeMigration` uses so the two reads always agree.
    func weeklyIntensity(
        weeks: Int = 12,
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> [IntensityWeek] {
        guard !isCancelled() else { return [] }

        let calendar = Calendar.current
        guard let window = RepRangeWeekWindow.make(
            weeks: weeks,
            now: now,
            calendar: calendar
        ) else { return [] }
        let validWeekStarts = Set(window.weekStarts)

        var byWeek: [Date: (strength: Int, hypertrophy: Int, endurance: Int)] = [:]

        for session in sessions {
            guard !isCancelled() else { return [] }
            let date = session.date
            guard date >= window.start, date <= now else { continue }
            guard let weekStart = calendar.dateInterval(
                of: .weekOfYear,
                for: date
            )?.start,
                validWeekStarts.contains(weekStart) else { continue }

            for replay in session.exercises {
                guard !isCancelled() else { return [] }
                guard replay.exercise.modality == .dynamicStrength,
                      replay.exercise.trackingMode == .reps
                else {
                    continue
                }
                for set in replay.exercise.sets {
                    guard !isCancelled() else { return [] }
                    guard set.isAnalyticsEligible, set.reps > 0 else {
                        continue
                    }
                    var bucket = byWeek[weekStart] ?? (0, 0, 0)
                    switch IntensityZone.zone(forReps: set.reps) {
                    case .strength: bucket.strength += 1
                    case .hypertrophy: bucket.hypertrophy += 1
                    case .endurance: bucket.endurance += 1
                    }
                    byWeek[weekStart] = bucket
                }
            }
        }

        guard !isCancelled() else { return [] }
        var result: [IntensityWeek] = []
        result.reserveCapacity(window.weekStarts.count)
        for weekStart in window.weekStarts {
            guard !isCancelled() else { return [] }
            let bucket = byWeek[weekStart] ?? (0, 0, 0)
            result.append(IntensityWeek(
                weekStart: weekStart,
                strengthSets: bucket.strength,
                hypertrophySets: bucket.hypertrophy,
                enduranceSets: bucket.endurance,
                isCurrentWeek: weekStart == window.currentWeekStart
            ))
        }
        return result
    }
}
