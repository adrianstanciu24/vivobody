//
//  TrainingLoadAggregation.swift
//  vivobody
//
//  Pure rolling-window aggregation for Training Load. It carries hard sets
//  and comparable volume load together, chooses one report-wide measure from
//  the current plus four baseline windows, and derives every headline, trend,
//  strip, and driver value from the shared chronological analytics replay.
//

import Foundation

@MainActor
extension [WorkoutSession] {
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

    /// Build the report from SessionAnalytics' shared chronological replay.
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
    /// Build the report from the shared chronological analytics replay.
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

        let today = calendar.startOfDay(for: now)
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
        let measure: TrainingLoadMeasure = current.volumeLoad.knownSubtotal > 0
            || previous.contains(where: { $0.volumeLoad.knownSubtotal > 0 })
            ? .volumeLoad
            : .hardSets
        guard let first = measurements.first(where: { $0.load(for: measure) > 0 })?.date else {
            return Self.emptyReport()
        }
        let firstDay = calendar.startOfDay(for: first)
        let daysLogged = Swift.max(
            0,
            calendar.dateComponents([.day], from: firstDay, to: today).day ?? 0
        )
        let activeBaseline = previous.filter { $0.load(for: measure) > 0 }
        let usual = daysLogged >= TrainingLoadReport.baselineMinimumDays
            && activeBaseline.count >= TrainingLoadReport.requiredActiveBaselineWeeks
            ? Self.median(previous.map { $0.load(for: measure) })
            : nil
        let currentLoad = current.load(for: measure)
        let ratio = usual.flatMap { $0 > 0 ? currentLoad / $0 : nil } ?? 0
        let provisionalUsual = Self.median(activeBaseline.map { $0.load(for: measure) })
        let provisionalRatio = usual == nil && provisionalUsual > 0
            ? currentLoad / provisionalUsual
            : nil
        let verdict = usual == nil ? LoadVerdict.insufficient : LoadVerdict.from(ratio: ratio)
        let points = Self.rollingPoints(
            measurements: measurements,
            measure: measure,
            firstDay: firstDay,
            today: today,
            calendar: calendar,
            isCancelled: isCancelled
        )
        guard !isCancelled() else { return Self.emptyReport() }
        let recentDays = Self.recentDailyLoads(
            measurements: measurements,
            measure: measure,
            today: today,
            calendar: calendar,
            isCancelled: isCancelled
        )
        guard !isCancelled() else { return Self.emptyReport() }

        return TrainingLoadReport(
            currentLoad: currentLoad,
            usualLoad: usual,
            ratio: ratio,
            provisionalRatio: provisionalRatio,
            verdict: verdict,
            daysLogged: daysLogged,
            activeBaselineWeeks: activeBaseline.count,
            points: points,
            recentDays: recentDays,
            drivers: TrainingLoadDrivers(
                volumeLoad: LoadDriver(
                    current: current.volumeLoad.knownSubtotal,
                    usual: usual == nil
                        ? nil
                        : Self.median(previous.map(\.volumeLoad.knownSubtotal))
                ),
                hardSets: LoadDriver(
                    current: current.hardSets,
                    usual: usual == nil ? nil : Self.median(previous.map(\.hardSets))
                ),
                sessions: LoadDriver(
                    current: Double(current.sessions),
                    usual: usual == nil
                        ? nil
                        : Self.median(previous.map { Double($0.sessions) })
                ),
                heavySets: LoadDriver(
                    current: current.heavySets,
                    usual: usual == nil ? nil : Self.median(previous.map(\.heavySets))
                ),
                moderateSets: LoadDriver(
                    current: current.moderateSets,
                    usual: usual == nil ? nil : Self.median(previous.map(\.moderateSets))
                )
            ),
            measure: measure,
            loadAvailability: current.volumeLoad.availability
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
        let hardSets: Double
        let volumeLoad: ComparableTonnageSummary
        let heavySets: Double
        let moderateSets: Double

        func load(for measure: TrainingLoadMeasure) -> Double {
            switch measure {
            case .volumeLoad:
                volumeLoad.knownSubtotal
            case .hardSets:
                hardSets
            }
        }
    }

    private struct Window {
        let hardSets: Double
        let volumeLoad: ComparableTonnageSummary
        let sessions: Int
        let heavySets: Double
        let moderateSets: Double

        static let zero = Window(
            hardSets: 0,
            volumeLoad: .zero,
            sessions: 0,
            heavySets: 0,
            moderateSets: 0
        )

        func load(for measure: TrainingLoadMeasure) -> Double {
            switch measure {
            case .volumeLoad:
                volumeLoad.knownSubtotal
            case .hardSets:
                hardSets
            }
        }
    }

    /// Keep completed sessions carrying either report measure or missing
    /// comparable-load coverage.
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
                  session.totalSetEquivalent > 0
                  || session.volumeLoad.knownSubtotal > 0
                  || session.volumeLoad.availability != .complete
            else {
                continue
            }
            result.append(Measurement(
                date: session.date,
                hardSets: session.totalSetEquivalent,
                volumeLoad: session.volumeLoad,
                heavySets: session.heavySets,
                moderateSets: session.moderateSets
            ))
        }
        return result
    }

    private static func rollingPoints(
        measurements: [Measurement],
        measure: TrainingLoadMeasure,
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
        for offset in 0 ... days {
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
                && previous.count(where: { $0.load(for: measure) > 0 })
                >= TrainingLoadReport.requiredActiveBaselineWeeks
                ? median(previous.map { $0.load(for: measure) })
                : nil
            result.append(LoadPoint(
                date: day,
                load: current.load(for: measure),
                productiveLower: usual.map { $0 * LoadVerdict.recentRatioBand.lowerBound },
                productiveUpper: usual.map { $0 * LoadVerdict.recentRatioBand.upperBound }
            ))
        }
        return result
    }

    private static func recentDailyLoads(
        measurements: [Measurement],
        measure: TrainingLoadMeasure,
        today: Date,
        calendar: Calendar,
        isCancelled: @Sendable () -> Bool
    ) -> [DayLoad] {
        var result: [DayLoad] = []
        result.reserveCapacity(7)
        for offset in (0 ..< 7).reversed() {
            guard !isCancelled() else { return [] }
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            var load = 0.0
            var trained = false
            for measurement in measurements {
                guard !isCancelled() else { return [] }
                if calendar.startOfDay(for: measurement.date) == day {
                    load += measurement.load(for: measure)
                    trained = true
                }
            }
            result.append(DayLoad(date: day, load: load, trained: trained))
        }
        return result
    }

    private static func window(
        endingOn day: Date,
        measurements: [Measurement],
        calendar: Calendar,
        isCancelled: @Sendable () -> Bool
    ) -> Window {
        guard !isCancelled() else {
            return .zero
        }
        guard
            let end = calendar.date(byAdding: .day, value: 1, to: day),
            let start = calendar.date(byAdding: .day, value: -6, to: day)
        else {
            return .zero
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
        for offset in 1 ... 4 {
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
        var hardSets = 0.0
        var volumeLoad = ComparableTonnageSummary.zero
        var sessions = 0
        var heavySets = 0.0
        var moderateSets = 0.0
        for measurement in measurements {
            guard !isCancelled() else {
                return .zero
            }
            guard measurement.date >= start, measurement.date < end else { continue }
            hardSets += measurement.hardSets
            volumeLoad = volumeLoad.merging(measurement.volumeLoad)
            sessions += 1
            heavySets += measurement.heavySets
            moderateSets += measurement.moderateSets
        }
        return Window(
            hardSets: hardSets,
            volumeLoad: volumeLoad,
            sessions: sessions,
            heavySets: heavySets,
            moderateSets: moderateSets
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
