//
//  SchemaVersioning.swift
//  vivobody
//
//  Versioned SwiftData schema + migration plan. Pre-production the
//  plan is deliberately NOT wired into the container (see
//  vivobodyApp.swift): staged migration matches stores by checksum,
//  and because every SchemaVN references the live model classes, any
//  field change desyncs all declared versions and bricks the store.
//  All changes currently ride automatic lightweight migration; the
//  versions and plan are kept so staged migration (with frozen model
//  copies per version) can be adopted when real stores ship.
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

/// Schema version V3. Marks the removal of the warm-up set
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

/// Deliberately empty in normal use. SwiftData excludes index metadata
/// from its schema checksum, so this V4-only entity gives the index
/// migration a real model delta and ensures existing stores are upgraded.
/// Keep it in every schema after V4; no rows need to be inserted.
@Model
private final class SchemaV4IndexMigrationMarker {
    var generation: Int = 4

    init() {}
}

/// Current schema version (V4). Adds targeted WorkoutSession indexes
/// for date ranges, external UUID lookups, and active-draft ordering.
enum SchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(4, 0, 0) }

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
            SchemaV4IndexMigrationMarker.self,
        ]
    }
}

/// Migration plan covering V1 → V2 → V3 → V4. V4 is explicit because
/// its performance indexes alone would not change the schema checksum.
enum VivobodyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
        ]
    }
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
