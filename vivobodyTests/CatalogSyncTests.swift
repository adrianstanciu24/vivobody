//
//  CatalogSyncTests.swift
//  vivobodyTests
//
//  Proves launch reconciliation keeps the persistent bundled catalog aligned
//  with the generated source while preserving user-owned defaults, favorites,
//  measured maxes, and custom exercises.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct CatalogSyncTests {
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

        #expect(ExerciseCatalogItem.synchronizeBundledCatalog(
            in: context,
            defaults: testDefaults.defaults
        ).isEmpty)

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
        ExerciseCatalogItem.synchronizeBundledCatalog(
            in: context,
            defaults: testDefaults.defaults
        )

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

        #expect(ExerciseCatalogItem.synchronizeBundledCatalog(
            in: context,
            defaults: testDefaults.defaults
        ) == [removed.id])

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
        #expect(ExerciseCatalogItem.synchronizeBundledCatalog(
            in: context,
            defaults: testDefaults.defaults
        ).isEmpty)
        #expect(ExerciseCatalogItem.synchronizeBundledCatalog(
            in: context,
            defaults: testDefaults.defaults
        ).isEmpty)
        let count = try context.fetchCount(FetchDescriptor<ExerciseCatalogItem>())
        #expect(count == CatalogData.records.count)
    }

    @Test func synchronizationRepairsPersistedDipAnatomyAndKeepsUserState() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        ExerciseCatalogItem.synchronizeBundledCatalog(
            in: context,
            defaults: testDefaults.defaults
        )

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

        ExerciseCatalogItem.synchronizeBundledCatalog(
            in: context,
            defaults: testDefaults.defaults
        )

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
        ExerciseCatalogItem.synchronizeBundledCatalog(
            in: context,
            defaults: testDefaults.defaults
        )

        let bundled = try #require(
            try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
                .first { $0.catalogID == "barbell-bench-press" }
        )
        try ExerciseCatalogItem.deleteFromCatalog(
            bundled,
            in: context,
            defaults: testDefaults.defaults
        )

        ExerciseCatalogItem.synchronizeBundledCatalog(
            in: context,
            defaults: testDefaults.defaults
        )
        let hidden = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(!hidden.contains { $0.catalogID == "barbell-bench-press" })

        ExerciseCatalogItem.clearBundledCatalogDeletions(defaults: testDefaults.defaults)
        ExerciseCatalogItem.synchronizeBundledCatalog(
            in: context,
            defaults: testDefaults.defaults
        )
        let restored = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(restored.contains { $0.catalogID == "barbell-bench-press" })
    }
}
