//
//  SessionInsightsTests.swift
//  vivobodyTests
//
//  Guards the four session-scoped reads behind the workout receipt:
//  density (tonnage per minute), hard-set count (RIR ≤ 1), the
//  per-exercise waterfall (shares within separate weight-volume and
//  hold-time pools), and planned-vs-actual adherence.
//

import Foundation
import Testing
@testable import vivobody

struct SessionInsightsTests {

    // MARK: - Builders

    /// A completed session spanning `minutes` of wall-clock time.
    private func session(minutes: Double, _ exercises: [Exercise]) -> WorkoutSession {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let s = WorkoutSession(exercises: exercises, startedAt: start)
        s.completedAt = start.addingTimeInterval(minutes * 60)
        return s
    }

    /// A reps exercise with explicit per-set (weight, reps, rir?,
    /// completed) and an optional uniform plan snapshot.
    private func lift(
        _ name: String = "Bench Press",
        _ group: MuscleGroup = .chest,
        sets: [(weight: Double, reps: Int, rir: Int?, completed: Bool)],
        planWeight: Double = 0,
        planReps: Int = 0
    ) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: 0, plannedWeight: 0)
        for (i, s) in sets.enumerated() {
            ex.sets.append(
                WorkoutSet(
                    weight: s.weight,
                    reps: s.reps,
                    isCompleted: s.completed,
                    repsInReserve: s.rir ?? 2,
                    rirLogged: s.rir != nil,
                    sortOrder: i,
                    plannedWeight: planWeight,
                    plannedReps: planReps
                )
            )
        }
        return ex
    }

    private func hold(
        _ name: String,
        seconds: [TimeInterval],
        planDuration: TimeInterval = 0
    ) -> Exercise {
        let ex = Exercise(name: name, group: .core, plannedSets: 0, plannedWeight: 0, trackingMode: .duration)
        for (i, sec) in seconds.enumerated() {
            ex.sets.append(
                WorkoutSet(weight: 0, reps: 0, duration: sec, isCompleted: true, sortOrder: i, plannedDuration: planDuration)
            )
        }
        return ex
    }

    // MARK: - Density

    @Test func densityIsVolumePerMinute() {
        // 3 sets × 100 × 10 = 3000 lb over 30 min → 100 lb/min.
        let s = session(minutes: 30, [lift(sets: [(100, 10, nil, true), (100, 10, nil, true), (100, 10, nil, true)])])
        #expect(abs((s.volumeDensity ?? 0) - 100) < 0.001)
    }

    @Test func densityNilForSubMinuteSession() {
        let s = session(minutes: 0.5, [lift(sets: [(100, 10, nil, true)])])
        #expect(s.volumeDensity == nil)
    }

    @Test func densityNilForHoldsOnlySession() {
        let s = session(minutes: 10, [hold("Plank", seconds: [60, 60])])
        #expect(s.volumeDensity == nil)
    }

    // MARK: - Hard sets

    @Test func hardSetsCountRIRAtOrBelowOne() {
        let s = session(minutes: 20, [lift(sets: [
            (100, 8, 0, true),   // hard
            (100, 8, 1, true),   // hard
            (100, 8, 2, true),   // not hard
            (100, 8, nil, true)  // unrated → ignored
        ])])
        #expect(s.hardSetCount == 2)
        #expect(s.hasLoggedRIR == true)
    }

    @Test func noLoggedRIRMeansNoHardSets() {
        let s = session(minutes: 20, [lift(sets: [(100, 8, nil, true), (100, 8, nil, true)])])
        #expect(s.hasLoggedRIR == false)
        #expect(s.hardSetCount == 0)
    }

    // MARK: - Waterfall

    @Test func volumeSharesSplitTheRepsPool() {
        // Bench 2000 (2×100×10), Row 1000 (1×100×10) → 2/3 and 1/3.
        let bench = lift("Bench Press", .chest, sets: [(100, 10, nil, true), (100, 10, nil, true)])
        let row = lift("Barbell Row", .back, sets: [(100, 10, nil, true)])
        let s = session(minutes: 30, [bench, row])
        let contrib = s.contributions()

        #expect(abs((contrib[bench.id]?.share ?? 0) - 2.0 / 3.0) < 0.001)
        #expect(abs((contrib[row.id]?.share ?? 0) - 1.0 / 3.0) < 0.001)
        #expect(contrib[bench.id]?.isDuration == false)
    }

    @Test func holdsFormTheirOwnSeparatePool() {
        // A reps lift and two holds: the holds split the hold-time
        // pool (90 / 30) independently of the weight-volume pool.
        let press = lift("Overhead Press", .shoulders, sets: [(100, 10, nil, true)])
        let plank = hold("Plank", seconds: [90])
        let hang = hold("Dead Hang", seconds: [30])
        let s = session(minutes: 25, [press, plank, hang])
        let contrib = s.contributions()

        // Reps lift owns 100% of the (single-exercise) volume pool.
        #expect(abs((contrib[press.id]?.share ?? 0) - 1.0) < 0.001)
        // Holds split 90:30 of the hold-time pool.
        #expect(abs((contrib[plank.id]?.share ?? 0) - 0.75) < 0.001)
        #expect(abs((contrib[hang.id]?.share ?? 0) - 0.25) < 0.001)
        #expect(contrib[plank.id]?.isDuration == true)
    }

    // MARK: - Adherence

    @Test func beatPlanWhenTopSetExceedsPlannedWeight() {
        let ex = lift(sets: [(105, 8, nil, true)], planWeight: 100, planReps: 8)
        let s = session(minutes: 20, [ex])
        let adherence = s.adherence(for: ex)
        #expect(adherence?.weightDelta == 5)
        #expect(adherence?.repsDelta == 0)
        #expect(adherence?.beatPlan == true)
        #expect(adherence?.isOnPlan == false)
    }

    @Test func onPlanWhenTopSetMatches() {
        let ex = lift(sets: [(100, 8, nil, true)], planWeight: 100, planReps: 8)
        let s = session(minutes: 20, [ex])
        let adherence = s.adherence(for: ex)
        #expect(adherence?.isOnPlan == true)
    }

    @Test func repDeltaWhenSameWeightFewerReps() {
        let ex = lift(sets: [(100, 6, nil, true)], planWeight: 100, planReps: 8)
        let s = session(minutes: 20, [ex])
        let adherence = s.adherence(for: ex)
        #expect(adherence?.weightDelta == 0)
        #expect(adherence?.repsDelta == -2)
        #expect(adherence?.beatPlan == false)
    }

    @Test func adherenceNilWithoutAPlan() {
        let ex = lift(sets: [(100, 8, nil, true)])  // no plan snapshot
        let s = session(minutes: 20, [ex])
        #expect(s.adherence(for: ex) == nil)
    }

    @Test func holdAdherenceTracksDurationDelta() {
        let ex = hold("Plank", seconds: [75], planDuration: 60)
        let s = session(minutes: 10, [ex])
        let adherence = s.adherence(for: ex)
        #expect(adherence?.isDuration == true)
        #expect(adherence?.durationDelta == 15)
        #expect(adherence?.beatPlan == true)
    }
}
