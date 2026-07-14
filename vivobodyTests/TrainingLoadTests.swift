//
//  TrainingLoadTests.swift
//  vivobodyTests
//
//  Guards personal rolling training load on a virtual clock: estimated
//  hard-set equivalents, seven-day calendar windows, four prior-week
//  baseline, status bands, drivers, and the 12-week trend.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct TrainingLoadTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func session(
        daysAgo: Int,
        sets: Int,
        reps: Int = 8,
        weight: Double = 100,
        completed: Bool = true,
        mode: TrackingMode = .reps,
        duration: TimeInterval = 0
    ) -> WorkoutSession {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        let ex = Exercise(
            name: mode == .duration ? "Plank" : "Bench Press",
            group: mode == .duration ? .core : .chest,
            plannedSets: 0,
            plannedWeight: 0,
            trackingMode: mode
        )
        for i in 0..<sets {
            ex.sets.append(
                WorkoutSet(
                    weight: weight,
                    reps: reps,
                    duration: duration,
                    isCompleted: true,
                    sortOrder: i
                )
            )
        }
        let s = WorkoutSession(exercises: [ex], startedAt: date)
        if completed {
            s.completedAt = date
        }
        return s
    }

    private func steadyBaseline(sets: Int = 3) -> [WorkoutSession] {
        [9, 16, 23, 30].map { session(daysAgo: $0, sets: sets) }
    }

    // MARK: - History gate

    @Test func insufficientBeforeFourWeeks() {
        let sessions = [
            session(daysAgo: 1, sets: 3),
            session(daysAgo: 8, sets: 3),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.verdict == .insufficient)
        #expect(report.hasEnoughHistory == false)
        #expect(abs((report.provisionalRatio ?? 0) - 1) < 0.001)
        #expect(report.gaugeRatio == report.provisionalRatio)
    }

    @Test func sparseBaselineStaysInsufficient() {
        let sessions = [
            session(daysAgo: 2, sets: 3),
            session(daysAgo: 9, sets: 3),
            session(daysAgo: 30, sets: 3),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.daysLogged >= 28)
        #expect(report.verdict == .insufficient)
        #expect(report.usualLoad == nil)
    }

    @Test func emptyHistoryIsInsufficient() {
        let report = [WorkoutSession]().trainingLoad(now: now, calendar: calendar)
        #expect(report.verdict == .insufficient)
        #expect(report.currentLoad == 0)
        #expect(report.points.isEmpty)
        #expect(report.provisionalRatio == nil)
        #expect(report.gaugeRatio == nil)
    }

    // MARK: - Personal range

    @Test func steadyLoadReadsProductive() {
        var sessions = steadyBaseline()
        sessions.append(session(daysAgo: 2, sets: 3))
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(abs(report.currentLoad - 3) < 0.001)
        #expect(abs((report.usualLoad ?? 0) - 3) < 0.001)
        #expect(abs(report.ratio - 1.0) < 0.001)
        #expect(report.provisionalRatio == nil)
        #expect(report.gaugeRatio == report.ratio)
        #expect(report.verdict == .productive)
        #expect(abs((report.productiveRange?.lowerBound ?? 0) - 2.4) < 0.001)
        #expect(abs((report.productiveRange?.upperBound ?? 0) - 3.9) < 0.001)
    }

    @Test func loadAboveRangeReadsHigh() {
        var sessions = steadyBaseline(sets: 2)
        sessions.append(session(daysAgo: 2, sets: 4))
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.ratio > 1.3)
        #expect(report.verdict == .high)
    }

    @Test func loadBelowRangeReadsLow() {
        var sessions = steadyBaseline(sets: 4)
        sessions.append(session(daysAgo: 2, sets: 2))
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.ratio < 0.8)
        #expect(report.verdict == .low)
    }

    @Test func statusBoundariesAreInclusiveOfProductiveRange() {
        #expect(LoadVerdict.from(ratio: 0.799) == .low)
        #expect(LoadVerdict.from(ratio: 0.8) == .productive)
        #expect(LoadVerdict.from(ratio: 1.3) == .productive)
        #expect(LoadVerdict.from(ratio: 1.301) == .high)
    }

    @Test func medianBaselineResistsOneUnusualWeek() {
        var sessions = [
            session(daysAgo: 9, sets: 3),
            session(daysAgo: 16, sets: 12),
            session(daysAgo: 23, sets: 3),
            session(daysAgo: 30, sets: 3),
        ]
        sessions.append(session(daysAgo: 2, sets: 3))
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(abs((report.usualLoad ?? 0) - 3) < 0.001)
        #expect(report.verdict == .productive)
    }

    // MARK: - Calendar windows

    @Test func rollingWindowIncludesSevenCalendarDays() {
        let sessions = [
            session(daysAgo: 6, sets: 2),
            session(daysAgo: 7, sets: 5),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(abs(report.currentLoad - 2) < 0.001)
    }

    @Test func futureAndIncompleteSessionsAreExcluded() {
        let sessions = [
            session(daysAgo: 1, sets: 2),
            session(daysAgo: 2, sets: 5, completed: false),
            session(daysAgo: -1, sets: 7),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(abs(report.currentLoad - 2) < 0.001)
    }

    @Test func bodyweightAndTimedWorkContribute() {
        let sessions = [
            session(daysAgo: 1, sets: 1, reps: 10, weight: 0),
            session(daysAgo: 2, sets: 1, reps: 0, weight: 0, mode: .duration, duration: 30),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(abs(report.currentLoad - 2) < 0.001)
    }

    // MARK: - Drivers

    @Test func driversCompareCurrentWorkWithUsual() {
        var sessions = [9, 16, 23, 30].map {
            session(daysAgo: $0, sets: 3, reps: 5)
        }
        sessions.append(session(daysAgo: 1, sets: 3, reps: 5))
        sessions.append(session(daysAgo: 4, sets: 3, reps: 5))

        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.drivers.hardSets.current == 6)
        #expect(report.drivers.hardSets.usual == 3)
        #expect(report.drivers.sessions.current == 2)
        #expect(report.drivers.sessions.usual == 1)
        #expect(report.drivers.heavySets.current == 6)
        #expect(report.drivers.heavySets.usual == 3)
    }

    // MARK: - Recent days

    @Test func recentDaysSpanTrailingWeekEndingToday() {
        let sessions = [
            session(daysAgo: 0, sets: 3),
            session(daysAgo: 2, sets: 2),
            session(daysAgo: 7, sets: 5),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.recentDays.count == 7)
        #expect(report.recentDays == report.recentDays.sorted { $0.date < $1.date })
        #expect(report.recentDays.last?.date == calendar.startOfDay(for: now))
        #expect(report.recentDays.last?.load == 3)
        #expect(report.recentDays[4].load == 2)
        // Day 7 falls outside the trailing-week strip.
        #expect(report.recentDays.map(\.load).reduce(0, +) == 5)
    }

    @Test func recentDaysZeroFillRestDays() {
        let sessions = [session(daysAgo: 3, sets: 4)]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.recentDays.filter(\.trained).count == 1)
        #expect(report.recentDays[3].load == 4)
        #expect(report.recentDays.last?.trained == false)
    }

    @Test func recentDaysMergeSameDaySessions() {
        let sessions = [
            session(daysAgo: 1, sets: 2),
            session(daysAgo: 1, sets: 3),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.recentDays[5].load == 5)
    }

    @Test func recentDaysEmptyWithoutHistory() {
        let report = [WorkoutSession]().trainingLoad(now: now, calendar: calendar)
        #expect(report.recentDays.isEmpty)
    }

    // MARK: - Trend

    @Test func trendIsChronologicalAndEndsToday() {
        let sessions = [
            session(daysAgo: 16, sets: 2),
            session(daysAgo: 0, sets: 3),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.points.count == 17)
        #expect(report.points == report.points.sorted { $0.date < $1.date })
        #expect(report.points.last?.date == calendar.startOfDay(for: now))
        #expect(report.points.last?.load == 3)
    }

    @Test func trendCapsAtEightyFourDailyPoints() {
        let sessions = stride(from: 0, through: 700, by: 7).map {
            session(daysAgo: $0, sets: 1)
        }
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.points.count == 84)
    }

    @Test func trendBandUsesOnlyPriorWeeks() {
        var sessions = steadyBaseline(sets: 3)
        sessions.append(session(daysAgo: 2, sets: 12))
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        let latest = report.points.last
        #expect(latest?.load == 12)
        #expect(abs((latest?.productiveLower ?? 0) - 2.4) < 0.001)
        #expect(abs((latest?.productiveUpper ?? 0) - 3.9) < 0.001)
    }
}
