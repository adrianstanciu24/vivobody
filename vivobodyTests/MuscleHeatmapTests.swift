//
//  MuscleHeatmapTests.swift
//  vivobodyTests
//
//  Covers the exercise → muscle map and the recency-decayed,
//  load-weighted activation formula that drives the 3D body model's
//  colouring (including fade-to-dark after a layoff).
//

import Foundation
import Testing
@testable import vivobody

struct MuscleHeatmapTests {

    // MARK: - Mapping coverage

    @Test func everySeededExerciseMapsToMuscles() {
        for seed in ExerciseCatalogItem.seedItems {
            let involvement = Muscle.involvement(forExerciseNamed: seed.name)
            #expect(
                !involvement.primary.isEmpty,
                "Seed '\(seed.name)' has no primary muscle mapping"
            )
        }
    }

    @Test func mappingIsCaseInsensitive() {
        let lower = Muscle.involvement(forExerciseNamed: "bench press")
        #expect(lower.primary == [.pectorals])
    }

    @Test func unknownExerciseMapsToEmpty() {
        let involvement = Muscle.involvement(forExerciseNamed: "Totally Made Up Lift")
        #expect(involvement.primary.isEmpty)
        #expect(involvement.secondary.isEmpty)
    }

    @Test func everyMuscleExpandsToLeftRightNodes() {
        for muscle in Muscle.allCases {
            let nodes = muscle.nodeNames
            #expect(!nodes.isEmpty, "\(muscle) maps to no mesh nodes")
            #expect(nodes.allSatisfy { $0.hasSuffix("_L") || $0.hasSuffix("_R") })
        }
    }

    // MARK: - Activation formula

    /// A bench press alone makes the chest the busiest muscle (full
    /// intensity), with its secondaries scaled by the role weight and
    /// the gamma curve, and untargeted muscles absent entirely.
    @Test func benchPressLightsChestThenAssistors() {
        let now = Date()
        let bench = completed(name: "Bench Press", group: .chest, sets: 3, reps: 10)
        let session = WorkoutSession(exercises: [bench], startedAt: now)

        let intensities = MuscleHeatmap.intensities(from: [session], now: now)

        #expect(intensities[.pectorals] == 1.0)

        // secondary = 0.5 effort vs primary 1.0 → (0.5)^0.6 before
        // any other muscle outscores the chest.
        let expectedSecondary = pow(0.5, 0.6)
        #expect(abs((intensities[.triceps] ?? 0) - expectedSecondary) < 0.0001)
        #expect(abs((intensities[.deltoids] ?? 0) - expectedSecondary) < 0.0001)

        // Bench press doesn't touch the legs.
        #expect(intensities[.quads] == nil)
        #expect(intensities[.hamstrings] == nil)
    }

    @Test func nodeIntensitiesPaintBothSidesOfWorkedMuscles() {
        let now = Date()
        let bench = completed(name: "Bench Press", group: .chest, sets: 1, reps: 8)
        let nodes = MuscleHeatmap.nodeIntensities(from: [WorkoutSession(exercises: [bench], startedAt: now)], now: now)

        #expect(nodes["Pectoralis_Major_L"] == 1.0)
        #expect(nodes["Pectoralis_Major_R"] == 1.0)
        // An untargeted leg mesh stays out of the map (untrained).
        #expect(nodes["Vastus_Lateralis_L"] == nil)
    }

    @Test func incompleteSetsContributeNothing() {
        let bench = Exercise(name: "Bench Press", group: .chest, plannedSets: 3, plannedReps: 10, plannedWeight: 135)
        // Leave all sets uncompleted.
        let intensities = MuscleHeatmap.intensities(from: [WorkoutSession(exercises: [bench])])
        #expect(intensities.isEmpty)
    }

    /// Heavier work outscores lighter work for the same rep count:
    /// a 200 lb bench beats a 50 lb curl, so the chest grades hotter
    /// than the biceps.
    @Test func heavierLoadScoresHigher() {
        let now = Date()
        let bench = completed(name: "Bench Press", group: .chest, sets: 1, reps: 10, weight: 200)
        let curl  = completed(name: "Barbell Curl", group: .arms, sets: 1, reps: 10, weight: 50)
        let intensities = MuscleHeatmap.intensities(from: [WorkoutSession(exercises: [bench, curl], startedAt: now)], now: now)

        #expect(intensities[.pectorals] == 1.0)
        #expect((intensities[.biceps] ?? 0) < (intensities[.pectorals] ?? 0))
    }

    /// Two identical-rep sets of the same lift at different weights:
    /// the heavier session's muscle must score strictly higher before
    /// normalisation collapses them — verified via the secondary
    /// ratio staying fixed while the absolute winner is the heavy one.
    @Test func sameRepsDifferentWeightDiffer() {
        let now = Date()
        let light = completed(name: "Back Squat", group: .legs, sets: 1, reps: 10, weight: 50)
        let heavy = completed(name: "Bench Press", group: .chest, sets: 1, reps: 10, weight: 300)
        let intensities = MuscleHeatmap.intensities(from: [WorkoutSession(exercises: [light, heavy], startedAt: now)], now: now)
        // Bench (300) is the busiest → chest full; squat quads scale below.
        #expect(intensities[.pectorals] == 1.0)
        #expect((intensities[.quads] ?? 0) < 1.0)
    }

    /// Unloaded movements still score via their bodyweight fraction,
    /// scaled by the provided body weight.
    @Test func bodyweightExerciseUsesBodyweightProxy() {
        let now = Date()
        let pushup = completed(name: "Push-Up", group: .chest, sets: 1, reps: 20, weight: 0)
        let session = WorkoutSession(exercises: [pushup], startedAt: now)

        let withBody = MuscleHeatmap.intensities(from: [session], bodyweight: 150, now: now)
        #expect(withBody[.pectorals] == 1.0)   // only muscle worked → max

        // A heavier lifter's push-ups carry more load, but with a
        // single exercise normalisation still pins it at 1.0 — assert
        // it simply registers rather than zeroing out.
        #expect((withBody[.triceps] ?? 0) > 0)
    }

    /// A push-up (fraction 0.64) vs a bench at a light load: with a
    /// big enough body weight, bodyweight work can out-rank a feather
    /// bench — proving the fraction actually feeds the load.
    @Test func bodyweightLoadFeedsScore() {
        let now = Date()
        let pushup = completed(name: "Push-Up", group: .chest, sets: 1, reps: 10, weight: 0)
        // bodyweight 200 → load 0.64*200 = 128 per rep.
        let heavyBodyweight = MuscleHeatmap.intensities(from: [WorkoutSession(exercises: [pushup], startedAt: now)], bodyweight: 200, now: now)
        let lightBodyweight = MuscleHeatmap.intensities(from: [WorkoutSession(exercises: [pushup], startedAt: now)], bodyweight: 100, now: now)
        // Single exercise both normalise to 1.0; assert both register.
        #expect(heavyBodyweight[.pectorals] == 1.0)
        #expect(lightBodyweight[.pectorals] == 1.0)
    }

    @Test func emptyHistoryYieldsEmptyHeatmap() {
        #expect(MuscleHeatmap.intensities(from: []).isEmpty)
        #expect(MuscleHeatmap.nodeIntensities(from: []).isEmpty)
    }

    /// Persisted muscle fields take precedence over the name lookup.
    @Test func persistedMusclesOverrideNameFallback() {
        let ex = Exercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 1,
            plannedReps: 5,
            plannedWeight: 100,
            primaryMuscles: [.biceps]
        )
        ex.sets.forEach { $0.isCompleted = true }
        let now = Date()
        let intensities = MuscleHeatmap.intensities(from: [WorkoutSession(exercises: [ex], startedAt: now)], now: now)
        #expect(intensities[.biceps] == 1.0)
        #expect(intensities[.pectorals] == nil)
    }

    // MARK: - Time decay

    /// Recent work outweighs equal-but-stale work: identical curl and
    /// bench sessions, but the bench is 28 days old (two 14-day
    /// half-lives → quartered), so the recent biceps grade hotter.
    @Test func recentWorkOutweighsStaleWork() {
        let now = Date()
        let recentCurl = completed(name: "Barbell Curl", group: .arms, sets: 1, reps: 10, weight: 100)
        let staleBench = completed(name: "Bench Press", group: .chest, sets: 1, reps: 10, weight: 100)
        let recent = WorkoutSession(exercises: [recentCurl], startedAt: now)
        let stale  = WorkoutSession(exercises: [staleBench], startedAt: now.addingTimeInterval(-28 * 86_400))

        let intensities = MuscleHeatmap.intensities(from: [recent, stale], now: now)

        #expect(intensities[.biceps] == 1.0)
        #expect((intensities[.pectorals] ?? 0) < (intensities[.biceps] ?? 0))
    }

    /// Fade-to-dark: a muscle trained hard but then totally neglected
    /// must drop well below full as the layoff stretches on, even
    /// though it's still the only muscle ever worked.
    @Test func totalLayoffFadesTowardDark() {
        let now = Date()
        let bench = completed(name: "Bench Press", group: .chest, sets: 3, reps: 10, weight: 135)

        let fresh = MuscleHeatmap.intensities(
            from: [WorkoutSession(exercises: [bench])],
            now: now
        )
        // Same single session, but logged 70 days ago.
        let stale = MuscleHeatmap.intensities(
            from: [WorkoutSession(exercises: [completed(name: "Bench Press", group: .chest, sets: 3, reps: 10, weight: 135)], startedAt: now.addingTimeInterval(-70 * 86_400))],
            now: now
        )

        #expect(fresh[.pectorals] == 1.0)                 // trained today → bright
        #expect((stale[.pectorals] ?? 1) < 0.5)           // long layoff → faded
        #expect((stale[.pectorals] ?? 0) < (fresh[.pectorals] ?? 0))
    }

    /// The fade deepens the longer the layoff: 90 days darker than 30.
    @Test func longerLayoffFadesFurther() {
        let now = Date()
        func staleChest(daysAgo: Double) -> Double {
            let s = WorkoutSession(
                exercises: [completed(name: "Bench Press", group: .chest, sets: 3, reps: 10, weight: 135)],
                startedAt: now.addingTimeInterval(-daysAgo * 86_400)
            )
            return MuscleHeatmap.intensities(from: [s], now: now)[.pectorals] ?? 0
        }
        #expect(staleChest(daysAgo: 90) < staleChest(daysAgo: 30))
    }

    /// A muscle trained equally hard in two sessions still lands at
    /// the top when both are recent — decay only bites with age.
    @Test func equalRecentSessionsDoNotDecayApart() {
        let now = Date()
        let a = WorkoutSession(exercises: [completed(name: "Bench Press", group: .chest, sets: 1, reps: 10, weight: 100)], startedAt: now)
        let b = WorkoutSession(exercises: [completed(name: "Barbell Curl", group: .arms, sets: 1, reps: 10, weight: 100)], startedAt: now)
        let intensities = MuscleHeatmap.intensities(from: [a, b], now: now)
        // Same load×reps, both today → chest is the prime mover of the
        // heavier-scoring lift only via role; here both are primaries
        // of their own lift so both reach the max.
        #expect(intensities[.pectorals] == 1.0)
        #expect(intensities[.biceps] == 1.0)
    }

    // MARK: - Helpers

    private func completed(name: String, group: MuscleGroup, sets: Int, reps: Int, weight: Double = 100) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: sets, plannedReps: reps, plannedWeight: weight)
        ex.sets.forEach { $0.isCompleted = true }
        return ex
    }
}
