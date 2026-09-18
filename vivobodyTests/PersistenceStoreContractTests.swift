//
//  PersistenceStoreContractTests.swift
//  vivobodyTests
//
//  Reopens the checked-in SchemaV1 SwiftData baseline through the production
//  migration plan and verifies representative user-owned graphs survive.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

private final class PersistenceFixtureBundleToken {}

@MainActor
struct PersistenceStoreContractTests {
    private enum Fixture {
        static let archivedSessionID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        static let activeSessionID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        static let workoutExerciseID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        static let workoutSetID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        static let templateID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
        static let templateExerciseID = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
        static let templateSetID = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
        static let catalogID = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!
        static let bodyWeightID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!
        static let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        static let completedAt = Date(timeIntervalSince1970: 1_700_003_600)
        static let execution = ExecutionInstructions(
            startingPosition: "Set the cable near waist height and take the handle in one hand.",
            movement: "Pull the handle toward the ribs without rotating the torso.",
            endpoint: "Finish the pull with the handle beside the ribs.",
            returnPhase: "Return the handle under control until the arm is straight.",
            controlledJoints: "Keep the torso still and the knees softly bent.",
            supportAndPosture: "Keep the trunk braced and both feet planted.",
            disqualifyingCompensations: [
                "Twisting the torso turns the row into a rotational pull."
            ],
            sideOrDirection: nil
        )
    }

    @Test func schemaV1BaselineReopensAndPreservesUserData() throws {
        let bundle = Bundle(for: PersistenceFixtureBundleToken.self)
        let fixtureURL = try #require(
            bundle.url(
                forResource: "PersistenceBaseline",
                withExtension: "store",
                subdirectory: "Fixtures"
            )
                ?? bundle.url(
                    forResource: "PersistenceBaseline",
                    withExtension: "store"
                )
        )
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistenceStoreContractTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let storeURL = temporaryDirectory.appendingPathComponent("vivobody.store")
        try FileManager.default.copyItem(at: fixtureURL, to: storeURL)

        let container = try VivobodyStore.makeContainer(at: storeURL)
        let context = ModelContext(container)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        #expect(sessions.count == 2)

        let archived = try #require(sessions.first { $0.id == Fixture.archivedSessionID })
        #expect(archived.startedAt == Fixture.startedAt)
        #expect(archived.completedAt == Fixture.completedAt)
        #expect(archived.restDuration == 75)
        #expect(archived.bodyweightAtStart == 182.5)
        let exercise = try #require(archived.orderedExercises.first)
        #expect(exercise.id == Fixture.workoutExerciseID)
        #expect(exercise.name == "Fixture Bench Press")
        #expect(exercise.catalogID == "barbell-bench-press")
        #expect(exercise.trainingRoleRaw == nil)
        let set = try #require(exercise.orderedSets.first)
        #expect(set.id == Fixture.workoutSetID)
        #expect(set.weight == 225)
        #expect(set.reps == 5)
        #expect(set.isCompleted)
        #expect(set.repsInReserve == 1)
        #expect(set.rirLogged)

        let active = try #require(sessions.first { $0.id == Fixture.activeSessionID })
        #expect(active.completedAt == nil)
        #expect(active.isResting)
        #expect(active.activeExerciseIndex == 0)

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let template = try #require(templates.first { $0.id == Fixture.templateID })
        #expect(template.name == "Fixture Strength Day")
        #expect(template.scheduledWeekdays == [2, 5])
        let templateExercise = try #require(template.orderedExercises.first)
        #expect(templateExercise.id == Fixture.templateExerciseID)
        #expect(templateExercise.catalogID == "barbell-bench-press")
        #expect(templateExercise.trainingRoleRaw == nil)
        #expect(templateExercise.loadPolicy == .fixed)
        #expect(templateExercise.hasStartingLoad)
        let templateSet = try #require(templateExercise.orderedSets.first)
        #expect(templateSet.id == Fixture.templateSetID)
        #expect(templateSet.weight == 205)
        #expect(templateSet.reps == 6)

        let catalog = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        let custom = try #require(catalog.first { $0.id == Fixture.catalogID })
        #expect(custom.name == "Fixture Custom Row")
        #expect(custom.isUserCreated)
        #expect(custom.isFavorite)
        #expect(custom.oneRepMax == 275)
        #expect(custom.trainingRoleRaw == nil)
        #expect(custom.execution == Fixture.execution)

        let weights = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        let bodyWeight = try #require(weights.first { $0.id == Fixture.bodyWeightID })
        #expect(bodyWeight.date == Fixture.startedAt)
        #expect(bodyWeight.weight == 182.5)
    }

    @Test func schemaV2LoadPolicyAndSessionPlanReopen() throws {
        let bundle = Bundle(for: PersistenceFixtureBundleToken.self)
        let fixture = try #require(bundle.url(forResource: "PersistenceTemplateLoadsV2", withExtension: "store", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "PersistenceTemplateLoadsV2", withExtension: "store"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SchemaV2Reopen-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("vivobody.store")
        try FileManager.default.copyItem(at: fixture, to: url)
        let container = try VivobodyStore.makeContainer(at: url)
        let context = ModelContext(container)
        let template = try #require(context.fetch(FetchDescriptor<WorkoutTemplate>()).first { $0.name == "Load Test" })
        let exercise = try #require(template.orderedExercises.first)
        #expect(exercise.loadPolicy == .lastWorkout)
        #expect(exercise.hasStartingLoad)
        #expect(exercise.plannedWeight == 135)
        #expect(exercise.plannedReps == 8)
        let active = try #require(context.fetch(FetchDescriptor<WorkoutSession>()).first { $0.completedAt == nil })
        let activeExercise = try #require(active.orderedExercises.first)
        #expect(activeExercise.orderedSets.map(\.weight) == [155, 150, 150])
        #expect(activeExercise.orderedSets.map(\.plannedWeight) == [155, 150, 150])
        #expect(activeExercise.orderedSets.allSatisfy { $0.reps == 8 && $0.plannedReps == 8 && !$0.isCompleted })
    }
}
