//
//  MuscleMappingTests.swift
//  vivobodyTests
//
//  Guards the categorical exercise → muscle taxonomy shared by body
//  visualization and volume analytics: catalog roles decode strictly,
//  anatomy intensity differs from volume credit, glute regions remain
//  independent, the one-time InvolvementSnapshotRepair rewrites legacy
//  bundled snapshots without contaminating custom exercises, and every
//  visual muscle maps to real model nodes.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct MuscleMappingTests {

    @Test func catalogDecodesFromBundle() {
        #expect(CatalogData.records.count == 464)
        #expect(CatalogData.record(forExerciseNamed: "Barbell Bench Press") != nil)
    }

    @Test func involvementRolesProjectToCanonicalAnatomyAndVolumeValues() {
        for record in CatalogData.records {
            for contribution in record.muscleInvolvement.contributions {
                #expect(contribution.snapshotValue == contribution.role.snapshotValue)
                #expect(contribution.anatomyIntensity == contribution.role.anatomyIntensity)
                #expect(contribution.volumeCredit == contribution.role.volumeCredit)
            }
        }

        #expect(MuscleRole.primary.snapshotValue == 1)
        #expect(MuscleRole.primary.anatomyIntensity == 1)
        #expect(MuscleRole.primary.volumeCredit == 1)
        #expect(MuscleRole.secondary.snapshotValue == 0.5)
        #expect(MuscleRole.secondary.anatomyIntensity == 0.5)
        #expect(MuscleRole.secondary.volumeCredit == 0.5)
        #expect(MuscleRole.stabilizer.snapshotValue == 0.2)
        #expect(MuscleRole.stabilizer.anatomyIntensity == 0.2)
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
        let lower = Muscle.involvement(forExerciseNamed: "barbell bench press")
        #expect(lower.primary == [.pectorals])
    }

    @Test func unknownExerciseMapsToEmpty() {
        let involvement = Muscle.involvement(forExerciseNamed: "Totally Made Up Lift")
        #expect(involvement.isEmpty)
        #expect(involvement.primary.isEmpty)
        #expect(involvement.secondary.isEmpty)
    }

    @Test func benchPressRolesSeparateSynergistsFromStabilizers() {
        let bench = Muscle.involvement(forExerciseNamed: "Barbell Bench Press")
        #expect(bench.role(for: .pectorals) == .primary)
        #expect(bench.role(for: .triceps) == .secondary)
        #expect(bench.role(for: .deltoids) == .secondary)
        #expect(bench.role(for: .biceps) == .stabilizer)
        #expect(bench.volumeCredit(for: .biceps) == 0)
        #expect(bench.snapshot[Muscle.biceps.rawValue] == 0.2)
        #expect(bench.primary == [.pectorals])
        #expect(bench.secondary == [.triceps, .deltoids])
        #expect(bench.stabilizers == [.biceps])
    }

    @Test func anatomyProjectionShowsStabilizersWithoutVolumeCredit() {
        let bench = Muscle.involvement(forExerciseNamed: "Barbell Bench Press")
        let nodes = bench.anatomyNodeChannels
        #expect(nodes["Pectoralis_Major_Clavicular_L"]?.intensity == 1)
        #expect(nodes["Pectoralis_Major_Sternocostal_L"]?.intensity == 1)
        #expect(nodes["Triceps_L"]?.intensity == 0.5)
        #expect(nodes["Biceps_L"]?.intensity == 0.2)
        #expect(nodes["Biceps_L"]?.baseline == .trained)
        #expect(bench.volumeCredit(for: .biceps) == 0)
    }

    @Test func powerKeepsAnatomyButEarnsNoDevelopmentCredit() throws {
        let power = try #require(CatalogData.record(forExerciseNamed: "Kettlebell Sumo High Pull"))
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
        #expect(SetStimulus.credit(for: exercise).isEmpty)
    }

    @Test func gluteExercisesKeepMaxAndMedSeparate() {
        let hipThrust = Muscle.involvement(forExerciseNamed: "Barbell Hip Thrust")
        #expect(hipThrust.role(for: .gluteMax) == .primary)
        #expect(hipThrust.role(for: .gluteMed) == nil)

        let hipAbduction = Muscle.involvement(forExerciseNamed: "Machine Hip Abduction")
        #expect(hipAbduction.role(for: .gluteMed) == .primary)
        #expect(hipAbduction.role(for: .tensorFasciaeLatae) == .secondary)
        #expect(hipAbduction.role(for: .gluteMax) == nil)
        #expect(hipAbduction.stabilizers.isEmpty)

        let nodes = hipAbduction.anatomyNodeChannels
        #expect(nodes["Gluteus_Medius_L"]?.intensity == 1)
        #expect(nodes["Tensor_Fascia_Latae_L"]?.intensity == 0.5)
        #expect(nodes["Rectus_Abdomini_L"] == nil)
    }

    @Test func obsoleteMuscleSnapshotKeysAreNotDecoded() {
        let involvement = Muscle.Involvement(snapshot: [
            "glutes": MuscleRole.primary.snapshotValue,
            "teres": MuscleRole.primary.snapshotValue,
        ])
        #expect(involvement.isEmpty)
    }

    /// The one-time repair pass rewrites undecodable legacy bundled
    /// snapshots (and the two known Hip Abduction upgrades) from the
    /// catalog, after which the pure snapshot decode is canonical.
    @Test func repairRewritesLegacyBundledSnapshotsFromTheCatalog() throws {
        let legacySnapshot = [
            "glutes": MuscleRole.primary.snapshotValue,
            "abs": MuscleRole.stabilizer.snapshotValue,
            "obliques": MuscleRole.stabilizer.snapshotValue,
            "hipFlexors": MuscleRole.stabilizer.snapshotValue,
        ]
        let repaired = try #require(InvolvementSnapshotRepair.repairedSnapshot(
            from: legacySnapshot,
            catalogID: nil,
            exerciseName: "Machine Hip Abduction"
        ))
        let involvement = Muscle.Involvement(snapshot: repaired)
        #expect(involvement.role(for: .gluteMed) == .primary)
        #expect(involvement.role(for: .tensorFasciaeLatae) == .secondary)
        #expect(involvement.role(for: .gluteMax) == nil)
        #expect(involvement.stabilizers.isEmpty)

        // Once repaired, the snapshot is canonical and never rewritten
        // again.
        #expect(Muscle.Involvement.isCanonicalSnapshot(repaired))
        #expect(InvolvementSnapshotRepair.repairedSnapshot(
            from: repaired,
            catalogID: "machine-hip-abduction",
            exerciseName: "Machine Hip Abduction"
        ) == nil)
    }

    /// The two exact historical Hip Abduction snapshots earn the
    /// known catalog-role upgrade even though they are canonical and
    /// carry a primary.
    @Test func repairUpgradesKnownHistoricalHipAbductionSnapshots() throws {
        let preTFL = [
            "gluteMed": MuscleRole.primary.snapshotValue,
            "abs": MuscleRole.stabilizer.snapshotValue,
            "obliques": MuscleRole.stabilizer.snapshotValue,
            "hipFlexors": MuscleRole.stabilizer.snapshotValue,
        ]
        let repaired = try #require(InvolvementSnapshotRepair.repairedSnapshot(
            from: preTFL,
            catalogID: "machine-hip-abduction",
            exerciseName: "Machine Hip Abduction"
        ))
        let involvement = Muscle.Involvement(snapshot: repaired)
        #expect(involvement.role(for: .gluteMed) == .primary)
        #expect(involvement.role(for: .tensorFasciaeLatae) == .secondary)
        #expect(involvement.stabilizers.isEmpty)

        let preCoreRemoval = preTFL.merging(
            [Muscle.tensorFasciaeLatae.rawValue: MuscleRole.secondary.snapshotValue],
            uniquingKeysWith: { _, new in new }
        )
        let repairedCore = try #require(InvolvementSnapshotRepair.repairedSnapshot(
            from: preCoreRemoval,
            catalogID: nil,
            exerciseName: "Machine Hip Abduction"
        ))
        let coreInvolvement = Muscle.Involvement(snapshot: repairedCore)
        #expect(coreInvolvement.role(for: .gluteMed) == .primary)
        #expect(coreInvolvement.role(for: .tensorFasciaeLatae) == .secondary)
        #expect(coreInvolvement.stabilizers.isEmpty)
    }

    /// A valid pick-time snapshot with a primary is immutable — the
    /// repair must not rewrite honest authored history.
    @Test func repairLeavesCanonicalSnapshotsUntouched() {
        let authored = Muscle.Involvement(contributions: [
            .init(muscle: .quads, role: .primary),
            .init(muscle: .gluteMax, role: .secondary),
        ]).snapshot
        #expect(InvolvementSnapshotRepair.repairedSnapshot(
            from: authored,
            catalogID: "bench-press",
            exerciseName: "Barbell Bench Press"
        ) == nil)
    }

    @Test @MainActor func invalidCustomSnapshotDoesNotBorrowBundledAnatomyByName() {
        let custom = ExerciseCatalogItem(
            name: "Machine Hip Abduction",
            group: .legs,
            defaultWeight: 90,
            isUserCreated: true
        )
        custom.muscleInvolvementSnapshot = [
            "glutes": MuscleRole.primary.snapshotValue,
        ]

        // The pure decode drops the undecodable key…
        #expect(custom.muscleInvolvement.isEmpty)
        // …and the repair drops it from storage without borrowing the
        // bundled record's anatomy by name.
        let repaired = InvolvementSnapshotRepair.repairedSnapshot(
            from: custom.muscleInvolvementSnapshot,
            catalogID: nil,
            exerciseName: custom.name,
            allowsCatalogNameLookup: false
        )
        #expect(repaired?.isEmpty == true)
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
            name: "Barbell Bench Press",
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
        let classification = ExerciseClassification.forExerciseNamed("Barbell Bench Press")
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
            "Bench Dip",
            "Ring Dip",
        ]

        for name in verticalDips {
            let record = CatalogData.record(forExerciseNamed: name)
            #expect(record?.mechanicValue == .compound)
            #expect(record?.patternValue == .push)
            #expect(record?.directionValue == .vertical)
        }

        let invertedPulldown = CatalogData.record(forExerciseNamed: "Underhand Lat Pulldown")
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

    @Test func deltoidRegionMapsToIndependentHeads() {
        #expect(Muscle.deltoids.nodeNames == [
            "Deltoid_Anterior_L", "Deltoid_Anterior_R",
            "Deltoid_Lateral_L", "Deltoid_Lateral_R",
            "Deltoid_Posterior_L", "Deltoid_Posterior_R",
        ])
    }

    @Test func pectoralRegionMapsToIndependentHeads() {
        #expect(Muscle.pectorals.nodeNames == [
            "Pectoralis_Major_Clavicular_L", "Pectoralis_Major_Clavicular_R",
            "Pectoralis_Major_Sternocostal_L", "Pectoralis_Major_Sternocostal_R",
            "Pectoralis_Minor_L", "Pectoralis_Minor_R",
        ])
    }

    @Test func trapeziusRegionMapsToIndependentFiberGroups() {
        #expect(Muscle.traps.nodeNames == [
            "Trapezius_Upper_L", "Trapezius_Upper_R",
            "Trapezius_Middle_L", "Trapezius_Middle_R",
            "Trapezius_Lower_L", "Trapezius_Lower_R",
            "Levator_Scapulaes_L", "Levator_Scapulaes_R",
        ])
    }

    @Test func lateralHipRegionsMapToIndependentMeshes() {
        #expect(Muscle.gluteMax.nodeNames == ["Gluteus_Maximus_L", "Gluteus_Maximus_R"])
        #expect(Muscle.gluteMed.nodeNames == ["Gluteus_Medius_L", "Gluteus_Medius_R"])
        #expect(Muscle.tensorFasciaeLatae.nodeNames == [
            "Tensor_Fascia_Latae_L", "Tensor_Fascia_Latae_R",
        ])
        #expect(!Muscle.hipFlexors.nodeNames.contains("Tensor_Fascia_Latae_L"))
        #expect(Set(Muscle.gluteMax.nodeNames).isDisjoint(with: Muscle.gluteMed.nodeNames))
        #expect(Set(Muscle.gluteMed.nodeNames).isDisjoint(with: Muscle.tensorFasciaeLatae.nodeNames))
    }

    @Test func visibleAccessoryMeshesFollowTheirTrainableRegions() {
        #expect(Muscle.traps.nodeNames.contains("Levator_Scapulaes_L"))
        #expect(Muscle.traps.nodeNames.contains("Levator_Scapulaes_R"))

        #expect(Muscle.calves.nodeNames.contains("Flexor_Hallucis_Longus_L"))
        #expect(Muscle.calves.nodeNames.contains("Flexor_Hallucis_Longus_R"))

        let shinNodes = Set(Muscle.shins.nodeNames)
        #expect(shinNodes.contains("Extensor_Digitorum_Longus_L"))
        #expect(shinNodes.contains("Extensor_Digitorum_Longus_R"))
        #expect(shinNodes.contains("Extensor_Hallucis_Longus_L"))
        #expect(shinNodes.contains("Extensor_Hallucis_Longus_R"))
    }

    private static func muscleList(_ muscles: Set<Muscle>) -> String {
        let rawValues = muscles.map(\.rawValue).sorted()
        return rawValues.isEmpty ? "none" : rawValues.joined(separator: ", ")
    }

}
