//
//  ExerciseEffortTests.swift
//  vivobodyTests
//
//  Guards the per-exercise effort read behind the Exercise detail
//  "Effort" card. The verdict is the actionable bit: reps left in the
//  tank with the plan finished reads "ready to add load"; grinding to
//  failure while the top set regresses reads "grinding"; the middle
//  reads "pushing". Everything is gated on real `rirLogged` readings
//  and a minimum sample, and timed holds carry no RIR at all.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseEffortTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Builders

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    /// Build a reps exercise from explicit per-set tuples. A `rir` of
    /// nil leaves the set unrated (`rirLogged == false`); `completed`
    /// defaults true.
    private func lift(
        _ name: String = "Bench Press",
        _ group: MuscleGroup = .chest,
        sets: [(weight: Double, reps: Int, rir: Int?, completed: Bool)]
    ) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: 0, plannedReps: 8, plannedWeight: 100)
        for (i, s) in sets.enumerated() {
            ex.sets.append(
                WorkoutSet(
                    weight: s.weight,
                    reps: s.reps,
                    isCompleted: s.completed,
                    repsInReserve: s.rir ?? 2,
                    rirLogged: s.rir != nil,
                    sortOrder: i
                )
            )
        }
        return ex
    }

    private func hold(_ name: String, seconds: TimeInterval) -> Exercise {
        let ex = Exercise(
            name: name,
            group: .core,
            plannedSets: 0,
            plannedWeight: 0,
            trackingMode: .duration,
            plannedDuration: seconds
        )
        for i in 0..<3 {
            ex.sets.append(WorkoutSet(weight: 0, reps: 0, duration: seconds, isCompleted: true, sortOrder: i))
        }
        return ex
    }

    // MARK: - Verdicts

    @Test func readyWhenRepsInReserveAndPlanComplete() {
        let prior = session(at: day(0), [lift(sets: [(100, 8, 2, true), (100, 8, 2, true), (100, 8, 2, true)])])
        let last = session(at: day(4), [lift(sets: [(100, 8, 2, true), (100, 8, 3, true), (100, 8, 2, true)])])

        let summary = [prior, last].effortSummary(forExerciseNamed: "Bench Press")
        #expect(summary?.verdict == .ready)
        #expect((summary?.avgRIR ?? 0) >= 2)
        #expect(summary?.lastSessionSetCount == 3)
        #expect(summary?.loggedSetCount == 6)
    }

    @Test func grindWhenTrainedToFailureAndRegressing() {
        let prior = session(at: day(0), [lift(sets: [(100, 8, 0, true), (100, 8, 0, true), (100, 7, 0, true)])])
        // Lighter top set the next session, still hammering to failure.
        let last = session(at: day(4), [lift(sets: [(95, 8, 0, true), (95, 8, 0, true), (95, 7, 0, true)])])

        let summary = [prior, last].effortSummary(forExerciseNamed: "Bench Press")
        #expect(summary?.verdict == .grind)
        #expect((summary?.avgRIR ?? 9) <= 0.5)
    }

    @Test func pushInTheProductiveMiddle() {
        let prior = session(at: day(0), [lift(sets: [(100, 8, 1, true), (100, 8, 1, true), (100, 8, 1, true)])])
        let last = session(at: day(4), [lift(sets: [(105, 8, 1, true), (105, 8, 1, true), (105, 8, 1, true)])])

        let summary = [prior, last].effortSummary(forExerciseNamed: "Bench Press")
        #expect(summary?.verdict == .push)
    }

    @Test func highRIRButIncompletePlanIsNotReady() {
        let prior = session(at: day(0), [lift(sets: [(100, 8, 3, true), (100, 8, 3, true), (100, 8, 3, true)])])
        // Plenty in reserve, but the last set was abandoned.
        let last = session(at: day(4), [lift(sets: [(100, 8, 3, true), (100, 8, 3, true), (100, 8, nil, false)])])

        let summary = [prior, last].effortSummary(forExerciseNamed: "Bench Press")
        #expect(summary?.verdict == .push)
    }

    // MARK: - Gating

    @Test func nilBelowThreeLoggedReadings() {
        let s = session(at: day(0), [lift(sets: [(100, 8, 2, true), (100, 8, 2, true)])])
        #expect([s].effortSummary(forExerciseNamed: "Bench Press") == nil)
    }

    @Test func unratedSetsDontCountTowardSample() {
        // Six completed sets, but only two carry a real RIR reading.
        let s = session(at: day(0), [lift(sets: [
            (100, 8, 2, true), (100, 8, nil, true), (100, 8, nil, true),
            (100, 8, 2, true), (100, 8, nil, true), (100, 8, nil, true)
        ])])
        #expect([s].effortSummary(forExerciseNamed: "Bench Press") == nil)
    }

    @Test func durationExerciseHasNoEffortRead() {
        let s = session(at: day(0), [hold("Plank", seconds: 60)])
        #expect([s].effortSummary(forExerciseNamed: "Plank") == nil)
    }

    @Test func emptyArchiveIsNil() {
        #expect([WorkoutSession]().effortSummary(forExerciseNamed: "Bench Press") == nil)
    }
}
