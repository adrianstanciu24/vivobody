//
//  BiomechanicsDomainTests.swift
//  vivobodyTests
//
//  Verifies the biomechanics domain contract independently from UI:
//  categorical muscle roles, modality gates, effective-load polarity,
//  stable catalog snapshots, and strict catalog validation failures.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct BiomechanicsDomainTests {

    @Test func loadProfilesRespectResistancePolarity() {
        let external = ExerciseLoadProfile(mode: .external, bodyweightFraction: 0)
        #expect(external.effectiveLoad(loggedWeight: 80, bodyweight: 200) == 80)
        #expect(external.effectiveLoad(loggedWeight: 80, bodyweight: 0) == 80)

        let weightedBodyweight = ExerciseLoadProfile(mode: .bodyweightAdded, bodyweightFraction: 0.5)
        #expect(weightedBodyweight.effectiveLoad(loggedWeight: 25, bodyweight: 200) == 125)
        #expect(weightedBodyweight.effectiveLoad(loggedWeight: 25, bodyweight: 0) == nil)

        let assisted = ExerciseLoadProfile(mode: .assistanceSubtracted, bodyweightFraction: 1)
        #expect(assisted.effectiveLoad(loggedWeight: 60, bodyweight: 200) == 140)
        #expect(assisted.effectiveLoad(loggedWeight: 60, bodyweight: 0) == nil)
        #expect(assisted.withinSnapshotLoadMarker(loggedWeight: 40) == -40)
        #expect(assisted.withinSnapshotLoadDelta(
            actualLoggedWeight: 40,
            plannedLoggedWeight: 60
        ) == 20)

        let nonComparable = ExerciseLoadProfile(mode: .nonComparable, bodyweightFraction: 0)
        #expect(nonComparable.effectiveLoad(loggedWeight: 50, bodyweight: 200) == nil)
    }

    @Test func modalitiesGateStrengthAnalytics() {
        #expect(ExerciseModality.dynamicStrength.supportsHardSetAnalytics)
        #expect(ExerciseModality.isometricStrength.supportsHardSetAnalytics)
        #expect(!ExerciseModality.power.supportsHardSetAnalytics)
        #expect(!ExerciseModality.conditioning.supportsHardSetAnalytics)
        #expect(!ExerciseModality.mobility.supportsHardSetAnalytics)

        #expect(ExerciseModality.dynamicStrength.requiresPrimaryMuscle)
        #expect(ExerciseModality.isometricStrength.requiresPrimaryMuscle)
        #expect(ExerciseModality.power.requiresPrimaryMuscle)
        #expect(!ExerciseModality.conditioning.requiresPrimaryMuscle)
        #expect(!ExerciseModality.mobility.requiresPrimaryMuscle)

        #expect(ExerciseModality.dynamicStrength.supportsStrengthPR(for: .reps))
        #expect(!ExerciseModality.dynamicStrength.supportsStrengthPR(for: .duration))
        #expect(ExerciseModality.isometricStrength.supportsStrengthPR(for: .duration))
        #expect(!ExerciseModality.isometricStrength.supportsStrengthPR(for: .reps))
        #expect(!ExerciseModality.power.supportsStrengthPR(for: .reps))

        #expect(ExerciseModality.power.supportsPerformanceRecord(
            for: .reps,
            loadMode: .external
        ))
        #expect(!ExerciseModality.power.supportsPerformanceRecord(
            for: .reps,
            loadMode: .bodyweightAdded
        ))
        #expect(ExerciseModality.power.supportsComparableTonnage(
            for: .reps,
            loadMode: .external
        ))
        #expect(!ExerciseModality.power.supportsEstimatedOneRepMax(
            for: .reps,
            loadMode: .external
        ))
    }

    @Test func sharedStrengthRecordComparatorUsesLoadThenReps() throws {
        let baseline = try #require(StrengthPerformance.makeDynamic(effectiveLoad: 100, reps: 5))
        let moreReps = try #require(StrengthPerformance.makeDynamic(effectiveLoad: 100, reps: 6))
        let lowerLoadHighVolume = try #require(
            StrengthPerformance.makeDynamic(effectiveLoad: 95, reps: 20)
        )

        #expect(moreReps.beats(baseline))
        #expect(!lowerLoadHighVolume.beats(baseline))
        #expect(StrengthPerformance.isometric(duration: 45).beats(.isometric(duration: 30)))
        #expect(baseline.advancement(over: nil) == .load)
        #expect(moreReps.advancement(over: baseline) == .repetitions)
    }

    @Test func comparableIsometricsUseLoadThenDuration() throws {
        let baseline = try #require(StrengthPerformance.makeIsometric(
            effectiveLoad: 50,
            comparesLoad: true,
            duration: 60
        ))
        let heavierShorter = try #require(StrengthPerformance.makeIsometric(
            effectiveLoad: 55,
            comparesLoad: true,
            duration: 30
        ))
        let sameLoadLonger = try #require(StrengthPerformance.makeIsometric(
            effectiveLoad: 50,
            comparesLoad: true,
            duration: 75
        ))
        let durationOnly = try #require(StrengthPerformance.makeIsometric(duration: 90))

        #expect(heavierShorter.beats(baseline))
        #expect(sameLoadLonger.beats(baseline))
        #expect(!durationOnly.beats(baseline))
        #expect(heavierShorter.advancement(over: baseline) == .load)
        #expect(sameLoadLonger.advancement(over: baseline) == .duration)
        #expect(baseline.advancement(over: nil) == .load)
        #expect(durationOnly.advancement(over: nil) == .duration)
        #expect(heavierShorter.primaryMetricKind == .load)
        #expect(durationOnly.primaryMetricKind == .duration)
    }

    @Test func externalPowerHasTonnageAndRecordsButNoHardSets() {
        let power = Exercise(
            name: "Power Clean Fixture",
            group: .legs,
            plannedSets: 1,
            plannedReps: 3,
            plannedWeight: 100,
            modality: .power,
            loadMode: .external
        )
        power.sets.forEach { $0.isCompleted = true }

        #expect(power.bestStrengthPerformance == .dynamic(effectiveLoad: 100, reps: 3))
        #expect(power.completedComparableTonnage == 300)
        #expect(power.completedHardSetCount == 0)

        let jump = Exercise(
            name: "Jump Fixture",
            group: .legs,
            plannedSets: 1,
            plannedReps: 3,
            plannedWeight: 0,
            modality: .power,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )
        jump.sets.forEach { $0.isCompleted = true }
        #expect(jump.bestStrengthPerformance == nil)
        #expect(jump.completedComparableTonnage == nil)
    }

    @Test func setFormattingPreservesLoadMeaning() {
        #expect(SetSpecFormatter.format(
            weight: 0, reps: 8, duration: 0, trackingMode: .reps,
            loadMode: .bodyweightAdded, unit: .lb
        ) == "BW x 8")
        #expect(SetSpecFormatter.format(
            weight: 25, reps: 8, duration: 0, trackingMode: .reps,
            loadMode: .bodyweightAdded, unit: .lb
        ) == "BW + 25 x 8")
        #expect(SetSpecFormatter.format(
            weight: 40, reps: 8, duration: 0, trackingMode: .reps,
            loadMode: .assistanceSubtracted, unit: .lb
        ) == "40 assist x 8")
        #expect(SetSpecFormatter.format(
            weight: 0, reps: 12, duration: 0, trackingMode: .reps,
            loadMode: .nonComparable, unit: .lb
        ) == "12 reps")
    }

    @Test func catalogSemanticsSnapshotThroughTemplateAndWorkout() throws {
        let record = try #require(CatalogData.record(forExerciseNamed: "Bench Press"))
        let item = ExerciseCatalogItem(record: record, createdAt: Date(timeIntervalSince1970: 0))
        let templateExercise = TemplateExercise(from: item, sortOrder: 0)
        let exercise = Exercise(from: templateExercise)

        #expect(item.catalogID == record.catalogID)
        #expect(templateExercise.catalogID == record.catalogID)
        #expect(exercise.catalogID == record.catalogID)
        #expect(exercise.modality == record.modality)
        #expect(exercise.loadMode == record.loadMode)
        #expect(exercise.bodyweightFraction == record.bodyweightFraction)
        #expect(exercise.muscleInvolvement.roles == record.muscleInvolvement.roles)
    }

    @Test func stableCatalogIdentityWinsOverInstallLocalUUID() {
        let first = Exercise(
            name: "Old Display Name",
            catalogItemID: UUID(),
            catalogID: "bench-press",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0
        )
        let second = Exercise(
            name: "Bench Press",
            catalogItemID: UUID(),
            catalogID: "bench-press",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0
        )

        #expect(first.historyKey == second.historyKey)
        #expect(first.historyKey == "bundled:bench-press")
    }

    @Test func customIdentityPartitionsIncompatiblePerformanceKinds() {
        let itemID = UUID()
        let externalLift = Exercise(
            name: "Custom Fixture",
            catalogItemID: itemID,
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0
        )
        let hold = Exercise(
            name: "Custom Fixture",
            catalogItemID: itemID,
            group: .core,
            plannedSets: 0,
            plannedWeight: 0,
            trackingMode: .duration,
            modality: .isometricStrength,
            loadMode: .nonComparable
        )
        let assistedLift = Exercise(
            name: "Custom Fixture",
            catalogItemID: itemID,
            group: .back,
            plannedSets: 0,
            plannedWeight: 0,
            loadMode: .assistanceSubtracted,
            bodyweightFraction: 1
        )
        let halfBodyweightLift = Exercise(
            name: "Custom Fixture",
            catalogItemID: itemID,
            group: .back,
            plannedSets: 0,
            plannedWeight: 0,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 0.5
        )
        let fullBodyweightLift = Exercise(
            name: "Custom Fixture",
            catalogItemID: itemID,
            group: .back,
            plannedSets: 0,
            plannedWeight: 0,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )

        #expect(externalLift.historyKey != hold.historyKey)
        #expect(externalLift.historyKey != assistedLift.historyKey)
        #expect(halfBodyweightLift.historyKey != fullBodyweightLift.historyKey)
        #expect(externalLift.historyKey.contains("dynamicLoadAndReps"))
        #expect(externalLift.historyKey.contains("load=external"))
        #expect(assistedLift.historyKey.contains("load=assistanceSubtracted"))
        #expect(halfBodyweightLift.historyKey.contains("bodyweightBps=5000"))
        #expect(fullBodyweightLift.historyKey.contains("bodyweightBps=10000"))
        #expect(hold.historyKey.contains("isometricDuration"))
    }

    @Test func strictCatalogRejectsIncompleteBiomechanics() {
        expectValidationError(.emptyInvolvement("test"), records: [record(involvement: [])])
        expectValidationError(
            .missingPrimary("test"),
            records: [record(involvement: [.init(muscle: .pectorals, role: .secondary)])]
        )
        expectValidationError(
            .primaryGroupMismatch("test"),
            records: [record(involvement: [.init(muscle: .lats, role: .primary)])]
        )
        expectValidationError(
            .invalidMechanicPattern("test"),
            records: [record(mechanic: .compound, pattern: nil, direction: nil)]
        )
        expectValidationError(
            .invalidLoadFraction("test"),
            records: [record(bodyweightFraction: 0.5, loadMode: .external)]
        )
        expectValidationError(
            .comparableBandLoad("test"),
            records: [record(equipment: .band, loadMode: .external)]
        )
        expectValidationError(
            .invalidModalityTracking("test"),
            records: [record(trackingMode: .duration, defaultDuration: 30, modality: .dynamicStrength)]
        )
        expectValidationError(
            .invalidKilogramDefault("test"),
            records: [record(defaultWeightKg: 11)]
        )
    }

    @Test func strictCatalogRejectsIdentityAndAliasCollisions() {
        let first = record(catalogID: "first", name: "First Exercise", aliases: ["Shared Alias"])
        let duplicateAlias = record(catalogID: "second", name: "Second Exercise", aliases: ["shared alias"])
        expectValidationError(.duplicateAlias("shared alias"), records: [first, duplicateAlias])

        let canonicalConflict = record(
            catalogID: "second",
            name: "Second Exercise",
            aliases: ["First Exercise"]
        )
        expectValidationError(
            .aliasConflictsWithName("First Exercise"),
            records: [record(catalogID: "first", name: "First Exercise"), canonicalConflict]
        )
    }

    private func record(
        catalogID: String = "test",
        name: String = "Test Exercise",
        defaultWeightKg: Double? = 10,
        trackingMode: TrackingMode = .reps,
        defaultDuration: TimeInterval? = nil,
        equipment: Equipment = .barbell,
        mechanic: Mechanic = .compound,
        pattern: MovementPattern? = .push,
        direction: PushPullDirection? = .horizontal,
        aliases: [String] = [],
        bodyweightFraction: Double = 0,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external,
        involvement: [CatalogRecord.MuscleAssignment] = [
            .init(muscle: .pectorals, role: .primary)
        ]
    ) -> CatalogRecord {
        CatalogRecord(
            catalogID: catalogID,
            name: name,
            group: .chest,
            defaultWeight: 20,
            defaultWeightKg: defaultWeightKg,
            reps: 8,
            trackingMode: trackingMode,
            defaultDuration: defaultDuration,
            equipment: equipment,
            mechanic: mechanic,
            pattern: pattern,
            direction: direction,
            plane: .sagittal,
            laterality: .bilateral,
            aliases: aliases,
            bodyweightFraction: bodyweightFraction,
            modality: modality,
            loadMode: loadMode,
            movementDefinition: "A complete test movement definition.",
            involvement: involvement
        )
    }

    private func expectValidationError(
        _ expected: CatalogData.ValidationError,
        records: [CatalogRecord]
    ) {
        do {
            try CatalogData.validate(records)
            Issue.record("Expected catalog validation to fail with \(expected)")
        } catch let error as CatalogData.ValidationError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected validation error: \(error)")
        }
    }
}
