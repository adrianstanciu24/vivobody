//
//  WorkoutSessionArchiveFailureTests.swift
//  vivobodyTests
//
//  Guards recovery when archiving an active draft cannot be persisted. The
//  retained session must remain eligible for workout interactions and retry.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct WorkoutSessionArchiveFailureTests {
    @Test func failedArchiveRestoresDraftCompletionStamp() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkoutSessionArchiveFailureTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("archive.store")
        let sessionID = UUID()
        let exerciseID = UUID()
        let activeSetID: UUID = try autoreleasepool {
            let configuration = ModelConfiguration(
                "archive",
                schema: VivobodyStore.schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: VivobodyStore.schema,
                configurations: [configuration]
            )
            let context = ModelContext(container)
            let exercise = Exercise(
                id: exerciseID,
                name: "Bench Press",
                group: .chest,
                plannedSets: 2,
                plannedReps: 8,
                plannedWeight: 135
            )
            exercise.orderedSets[0].isCompleted = true
            let session = WorkoutSession(id: sessionID, exercises: [exercise])
            context.insert(session)
            try context.save()
            return try #require(session.activeSet(for: exercise)?.id)
        }

        try autoreleasepool {
            let configuration = ModelConfiguration(
                "archive",
                schema: VivobodyStore.schema,
                url: storeURL,
                allowsSave: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: VivobodyStore.schema,
                configurations: [configuration]
            )
            let context = ModelContext(container)
            let session = try #require(
                try context.fetch(FetchDescriptor<WorkoutSession>())
                    .first { $0.id == sessionID }
            )
            let controller = WorkoutSessionController()
            controller.modelContext = context
            controller.activeSession = session
            controller.isWorkoutExpanded = true

            controller.dismissActiveWorkout()

            #expect(controller.activeSession === session)
            #expect(controller.isWorkoutExpanded)
            #expect(controller.lastSaveError != nil)
            #expect(session.completedAt == nil)
            #expect(!context.hasChanges)

            let result = controller.completeActiveSet(
                ActiveSetCompletionRequest(
                    sessionID: sessionID,
                    exerciseID: exerciseID,
                    expectedActiveSetID: activeSetID,
                    personalRecord: nil
                )
            )
            #expect(result == .saveFailed)
        }
    }
}
