//
//  ExerciseEntity.swift
//  vivobody
//
//  A catalog exercise as an App Intents entity, indexed in Spotlight. Its
//  query runs in the app process and reads SwiftData through
//  AppIntentRouter's container on the main actor. A Spotlight tap runs
//  OpenExerciseIntent, which shows the exercise detail.
//

import AppIntents
import CoreSpotlight
import SwiftData

// MARK: - Entity

nonisolated struct ExerciseEntity: IndexedEntity {
    /// The catalog item's UUID string.
    let id: String
    let name: String
    let summary: String
    let keywords: [String]
    let rankingHint: Int?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Exercise"
    static let defaultQuery = ExerciseQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(summary)")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.contentDescription = summary
        attributes.keywords = keywords
        if let rankingHint {
            attributes.rankingHint = NSNumber(value: rankingHint)
        }
        return attributes
    }

    /// The single projection from the model. Queries, single-item indexing,
    /// and the launch reindex on SpotlightIndexStore's actor all use it.
    init(_ item: ExerciseCatalogItem) {
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
        id = item.id.uuidString
        name = item.name
        summary = [
            item.group.displayName,
            item.equipment.displayName,
            item.mechanic.displayName,
            item.trainingRole?.displayName,
        ].compactMap(\.self).joined(separator: " · ")
        self.keywords = keywords
        rankingHint = item.searchPriority > 0 ? item.searchPriority : nil
    }
}

// MARK: - Query

struct ExerciseQuery: EntityStringQuery {
    @Dependency private var router: AppIntentRouter

    @MainActor
    func entities(for identifiers: [String]) async throws -> [ExerciseEntity] {
        guard let context = router.container?.mainContext else { return [] }
        let ids = identifiers.compactMap(UUID.init(uuidString:))
        let items = try context.fetch(
            FetchDescriptor<ExerciseCatalogItem>(predicate: #Predicate { ids.contains($0.id) })
        )
        let byID = Dictionary(
            items.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return ids.compactMap { byID[$0].map(ExerciseEntity.init) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [ExerciseEntity] {
        guard let context = router.container?.mainContext else { return [] }
        let needle = string.lowercased()
        return try context.fetch(
            FetchDescriptor<ExerciseCatalogItem>(sortBy: [SortDescriptor(\.name)])
        )
        .filter { item in
            item.name.lowercased().contains(needle)
                || item.aliases.contains { $0.lowercased().contains(needle) }
        }
        .map(ExerciseEntity.init)
    }
}

// MARK: - Open intent

/// Runs when the user taps the exercise in Spotlight.
struct OpenExerciseIntent: OpenIntent {
    nonisolated static let title: LocalizedStringResource = "Open Exercise"
    nonisolated static let description = IntentDescription("Show a vivobody exercise's details.")
    nonisolated static var supportedModes: IntentModes {
        .foreground(.immediate)
    }

    @Parameter(title: "Exercise")
    var target: ExerciseEntity

    @Dependency private var router: AppIntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: target.id) {
            router.perform(.showExercise(id))
        }
        return .result()
    }
}
