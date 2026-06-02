//
//  ConsistencyReportTests.swift
//  vivobodyTests
//
//  Guards the Insights "Consistency" board. The heatmap grid is fixed
//  in shape (26 weeks × 7 days) and shaded by a pure set-count bucket
//  (tested directly); the rollups are tested on a virtual clock —
//  sessions-per-week averages the recent window, RIR averages only
//  logged reps-sets, and the week streak counts consecutive trained
//  weeks while tolerating a not-yet-started current week.
//

import Foundation
import Testing
@testable import vivobody

struct ConsistencyReportTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    /// A date `n` days out from origin, then shifted to the Wednesday
    /// of its week so the "current" column always has future days —
    /// keeps the streak tests independent of which weekday `origin`
    /// lands on.
    private func wednesday(_ n: Double) -> Date {
        let cal = Calendar.current
        let base = day(n)
        let weekday = cal.component(.weekday, from: base)   // 1 = Sun … 7 = Sat
        return cal.date(byAdding: .day, value: 4 - weekday, to: base) ?? base
    }

    // MARK: - Helpers

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    private func lift(_ name: String = "Bench Press", _ group: MuscleGroup = .chest, sets: Int = 4, rir: Int = 2) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: sets, plannedReps: 8, plannedWeight: 100)
        ex.sets.forEach { $0.isCompleted = true; $0.repsInReserve = rir }
        return ex
    }

    private func plank(sets: Int = 3) -> Exercise {
        let ex = Exercise(
            name: "Plank",
            group: .core,
            plannedSets: sets,
            plannedReps: 0,
            plannedWeight: 0,
            trackingMode: .duration,
            plannedDuration: 45
        )
        ex.sets.forEach { $0.isCompleted = true }
        return ex
    }

    // MARK: - Level thresholds (pure)

    @Test func levelBuckets() {
        #expect(ConsistencyReport.level(forSets: 0) == 0)
        #expect(ConsistencyReport.level(forSets: 1) == 1)
        #expect(ConsistencyReport.level(forSets: 5) == 1)
        #expect(ConsistencyReport.level(forSets: 6) == 2)
        #expect(ConsistencyReport.level(forSets: 11) == 2)
        #expect(ConsistencyReport.level(forSets: 12) == 3)
        #expect(ConsistencyReport.level(forSets: 17) == 3)
        #expect(ConsistencyReport.level(forSets: 18) == 4)
        #expect(ConsistencyReport.level(forSets: 40) == 4)
    }

    // MARK: - Grid shape

    @Test func gridIsAlwaysFullSixMonths() {
        let report = [session(at: day(100), [lift()])].consistency(now: day(100))
        #expect(report.weeks.count == ConsistencyReport.windowWeeks)
        #expect(report.weeks.allSatisfy { $0.count == 7 })
    }

    // MARK: - Trained day lands in the grid, shaded by volume

    @Test func trainedDayShadesToday() {
        let now = day(100)
        let report = [session(at: now, [lift(sets: 10)])].consistency(now: now)

        let todayCell = report.weeks.flatMap { $0 }.first { $0.isToday }
        #expect(todayCell != nil)
        #expect(todayCell?.sets == 10)
        #expect(todayCell?.level == 2)          // 6…11 sets
        #expect(report.hasActivity)
        #expect(report.daysTrainedInWindow == 1)
    }

    // MARK: - Sessions per week averages the recent window

    @Test func sessionsPerWeekAveragesRecentWindow() {
        let now = day(100)
        // 8 sessions spread across the trailing 28-day window.
        let sessions = (0..<8).map { k in
            session(at: day(100 - Double(k) * 3), [lift()])
        }
        let report = sessions.consistency(now: now)
        #expect(report.recentSessions == 8)
        #expect(abs(report.sessionsPerWeek - 2.0) < 1e-9)   // 8 / 4 weeks
    }

    // MARK: - RIR averages only logged reps-sets

    @Test func averageRIRReadsLoggedEffort() {
        let now = day(100)
        let report = [session(at: now, [lift(sets: 4, rir: 1)])].consistency(now: now)
        #expect(report.averageRIR != nil)
        #expect(abs((report.averageRIR ?? 0) - 1.0) < 1e-9)
    }

    @Test func timedHoldsCarryNoRIR() {
        let now = day(100)
        // A duration-only day still counts as trained, but holds carry
        // no reps-in-reserve, so the effort read is absent.
        let report = [session(at: now, [plank(sets: 3)])].consistency(now: now)
        #expect(report.hasActivity)
        #expect(report.daysTrainedInWindow == 1)
        #expect(report.averageRIR == nil)
    }

    // MARK: - Week streak

    @Test func weekStreakCountsConsecutiveWeeks() {
        let now = wednesday(300)
        let cal = Calendar.current
        let sessions = [0, 7, 14].map { off in
            session(at: cal.date(byAdding: .day, value: -off, to: now) ?? now, [lift()])
        }
        #expect(sessions.consistency(now: now).weekStreak == 3)
    }

    @Test func weekStreakBreaksOnGap() {
        let now = wednesday(300)
        let cal = Calendar.current
        let sessions = [0, 7, 21].map { off in   // missing week at -14
            session(at: cal.date(byAdding: .day, value: -off, to: now) ?? now, [lift()])
        }
        #expect(sessions.consistency(now: now).weekStreak == 2)
    }

    @Test func weekStreakToleratesUnstartedCurrentWeek() {
        let now = wednesday(300)
        let cal = Calendar.current
        // Nothing logged this week yet, but the prior two weeks ran —
        // the streak survives until the week actually lapses.
        let sessions = [7, 14].map { off in
            session(at: cal.date(byAdding: .day, value: -off, to: now) ?? now, [lift()])
        }
        #expect(sessions.consistency(now: now).weekStreak == 2)
    }

    // MARK: - Empty

    @Test func emptyArchiveHasNoActivity() {
        let report = [WorkoutSession]().consistency(now: day(100))
        #expect(!report.hasActivity)
        #expect(report.weekStreak == 0)
        #expect(report.averageRIR == nil)
        #expect(report.recentSessions == 0)
        #expect(report.daysTrainedInWindow == 0)
        #expect(report.weeks.count == ConsistencyReport.windowWeeks)
    }
}
