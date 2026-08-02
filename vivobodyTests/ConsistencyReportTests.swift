//
//  ConsistencyReportTests.swift
//  vivobodyTests
//
//  Guards the Insights "Consistency" board. The heatmap grid is fixed
//  in shape (26 weeks × 7 days) and shaded by a pure set-count bucket
//  (tested directly); the rollups are tested on a virtual clock —
//  sessions-per-week uses an exact half-open 28-calendar-day window,
//  RIR reports both its rated average and coverage, and the unbounded
//  week streak tolerates a not-yet-started current week on every day.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
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

    private func finalMomentOfWeek(_ n: Double) -> Date {
        let calendar = Calendar.current
        let base = day(n)
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: base) else {
            return base
        }
        return interval.end.addingTimeInterval(-1)
    }

    // MARK: - Helpers

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    private func lift(
        _ name: String = "Bench Press",
        _ group: MuscleGroup = .chest,
        sets: Int = 4,
        rir: Int? = nil,
        modality: ExerciseModality = .dynamicStrength
    ) -> Exercise {
        let ex = Exercise(
            name: name,
            group: group,
            plannedSets: sets,
            plannedReps: 8,
            plannedWeight: 100,
            modality: modality
        )
        ex.sets.forEach {
            $0.isCompleted = true
            $0.repsInReserve = rir ?? 2
            $0.rirLogged = rir != nil
        }
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
            modality: .isometricStrength,
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

    @Test func recentWindowIsExactlyTwentyEightCalendarDaysAndExcludesFuture() {
        let now = day(100)
        let sessions = [
            session(at: now, [lift()]),
            session(at: day(73), [lift()]),       // Day 27: included.
            session(at: day(72), [lift()]),       // Day 28: excluded.
            session(at: now.addingTimeInterval(60), [lift()]), // Future today.
            session(at: day(101), [lift()]),      // Future day.
        ]

        let report = sessions.consistency(now: now)

        #expect(report.recentSessions == 2)
        #expect(abs(report.sessionsPerWeek - 0.5) < 1e-9)
        // The day-28 workout remains valid six-month calendar history;
        // only the two future sessions disappear from every rollup.
        #expect(report.daysTrainedInWindow == 3)
    }

    // MARK: - RIR averages only logged reps-sets

    @Test func averageRIRReadsLoggedEffort() {
        let now = day(100)
        let report = [session(at: now, [lift(sets: 4, rir: 1)])].consistency(now: now)
        #expect(report.averageRIR != nil)
        #expect(abs((report.averageRIR ?? 0) - 1.0) < 1e-9)
        #expect(report.rirEligibleSets == 4)
        #expect(report.rirLoggedSets == 4)
        #expect(abs(report.rirCoverage - 1) < 1e-9)
    }

    @Test func defaultRIRValueWithoutExplicitLogIsIgnored() {
        let now = day(100)
        let unrated = lift(sets: 2)

        #expect(unrated.sets.allSatisfy { $0.repsInReserve == 2 && !$0.rirLogged })
        let report = [session(at: now, [unrated])].consistency(now: now)
        #expect(report.averageRIR == nil)
        #expect(report.rirEligibleSets == 2)
        #expect(report.rirLoggedSets == 0)
        #expect(report.rirCoverage == 0)
    }

    @Test func effortExcludesEmptyIncompleteAndNonStrengthSets() {
        let now = day(100)
        let strength = lift(sets: 4)
        let strengthSets = strength.orderedSets
        strengthSets[0].repsInReserve = 1
        strengthSets[0].rirLogged = true
        strengthSets[1].repsInReserve = 5       // Stored default-like value, never rated.
        strengthSets[2].reps = 0
        strengthSets[2].repsInReserve = 0
        strengthSets[2].rirLogged = true        // Empty completed set.
        strengthSets[3].isCompleted = false
        strengthSets[3].repsInReserve = 0
        strengthSets[3].rirLogged = true        // Rated but incomplete.

        let conditioning = lift(sets: 2, rir: 0, modality: .conditioning)
        let mobility = lift(sets: 2, rir: 5, modality: .mobility)
        let report = [session(at: now, [strength, conditioning, mobility])]
            .consistency(now: now)

        #expect(abs((report.averageRIR ?? -1) - 1) < 1e-9)
        #expect(report.rirEligibleSets == 2)
        #expect(report.rirLoggedSets == 1)
        #expect(abs(report.rirCoverage - 0.5) < 1e-9)
    }

    @Test func isometricRepsMismatchDoesNotContributeRIR() {
        let now = day(100)
        // Isometric strength is eligible for hard-set analytics only
        // when duration-tracked. A corrupt reps snapshot must not make
        // its stored RIR look like a valid dynamic-strength rating.
        let mismatched = lift(
            "Invalid Isometric Reps",
            .core,
            sets: 3,
            rir: 0,
            modality: .isometricStrength
        )

        let report = [session(at: now, [mismatched])].consistency(now: now)
        #expect(report.averageRIR == nil)
    }

    @Test func timedHoldsCarryNoRIR() {
        let now = day(100)
        // A duration-only day still counts as trained, but holds carry
        // no reps-in-reserve, so the effort read is absent.
        let report = [session(at: now, [plank(sets: 3)])].consistency(now: now)
        #expect(report.hasActivity)
        #expect(report.daysTrainedInWindow == 1)
        #expect(report.averageRIR == nil)
        #expect(report.rirEligibleSets == 0)
        #expect(report.rirLoggedSets == 0)
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

    @Test func weekStreakToleratesUnstartedCurrentWeekOnFinalWeekday() {
        let now = finalMomentOfWeek(300)
        let calendar = Calendar.current
        let sessions = [7, 14].map { offset in
            session(
                at: calendar.date(byAdding: .day, value: -offset, to: now) ?? now,
                [lift()]
            )
        }

        #expect(sessions.consistency(now: now).weekStreak == 2)
    }

    @Test func weekStreakIsNotCappedByHeatmapWindow() {
        let now = wednesday(500)
        let calendar = Calendar.current
        let sessions = (0..<30).map { week in
            session(
                at: calendar.date(byAdding: .day, value: -(week * 7), to: now) ?? now,
                [lift(sets: 1)]
            )
        }

        let report = sessions.consistency(now: now)
        #expect(report.weeks.count == ConsistencyReport.windowWeeks)
        #expect(report.weekStreak == 30)
    }

    // MARK: - Empty

    @Test func emptyArchiveHasNoActivity() {
        let report = [WorkoutSession]().consistency(now: day(100))
        #expect(!report.hasActivity)
        #expect(report.weekStreak == 0)
        #expect(report.averageRIR == nil)
        #expect(report.rirEligibleSets == 0)
        #expect(report.rirLoggedSets == 0)
        #expect(report.rirCoverage == 0)
        #expect(report.recentSessions == 0)
        #expect(report.daysTrainedInWindow == 0)
        #expect(report.weeks.count == ConsistencyReport.windowWeeks)
    }
}
