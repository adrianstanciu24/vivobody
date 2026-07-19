//
//  MuscleMappingTests.swift
//  vivobodyTests
//
//  Guards the categorical exercise → muscle taxonomy shared by body
//  visualization and volume analytics: catalog roles decode strictly,
//  visual intensity differs from volume credit, glute regions remain
//  independent, and every visual muscle maps to real model nodes.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct MuscleMappingTests {

    @Test func catalogDecodesFromBundle() {
        #expect(CatalogData.records.count == 599)
        #expect(CatalogData.record(forExerciseNamed: "Bench Press") != nil)
    }

    @Test func involvementRolesProjectToCanonicalVisualAndVolumeValues() {
        for record in CatalogData.records {
            for contribution in record.muscleInvolvement.contributions {
                #expect(contribution.visualIntensity == contribution.role.visualIntensity)
                #expect(contribution.volumeCredit == contribution.role.volumeCredit)
            }
        }

        #expect(MuscleRole.primary.visualIntensity == 1)
        #expect(MuscleRole.primary.volumeCredit == 1)
        #expect(MuscleRole.secondary.visualIntensity == 0.5)
        #expect(MuscleRole.secondary.volumeCredit == 0.5)
        #expect(MuscleRole.stabilizer.visualIntensity == 0.2)
        #expect(MuscleRole.stabilizer.volumeCredit == 0)
    }

    @Test func everyRecordHasAStableIdentityAndMovementDefinition() {
        let ids = CatalogData.records.map(\.catalogID)
        #expect(Set(ids).count == ids.count)

        for record in CatalogData.records {
            #expect(!record.catalogID.isEmpty)
            #expect(!record.movementDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test func everyMuscleIsTargetedByAtLeastOneCatalogExercise() {
        let positiveInvolvement = CatalogData.records.flatMap { record in
            record.involvement
        }
        let targeted = Set(positiveInvolvement.map(\.muscle))
        let expected = Set(Muscle.allCases)
        let missing = expected.subtracting(targeted)

        #expect(
            targeted == expected,
            """
            Catalog muscle coverage does not match Muscle.allCases.
            Missing: \(Self.muscleList(missing))
            """
        )
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

    @Test func benchPressRolesSeparateSynergistsFromStabilizers() {
        let bench = Muscle.involvement(forExerciseNamed: "Bench Press")
        #expect(bench.role(for: .pectorals) == .primary)
        #expect(bench.role(for: .triceps) == .secondary)
        #expect(bench.role(for: .deltoids) == .secondary)
        #expect(bench.role(for: .biceps) == .stabilizer)
        #expect(bench.volumeCredit(for: .biceps) == 0)
        #expect(bench.visualIntensity(for: .biceps) == 0.2)
        #expect(bench.primary == [.pectorals])
        #expect(bench.secondary == [.triceps, .deltoids])
        #expect(bench.stabilizers == [.biceps])
    }

    @Test func anatomyProjectionIncludesStabilizersAtVisualIntensity() {
        let bench = Muscle.involvement(forExerciseNamed: "Bench Press")
        let nodes = bench.anatomyNodeChannels
        #expect(nodes["Pectoralis_Major_L"]?.intensity == 1)
        #expect(nodes["Triceps_L"]?.intensity == 0.5)
        #expect(nodes["Biceps_L"]?.intensity == 0.2)
        #expect(nodes["Biceps_L"]?.baseline == .trained)
    }

    @Test func powerKeepsAnatomyButEarnsNoDevelopmentCredit() throws {
        let power = try #require(CatalogData.record(forExerciseNamed: "Kettlebell sumo high pull"))
        #expect(!power.muscleInvolvement.anatomyNodeChannels.isEmpty)

        let exercise = Exercise(
            name: power.name,
            group: power.group,
            plannedSets: 3,
            plannedReps: 5,
            plannedWeight: 0,
            muscleInvolvement: power.muscleInvolvement,
            modality: .power
        )
        exercise.sets.forEach { $0.isCompleted = true }
        var calculator = SetStimulus.Calculator()
        #expect(calculator.credit(for: exercise, at: Date()).isEmpty)
    }

    @Test func gluteExercisesKeepMaxAndMedSeparate() {
        let hipThrust = Muscle.involvement(forExerciseNamed: "Barbell Hip Thrust")
        #expect(hipThrust.role(for: .gluteMax) == .primary)
        #expect(hipThrust.role(for: .gluteMed) == nil)

        let hipAbduction = Muscle.involvement(forExerciseNamed: "Machine Hip Abduction")
        #expect(hipAbduction.role(for: .gluteMed) == .primary)
        #expect(hipAbduction.role(for: .gluteMax) == nil)
    }

    @Test func obsoleteMuscleSnapshotKeysAreNotDecoded() {
        let involvement = Muscle.Involvement(snapshot: [
            "glutes": MuscleRole.primary.visualIntensity,
            "teres": MuscleRole.primary.visualIntensity,
        ])
        #expect(involvement.isEmpty)
    }

    @Test func snapshotsRoundTripOnlyCanonicalRoles() {
        let source = Muscle.Involvement(contributions: [
            .init(muscle: .pectorals, role: .primary),
            .init(muscle: .triceps, role: .secondary),
            .init(muscle: .biceps, role: .stabilizer),
        ])
        let decoded = Muscle.Involvement(snapshot: source.snapshot)
        #expect(decoded.roles == source.roles)

        let obsoleteTier = Muscle.Involvement(snapshot: ["pectorals": 0.7])
        #expect(obsoleteTier.isEmpty)
    }

    @Test @MainActor func explicitCatalogInvolvementOverridesCuratedName() {
        let custom = Muscle.Involvement(contributions: [
            .init(muscle: .quads, role: .primary),
            .init(muscle: .gluteMax, role: .secondary),
            .init(muscle: .gluteMed, role: .secondary),
            .init(muscle: .calves, role: .stabilizer),
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
        #expect(item.muscleInvolvement.role(for: .pectorals) == nil)
    }

    @Test @MainActor func unknownCustomCatalogItemDoesNotInventGroupAnatomy() {
        let item = ExerciseCatalogItem(
            name: "Totally Made Up Lift",
            group: .back,
            defaultWeight: 0,
            isUserCreated: true
        )

        #expect(item.muscleInvolvementSnapshot.isEmpty)
        #expect(item.muscleInvolvement.isEmpty)
    }

    @Test @MainActor func catalogDraftRequiresExplicitMuscleRoles() {
        var draft = CatalogDraft.empty
        #expect(draft.muscleInvolvement.isEmpty)

        draft.group = .legs
        #expect(draft.muscleInvolvement.isEmpty)

        draft.muscleInvolvementSnapshot = Muscle.Involvement(contributions: [
            .init(muscle: .gluteMed, role: .primary)
        ]).snapshot
        #expect(draft.muscleInvolvement.hasPrimary)
        #expect(draft.muscleInvolvement.role(for: .gluteMed) == .primary)
        #expect(draft.muscleInvolvement.role(for: .gluteMax) == nil)
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
                    "'\(record.name)' is \(record.pattern?.rawValue ?? "push/pull") without a direction"
                )
            } else {
                #expect(
                    record.directionValue == nil,
                    "'\(record.name)' has direction but is not push/pull"
                )
            }
        }
    }

    @Test func correctedPushPullExercisesKeepTheirCuratedDirections() {
        let verticalDips = [
            "Dips Between Two Benches",
            "Floor dips",
            "Ring Dips",
            "TRX dips",
        ]

        for name in verticalDips {
            let record = CatalogData.record(forExerciseNamed: name)
            #expect(record?.mechanicValue == .compound)
            #expect(record?.patternValue == .push)
            #expect(record?.directionValue == .vertical)
        }

        let invertedPulldown = CatalogData.record(forExerciseNamed: "Underhand Lat Pull Down")
        #expect(invertedPulldown?.equipmentValue == .cable)
        #expect(invertedPulldown?.patternValue == .pull)
        #expect(invertedPulldown?.directionValue == .vertical)
        #expect(invertedPulldown?.bodyweightFractionValue == 0)

        #expect(CatalogData.record(forExerciseNamed: "Rope Pullover/row") == nil)
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
            #expect(nodes.isEmpty == !muscle.isVisualized)
            #expect(nodes.allSatisfy { $0.hasSuffix("_L") || $0.hasSuffix("_R") })
        }
    }

    @Test func rotatorCuffRegionsAreAnatomicallySeparated() {
        #expect(Muscle.externalRotators.nodeNames == [
            "Teres_Minor_L", "Teres_Minor_R",
            "Infraspinatus_L", "Infraspinatus_R",
        ])
        #expect(Muscle.teresMajor.nodeNames == ["Teres_Major_L", "Teres_Major_R"])
        #expect(Muscle.subscapularis.nodeNames.isEmpty)
        #expect(!Muscle.subscapularis.isVisualized)
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

}
