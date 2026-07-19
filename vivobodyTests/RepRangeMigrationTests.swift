//
//  RepRangeMigrationTests.swift
//
//  Guards the rep-range drift engine behind the Insights "Rep trend"
//  section. It buckets completed reps-mode sets by ISO week, averages
//  reps per set per week, and fits a least-squares line to the weekly
//  points, so it's tested on a virtual clock: a descending reps
//  series drifts toward strength, an ascending one toward endurance,
//  a flat one holds stable, and too-thin / out-of-window / non-reps
//  data is excluded.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct RepRangeMigrationTests {

    // MARK: - Virtual clock

    /// Tuesday, 14 Nov 2023 — picked so 7-day-spaced sessions land in
    /// distinct ISO weeks under both Mon-start and Sun-start calendars.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Helpers

    private func session(daysAgo: Double, _ exercises: [Exercise]) -> WorkoutSession {
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    /// Reps exercise built from (reps, completed) tuples at a fixed
    /// weight, mirroring `IntensityMixTests.lift`.
    private func lift(
        _ sets: [(reps: Int, completed: Bool)],
        modality: ExerciseModality = .dynamicStrength
    ) -> Exercise {
        let ex = Exercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0,
            modality: modality
        )
        for (i, s) in sets.enumerated() {
            ex.sets.append(WorkoutSet(weight: 100, reps: s.reps, isCompleted: s.completed, sortOrder: i))
        }
        return ex
    }

    /// Convenience: one completed reps set at `reps`.
    private func lift(_ reps: Int) -> Exercise {
        lift([(reps, true)])
    }

    /// Timed-hold exercise (`.duration`) with completed sets.
    private func hold(seconds: [TimeInterval]) -> Exercise {
        let ex = Exercise(
            name: "Plank",
            group: .core,
            plannedSets: 0,
            plannedWeight: 0,
            trackingMode: .duration,
            modality: .isometricStrength
        )
        for (i, sec) in seconds.enumerated() {
            ex.sets.append(WorkoutSet(weight: 0, reps: 0, duration: sec, isCompleted: true, sortOrder: i))
        }
        return ex
    }

    // MARK: - Bucketing

    @Test func sessionsInSameWeekAggregateIntoOnePoint() {
        // daysAgo 0 (Tue Nov 14) and daysAgo 1 (Mon Nov 13) share an
        // ISO week under both Mon-start and Sun-start calendars.
        let s1 = session(daysAgo: 0, [lift(8)])
        let s2 = session(daysAgo: 1, [lift(10)])
        let report = [s1, s2].repRangeMigration(now: now)

        #expect(report.points.count == 1)
        #expect(report.points.first?.sets == 2)
        // (8 + 10) / 2 = 9.0
        #expect(abs((report.points.first?.averageReps ?? -1) - 9.0) < 0.001)
    }

    @Test func averageRepsPerSetComputedCorrectly() {
        let ex = lift([(3, true), (8, true), (13, true)])
        let report = [session(daysAgo: 1, [ex])].repRangeMigration(now: now)

        #expect(report.points.count == 1)
        #expect(report.points.first?.sets == 3)
        // (3 + 8 + 13) / 3 = 8.0
        #expect(abs((report.points.first?.averageReps ?? -1) - 8.0) < 0.001)
    }

    // MARK: - Verdicts

    @Test func descendingRepsDriftTowardStrength() {
        // Earliest week → latest week: 12, 10, 8, 6, 4 reps/set.
        let sessions: [WorkoutSession] = [
            session(daysAgo: 28, [lift(12)]),
            session(daysAgo: 21, [lift(10)]),
            session(daysAgo: 14, [lift(8)]),
            session(daysAgo: 7,  [lift(6)]),
            session(daysAgo: 0,  [lift(4)]),
        ]
        let report = sessions.repRangeMigration(now: now)

        #expect(report.hasTrend)
        #expect(report.verdict == .towardStrength)
        #expect(report.slopePerWeek < 0)
        #expect(abs(report.earlierAverage - 12.0) < 0.001)
        #expect(abs(report.currentAverage - 4.0) < 0.001)
    }

    @Test func ascendingRepsDriftTowardEndurance() {
        // Earliest week → latest week: 4, 6, 8, 10, 12 reps/set.
        let sessions: [WorkoutSession] = [
            session(daysAgo: 28, [lift(4)]),
            session(daysAgo: 21, [lift(6)]),
            session(daysAgo: 14, [lift(8)]),
            session(daysAgo: 7,  [lift(10)]),
            session(daysAgo: 0,  [lift(12)]),
        ]
        let report = sessions.repRangeMigration(now: now)

        #expect(report.hasTrend)
        #expect(report.verdict == .towardEndurance)
        #expect(report.slopePerWeek > 0)
        #expect(abs(report.earlierAverage - 4.0) < 0.001)
        #expect(abs(report.currentAverage - 12.0) < 0.001)
    }

    @Test func flatRepsHoldStable() {
        // Five weeks, every set at 8 reps — slope ≈ 0.
        let sessions: [WorkoutSession] = [
            session(daysAgo: 28, [lift(8)]),
            session(daysAgo: 21, [lift(8)]),
            session(daysAgo: 14, [lift(8)]),
            session(daysAgo: 7,  [lift(8)]),
            session(daysAgo: 0,  [lift(8)]),
        ]
        let report = sessions.repRangeMigration(now: now)

        #expect(report.hasTrend)
        #expect(report.verdict == .stable)
        #expect(abs(report.slopePerWeek) < 0.1)
    }

    // MARK: - Exclusions

    @Test func timedHoldsExcluded() {
        // A duration exercise contributes no reps-mode sets, so even
        // with several weekly sessions there's no data.
        let sessions: [WorkoutSession] = [
            session(daysAgo: 28, [hold(seconds: [60])]),
            session(daysAgo: 21, [hold(seconds: [60])]),
            session(daysAgo: 14, [hold(seconds: [60])]),
        ]
        let report = sessions.repRangeMigration(now: now)

        #expect(report.points.isEmpty)
        #expect(!report.hasTrend)
    }

    @Test func incompleteSetsExcluded() {
        // Only the completed set counts; the incomplete and zero-rep
        // sets are dropped from the weekly average.
        let ex = lift([(8, true), (8, false), (0, true)])
        let report = [session(daysAgo: 1, [ex])].repRangeMigration(now: now)

        #expect(report.points.count == 1)
        #expect(report.points.first?.sets == 1)
        #expect(abs((report.points.first?.averageReps ?? -1) - 8.0) < 0.001)
    }

    @Test func onlyDynamicStrengthRepsEnterWeeklyAverages() {
        let dynamic = lift([(8, true)])
        let conditioning = lift([(30, true)], modality: .conditioning)
        let mobility = lift([(2, true)], modality: .mobility)
        let invalidIsometricReps = lift([(20, true)], modality: .isometricStrength)
        let report = [
            session(daysAgo: 1, [dynamic, conditioning, mobility, invalidIsometricReps])
        ].repRangeMigration(now: now)

        #expect(report.points.count == 1)
        #expect(report.points.first?.sets == 1)
        #expect(abs((report.points.first?.averageReps ?? -1) - 8.0) < 0.001)
    }

    // MARK: - Trend floor

    @Test func fewerThanThreeWeeksHasNoTrend() {
        // Two distinct weeks of data — below the 3-week floor.
        let sessions: [WorkoutSession] = [
            session(daysAgo: 7, [lift(8)]),
            session(daysAgo: 0, [lift(6)]),
        ]
        let report = sessions.repRangeMigration(now: now)

        #expect(report.points.count == 2)
        #expect(!report.hasTrend)
        #expect(report.verdict == .stable)
        #expect(report.slopePerWeek == 0)
    }

    // MARK: - Window

    @Test func windowRespected() {
        // 12-week default window (84 days). A session 100 days ago is
        // outside; the in-window session at daysAgo 1 stands alone.
        let recent = session(daysAgo: 1, [lift(8)])
        let old = session(daysAgo: 100, [lift(3)])
        let report = [recent, old].repRangeMigration(now: now)

        #expect(report.points.count == 1)
        #expect(report.points.first?.sets == 1)
        #expect(abs((report.points.first?.averageReps ?? -1) - 8.0) < 0.001)
        #expect(!report.hasTrend)
    }

    @Test func emptyArchiveHasNoData() {
        let report = [WorkoutSession]().repRangeMigration(now: now)
        #expect(report.points.isEmpty)
        #expect(!report.hasTrend)
        #expect(report.verdict == .stable)
        #expect(report.currentAverage == 0)
        #expect(report.earlierAverage == 0)
    }
}
