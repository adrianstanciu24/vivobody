//
//  CatalogSyncTests.swift
//  vivobodyTests
//
//  Proves launch reconciliation keeps the persistent bundled catalog aligned
//  with the generated source while preserving user-owned defaults, favorites,
//  measured maxes, custom exercises, and copied template/history snapshots.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct CatalogSyncTests {
    private enum ExpectedSaveError: Error {
        case failed
    }

    private func makeContext() throws -> ModelContext {
        let schema = VivobodyStore.schema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "CatalogSyncTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }

    private func reconcile(
        in context: ModelContext,
        defaults: UserDefaults
    ) throws -> CatalogReconciliationResult {
        try CatalogLaunchReconciler.reconcile(in: context, defaults: defaults)
    }

    @Test func synchronizationAddsCurrentBundleAndPreservesCustomExercise() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        let custom = ExerciseCatalogItem(
            name: "My Custom Movement",
            group: .chest,
            defaultWeight: 45,
            trainingRole: .pull,
            isUserCreated: true
        )
        context.insert(custom)
        try context.save()

        let result = try reconcile(in: context, defaults: testDefaults.defaults)
        #expect(result.removedItemIDs.isEmpty)
        #expect(result.insertedItemCount == CatalogData.records.count)

        let remaining = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(remaining.count == CatalogData.records.count + 1)
        #expect(remaining.contains { $0.id == custom.id })
        #expect(custom.trainingRole == .pull)
        #expect(Set(remaining.compactMap(\.catalogID)).count == CatalogData.records.count)
    }

    @Test func synchronizationRemovesMissingSeedAndRestoresCanonicalFields() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        _ = try reconcile(in: context, defaults: testDefaults.defaults)

        let bundled = try #require(
            try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
                .first { $0.catalogID == "barbell-bench-press" }
        )
        let authored = try #require(
            CatalogData.record(forCatalogID: "barbell-bench-press")
        )
        bundled.name = "Temporary Development Name"
        bundled.group = .legs
        bundled.trainingRole = .other
        bundled.defaultWeight = 222
        bundled.defaultWeightKg = 100
        bundled.defaultDuration = 17
        bundled.oneRepMax = 315
        bundled.isFavorite = true

        let removed = ExerciseCatalogItem(
            catalogID: "removed-test-seed",
            name: "Removed Test Seed",
            group: .legs,
            defaultWeight: 35
        )
        context.insert(removed)
        try context.save()

        let result = try reconcile(in: context, defaults: testDefaults.defaults)
        #expect(result.removedItemIDs == [removed.id])

        #expect(bundled.name == authored.name)
        #expect(bundled.group == authored.group)
        #expect(bundled.familyID == authored.familyID)
        #expect(bundled.trainingRole == authored.trainingRole)
        #expect(bundled.muscleInvolvementSnapshot == authored.muscleInvolvement.snapshot)
        #expect(bundled.defaultWeight == 222)
        #expect(bundled.defaultWeightKg == 100)
        #expect(bundled.defaultDuration == 17)
        #expect(bundled.oneRepMax == 315)
        #expect(bundled.isFavorite)

        let remaining = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(!remaining.contains { $0.id == removed.id })
    }

    @Test func synchronizationIsIdempotent() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        let initial = try reconcile(in: context, defaults: testDefaults.defaults)
        let repeated = try reconcile(in: context, defaults: testDefaults.defaults)
        #expect(initial.removedItemIDs.isEmpty)
        #expect(initial.insertedItemCount == CatalogData.records.count)
        #expect(repeated.removedItemIDs.isEmpty)
        #expect(repeated.insertedItemCount == 0)
        #expect(repeated.reconciledItemCount == CatalogData.records.count)
        let count = try context.fetchCount(FetchDescriptor<ExerciseCatalogItem>())
        #expect(count == CatalogData.records.count)
    }

    @Test func synchronizationRepairsPersistedDipAnatomyAndKeepsUserState() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        _ = try reconcile(in: context, defaults: testDefaults.defaults)

        let dip = try #require(
            try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
                .first { $0.catalogID == "bar-dip" }
        )
        dip.muscleInvolvementSnapshot.removeValue(
            forKey: Muscle.pectoralisMajorSternocostal.rawValue
        )
        dip.defaultWeight = 45
        dip.isFavorite = true
        try context.save()

        _ = try reconcile(in: context, defaults: testDefaults.defaults)

        #expect(
            dip.muscleInvolvementSnapshot[
                Muscle.pectoralisMajorSternocostal.rawValue
            ] == MuscleRole.primary.snapshotValue
        )
        #expect(dip.defaultWeight == 45)
        #expect(dip.isFavorite)
    }

    @Test func explicitBundledDeletionPersistsUntilReset() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        _ = try reconcile(in: context, defaults: testDefaults.defaults)

        let bundled = try #require(
            try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
                .first { $0.catalogID == "barbell-bench-press" }
        )
        try CatalogMutationBoundary(
            context: context,
            defaults: testDefaults.defaults,
            effects: .none
        ).delete(bundled)

        _ = try reconcile(in: context, defaults: testDefaults.defaults)
        let hidden = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(!hidden.contains { $0.catalogID == "barbell-bench-press" })

        CatalogDeletionTombstones.clear(in: testDefaults.defaults)
        _ = try reconcile(in: context, defaults: testDefaults.defaults)
        let restored = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(restored.contains { $0.catalogID == "barbell-bench-press" })
    }

    @Test func explicitDeletionKeepsTemplateAndWorkoutSnapshots() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        _ = try reconcile(in: context, defaults: testDefaults.defaults)

        let bundled = try #require(
            try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
                .first { $0.catalogID == "barbell-bench-press" }
        )
        let catalogItemID = bundled.id
        let templateExercise = TemplateExercise(from: bundled, sortOrder: 0)
        let workoutExercise = Exercise(from: bundled, sortOrder: 0)
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [templateExercise]
        )
        let session = WorkoutSession(exercises: [workoutExercise])
        session.completedAt = Date()
        context.insert(template)
        context.insert(session)
        try context.saveOrRollback()

        try CatalogMutationBoundary(
            context: context,
            defaults: testDefaults.defaults,
            effects: .none
        ).delete(bundled)

        let catalog = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        let savedTemplateExercise = try #require(
            try context.fetch(FetchDescriptor<TemplateExercise>()).first
        )
        let savedWorkoutExercise = try #require(
            try context.fetch(FetchDescriptor<Exercise>()).first
        )
        #expect(!catalog.contains { $0.id == catalogItemID })
        #expect(savedTemplateExercise.name == "Barbell Bench Press")
        #expect(savedTemplateExercise.catalogItemID == catalogItemID)
        #expect(savedTemplateExercise.catalogID == "barbell-bench-press")
        #expect(savedWorkoutExercise.name == "Barbell Bench Press")
        #expect(savedWorkoutExercise.catalogItemID == catalogItemID)
        #expect(savedWorkoutExercise.catalogID == "barbell-bench-press")
    }

    @Test func failedReconciliationRollsBackCanonicalEditsDeletesAndInserts() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        let bundled = ExerciseCatalogItem(
            catalogID: "barbell-bench-press",
            name: "Locally Edited Name",
            group: .legs,
            defaultWeight: 222
        )
        let removed = ExerciseCatalogItem(
            catalogID: "removed-test-seed",
            name: "Removed Test Seed",
            group: .legs,
            defaultWeight: 35
        )
        context.insert(bundled)
        context.insert(removed)
        try context.saveOrRollback()

        do {
            _ = try CatalogLaunchReconciler.reconcile(
                in: context,
                defaults: testDefaults.defaults,
                saveChanges: { _ in throw ExpectedSaveError.failed }
            )
            Issue.record("Expected reconciliation to throw")
        } catch {
            #expect(error is ExpectedSaveError)
        }

        let remaining = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(remaining.count == 2)
        #expect(remaining.contains { item in
            item.id == bundled.id
                && item.name == "Locally Edited Name"
                && item.group == .legs
        })
        #expect(remaining.contains { $0.id == removed.id })
    }
}
