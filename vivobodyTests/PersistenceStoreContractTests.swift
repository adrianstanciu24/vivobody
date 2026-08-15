//
//  PersistenceStoreContractTests.swift
//  vivobodyTests
//
//  Reopens a checked-in pre-release SwiftData baseline through the production
//  container factory and verifies representative user-owned graphs survive.
//  SchemaV1 and permanent migration fixtures begin at the release boundary.
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
        static let movementSteps = [
            "Set the cable near waist height and take the handle in one hand.",
            "Pull the handle toward the ribs, then return it under control.",
        ]
    }

    @Test func preReleaseBaselineReopensAndPreservesUserData() throws {
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
        #expect(custom.movementSteps == Fixture.movementSteps)

        let weights = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        let bodyWeight = try #require(weights.first { $0.id == Fixture.bodyWeightID })
        #expect(bodyWeight.date == Fixture.startedAt)
        #expect(bodyWeight.weight == 182.5)
    }
}
