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
//  @MainActor-isolated non-Sendable types under Swift 6, so the whole
//  indexer is @MainActor — model reads, item construction, and the
//  CoreSpotlight calls all run on the main actor. The async
//  index/delete calls still suspend (yielding the main actor) and the
//  system dispatches the real indexing work off-main internally, so
//  the UI is not blocked. Call sites (UI screens, AppRoot.onAppear)
//  are already on the main actor.
//

import CoreSpotlight
import UniformTypeIdentifiers

@MainActor
enum SpotlightIndexer {
    static let templateDomain = "astanciu.vivobody.templates"
    static let exerciseDomain = "astanciu.vivobody.exercises"

    static func templateIdentifier(_ id: UUID) -> String {
        "template:\(id.uuidString)"
    }

    static func exerciseIdentifier(_ id: UUID) -> String {
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

    /// Wipe both domains and re-index the current store. Called on
    /// app launch so the Spotlight index always matches SwiftData
    /// even if items were added or removed while the app wasn't
    /// running (or before indexing was wired). Idempotent; safe to
    /// call on every appear.
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

    /// Version-throttled reindex: only runs the full delete + reindex
    /// when the app's marketing version has changed since the last
    /// pass. Prevents a wasteful wipe-and-rebuild on every launch.
    static func reindexAllIfNeeded(templates: [WorkoutTemplate], items: [ExerciseCatalogItem]) {
        let defaults = UserDefaults.standard
        let lastVersion = defaults.string(forKey: SettingsKey.spotlightReindexedVersion)
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        guard lastVersion != currentVersion else { return }
        reindexAll(templates: templates, items: items)
        defaults.set(currentVersion, forKey: SettingsKey.spotlightReindexedVersion)
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
            item.mechanic.displayName
        ].joined(separator: " · ")
        var keywords: [String] = [item.name]
        keywords.append(contentsOf: item.aliases)
        keywords.append(item.group.displayName)
        keywords.append(item.equipment.displayName)
        keywords.append(item.mechanic.displayName)
        if let movementLabel = item.movementLabel {
            keywords.append(movementLabel)
        }
        if let direction = item.direction {
            keywords.append(direction.displayName)
        }
        attributes.keywords = keywords
        return CSSearchableItem(
            uniqueIdentifier: exerciseIdentifier(item.id),
            domainIdentifier: exerciseDomain,
            attributeSet: attributes
        )
    }
}
