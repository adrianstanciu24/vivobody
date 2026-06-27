//
//  MuscleMappingTests.swift
//  vivobodyTests
//
//  Guards the exercise → muscle taxonomy that both the body model and
//  the development engine build on, now sourced from the bundled
//  `catalog.json` (`CatalogData`): the catalog decodes, involvement
//  weights are well-formed, the lookup is case-insensitive, unknown
//  names fall back to empty, and every muscle expands to real `_L`/`_R`
//  mesh nodes.
//

import Foundation
import Testing
@testable import vivobody

struct MuscleMappingTests {

    @Test func catalogDecodesFromBundle() {
        #expect(CatalogData.records.count > 650)
        #expect(CatalogData.record(forExerciseNamed: "Bench Press") != nil)
    }

    @Test func involvementWeightsAreWellFormed() {
        for record in CatalogData.records {
            for (_, weight) in record.muscleInvolvement.contributions {
                #expect(
                    weight > 0 && weight <= 1,
                    "'\(record.name)' has out-of-range involvement weight \(weight)"
                )
            }
        }
    }

    @Test func everyRecordGroupIsValid() {
        for record in CatalogData.records {
            #expect(
                MuscleGroup(rawValue: record.group) != nil,
                "'\(record.name)' has unknown group '\(record.group)'"
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

    @Test func benchPressContributionsGradeFromPrime() {
        let bench = Muscle.involvement(forExerciseNamed: "Bench Press")
        let w = bench.weights
        // Authored grading: chest is the prime mover, triceps a heavier
        // synergist than the assisting front delt — strictly stepping down.
        #expect(w[.pectorals] == Muscle.Involvement.prime)
        #expect(w[.triceps] == Muscle.Involvement.major)
        #expect(w[.deltoids] == Muscle.Involvement.minor)
        #expect(w[.pectorals]! > w[.triceps]!)
        #expect(w[.triceps]! > w[.deltoids]!)
        #expect(bench.primary == [.pectorals])
        #expect(bench.secondary == [.triceps, .deltoids])
    }

    @Test @MainActor func classificationResolvesForKnownLift() {
        let classification = ExerciseClassification.forExerciseNamed("Bench Press")
        #expect(classification?.equipment == .barbell)
        #expect(classification?.mechanic == .compound)
    }

    @Test func everyMuscleExpandsToLeftRightNodes() {
        for muscle in Muscle.allCases {
            let nodes = muscle.nodeNames
            #expect(!nodes.isEmpty, "\(muscle) maps to no mesh nodes")
            #expect(nodes.allSatisfy { $0.hasSuffix("_L") || $0.hasSuffix("_R") })
        }
    }
}
