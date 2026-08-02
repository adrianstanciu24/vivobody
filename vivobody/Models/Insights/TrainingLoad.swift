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
//  them. A personal recent range of 0.8...1.3 times that median gives
//  relative context; it is not a clinical recovery, productivity, or
//  injury-risk claim.
//
//  The trend contains up to 84 daily points. Every point uses the
//  trailing seven days and, where enough prior history exists, its
//  own historical recent range. Pure value-type computation on
//  injected dates and calendars (see `TrainingLoadTests`).
//

import Foundation

// MARK: - Verdict

nonisolated enum LoadVerdict: Hashable, Sendable {
    case insufficient
    /// Below the user's recent four-week range.
    case low
    /// Within the user's recent four-week range. The case name remains
    /// stable for source compatibility; UI copy calls this "within."
    case productive
    /// Above the user's recent four-week range.
    case high

    /// Recent-range band for current ÷ four-week median load. Single
    /// source of truth — the report's absolute range and every gauge
    /// derive from these bounds.
    static let recentRatioBand: ClosedRange<Double> = 0.8...1.3

    /// Compatibility spelling for existing non-Insights consumers.
    static var productiveRatioBand: ClosedRange<Double> { recentRatioBand }

    static func from(ratio: Double) -> LoadVerdict {
        switch ratio {
        case ..<recentRatioBand.lowerBound: return .low
        case ...recentRatioBand.upperBound: return .productive
        default:                            return .high
        }
    }
}

// MARK: - Trend and drivers

/// One daily sample of the rolling seven-day load.
nonisolated struct LoadPoint: Identifiable, Hashable, Sendable {
    var id: Date { date }
    let date: Date
    let load: Double
    let productiveLower: Double?
    let productiveUpper: Double?

    /// Recent-range spellings used by current UI. Stored-property names
    /// remain stable for snapshots and existing callers.
    var rangeLower: Double? { productiveLower }
    var rangeUpper: Double? { productiveUpper }
}

/// Estimated hard-set equivalents completed on one calendar day —
/// the per-day (not rolling) sample behind the Today readiness strip.
nonisolated struct DayLoad: Identifiable, Hashable, Sendable {
    var id: Date { date }
    let date: Date
    let load: Double

    var trained: Bool { load > 0 }

    /// Very short weekday symbol ("M", "T", …) for day-strip labels.
    func weekdayInitial(calendar: Calendar = .current) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }
}

nonisolated struct LoadDriver: Hashable, Sendable {
    let current: Double
    let usual: Double?
}

nonisolated struct TrainingLoadDrivers: Hashable, Sendable {
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

nonisolated struct TrainingLoadReport: Hashable, Sendable {
    /// Minimum observation span before the four-week comparison settles.
    static let baselineMinimumDays = 28
    /// At least three of the four prior weeks must contain qualifying work.
    static let requiredActiveBaselineWeeks = 3

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
    /// Prior non-overlapping weeks containing qualifying strength work.
    let activeBaselineWeeks: Int
    /// Rolling seven-day load over at most the trailing 12 weeks.
    let points: [LoadPoint]
    /// Per-day loads for the trailing seven calendar days, oldest
    /// first and ending today. Untrained days appear with zero load.
    let recentDays: [DayLoad]
    let drivers: TrainingLoadDrivers

    /// Explicit initializer keeps existing fixtures source-compatible
    /// while allowing analytics to expose concrete baseline progress.
    init(
        currentLoad: Double,
        usualLoad: Double?,
        ratio: Double,
        provisionalRatio: Double?,
        verdict: LoadVerdict,
        daysLogged: Int,
        activeBaselineWeeks: Int = 0,
        points: [LoadPoint],
        recentDays: [DayLoad],
        drivers: TrainingLoadDrivers
    ) {
        self.currentLoad = currentLoad
        self.usualLoad = usualLoad
        self.ratio = ratio
        self.provisionalRatio = provisionalRatio
        self.verdict = verdict
        self.daysLogged = daysLogged
        self.activeBaselineWeeks = activeBaselineWeeks
        self.points = points
        self.recentDays = recentDays
        self.drivers = drivers
    }

    var hasEnoughHistory: Bool { verdict != .insufficient }

    /// The best available position for compact visual gauges.
    var gaugeRatio: Double? {
        hasEnoughHistory ? ratio : provisionalRatio
    }

    var recentRange: ClosedRange<Double>? {
        guard let usualLoad else { return nil }
        let band = LoadVerdict.recentRatioBand
        return (usualLoad * band.lowerBound)...(usualLoad * band.upperBound)
    }

    /// Compatibility spelling for existing non-Insights consumers.
    var productiveRange: ClosedRange<Double>? { recentRange }

    var observedBaselineDays: Int {
        min(Self.baselineMinimumDays, max(0, daysLogged))
    }

    var baselineDaysRemaining: Int {
        max(0, Self.baselineMinimumDays - daysLogged)
    }

    var baselineWeeksRemaining: Int {
        max(0, Self.requiredActiveBaselineWeeks - activeBaselineWeeks)
    }

    var changeFromUsual: Double? {
        guard let usualLoad, usualLoad > 0 else { return nil }
        return (currentLoad - usualLoad) / usualLoad
    }

    // MARK: Gauge geometry

    /// The compact gauges plot ratios on a 0…2× track.
    static let gaugeRatioSpan: Double = 2

    /// Fractional position (0…1) of a ratio along the gauge track.
    static func gaugePosition(forRatio ratio: Double) -> Double {
        min(1, max(0, ratio / gaugeRatioSpan))
    }

    /// The recent band mapped onto the gauge track.
    static var gaugeRecentBand: ClosedRange<Double> {
        let band = LoadVerdict.recentRatioBand
        return gaugePosition(forRatio: band.lowerBound)...gaugePosition(forRatio: band.upperBound)
    }

    /// Compatibility spelling for existing non-Insights consumers.
    static var gaugeProductiveBand: ClosedRange<Double> { gaugeRecentBand }

    /// Marker position for the best available ratio; nil while no
    /// comparison exists at all.
    var gaugeMarkerPosition: Double? {
        gaugeRatio.map(Self.gaugePosition(forRatio:))
    }
}

// MARK: - Aggregation

@MainActor
extension Array where Element == WorkoutSession {
    /// Personal rolling workload report as of `now`.
    func trainingLoad(
        now: Date = Date(),
        calendar: Calendar = .current,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> TrainingLoadReport {
        AnalyticsAccumulator.replay(
            AnalyticsSnapshot(
                sessions: filter { $0.completedAt != nil }
            ),
            isCancelled: isCancelled
        ).trainingLoad(
            now: now,
            calendar: calendar,
            isCancelled: isCancelled
        )
    }

    /// Build the report from SessionAnalytics' single stimulus replay.
    func trainingLoad(
        using accumulator: AnalyticsAccumulator,
        now: Date = Date(),
        calendar: Calendar = .current,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> TrainingLoadReport {
        accumulator.trainingLoad(
            now: now,
            calendar: calendar,
            isCancelled: isCancelled
        )
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Build the report from the single chronological stimulus replay.
    func trainingLoad(
        now: Date = Date(),
        calendar: Calendar = .current,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> TrainingLoadReport {
        guard !isCancelled() else { return Self.emptyReport() }
        let measurements = Self.measurements(
            from: self,
            through: now,
            isCancelled: isCancelled
        )
        guard !isCancelled() else { return Self.emptyReport() }
        guard let first = measurements.first?.date else {
            return Self.emptyReport()
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
            calendar: calendar,
            isCancelled: isCancelled
        )
        guard !isCancelled() else { return Self.emptyReport() }
        let previous = Self.previousWindows(
            before: today,
            measurements: measurements,
            calendar: calendar,
            isCancelled: isCancelled
        )
        guard !isCancelled() else { return Self.emptyReport() }
        let activeBaseline = previous.filter { $0.load > 0 }
        let usual = daysLogged >= TrainingLoadReport.baselineMinimumDays
            && activeBaseline.count >= TrainingLoadReport.requiredActiveBaselineWeeks
            ? Self.median(previous.map(\.load))
            : nil
        let ratio = usual.flatMap { $0 > 0 ? current.load / $0 : nil } ?? 0
        let provisionalUsual = Self.median(activeBaseline.map(\.load))
        let provisionalRatio = usual == nil && provisionalUsual > 0
            ? current.load / provisionalUsual
            : nil
        let verdict = usual == nil ? LoadVerdict.insufficient : LoadVerdict.from(ratio: ratio)
        let points = Self.rollingPoints(
            measurements: measurements,
            firstDay: firstDay,
            today: today,
            calendar: calendar,
            isCancelled: isCancelled
        )
        guard !isCancelled() else { return Self.emptyReport() }
        let recentDays = Self.recentDailyLoads(
            measurements: measurements,
            today: today,
            calendar: calendar,
            isCancelled: isCancelled
        )
        guard !isCancelled() else { return Self.emptyReport() }

        return TrainingLoadReport(
            currentLoad: current.load,
            usualLoad: usual,
            ratio: ratio,
            provisionalRatio: provisionalRatio,
            verdict: verdict,
            daysLogged: daysLogged,
            activeBaselineWeeks: activeBaseline.count,
            points: points,
            recentDays: recentDays,
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

    private static func emptyReport() -> TrainingLoadReport {
        TrainingLoadReport(
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
        from accumulator: AnalyticsAccumulator,
        through now: Date,
        isCancelled: @Sendable () -> Bool
    ) -> [Measurement] {
        var result: [Measurement] = []
        result.reserveCapacity(accumulator.sessions.count)
        for session in accumulator.sessions {
            guard !isCancelled() else { return [] }
            guard session.isCompleted,
                  session.date <= now,
                  session.totalSetEquivalent > 0 else {
                continue
            }
            result.append(Measurement(
                date: session.date,
                load: session.totalSetEquivalent,
                heavySets: session.heavySets
            ))
        }
        return result
    }

    private static func rollingPoints(
        measurements: [Measurement],
        firstDay: Date,
        today: Date,
        calendar: Calendar,
        isCancelled: @Sendable () -> Bool
    ) -> [LoadPoint] {
        guard !isCancelled() else { return [] }
        guard let twelveWeeksAgo = calendar.date(byAdding: .day, value: -83, to: today) else {
            return []
        }
        let start = Swift.max(firstDay, twelveWeeksAgo)
        let days = Swift.max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)

        var result: [LoadPoint] = []
        result.reserveCapacity(days + 1)
        for offset in 0...days {
            guard !isCancelled() else { return [] }
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                continue
            }
            let current = window(
                endingOn: day,
                measurements: measurements,
                calendar: calendar,
                isCancelled: isCancelled
            )
            guard !isCancelled() else { return [] }
            let previous = previousWindows(
                before: day,
                measurements: measurements,
                calendar: calendar,
                isCancelled: isCancelled
            )
            guard !isCancelled() else { return [] }
            let age = calendar.dateComponents([.day], from: firstDay, to: day).day ?? 0
            let usual = age >= TrainingLoadReport.baselineMinimumDays
                && previous.filter({ $0.load > 0 }).count
                    >= TrainingLoadReport.requiredActiveBaselineWeeks
                ? median(previous.map(\.load))
                : nil
            result.append(LoadPoint(
                date: day,
                load: current.load,
                productiveLower: usual.map { $0 * LoadVerdict.recentRatioBand.lowerBound },
                productiveUpper: usual.map { $0 * LoadVerdict.recentRatioBand.upperBound }
            ))
        }
        return result
    }

    private static func recentDailyLoads(
        measurements: [Measurement],
        today: Date,
        calendar: Calendar,
        isCancelled: @Sendable () -> Bool
    ) -> [DayLoad] {
        var result: [DayLoad] = []
        result.reserveCapacity(7)
        for offset in (0..<7).reversed() {
            guard !isCancelled() else { return [] }
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            var load = 0.0
            for measurement in measurements {
                guard !isCancelled() else { return [] }
                if calendar.startOfDay(for: measurement.date) == day {
                    load += measurement.load
                }
            }
            result.append(DayLoad(date: day, load: load))
        }
        return result
    }

    private static func window(
        endingOn day: Date,
        measurements: [Measurement],
        calendar: Calendar,
        isCancelled: @Sendable () -> Bool
    ) -> Window {
        guard !isCancelled() else { return Window(load: 0, sessions: 0, heavySets: 0) }
        guard
            let end = calendar.date(byAdding: .day, value: 1, to: day),
            let start = calendar.date(byAdding: .day, value: -6, to: day)
        else {
            return Window(load: 0, sessions: 0, heavySets: 0)
        }
        return window(
            from: start,
            to: end,
            measurements: measurements,
            isCancelled: isCancelled
        )
    }

    private static func previousWindows(
        before day: Date,
        measurements: [Measurement],
        calendar: Calendar,
        isCancelled: @Sendable () -> Bool
    ) -> [Window] {
        guard !isCancelled() else { return [] }
        guard let currentStart = calendar.date(byAdding: .day, value: -6, to: day) else {
            return []
        }
        var result: [Window] = []
        result.reserveCapacity(4)
        for offset in 1...4 {
            guard !isCancelled() else { return [] }
            guard
                let end = calendar.date(byAdding: .day, value: -7 * (offset - 1), to: currentStart),
                let start = calendar.date(byAdding: .day, value: -7, to: end)
            else {
                continue
            }
            result.append(window(
                from: start,
                to: end,
                measurements: measurements,
                isCancelled: isCancelled
            ))
        }
        return result
    }

    private static func window(
        from start: Date,
        to end: Date,
        measurements: [Measurement],
        isCancelled: @Sendable () -> Bool
    ) -> Window {
        var load = 0.0
        var sessions = 0
        var heavySets = 0.0
        for measurement in measurements {
            guard !isCancelled() else {
                return Window(load: 0, sessions: 0, heavySets: 0)
            }
            guard measurement.date >= start && measurement.date < end else { continue }
            load += measurement.load
            sessions += 1
            heavySets += measurement.heavySets
        }
        return Window(
            load: load,
            sessions: sessions,
            heavySets: heavySets
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
