//
//  MovementCompositionTests.swift
//  vivobodyTests
//
//  Guards the compound-vs-isolation split: classification by name via
//  the catalog, the 4-week window, exclusion of holds and incomplete
//  sets, unclassified bucketing for custom names, and the dominant-
//  mechanic read (ties break to compound).
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct MovementCompositionTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func session(daysAgo: Double, _ exercises: [Exercise]) -> WorkoutSession {
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    /// Reps exercise from (reps, completed) tuples at a fixed weight.
    /// Name drives classification, so it's parameterised.
    private func lift(_ name: String,
                      _ group: MuscleGroup,
                      _ sets: [(reps: Int, completed: Bool)]) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: 0, plannedWeight: 0)
        for (i, s) in sets.enumerated() {
            ex.sets.append(WorkoutSet(weight: 100, reps: s.reps, isCompleted: s.completed, sortOrder: i))
        }
        return ex
    }

    private func hold(seconds: [TimeInterval]) -> Exercise {
        let ex = Exercise(name: "Plank", group: .core, plannedSets: 0, plannedWeight: 0, trackingMode: .duration)
        for (i, sec) in seconds.enumerated() {
            ex.sets.append(WorkoutSet(weight: 0, reps: 0, duration: sec, isCompleted: true, sortOrder: i))
        }
        return ex
    }

    // MARK: - Classification + counting

    @Test func countsCompoundAndIsolationSets() {
        // "Bench Press" = compound; "Leg Curl" = isolation (verified
        // in the bundled catalog).
        let bench = lift("Bench Press", .chest, [(8, true), (8, true)])
        let curl = lift("Leg Curl", .legs, [(12, true), (12, true), (12, true)])
        let split = [session(daysAgo: 1, [bench, curl])].compoundIsolationSplit(now: now)
        #expect(split.compoundSets == 2)
        #expect(split.isolationSets == 3)
        #expect(split.unclassifiedSets == 0)
        #expect(split.classifiedTotal == 5)
        #expect(split.hasData)
    }

    // MARK: - Exclusions

    @Test func ignoresIncompleteSets() {
        let ex = lift("Bench Press", .chest, [(8, true), (8, false), (8, true)])
        let split = [session(daysAgo: 1, [ex])].compoundIsolationSplit(now: now)
        #expect(split.compoundSets == 2)
        #expect(split.classifiedTotal == 2)
    }

    @Test func ignoresTimedHolds() {
        let split = [session(daysAgo: 1, [hold(seconds: [60, 45])])].compoundIsolationSplit(now: now)
        #expect(split.hasData == false)
        #expect(split.classifiedTotal == 0)
        #expect(split.unclassifiedSets == 0)
    }

    @Test func respectsTheWindow() {
        let recent = session(daysAgo: 3, [lift("Bench Press", .chest, [(8, true)])])
        let old = session(daysAgo: 40, [lift("Bench Press", .chest, [(8, true), (8, true)])])
        let split = [recent, old].compoundIsolationSplit(now: now) // default 28d window
        #expect(split.compoundSets == 1)
        #expect(split.isolationSets == 0)
    }

    // MARK: - Unclassified

    @Test func unclassifiedBucketedSeparatelyAndExcludedFromShares() {
        let bench = lift("Bench Press", .chest, [(8, true)])              // compound, 1
        let custom = lift("My Weird Lift", .chest, [(8, true), (8, true)]) // unclassified, 2
        let split = [session(daysAgo: 1, [bench, custom])].compoundIsolationSplit(now: now)
        #expect(split.compoundSets == 1)
        #expect(split.isolationSets == 0)
        #expect(split.unclassifiedSets == 2)
        #expect(split.classifiedTotal == 1)
        #expect(abs(split.share(.compound) - 1.0) < 0.001)
        #expect(abs(split.share(.isolation) - 0.0) < 0.001)
    }

    // MARK: - Dominant + shares

    @Test func dominantTieResolvesTowardCompound() {
        let bench = lift("Bench Press", .chest, [(8, true)])   // compound, 1
        let curl = lift("Leg Curl", .legs, [(12, true)])       // isolation, 1
        let split = [session(daysAgo: 1, [bench, curl])].compoundIsolationSplit(now: now)
        #expect(split.compoundSets == 1)
        #expect(split.isolationSets == 1)
        #expect(split.dominant == .compound)
    }

    @Test func sharesComputedOverClassifiedTotalOnly() {
        let bench = lift("Bench Press", .chest, [(8, true), (8, true)])        // compound, 2
        let curl = lift("Leg Curl", .legs, [(12, true)])                       // isolation, 1
        let custom = lift("My Weird Lift", .chest, [(8, true), (8, true), (8, true)]) // unclassified, 3
        let split = [session(daysAgo: 1, [bench, curl, custom])].compoundIsolationSplit(now: now)
        #expect(split.classifiedTotal == 3)
        #expect(split.unclassifiedSets == 3)
        #expect(abs(split.share(.compound) - (2.0 / 3.0)) < 0.001)
        #expect(abs(split.share(.isolation) - (1.0 / 3.0)) < 0.001)
        #expect(split.dominant == .compound)
    }

    @Test func emptyHasNoDominant() {
        let split = [WorkoutSession]().compoundIsolationSplit(now: now)
        #expect(split.dominant == nil)
        #expect(split.hasData == false)
    }
}
