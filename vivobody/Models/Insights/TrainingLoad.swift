//
//  TrainingLoad.swift
//  vivobody
//
//  The personal workload lens for Insights. Load is expressed in
//  estimated hard-set equivalents, the same currency used by muscle
//  volume, so bodyweight work and timed holds count while warm-ups,
//  easy sets, and heavy singles are weighted honestly.
//
//  The headline compares the rolling last seven calendar days with
//  the median of the four non-overlapping weeks immediately before
//  them. A personal productive range of 0.8...1.3 times that usual
//  load gives the status context without presenting a clinical
//  recovery or injury-risk claim.
//
//  The trend contains up to 84 daily points. Every point uses the
//  trailing seven days and, where enough prior history exists, its
//  own historical productive range. Pure value-type computation on
//  injected dates and calendars (see `TrainingLoadTests`).
//

import Foundation

// MARK: - Verdict

nonisolated enum LoadVerdict: Hashable {
    case insufficient
    case low
    case productive
    case high

    static func from(ratio: Double) -> LoadVerdict {
        switch ratio {
        case ..<0.8: return .low
        case ...1.3: return .productive
        default:     return .high
        }
    }
}

// MARK: - Trend and drivers

/// One daily sample of the rolling seven-day load.
nonisolated struct LoadPoint: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let load: Double
    let productiveLower: Double?
    let productiveUpper: Double?
}

/// Estimated hard-set equivalents completed on one calendar day —
/// the per-day (not rolling) sample behind the Today readiness strip.
nonisolated struct DayLoad: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let load: Double

    var trained: Bool { load > 0 }
}

nonisolated struct LoadDriver: Hashable {
    let current: Double
    let usual: Double?
}

nonisolated struct TrainingLoadDrivers: Hashable {
    let hardSets: LoadDriver
    let sessions: LoadDriver
    let heavySets: LoadDriver

    static let empty = TrainingLoadDrivers(
        hardSets: LoadDriver(current: 0, usual: nil),
        sessions: LoadDriver(current: 0, usual: nil),
        heavySets: LoadDriver(current: 0, usual: nil)
    )
}

// MARK: - Report

nonisolated struct TrainingLoadReport: Hashable {
    /// Estimated hard-set equivalents in the rolling last seven days.
    let currentLoad: Double
    /// Median weekly load across the four preceding weeks.
    let usualLoad: Double?
    /// Current load divided by usual load. Zero while forming.
    let ratio: Double
    /// Early comparison against the median active prior week. This
    /// powers a provisional gauge marker before the four-week personal
    /// baseline is stable; nil when no prior week exists or once the
    /// stable ratio is available.
    let provisionalRatio: Double?
    let verdict: LoadVerdict
    /// Whole calendar days from first completed work to `now`.
    let daysLogged: Int
    /// Rolling seven-day load over at most the trailing 12 weeks.
    let points: [LoadPoint]
    /// Per-day loads for the trailing seven calendar days, oldest
    /// first and ending today. Untrained days appear with zero load.
    let recentDays: [DayLoad]
    let drivers: TrainingLoadDrivers

    var hasEnoughHistory: Bool { verdict != .insufficient }

    /// The best available position for compact visual gauges.
    var gaugeRatio: Double? {
        hasEnoughHistory ? ratio : provisionalRatio
    }

    var productiveRange: ClosedRange<Double>? {
        guard let usualLoad else { return nil }
        return (usualLoad * 0.8)...(usualLoad * 1.3)
    }

    var changeFromUsual: Double? {
        guard let usualLoad, usualLoad > 0 else { return nil }
        return (currentLoad - usualLoad) / usualLoad
    }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Personal rolling workload report as of `now`.
    func trainingLoad(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TrainingLoadReport {
        let measurements = Self.measurements(from: self, through: now)
        guard let first = measurements.first?.date else {
            return TrainingLoadReport(
                currentLoad: 0,
                usualLoad: nil,
                ratio: 0,
                provisionalRatio: nil,
                verdict: .insufficient,
                daysLogged: 0,
                points: [],
                recentDays: [],
                drivers: .empty
            )
        }

        let today = calendar.startOfDay(for: now)
        let firstDay = calendar.startOfDay(for: first)
        let daysLogged = Swift.max(
            0,
            calendar.dateComponents([.day], from: firstDay, to: today).day ?? 0
        )
        let current = Self.window(
            endingOn: today,
            measurements: measurements,
            calendar: calendar
        )
        let previous = Self.previousWindows(
            before: today,
            measurements: measurements,
            calendar: calendar
        )
        let activeBaseline = previous.filter { $0.load > 0 }
        let usual = daysLogged >= 28 && activeBaseline.count >= 3
            ? Self.median(previous.map(\.load))
            : nil
        let ratio = usual.flatMap { $0 > 0 ? current.load / $0 : nil } ?? 0
        let provisionalUsual = Self.median(activeBaseline.map(\.load))
        let provisionalRatio = usual == nil && provisionalUsual > 0
            ? current.load / provisionalUsual
            : nil
        let verdict = usual == nil ? LoadVerdict.insufficient : LoadVerdict.from(ratio: ratio)

        return TrainingLoadReport(
            currentLoad: current.load,
            usualLoad: usual,
            ratio: ratio,
            provisionalRatio: provisionalRatio,
            verdict: verdict,
            daysLogged: daysLogged,
            points: Self.rollingPoints(
                measurements: measurements,
                firstDay: firstDay,
                today: today,
                calendar: calendar
            ),
            recentDays: Self.recentDailyLoads(
                measurements: measurements,
                today: today,
                calendar: calendar
            ),
            drivers: TrainingLoadDrivers(
                hardSets: LoadDriver(current: current.load, usual: usual),
                sessions: LoadDriver(
                    current: Double(current.sessions),
                    usual: usual == nil ? nil : Self.median(previous.map { Double($0.sessions) })
                ),
                heavySets: LoadDriver(
                    current: current.heavySets,
                    usual: usual == nil ? nil : Self.median(previous.map(\.heavySets))
                )
            )
        )
    }

    private struct Measurement {
        let date: Date
        let load: Double
        let heavySets: Double
    }

    private struct Window {
        let load: Double
        let sessions: Int
        let heavySets: Double
    }

    /// Replay completed sessions chronologically so each set is
    /// judged against only the exercise history that preceded it.
    private static func measurements(
        from sessions: [WorkoutSession],
        through now: Date
    ) -> [Measurement] {
        let completed = sessions
            .compactMap { session -> (WorkoutSession, Date)? in
                guard let date = session.completedAt, date <= now else { return nil }
                return (session, date)
            }
            .sorted { $0.1 < $1.1 }

        var calculator = SetStimulus.Calculator()
        return completed.compactMap { session, date in
            var load = 0.0
            var heavySets = 0.0
            for exercise in session.orderedExercises {
                load += calculator.setEquivalentCredit(for: exercise, at: date)
                guard exercise.modality == .dynamicStrength,
                      exercise.trackingMode == .reps else { continue }
                heavySets += Double(
                    exercise.orderedSets.filter {
                        $0.isAnalyticsEligible && (1...5).contains($0.reps)
                    }.count
                )
            }
            guard load > 0 else { return nil }
            return Measurement(date: date, load: load, heavySets: heavySets)
        }
    }

    private static func rollingPoints(
        measurements: [Measurement],
        firstDay: Date,
        today: Date,
        calendar: Calendar
    ) -> [LoadPoint] {
        guard let twelveWeeksAgo = calendar.date(byAdding: .day, value: -83, to: today) else {
            return []
        }
        let start = Swift.max(firstDay, twelveWeeksAgo)
        let days = Swift.max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)

        return (0...days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let current = window(endingOn: day, measurements: measurements, calendar: calendar)
            let previous = previousWindows(before: day, measurements: measurements, calendar: calendar)
            let age = calendar.dateComponents([.day], from: firstDay, to: day).day ?? 0
            let usual = age >= 28 && previous.filter({ $0.load > 0 }).count >= 3
                ? median(previous.map(\.load))
                : nil
            return LoadPoint(
                date: day,
                load: current.load,
                productiveLower: usual.map { $0 * 0.8 },
                productiveUpper: usual.map { $0 * 1.3 }
            )
        }
    }

    private static func recentDailyLoads(
        measurements: [Measurement],
        today: Date,
        calendar: Calendar
    ) -> [DayLoad] {
        (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let load = measurements
                .filter { calendar.startOfDay(for: $0.date) == day }
                .reduce(0) { $0 + $1.load }
            return DayLoad(date: day, load: load)
        }
    }

    private static func window(
        endingOn day: Date,
        measurements: [Measurement],
        calendar: Calendar
    ) -> Window {
        guard
            let end = calendar.date(byAdding: .day, value: 1, to: day),
            let start = calendar.date(byAdding: .day, value: -6, to: day)
        else {
            return Window(load: 0, sessions: 0, heavySets: 0)
        }
        return window(from: start, to: end, measurements: measurements)
    }

    private static func previousWindows(
        before day: Date,
        measurements: [Measurement],
        calendar: Calendar
    ) -> [Window] {
        guard let currentStart = calendar.date(byAdding: .day, value: -6, to: day) else {
            return []
        }
        return (1...4).compactMap { offset in
            guard
                let end = calendar.date(byAdding: .day, value: -7 * (offset - 1), to: currentStart),
                let start = calendar.date(byAdding: .day, value: -7, to: end)
            else {
                return nil
            }
            return window(from: start, to: end, measurements: measurements)
        }
    }

    private static func window(
        from start: Date,
        to end: Date,
        measurements: [Measurement]
    ) -> Window {
        let included = measurements.filter { $0.date >= start && $0.date < end }
        return Window(
            load: included.reduce(0) { $0 + $1.load },
            sessions: included.count,
            heavySets: included.reduce(0) { $0 + $1.heavySets }
        )
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
