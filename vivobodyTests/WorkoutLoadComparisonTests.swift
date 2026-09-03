//
//  WorkoutLoadComparisonTests.swift
//  vivobodyTests
//
//  Freezes normalized workout-progress averaging and comparison eligibility.
//

import Testing
@testable import vivobody

struct WorkoutLoadComparisonTests {
    @Test func baselineAveragesDifferentLengthWorkoutsOnOneProgressScale() {
        let baseline = WorkoutLoadBaseline.make(traces: [
            WorkoutLoadTrace(setLoads: [100, 100]),
            WorkoutLoadTrace(setLoads: [50]),
        ])

        #expect(baseline.workoutCount == 2)
        #expect(baseline.points.first?.value == 0)
        #expect(baseline.points[6].progress == 0.5)
        #expect(baseline.points[6].value == 62.5)
        #expect(baseline.averageTotal == 125)
    }

    @Test func baselineExcludesPartialAndUnavailableWorkouts() {
        let baseline = WorkoutLoadBaseline.make(traces: [
            WorkoutLoadTrace(setLoads: [100, 100]),
            WorkoutLoadTrace(setLoads: [300], availability: .partial),
            WorkoutLoadTrace(setLoads: [], availability: .unavailable),
        ])

        #expect(baseline.workoutCount == 1)
        #expect(baseline.averageTotal == 200)
    }

    @Test func comparisonUsesOneScaleAndPreservesExactEndpoints() throws {
        let baseline = WorkoutLoadBaseline.make(traces: [
            WorkoutLoadTrace(setLoads: [80, 120]),
        ])
        let comparison = try #require(WorkoutLoadComparison.make(
            current: WorkoutLoadTrace(setLoads: [100, 150, 50]),
            baseline: baseline
        ))

        #expect(comparison.currentPoints.first?.value == 0)
        #expect(comparison.currentTotal == 300)
        #expect(comparison.averageTotal == 200)
        #expect(comparison.averageWorkoutCount == 1)
        #expect(comparison.scaleMaximum == 324)
    }

    @Test func comparisonRequiresCompleteCurrentLoadAndAnArchiveBaseline() {
        let baseline = WorkoutLoadBaseline.make(traces: [
            WorkoutLoadTrace(setLoads: [100]),
        ])

        #expect(WorkoutLoadComparison.make(
            current: WorkoutLoadTrace(setLoads: [100], availability: .partial),
            baseline: baseline
        ) == nil)
        #expect(WorkoutLoadComparison.make(
            current: WorkoutLoadTrace(setLoads: [100]),
            baseline: .empty
        ) == nil)
    }
}
