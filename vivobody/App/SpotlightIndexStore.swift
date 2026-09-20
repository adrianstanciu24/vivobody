//
//  SpotlightIndexStore.swift
//  vivobody
//
//  SwiftData-backed preparation for the launch-time Spotlight backstop.
//  Model graphs stay on this ModelActor; only immutable searchable values
//  cross back to SpotlightIndexer's system-framework boundary.
//

import Foundation
import SwiftData

nonisolated struct SpotlightIndexItemSnapshot {
    let uniqueIdentifier: String
    let domainIdentifier: String
    let title: String
    let contentDescription: String
    let keywords: [String]
    let rankingHint: Int?
}

nonisolated struct SpotlightReindexPayload {
    let fingerprint: String
    let items: [SpotlightIndexItemSnapshot]
}

@ModelActor
actor SpotlightIndexStore {
    /// Avoid even opening the store when the app/catalog fingerprint already
    /// matches. On a mismatch, all model traversal and string projection stay
    /// off MainActor.
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

        let items = templates.map(Self.snapshot(for:))
            + catalogItems.map(Self.snapshot(for:))
        return SpotlightReindexPayload(
            fingerprint: fingerprint,
            items: items
        )
    }

    private static var currentFingerprint: String {
        let marketingVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "0"
        return "\(marketingVersion)|catalog:\(CatalogData.sourceFingerprint)"
    }

    private static func snapshot(
        for template: WorkoutTemplate
    ) -> SpotlightIndexItemSnapshot {
        let exercises = template.orderedExercises
        let exerciseCount = exercises.count
        let setCount = template.totalPlannedSets
        var keywords = template.muscleGroups.map(\.displayName)
        keywords.append(contentsOf: exercises.map(\.name))
        keywords.append(template.name)
        return SpotlightIndexItemSnapshot(
            uniqueIdentifier: SpotlightIndexer.templateIdentifier(template.id),
            domainIdentifier: SpotlightIndexer.templateDomain,
            title: template.name,
            contentDescription: "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") · "
                + "\(setCount) set\(setCount == 1 ? "" : "s")",
            keywords: keywords,
            rankingHint: nil
        )
    }

    private static func snapshot(
        for item: ExerciseCatalogItem
    ) -> SpotlightIndexItemSnapshot {
        let description = [
            item.group.displayName,
            item.equipment.displayName,
            item.mechanic.displayName,
            item.trainingRole?.displayName,
        ].compactMap(\.self).joined(separator: " · ")
        var keywords = [item.name]
        keywords.append(contentsOf: item.aliases)
        keywords.append(item.group.displayName)
        keywords.append(item.equipment.displayName)
        keywords.append(item.mechanic.displayName)
        if let trainingRole = item.trainingRole {
            keywords.append(trainingRole.displayName)
        }
        if let movementLabel = item.movementLabel {
            keywords.append(movementLabel)
        }
        if let direction = item.direction {
            keywords.append(direction.displayName)
        }
        return SpotlightIndexItemSnapshot(
            uniqueIdentifier: SpotlightIndexer.exerciseIdentifier(item.id),
            domainIdentifier: SpotlightIndexer.exerciseDomain,
            title: item.name,
            contentDescription: description,
            keywords: keywords,
            rankingHint: item.searchPriority > 0 ? item.searchPriority : nil
        )
    }
}
