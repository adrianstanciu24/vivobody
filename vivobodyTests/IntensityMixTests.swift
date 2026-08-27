//
//  IntensityMixTests.swift
//  vivobodyTests
//
//  Guards the rep-range distribution: plain low / moderate / high-rep
//  bucketing, the 28-day mix, an exact 12-calendar-week chart window,
//  future-date exclusion, sparse-sample state, and the dominant read.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct IntensityMixTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func session(daysAgo: Double, _ exercises: [Exercise]) -> WorkoutSession {
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    /// Reps exercise from (reps, completed) tuples at a fixed weight.
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

    @Test func bucketsByRepCount() {
        let ex = lift([(3, true), (5, true), (8, true), (12, true), (15, true), (20, true)])
        let mix = [session(daysAgo: 1, [ex])].intensityMix(now: now)
        #expect(mix.strengthSets == 2)     // 3, 5
        #expect(mix.hypertrophySets == 2)  // 8, 12
        #expect(mix.enduranceSets == 2)    // 15, 20
        #expect(mix.total == 6)
    }

    @Test func boundariesLandInTheRightZone() {
        // 5 = strength, 6 = hypertrophy, 12 = hypertrophy, 13 = endurance.
        let ex = lift([(5, true), (6, true), (12, true), (13, true)])
        let mix = [session(daysAgo: 1, [ex])].intensityMix(now: now)
        #expect(mix.strengthSets == 1)
        #expect(mix.hypertrophySets == 2)
        #expect(mix.enduranceSets == 1)
    }

    // MARK: - Exclusions

    @Test func ignoresIncompleteAndUnloggedReps() {
        let ex = lift([(8, true), (8, false), (0, true)])
        let mix = [session(daysAgo: 1, [ex])].intensityMix(now: now)
        #expect(mix.total == 1)
        #expect(mix.hypertrophySets == 1)
    }

    @Test func ignoresTimedHolds() {
        let mix = [session(daysAgo: 1, [hold(seconds: [60, 45])])].intensityMix(now: now)
        #expect(mix.hasData == false)
        #expect(mix.total == 0)
    }

    @Test func onlyDynamicStrengthRepsEnterTheMix() {
        let dynamic = lift([(5, true), (8, true)])
        let power = lift([(3, true)], modality: .power)
        let invalidIsometricReps = lift([(12, true)], modality: .isometricStrength)
        let archive = [session(daysAgo: 1, [dynamic, power, invalidIsometricReps])]

        let mix = archive.intensityMix(now: now)
        #expect(mix.strengthSets == 1)
        #expect(mix.hypertrophySets == 1)
        #expect(mix.enduranceSets == 0)

        let week = archive.weeklyIntensity(now: now)
        #expect(week.count == 12)
        #expect(week.last?.strengthSets == 1)
        #expect(week.last?.hypertrophySets == 1)
        #expect(week.last?.enduranceSets == 0)
    }

    @Test func respectsTheWindow() {
        let recent = session(daysAgo: 3, [lift([(8, true)])])
        let old = session(daysAgo: 40, [lift([(3, true), (3, true)])])
        let mix = [recent, old].intensityMix(now: now) // default 28d window
        #expect(mix.total == 1)
        #expect(mix.hypertrophySets == 1)
        #expect(mix.strengthSets == 0)
    }

    @Test func futureSessionsAreExcluded() {
        let future = session(daysAgo: -1, [lift([(3, true), (8, true), (20, true)])])
        let mix = [future].intensityMix(now: now)
        let weeks = [future].weeklyIntensity(now: now)

        #expect(mix.total == 0)
        #expect(weeks.count == 12)
        #expect(weeks.allSatisfy { $0.total == 0 })
    }

    @Test func sparseSamplesAreLabelledUntilSixSets() {
        let sparse = [session(daysAgo: 1, [lift([(8, true)])])].intensityMix(now: now)
        let clearSets: [(reps: Int, completed: Bool)] = Array(
            repeating: (reps: 8, completed: true),
            count: 6
        )
        let clear = [session(daysAgo: 1, [lift(clearSets)])]
            .intensityMix(now: now)

        #expect(sparse.hasSparseSample)
        #expect(!clear.hasSparseSample)
    }

    @Test func zonesUseDescriptiveRepLabels() {
        #expect(IntensityZone.strength.label == "Low reps")
        #expect(IntensityZone.hypertrophy.label == "Moderate reps")
        #expect(IntensityZone.endurance.label == "High reps")
    }

    // MARK: - Dominant + shares

    @Test func dominantIsTheHeaviestZone() {
        let ex = lift([(8, true), (8, true), (8, true), (3, true), (20, true)])
        let mix = [session(daysAgo: 1, [ex])].intensityMix(now: now)
        #expect(mix.dominant == .hypertrophy)
        #expect(abs(mix.share(.hypertrophy) - 0.6) < 0.001)
    }

    @Test func dominantTieResolvesTowardStrength() {
        // 2 strength vs 2 endurance: tie breaks toward the heavier end.
        let ex = lift([(3, true), (4, true), (15, true), (20, true)])
        let mix = [session(daysAgo: 1, [ex])].intensityMix(now: now)
        #expect(mix.dominant == .strength)
    }

    @Test func emptyHasNoDominant() {
        let mix = [WorkoutSession]().intensityMix(now: now)
        #expect(mix.dominant == nil)
        #expect(mix.hasData == false)
    }

    // MARK: - Weekly breakdown

    @Test func weeklyBucketsSitInTheirOwnWeeks() {
        let thisWeek = session(daysAgo: 0, [lift([(3, true), (8, true)])])
        let lastWeek = session(daysAgo: 7, [lift([(15, true)])])
        let weeks = [thisWeek, lastWeek].weeklyIntensity(now: now)
        let active = weeks.filter { $0.total > 0 }

        #expect(weeks.count == 12)
        #expect(active.count == 2)
        // Chronological ascending: older week first.
        #expect(active[0].weekStart < active[1].weekStart)
        #expect(active[0].enduranceSets == 1)
        #expect(active[0].total == 1)
        #expect(!active[0].isCurrentWeek)
        #expect(active[1].strengthSets == 1)
        #expect(active[1].hypertrophySets == 1)
        #expect(active[1].total == 2)
        #expect(active[1].isCurrentWeek)
    }

    @Test func weeklyRespectsTheWindow() {
        let recent = session(daysAgo: 3, [lift([(8, true)])])
        let ancient = session(daysAgo: 100, [lift([(3, true)])])
        let weeks = [recent, ancient].weeklyIntensity(weeks: 12, now: now)
        #expect(weeks.count == 12)
        #expect(weeks.reduce(0) { $0 + $1.hypertrophySets } == 1)
        #expect(weeks.reduce(0) { $0 + $1.strengthSets } == 0)
    }

    @Test func weeklyPreservesEmptyWeeksAndIgnoresHolds() {
        let holdsOnly = session(daysAgo: 7, [hold(seconds: [60])])
        let repsWeek = session(daysAgo: 0, [lift([(10, true)])])
        let weeks = [holdsOnly, repsWeek].weeklyIntensity(now: now)
        #expect(weeks.count == 12)
        #expect(weeks.filter { $0.total > 0 }.count == 1)
        #expect(weeks.last?.hypertrophySets == 1)
    }

    @Test func weeklyEmptyHistoryStillReturnsTheExactWindow() {
        let weeks = [WorkoutSession]().weeklyIntensity(now: now)
        #expect(weeks.count == 12)
        #expect(weeks.allSatisfy { $0.total == 0 })
        #expect(weeks.last?.isCurrentWeek == true)
    }

    @Test func weeklyMarksOnlyTheCurrentCalendarWeek() {
        let sessions = [
            session(daysAgo: 0, [lift([(8, true)])]),
            session(daysAgo: 7, [lift([(8, true)])]),
            session(daysAgo: 14, [lift([(8, true)])]),
        ]
        let weeks = sessions.weeklyIntensity(now: now)

        #expect(weeks.count == 12)
        #expect(weeks.filter { $0.total > 0 }.count == 3)
        #expect(weeks.filter(\.isCurrentWeek).count == 1)
        #expect(weeks.last?.isCurrentWeek == true)
    }

    @Test func requestedWindowHasExactlyConsecutiveCalendarWeeks() {
        let calendar = Calendar.current
        let weeks = [WorkoutSession]().weeklyIntensity(weeks: 12, now: now)

        #expect(weeks.count == 12)
        for pair in zip(weeks, weeks.dropFirst()) {
            #expect(calendar.date(byAdding: .weekOfYear, value: 1, to: pair.0.weekStart) == pair.1.weekStart)
        }
    }
}
