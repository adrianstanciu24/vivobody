//
//  SpotlightIndexStore.swift
//  vivobody
//
//  SwiftData-backed preparation for the launch-time Spotlight backstop.
//  Model graphs stay on this ModelActor; only Sendable entity values cross
//  back to SpotlightIndexer.
//

import Foundation
import SwiftData

nonisolated struct SpotlightReindexPayload {
    let fingerprint: String
    let templates: [WorkoutTemplateEntity]
    let exercises: [ExerciseEntity]
}

@ModelActor
actor SpotlightIndexStore {
    /// Avoid even opening the store when the fingerprint already matches. On
    /// a mismatch, all model traversal and entity projection stay off the
    /// main actor.
    func prepareReindexIfNeeded() throws -> SpotlightReindexPayload? {
        let fingerprint = Self.currentFingerprint
        guard UserDefaults.standard.string(
            forKey: SettingsKey.spotlightReindexFingerprint
        ) != fingerprint else {
            return nil
        }

        var templateDescriptor = FetchDescriptor<WorkoutTemplate>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        templateDescriptor.relationshipKeyPathsForPrefetching = [\.exercises]
        let templates = try modelContext.fetch(templateDescriptor)
        let catalogItems = try modelContext.fetch(FetchDescriptor<ExerciseCatalogItem>())

        return SpotlightReindexPayload(
            fingerprint: fingerprint,
            templates: templates.map(WorkoutTemplateEntity.init),
            exercises: catalogItems.map(ExerciseEntity.init)
        )
    }

    /// The entity version forces one reindex after the move from
    /// CoreSpotlight items to entities, which also deletes the legacy items.
    private static var currentFingerprint: String {
        let marketingVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "0"
        return "\(marketingVersion)|catalog:\(CatalogData.sourceFingerprint)|entities:1"
    }
}
