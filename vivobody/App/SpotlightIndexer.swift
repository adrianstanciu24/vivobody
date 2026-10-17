//
//  SpotlightIndexer.swift
//  vivobody
//
//  Spotlight indexing for WorkoutTemplates and ExerciseCatalogItems as App
//  Intents entities, so saved plans and catalog lifts appear in system-wide
//  Spotlight search. A tap runs the entity's OpenIntent (template -> start
//  workout; exercise -> detail sheet).
//
//  Before entities, the app indexed CoreSpotlight items in two domains. Every
//  full replacement deletes those domains; AppRoot's CSSearchableItemActionType
//  handler still routes a tap on a legacy item that the system has not yet
//  removed.
//
//  Concurrency: entity values are Sendable and are built when a change is
//  requested. Every index operation then runs in request order on one task
//  chain, so a full replacement cannot erase an entity indexed while it ran.
//  The launch payload is prepared on SpotlightIndexStore's actor inside that
//  same operation.
//

import AppIntents
import CoreSpotlight

@MainActor
enum SpotlightIndexer {
    private static let legacyDomains = [
        "astanciu.vivobody.templates",
        "astanciu.vivobody.exercises",
    ]

    private static var lastOperation: Task<Void, Never>?

    // MARK: - Index single

    /// Re-index one template after a create or edit.
    static func index(_ template: WorkoutTemplate) {
        let entity = WorkoutTemplateEntity(template)
        enqueue { try? await CSSearchableIndex.default().indexAppEntities([entity]) }
    }

    /// Re-index one catalog item after a create or edit.
    static func index(_ item: ExerciseCatalogItem) {
        let entity = ExerciseEntity(item)
        enqueue { try? await CSSearchableIndex.default().indexAppEntities([entity]) }
    }

    // MARK: - Reindex all

    /// Replace every indexed entity after an explicit catalog reset. Launch
    /// uses SpotlightIndexStore instead so model traversal stays off the main
    /// actor.
    static func reindexAll(templates: [WorkoutTemplate], items: [ExerciseCatalogItem]) {
        let templateEntities = templates.map(WorkoutTemplateEntity.init)
        let exerciseEntities = items.map(ExerciseEntity.init)
        enqueue {
            do {
                try await replaceAll(templates: templateEntities, exercises: exerciseEntities)
            } catch {
                AppDiagnostics.spotlightReindexFailed(error: error)
            }
        }
    }

    /// Remove deleted catalog items, then replace every entity when
    /// SpotlightIndexStore reports a stale fingerprint. The fingerprint is
    /// stored only after every step succeeds, so a failure retries on the
    /// next launch.
    static func scheduleLaunchMaintenance(
        removing identifiers: [UUID],
        store: SpotlightIndexStore
    ) {
        enqueue {
            if !identifiers.isEmpty {
                try? await CSSearchableIndex.default().deleteAppEntities(
                    identifiedBy: identifiers.map(\.uuidString),
                    ofType: ExerciseEntity.self
                )
            }
            do {
                // A model actor created on the main thread can run its
                // context work there; detaching keeps the fetch off it.
                let payload = try await Task.detached(priority: .utility) {
                    try await store.prepareReindexIfNeeded()
                }.value
                guard let payload else { return }
                try await replaceAll(templates: payload.templates, exercises: payload.exercises)
                UserDefaults.standard.set(
                    payload.fingerprint,
                    forKey: SettingsKey.spotlightReindexFingerprint
                )
            } catch {
                AppDiagnostics.spotlightReindexFailed(error: error)
            }
        }
    }

    private static func replaceAll(
        templates: [WorkoutTemplateEntity],
        exercises: [ExerciseEntity]
    ) async throws {
        let index = CSSearchableIndex.default()
        try await index.deleteSearchableItems(withDomainIdentifiers: legacyDomains)
        try await index.deleteAppEntities(ofType: WorkoutTemplateEntity.self)
        try await index.deleteAppEntities(ofType: ExerciseEntity.self)
        try await index.indexAppEntities(templates)
        try await index.indexAppEntities(exercises)
    }

    // MARK: - Delete

    static func removeTemplate(id: UUID) {
        enqueue {
            try? await CSSearchableIndex.default().deleteAppEntities(
                identifiedBy: [id.uuidString],
                ofType: WorkoutTemplateEntity.self
            )
        }
    }

    static func removeExercise(id: UUID) {
        enqueue {
            try? await CSSearchableIndex.default().deleteAppEntities(
                identifiedBy: [id.uuidString],
                ofType: ExerciseEntity.self
            )
        }
    }

    static func removeAllExercises() {
        enqueue {
            try? await CSSearchableIndex.default().deleteAppEntities(ofType: ExerciseEntity.self)
        }
    }

    // MARK: - Serialization

    private static func enqueue(_ operation: @escaping @MainActor @Sendable () async -> Void) {
        let previous = lastOperation
        lastOperation = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }
}
