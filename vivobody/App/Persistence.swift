//
//  Persistence.swift
//  vivobody
//
//  The single current, pre-release SwiftData schema, production container
//  factory, and storage-health state. There is deliberately no VersionedSchema
//  until the first public release establishes SchemaV1. Tests reopen a current
//  store through the real app path; the recovery fallback remains intact.
//

import Foundation
import SwiftData

enum VivobodyStore {
    static var schema: Schema {
        Schema([
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            TemplateSet.self,
            ExerciseCatalogItem.self,
            BodyWeightEntry.self,
        ])
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
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Opens an explicit on-disk store. The pre-release store contract copies
    /// its checked-in baseline to a temporary URL, then reopens that copy
    /// through the production schema without mutating the baseline.
    static func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = schema
        let configuration = ModelConfiguration(
            "vivobody",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
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
