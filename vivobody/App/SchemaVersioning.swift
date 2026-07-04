//
//  SchemaVersioning.swift
//  vivobody
//
//  Versioned SwiftData schema + empty migration plan. The rail
//  exists today so the day a non-additive change is needed, only
//  SchemaV2 + a MigrationStage are added — no structural rework.
//  Also surfaces the in-memory fallback flag so AppRoot can warn
//  the user instead of silently losing all persistence.
//

import SwiftData

/// Current schema version. All @Model types are declared here so
/// the versioned container initializer can wire the migration plan.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

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

/// Empty migration plan — V1 is the only version. Add SchemaV2 and
/// a `.lightweight` / `.custom` MigrationStage here when needed.
enum VivobodyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

/// Set to true when the on-disk store couldn't be opened and the
/// app fell back to an in-memory container. Checked by AppRoot to
/// surface a "data couldn't be opened" banner instead of silently
/// running in-memory (where nothing the user does is saved).
enum StorageHealth {
    nonisolated(unsafe) static var didFallbackToInMemory = false
}
