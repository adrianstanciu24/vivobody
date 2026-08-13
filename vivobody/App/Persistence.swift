//
//  Persistence.swift
//  vivobody
//
//  The single current SwiftData schema and storage-health state for the
//  pre-production app. There are no migration stages yet: development data is
//  reset when the model changes. The in-memory fallback remains so a store
//  failure produces an explicit warning instead of a launch crash.
//

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
