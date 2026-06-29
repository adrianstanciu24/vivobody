//
//  AppShortcuts.swift
//  vivobody
//
//  Siri shortcuts via the App Intents framework. Declares the app's
//  shortcuts so they appear in the Shortcuts app and are invocable by
//  voice, and adds a parameterized "start workout from a specific
//  template" intent so the user can say "Start the Bench Day workout
//  in vivobody."
//
//  Two shortcuts are donated via VivoShortcutsProvider:
//    1. Start Today's Workout  — reuses the existing
//       StartTodaysWorkoutIntent (also used by the Up Next widget).
//    2. Start Workout from Template — the parameterized
//       StartTemplateWorkoutIntent, resolved against the user's saved
//       templates.
//
//  Process boundary: App Intents that resolve a parameter run in a
//  system-hosted App Intents context, NOT the app process, so the
//  entity query cannot open the app's private SwiftData store. It
//  reads a Codable [TemplateEntitySnapshot] that WidgetSnapshotWriter
//  publishes into the App Group on every writeAll. The parameterized
//  intent's perform() then records the chosen template's UUID into
//  the App Group; AppRoot.consumeTemplateStartRequest fetches the
//  @Model from SwiftData on launch and starts it — the same
//  flag-and-consume handoff the widget intents already use.
//
//  This provider lives in the app target only (App/ is not shared
//  with the widget extension), which is required: an
//  AppShortcutsProvider must be registered from the app target.
//

import AppIntents
import Foundation

// MARK: - App Group payload

/// Minimal Codable identity the app publishes into the App Group so
/// the entity query (running in the system process) can enumerate the
/// user's templates without touching SwiftData. Just enough to
/// resolve and display each template.
struct TemplateEntitySnapshot: Codable, Sendable, Hashable {
    let id: String
    let name: String
}

// MARK: - App entity

/// A workout template as seen by Siri / Shortcuts. The `id` is the
/// template's UUID as a string so it round-trips to the consume
/// function, which fetches the real @Model by that UUID.
struct WorkoutTemplateEntity: AppEntity {
    let id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Workout Template"
    }

    static let defaultQuery = WorkoutTemplateQuery()

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Entity query (App Group only, no SwiftData)

/// Resolves template entities for Siri voice input and the Shortcuts
/// app parameter picker. Reads ONLY from the App Group snapshot —
/// never the app's SwiftData container — because the system hosts
/// this query outside the app process. Conforms to both
/// EnumerableEntityQuery (Shortcuts "Find" + options list) and
/// EntityStringQuery (voice name matching).
struct WorkoutTemplateQuery: EnumerableEntityQuery, EntityStringQuery {
    private func loadSnapshots() -> [TemplateEntitySnapshot] {
        guard
            let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
            let data = defaults.data(forKey: WidgetShared.templatesSnapshotKey)
        else { return [] }
        return (try? JSONDecoder().decode([TemplateEntitySnapshot].self, from: data)) ?? []
    }

    private func entity(for snapshot: TemplateEntitySnapshot) -> WorkoutTemplateEntity {
        WorkoutTemplateEntity(id: snapshot.id, name: snapshot.name)
    }

    func entities(for identifiers: [String]) async throws -> [WorkoutTemplateEntity] {
        let byID = Dictionary(uniqueKeysWithValues: loadSnapshots().map { ($0.id, $0) })
        return identifiers.compactMap { byID[$0].map(entity(for:)) }
    }

    func suggestedEntities() async throws -> [WorkoutTemplateEntity] {
        loadSnapshots().map(entity(for:))
    }

    func allEntities() async throws -> [WorkoutTemplateEntity] {
        loadSnapshots().map(entity(for:))
    }

    func entities(matching string: String) async throws -> [WorkoutTemplateEntity] {
        let needle = string.lowercased()
        return loadSnapshots()
            .filter { $0.name.lowercased().contains(needle) }
            .map(entity(for:))
    }
}

// MARK: - Parameterized intent: start a specific template

/// "Start the <template> workout." Resolves the template entity in the
/// system process, then records its UUID into the App Group and opens
/// the app. AppRoot consumes the UUID on launch, fetches the @Model,
/// and starts the workout — so SwiftData is only ever touched from
/// the app process.
struct StartTemplateWorkoutIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Start Workout from Template"
    nonisolated static let description = IntentDescription("Start a vivobody workout from a saved template.")
    nonisolated static var openAppWhenRun: Bool { true }

    @Parameter(title: "Template")
    var template: WorkoutTemplateEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start the \(\.$template) workout")
    }

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: WidgetShared.appGroup)?
            .set(template.id, forKey: WidgetShared.startTemplateWorkoutRequestKey)
        return .result()
    }
}

// MARK: - App shortcuts provider

/// Declares vivobody's shortcuts so they automatically appear in the
/// Shortcuts app and are eligible for Siri voice invocation. No
/// manual registration; the build's "Extract app intents metadata"
/// step discovers this type. Declaring here also makes the intents
/// candidates for Siri Suggestions (proactive suggestions still
/// benefit from in-app donations, which the existing continue-workout
/// NSUserActivity already provides for the active-workout case).
struct VivoShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTodaysWorkoutIntent(),
            phrases: [
                "Start my workout in \(.applicationName)",
                "Begin today's workout in \(.applicationName)"
            ],
            shortTitle: "Start Today's Workout",
            systemImageName: "figure.run"
        )

        AppShortcut(
            intent: StartTemplateWorkoutIntent(),
            phrases: [
                "Start the \(\.$template) workout in \(.applicationName)",
                "Begin \(\.$template) in \(.applicationName)"
            ],
            shortTitle: "Start Workout from Template",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
