//
//  WorkoutTemplateEntity.swift
//  vivobody
//
//  A saved workout template as an App Intents entity. The same value backs
//  the Siri and Shortcuts template parameter and the template's Spotlight
//  entry. Its query runs in the app process, which the system can launch in
//  the background, and reads SwiftData through AppIntentRouter's container on
//  the main actor. A Spotlight tap runs OpenWorkoutTemplateIntent, which
//  starts the template.
//

import AppIntents
import CoreSpotlight
import SwiftData

// MARK: - Entity

/// The `id` is the template's UUID string. Existing Shortcuts parameters
/// store it, so it must keep this format.
nonisolated struct WorkoutTemplateEntity: IndexedEntity {
    let id: String
    let name: String
    let summary: String
    let keywords: [String]

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workout Template"
    static let defaultQuery = WorkoutTemplateQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(summary)")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.contentDescription = summary
        attributes.keywords = keywords
        return attributes
    }

    /// The single projection from the model. Queries, single-item indexing,
    /// and the launch reindex on SpotlightIndexStore's actor all use it.
    init(_ template: WorkoutTemplate) {
        let exercises = template.orderedExercises
        let exerciseCount = exercises.count
        let setCount = template.totalPlannedSets
        var keywords = template.muscleGroups.map(\.displayName)
        keywords.append(contentsOf: exercises.map(\.name))
        keywords.append(template.name)
        id = template.id.uuidString
        name = template.name
        summary = "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") · "
            + "\(setCount) set\(setCount == 1 ? "" : "s")"
        self.keywords = keywords
    }
}

// MARK: - Query

/// EnumerableEntityQuery serves the Shortcuts picker and "Find"; the string
/// query serves Siri name matching.
struct WorkoutTemplateQuery: EnumerableEntityQuery, EntityStringQuery {
    @Dependency private var router: AppIntentRouter

    @MainActor
    func entities(for identifiers: [String]) async throws -> [WorkoutTemplateEntity] {
        let ids = identifiers.compactMap(UUID.init(uuidString:))
        let templates = try fetch(
            FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { ids.contains($0.id) })
        )
        let byID = Dictionary(
            templates.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return ids.compactMap { byID[$0].map(WorkoutTemplateEntity.init) }
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkoutTemplateEntity] {
        try allTemplates().map(WorkoutTemplateEntity.init)
    }

    @MainActor
    func allEntities() async throws -> [WorkoutTemplateEntity] {
        try allTemplates().map(WorkoutTemplateEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [WorkoutTemplateEntity] {
        let needle = string.lowercased()
        return try allTemplates()
            .filter { $0.name.lowercased().contains(needle) }
            .map(WorkoutTemplateEntity.init)
    }

    @MainActor
    private func allTemplates() throws -> [WorkoutTemplate] {
        try fetch(FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    @MainActor
    private func fetch(_ descriptor: FetchDescriptor<WorkoutTemplate>) throws -> [WorkoutTemplate] {
        guard let context = router.container?.mainContext else { return [] }
        return try context.fetch(descriptor)
    }
}

// MARK: - Open intent

/// Runs when the user taps the template in Spotlight. It starts the template,
/// as a tap on the former CoreSpotlight item did.
struct OpenWorkoutTemplateIntent: OpenIntent {
    nonisolated static let title: LocalizedStringResource = "Open Workout Template"
    nonisolated static let description = IntentDescription("Start a vivobody workout from a saved template.")
    nonisolated static var supportedModes: IntentModes {
        .foreground(.immediate)
    }

    @Parameter(title: "Template")
    var target: WorkoutTemplateEntity

    @Dependency private var router: AppIntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: target.id) {
            router.perform(.startTemplate(id))
        }
        return .result()
    }
}
