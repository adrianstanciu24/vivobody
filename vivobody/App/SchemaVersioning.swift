//
//  SchemaVersioning.swift
//  vivobody
//
//  Versioned SwiftData schema + empty migration plan. Every change
//  so far rides automatic lightweight migration (additive defaulted
//  fields; V3 dropped an attribute), so the plan carries no stages —
//  the rail exists so the day a custom migration is needed, only a
//  SchemaVN + MigrationStage are added, no structural rework.
//  Also surfaces the in-memory fallback flag so AppRoot can warn
//  the user instead of silently losing all persistence.
//

import SwiftData

/// Original schema version. All @Model types are declared here so
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

/// Schema version V2. The model list is identical to V1 — every
/// change up to V2 was additive (new optional or defaulted properties
/// that SwiftData migrates automatically via lightweight migration).
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }

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

/// Current schema version (V3). Marks the removal of the warm-up set
/// kind: the stored `kindRaw` attribute was dropped from `WorkoutSet`
/// and `TemplateSet`. Attribute removal is lightweight-compatible —
/// Core Data drops the column during automatic migration, the same
/// rail every additive change has ridden.
enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(3, 0, 0) }

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

/// Migration plan covering V1 → V2 → V3. Every change so far —
/// including the V3 `kindRaw` attribute drop — is handled by
/// SwiftData's automatic lightweight migration, so no explicit
/// `MigrationStage` entries are needed. Add a `.lightweight` /
/// `.custom` MigrationStage here the day one is required.
enum VivobodyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self] }
    static var stages: [MigrationStage] { [] }
}

/// Set to true when the on-disk store couldn't be opened and the
/// app fell back to an in-memory container. Checked by AppRoot to
/// surface a "data couldn't be opened" banner instead of silently
/// running in-memory (where nothing the user does is saved).
@MainActor
final class StorageHealth {
    static let shared = StorageHealth()
    var didFallbackToInMemory = false
    private init() {}
}
