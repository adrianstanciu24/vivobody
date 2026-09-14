//
//  Persistence.swift
//  vivobody
//
//  The versioned SwiftData schema, migration plan, production container
//  factory, and storage-health state. SchemaV1 freezes the first public model
//  graph; every future model change must add a new version and migration stage.
//

import Foundation
import SwiftData

enum VivobodySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            TemplateSet.self,
            ExerciseCatalogItem.self,
            BodyWeightEntry.self,
        ]
    }
}

enum VivobodyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [VivobodySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum VivobodyStore {
    static var schema: Schema {
        Schema(versionedSchema: VivobodySchemaV1.self)
    }

    /// Creates the normal named container used by the app, including its
    /// in-memory recovery configuration. Keep container construction here so
    /// tests cannot accidentally validate a different schema or option set.
    static func makeContainer(
        named name: String,
        isStoredInMemoryOnly: Bool
    ) throws -> ModelContainer {
        let schema = schema
        let configuration = ModelConfiguration(
            name,
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: VivobodyMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Opens an explicit on-disk store. The SchemaV1 contract copies its
    /// checked-in baseline to a temporary URL, then reopens that copy through
    /// the production migration plan without mutating the baseline.
    static func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = schema
        let configuration = ModelConfiguration(
            "vivobody",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: VivobodyMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

/// Set to true when the on-disk store couldn't be opened and the app fell
/// back to an in-memory container. AppRoot surfaces a warning instead of
/// silently allowing work that cannot be persisted.
@MainActor
final class StorageHealth {
    static let shared = StorageHealth()
    var didFallbackToInMemory = false
    private init() {}
}
