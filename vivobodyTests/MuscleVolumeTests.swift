//
//  MuscleVolumeTests.swift
//  vivobodyTests
//
//  Guards the weekly effective-set engine behind the Insights tab's
//  muscle-balance view. The interesting behaviour is all date- and
//  graded-weight-driven, so — like the development model — it's tested
//  on a virtual clock with no simulator.
//
//  Covered:
//    • Graded credit — a set splits across muscles by involvement
//      weight (chest 1.0, triceps 0.7, delts 0.4 from a bench set).
//    • Completion gate — only completed sets count.
//    • Rolling window — work outside the 7-day window stops counting
//      toward volume but still updates recency.
//    • Zones — under / optimal / high against per-muscle landmarks.
//    • Recency — days-since for trained muscles, nil for never-trained.
//    • Summary — neglect ranking puts rested muscles ahead of under ones.
//

import Foundation
import Testing
@testable import vivobody

struct MuscleVolumeTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Helpers

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    /// A lift whose first `completed` sets are marked done.
    private func lift(_ name: String, _ group: MuscleGroup, sets: Int, completed: Int? = nil) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: sets, plannedReps: 8, plannedWeight: 100)
        let doneCount = completed ?? sets
        for (i, set) in ex.orderedSets.enumerated() {
            set.isCompleted = i < doneCount
        }
        return ex
    }

    private func stat(_ muscle: Muscle, in stats: [MuscleVolumeStat]) -> MuscleVolumeStat {
        stats.first { $0.muscle == muscle }!
    }

    // MARK: - Graded credit

    @Test func benchSplitsSetsAcrossMusclesByWeight() {
        // The engine credits each muscle `sets × involvementWeight`.
        // Read the weights from the catalog so the test tracks the
        // shipped data instead of hard-coding a grading that can shift
        // when catalog.json is regenerated.
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 3)])
        let stats = [s].muscleVolume(now: day(0))
        let w = Muscle.involvement(forExerciseNamed: "Bench Press").weights

        #expect(abs(stat(.pectorals, in: stats).effectiveSets - 3.0 * (w[.pectorals] ?? 0)) < 1e-9)
        #expect(abs(stat(.triceps, in: stats).effectiveSets - 3.0 * (w[.triceps] ?? 0)) < 1e-9)
        #expect(abs(stat(.deltoids, in: stats).effectiveSets - 3.0 * (w[.deltoids] ?? 0)) < 1e-9)
        // Chest is the prime mover; the assistors are graded lower.
        #expect(w[.pectorals] == Muscle.Involvement.prime)
        #expect((w[.triceps] ?? 0) < w[.pectorals]!)
    }

    @Test func everyMuscleIsRepresentedEvenWhenUntrained() {
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 3)])
        let stats = [s].muscleVolume(now: day(0))
        #expect(stats.count == Muscle.allCases.count)
        // A leg muscle untouched by bench reads zero / untrained / never.
        let quads = stat(.quads, in: stats)
        #expect(quads.effectiveSets == 0)
        #expect(quads.zone == .untrained)
        #expect(quads.daysSinceLastTrained == nil)
    }

    // MARK: - Completion gate

    @Test func onlyCompletedSetsCount() {
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 4, completed: 2)])
        let stats = [s].muscleVolume(now: day(0))
        #expect(abs(stat(.pectorals, in: stats).effectiveSets - 2.0) < 1e-9)
    }

    // MARK: - Rolling window

    @Test func workOutsideWindowStopsCountingButKeepsRecency() {
        // Trained 9 days ago, evaluated today with the default 7-day
        // window: no volume credit, but recency still reflects it.
        let old = session(at: day(1), [lift("Bench Press", .chest, sets: 5)])
        let stats = [old].muscleVolume(now: day(10))

        let chest = stat(.pectorals, in: stats)
        #expect(chest.effectiveSets == 0)
        #expect(chest.zone == .untrained)
        #expect(chest.daysSinceLastTrained == 9)
    }

    @Test func workInsideWindowCounts() {
        let recent = session(at: day(8), [lift("Bench Press", .chest, sets: 5)])
        let stats = [recent].muscleVolume(now: day(10))
        #expect(abs(stat(.pectorals, in: stats).effectiveSets - 5.0) < 1e-9)
        #expect(stat(.pectorals, in: stats).daysSinceLastTrained == 2)
    }

    // MARK: - Zones

    @Test func zonesTrackLandmarks() {
        // Pectorals landmark: mev 8, optimalHigh 20.
        func chestZone(sets: Int) -> VolumeZone {
            let s = session(at: day(0), [lift("Bench Press", .chest, sets: sets)])
            return stat(.pectorals, in: [s].muscleVolume(now: day(0))).zone
        }
        #expect(chestZone(sets: 6) == .under)      // below MEV
        #expect(chestZone(sets: 12) == .optimal)   // inside the band
        #expect(chestZone(sets: 25) == .high)      // past the top
    }

    // MARK: - Summary

    @Test func neglectRankingPutsRestedAheadOfUnder() {
        // Chest gets plenty (optimal); its synergists land under;
        // every leg muscle is untrained. Rested muscles must rank as
        // more neglected than merely-under ones.
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 12)])
        let stats = [s].muscleVolume(now: day(0))
        let summary = stats.summary

        #expect(summary.optimalCount >= 1)
        #expect(summary.hasWindowActivity)

        // Find the first under-volume entry; everything before it must
        // be untrained.
        if let firstUnderIndex = summary.neglected.firstIndex(where: { $0.zone == .under }) {
            let prefix = summary.neglected[..<firstUnderIndex]
            #expect(prefix.allSatisfy { $0.zone == .untrained })
        }
    }

    @Test func emptyArchiveHasNoActivity() {
        let stats = [WorkoutSession]().muscleVolume(now: day(0))
        #expect(stats.count == Muscle.allCases.count)
        #expect(stats.allSatisfy { $0.zone == .untrained })
        #expect(!stats.summary.hasWindowActivity)
    }
}
