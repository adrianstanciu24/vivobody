//
//  MuscleMappingTests.swift
//  vivobodyTests
//
//  Guards the exercise → muscle taxonomy that both the body model and
//  the development engine build on: every seeded exercise resolves to
//  at least one muscle, the lookup is case-insensitive, unknown names
//  fall back to empty, and every muscle expands to real `_L`/`_R`
//  mesh nodes.
//

import Foundation
import Testing
@testable import vivobody

struct MuscleMappingTests {

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
        #expect(involvement.isEmpty)
        #expect(involvement.primary.isEmpty)
        #expect(involvement.secondary.isEmpty)
    }

    @Test func contributionsAreGraded() {
        let bench = Muscle.involvement(forExerciseNamed: "Bench Press")
        let w = bench.weights
        // Target chest is the prime mover; triceps a heavier synergist
        // than the assisting front delt — strictly stepping down.
        #expect(w[.pectorals] == Muscle.Involvement.prime)
        #expect(w[.triceps] == Muscle.Involvement.major)
        #expect(w[.deltoids] == Muscle.Involvement.minor)
        #expect(w[.pectorals]! > w[.triceps]!)
        #expect(w[.triceps]! > w[.deltoids]!)
        // Two-tier projection still partitions on the prime threshold.
        #expect(bench.primary == [.pectorals])
        #expect(bench.secondary == [.triceps, .deltoids])
    }

    @Test func everyMuscleExpandsToLeftRightNodes() {
        for muscle in Muscle.allCases {
            let nodes = muscle.nodeNames
            #expect(!nodes.isEmpty, "\(muscle) maps to no mesh nodes")
            #expect(nodes.allSatisfy { $0.hasSuffix("_L") || $0.hasSuffix("_R") })
        }
    }
}
