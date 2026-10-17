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
//       StartTodaysWorkoutIntent (also used by the Control Center
//       start-workout control).
//    2. Start Workout from Template — the parameterized
//       StartTemplateWorkoutIntent, resolved against the user's saved
//       templates.
//
//  Process boundary: the template parameter resolves through
//  WorkoutTemplateQuery, which runs in the app process (the system can
//  launch it in the background) and reads SwiftData. The intent's
//  perform() sends the chosen template's UUID through AppIntentRouter,
//  which starts it once AppRoot has restored the active workout.
//
//  This provider lives in the app target only (App/ is not shared
//  with the widget extension), which is required: an
//  AppShortcutsProvider must be registered from the app target.
//

import AppIntents
import Foundation
import VivoKit

// MARK: - Parameterized intent: start a specific template

/// "Start the <template> workout." Opens the app and sends the template's
/// UUID through AppIntentRouter, which fetches the @Model and starts the
/// workout.
struct StartTemplateWorkoutIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Start Workout from Template"
    nonisolated static let description = IntentDescription("Start a vivobody workout from a saved template.")
    nonisolated static var supportedModes: IntentModes {
        .foreground(.immediate)
    }

    @Parameter(title: "Template")
    var template: WorkoutTemplateEntity

    @Dependency private var router: AppIntentRouter

    static var parameterSummary: some ParameterSummary {
        Summary("Start the \(\.$template) workout")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: template.id) {
            router.perform(.startTemplate(id))
        }
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
