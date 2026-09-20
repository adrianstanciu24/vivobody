//
//  SpotlightIndexer.swift
//  vivobody
//
//  CoreSpotlight indexing for WorkoutTemplates and
//  ExerciseCatalogItems so the user's saved plans and catalog lifts
//  appear in system-wide Spotlight search. Typing "bench" or "push
//  day" on the home screen surfaces the matching template or
//  exercise; tapping a result relaunches the app and routes via the
//  CSSearchableItemActionType continuation handler in AppRoot
//  (template -> start workout; exercise -> detail sheet).
//
//  Identifiers are prefixed ("template:<uuid>" / "exercise:<uuid>")
//  so a single continuation handler can route both kinds, and each
//  kind gets its own domainIdentifier so a launch-time reindex can
//  wipe one family via deleteSearchableItems(withDomainIdentifiers:)
//  without touching the other.
//
//  Concurrency: CSSearchableItem and CSSearchableItemAttributeSet are
//  @MainActor-isolated non-Sendable types under Swift 6, so system object
//  construction stays here. Launch-time SwiftData reads and searchable-value
//  projection run separately in SpotlightIndexStore.
//

import CoreSpotlight
import UniformTypeIdentifiers

@MainActor
enum SpotlightIndexer {
    nonisolated static let templateDomain = "astanciu.vivobody.templates"
    nonisolated static let exerciseDomain = "astanciu.vivobody.exercises"
    nonisolated static func templateIdentifier(_ id: UUID) -> String {
        "template:\(id.uuidString)"
    }

    nonisolated static func exerciseIdentifier(_ id: UUID) -> String {
        "exercise:\(id.uuidString)"
    }

    // MARK: - Index single

    /// Re-index one template after a create/edit. Constructs the
    /// searchable item on the main actor, then awaits the index call
    /// (which suspends while the system does the actual work).
    static func index(_ template: WorkoutTemplate) {
        let item = searchableItem(for: template)
        Task { try? await CSSearchableIndex.default().indexSearchableItems([item]) }
    }

    /// Re-index one catalog item after a create/edit.
    static func index(_ item: ExerciseCatalogItem) {
        let searchable = searchableItem(for: item)
        Task { try? await CSSearchableIndex.default().indexSearchableItems([searchable]) }
    }

    // MARK: - Reindex all (launch backstop)

    /// Wipe both domains and re-index the supplied models after an explicit
    /// catalog/template mutation. Launch uses SpotlightIndexStore instead so
    /// model traversal does not occupy MainActor.
    static func reindexAll(templates: [WorkoutTemplate], items: [ExerciseCatalogItem]) {
        let all = templates.map { searchableItem(for: $0) }
            + items.map { searchableItem(for: $0) }
        Task {
            let index = CSSearchableIndex.default()
            try? await index.deleteSearchableItems(
                withDomainIdentifiers: [templateDomain, exerciseDomain]
            )
            try? await index.indexSearchableItems(all)
        }
    }

    /// Apply launch maintenance prepared by SpotlightIndexStore. Item creation
    /// yields in bounded batches so a catalog update cannot monopolize the main
    /// actor, while CoreSpotlight's async calls perform their work out of process.
    static func applyLaunchMaintenance(
        removing identifiers: [UUID],
        reindex payload: SpotlightReindexPayload?
    ) async {
        let index = CSSearchableIndex.default()
        if !identifiers.isEmpty {
            try? await index.deleteSearchableItems(
                withIdentifiers: identifiers.map(exerciseIdentifier)
            )
        }

        guard let payload else { return }
        var searchableItems: [CSSearchableItem] = []
        searchableItems.reserveCapacity(payload.items.count)
        for (index, snapshot) in payload.items.enumerated() {
            let attributes = CSSearchableItemAttributeSet(contentType: UTType.item)
            attributes.title = snapshot.title
            attributes.contentDescription = snapshot.contentDescription
            attributes.keywords = snapshot.keywords
            if let rankingHint = snapshot.rankingHint {
                attributes.rankingHint = NSNumber(value: rankingHint)
            }
            searchableItems.append(
                CSSearchableItem(
                    uniqueIdentifier: snapshot.uniqueIdentifier,
                    domainIdentifier: snapshot.domainIdentifier,
                    attributeSet: attributes
                )
            )
            if index > 0, index.isMultiple(of: 48) {
                await Task.yield()
            }
        }

        do {
            try await index.deleteSearchableItems(
                withDomainIdentifiers: [templateDomain, exerciseDomain]
            )
            try await index.indexSearchableItems(searchableItems)
            UserDefaults.standard.set(
                payload.fingerprint,
                forKey: SettingsKey.spotlightReindexFingerprint
            )
        } catch {
            AppDiagnostics.spotlightReindexFailed(error: error)
        }
    }

    // MARK: - Delete

    static func removeTemplate(id: UUID) {
        Task {
            try? await CSSearchableIndex.default()
                .deleteSearchableItems(withIdentifiers: [templateIdentifier(id)])
        }
    }

    static func removeExercise(id: UUID) {
        Task {
            try? await CSSearchableIndex.default()
                .deleteSearchableItems(withIdentifiers: [exerciseIdentifier(id)])
        }
    }

    static func removeAllExercises() {
        Task {
            try? await CSSearchableIndex.default()
                .deleteSearchableItems(withDomainIdentifiers: [exerciseDomain])
        }
    }

    // MARK: - Searchable-item construction (main-actor model reads)

    private static func searchableItem(for template: WorkoutTemplate) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.item)
        attributes.title = template.name
        let exerciseCount = template.orderedExercises.count
        let setCount = template.totalPlannedSets
        attributes.contentDescription =
            "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") · "
                + "\(setCount) set\(setCount == 1 ? "" : "s")"
        var keywords = template.muscleGroups.map(\.displayName)
        keywords.append(contentsOf: template.orderedExercises.map(\.name))
        keywords.append(template.name)
        attributes.keywords = keywords
        return CSSearchableItem(
            uniqueIdentifier: templateIdentifier(template.id),
            domainIdentifier: templateDomain,
            attributeSet: attributes
        )
    }

    private static func searchableItem(for item: ExerciseCatalogItem) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.item)
        attributes.title = item.name
        attributes.contentDescription = [
            item.group.displayName,
            item.equipment.displayName,
            item.mechanic.displayName,
            item.trainingRole?.displayName,
        ].compactMap(\.self).joined(separator: " · ")
        var keywords: [String] = [item.name]
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
        attributes.keywords = keywords
        if item.searchPriority > 0 {
            attributes.rankingHint = NSNumber(value: item.searchPriority)
        }
        return CSSearchableItem(
            uniqueIdentifier: exerciseIdentifier(item.id),
            domainIdentifier: exerciseDomain,
            attributeSet: attributes
        )
    }
}
