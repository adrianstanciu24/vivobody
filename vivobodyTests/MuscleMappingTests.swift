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

@MainActor
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

    @Test func everyMuscleIsTargetedByAtLeastOneCatalogExercise() {
        let positiveInvolvement = CatalogData.records.flatMap { record in
            (record.involvement ?? []).filter { $0.weight > 0 }
        }
        let targeted = Set(
            positiveInvolvement.compactMap { involvement -> Muscle? in
                Muscle(rawValue: involvement.muscle)
            }
        )
        let expected = Set(Muscle.allCases)
        let expectedRawValues = Set(Muscle.allCases.map(\.rawValue))
        let missing = expected.subtracting(targeted)
        let unexpectedRawValues = Set(positiveInvolvement.map(\.muscle)).subtracting(expectedRawValues)

        #expect(
            targeted == expected && unexpectedRawValues.isEmpty,
            """
            Catalog muscle coverage does not match Muscle.allCases.
            Missing: \(Self.muscleList(missing))
            Unexpected: \(Self.rawMuscleList(unexpectedRawValues))
            """
        )
    }

    @Test func everyCatalogMuscleStringIsValidMuscleRawValue() {
        for record in CatalogData.records {
            for involvement in record.involvement ?? [] {
                #expect(
                    Muscle(rawValue: involvement.muscle) != nil,
                    "'\(record.name)' has invalid catalog muscle '\(involvement.muscle)'"
                )
            }
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
        // synergist than the assisting front delt, with biceps only as a
        // trace dynamic stabilizer.
        #expect(w[.pectorals] == Muscle.Involvement.prime)
        #expect(w[.triceps] == Muscle.Involvement.major)
        #expect(w[.deltoids] == Muscle.Involvement.minor)
        #expect(w[.biceps] == Muscle.Involvement.trace)
        #expect(w[.pectorals]! > w[.triceps]!)
        #expect(w[.triceps]! > w[.deltoids]!)
        #expect(w[.deltoids]! > w[.biceps]!)
        #expect(bench.primary == [.pectorals])
        #expect(bench.secondary == [.triceps, .deltoids, .biceps])
    }

    @Test func gluteExercisesKeepMaxAndMedSeparate() {
        let hipThrust = Muscle.involvement(forExerciseNamed: "Barbell Hip Thrust")
        #expect(hipThrust.weights[.gluteMax] == Muscle.Involvement.prime)
        #expect(hipThrust.weights[.gluteMed] == nil)

        let hipAbduction = Muscle.involvement(forExerciseNamed: "Machine Hip Abduction")
        #expect(hipAbduction.weights[.gluteMed] == Muscle.Involvement.prime)
        #expect(hipAbduction.weights[.gluteMax] == nil)
    }

    @Test func legacyGlutesSnapshotCreditsBothNewRegions() {
        let involvement = Muscle.Involvement(snapshot: ["glutes": Muscle.Involvement.major])
        #expect(involvement.weights[.gluteMax] == Muscle.Involvement.major)
        #expect(involvement.weights[.gluteMed] == Muscle.Involvement.major)
        #expect(involvement.snapshot["glutes"] == nil)
    }

    @Test func authoringLevelsUseCatalogWeights() {
        #expect(Muscle.Involvement.Level.prime.rawValue == Muscle.Involvement.prime)
        #expect(Muscle.Involvement.Level.major.rawValue == Muscle.Involvement.major)
        #expect(Muscle.Involvement.Level.minor.rawValue == Muscle.Involvement.minor)
        #expect(Muscle.Involvement.Level.trace.rawValue == Muscle.Involvement.trace)
        #expect(Muscle.Involvement.Level.none.rawValue == 0)
    }

    @Test func everyGroupPresetHasPrimeMover() {
        for group in MuscleGroup.allCases {
            #expect(
                Muscle.defaultInvolvement(for: group).hasPrime,
                "\(group.rawValue) preset has no Prime muscle"
            )
        }
    }

    @Test @MainActor func explicitCatalogInvolvementOverridesCuratedName() {
        let custom = Muscle.Involvement(contributions: [
            (.quads, Muscle.Involvement.prime),
            (.gluteMax, Muscle.Involvement.major),
            (.gluteMed, Muscle.Involvement.minor),
            (.calves, Muscle.Involvement.trace),
        ])
        let item = ExerciseCatalogItem(
            name: "Bench Press",
            group: .legs,
            defaultWeight: 0,
            muscleInvolvement: custom,
            isUserCreated: true
        )

        #expect(item.muscleInvolvement.snapshot == custom.snapshot)
        #expect(item.muscleInvolvement.primary == [.quads])
        #expect(item.muscleInvolvement.weights[.pectorals] == nil)
    }

    @Test @MainActor func legacyCatalogItemRetainsFallbackInvolvement() {
        let item = ExerciseCatalogItem(
            name: "Totally Made Up Lift",
            group: .back,
            defaultWeight: 0,
            isUserCreated: true
        )

        #expect(item.muscleInvolvementSnapshot.isEmpty)
        #expect(item.muscleInvolvement.snapshot == Muscle.defaultInvolvement(for: .back).snapshot)
    }

    @Test @MainActor func catalogDraftUsesAndReplacesGroupPreset() {
        var draft = CatalogDraft.empty
        #expect(draft.muscleInvolvement.snapshot == Muscle.defaultInvolvement(for: .chest).snapshot)

        draft.applyMusclePreset(for: .legs)

        #expect(draft.muscleInvolvement.snapshot == Muscle.defaultInvolvement(for: .legs).snapshot)
        #expect(draft.muscleInvolvement.hasPrime)
    }

    @Test @MainActor func classificationResolvesForKnownLift() {
        let classification = ExerciseClassification.forExerciseNamed("Bench Press")
        #expect(classification?.equipment == .barbell)
        #expect(classification?.mechanic == .compound)
        #expect(classification?.pattern == .push)
        #expect(classification?.direction == .horizontal)
    }

    @Test func everyPushPullRecordHasDirectionAndOtherPatternsDoNot() {
        for record in CatalogData.records {
            if record.patternValue == .push || record.patternValue == .pull {
                #expect(
                    record.directionValue != nil,
                    "'\(record.name)' is \(record.pattern ?? "push/pull") without a direction"
                )
            } else {
                #expect(
                    record.direction == nil,
                    "'\(record.name)' has direction but is not push/pull"
                )
            }
        }
    }

    @Test func correctedPushPullExercisesKeepTheirCuratedDirections() {
        let verticalDips = [
            "Bench Dips On Floor HD",
            "Dips Between Two Benches",
            "Floor dips",
            "Ring Dips",
            "Triceps Dips (Assisted)",
            "TRX dips",
        ]

        for name in verticalDips {
            let record = CatalogData.record(forExerciseNamed: name)
            #expect(record?.mechanicValue == .compound)
            #expect(record?.patternValue == .push)
            #expect(record?.directionValue == .vertical)
        }

        let invertedPulldown = CatalogData.record(forExerciseNamed: "Inverted Lat Pull Down")
        #expect(invertedPulldown?.equipmentValue == .cable)
        #expect(invertedPulldown?.patternValue == .pull)
        #expect(invertedPulldown?.directionValue == .vertical)
        #expect(invertedPulldown?.bodyweightFractionValue == 0)

        let ropeRow = CatalogData.record(forExerciseNamed: "Rope Pullover/row")
        #expect(ropeRow?.patternValue == .pull)
        #expect(ropeRow?.directionValue == .horizontal)
    }

    @Test @MainActor func catalogItemKeepsDirectionConsistentWithPattern() {
        let item = ExerciseCatalogItem(
            name: "Test Press",
            group: .chest,
            defaultWeight: 0,
            pattern: .push,
            direction: .horizontal
        )
        #expect(item.movementLabel == "Horizontal Push")

        item.pattern = .squat
        #expect(item.direction == nil)
        #expect(item.movementLabel == "Squat")
    }

    @Test func everyMuscleExpandsToLeftRightNodes() {
        for muscle in Muscle.allCases {
            let nodes = muscle.nodeNames
            #expect(!nodes.isEmpty, "\(muscle) maps to no mesh nodes")
            #expect(nodes.allSatisfy { $0.hasSuffix("_L") || $0.hasSuffix("_R") })
        }
    }

    @Test func gluteRegionsMapToIndependentMeshes() {
        #expect(Muscle.gluteMax.nodeNames == ["Gluteus_Maximus_L", "Gluteus_Maximus_R"])
        #expect(Muscle.gluteMed.nodeNames == ["Gluteus_Medius_L", "Gluteus_Medius_R"])
        #expect(Set(Muscle.gluteMax.nodeNames).isDisjoint(with: Muscle.gluteMed.nodeNames))
    }

    private static func muscleList(_ muscles: Set<Muscle>) -> String {
        let rawValues = muscles.map(\.rawValue).sorted()
        return rawValues.isEmpty ? "none" : rawValues.joined(separator: ", ")
    }

    private static func rawMuscleList(_ rawValues: Set<String>) -> String {
        let sorted = rawValues.sorted()
        return sorted.isEmpty ? "none" : sorted.joined(separator: ", ")
    }
}
