//
//  CatalogPruneTests.swift
//  vivobodyTests
//
//  Proves pruneRemovedSeeds deletes exactly the seeded items whose
//  stable catalog ID no longer ships in the bundled catalog: retired
//  seeds disappear while still-bundled seeds and user-created
//  entries survive. Runs against an in-memory container so the
//  on-disk store is never touched.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct CatalogPruneTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV3.models, version: SchemaV3.versionIdentifier)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func pruneRemovesOnlyRetiredSeeds() throws {
        let context = try makeContext()
        ExerciseCatalogItem.seedIfEmpty(in: context)

        let retired = ExerciseCatalogItem(
            catalogID: "kettlebell-rdl-warm-up",
            name: "Kettlebell RDL (warm-up)",
            group: .legs,
            defaultWeight: 35
        )
        let custom = ExerciseCatalogItem(
            name: "My Custom Movement",
            group: .chest,
            defaultWeight: 45,
            isUserCreated: true
        )
        context.insert(retired)
        context.insert(custom)
        try context.save()

        let removed = ExerciseCatalogItem.pruneRemovedSeeds(in: context)
        #expect(removed == [retired.id])

        let remaining = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(remaining.count == CatalogData.records.count + 1)
        #expect(remaining.contains { $0.isUserCreated && $0.name == "My Custom Movement" })
        #expect(!remaining.contains { $0.catalogID == "kettlebell-rdl-warm-up" })
    }

    @Test func pruneIsANoOpWhenStoreMatchesBundle() throws {
        let context = try makeContext()
        ExerciseCatalogItem.seedIfEmpty(in: context)

        #expect(ExerciseCatalogItem.pruneRemovedSeeds(in: context).isEmpty)
        let count = try context.fetchCount(FetchDescriptor<ExerciseCatalogItem>())
        #expect(count == CatalogData.records.count)
    }
}
