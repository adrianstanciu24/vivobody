//
//  vivobodyApp.swift
//  vivobody
//
//  Created by Adrian Stanciu on 18.05.2026.
//

import SwiftUI
import SwiftData

@main
struct vivobodyApp: App {
    /// The SwiftData container. Holds every archived workout. The
    /// schema declares all three @Model classes; cascade-delete
    /// relationships keep exercises and sets bound to their session.
    private let container: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            TemplateSet.self,
            ExerciseCatalogItem.self,
            BodyWeightEntry.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A failed on-disk migration must not crash every launch.
            // Fall back to an in-memory store so the app stays usable;
            // the original store is left untouched on disk for recovery.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let memory = try? ModelContainer(for: schema, configurations: [fallback]) {
                return memory
            }
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .warmUpKeyboardOnce()
                #if DEBUG
                .task {
                    if CommandLine.arguments.contains("--seed-history") {
                        HistorySeeder.seed(into: container.mainContext)
                    } else if CommandLine.arguments.contains("--seed-showcase") {
                        HistorySeeder.seedShowcase(into: container.mainContext)
                    } else if CommandLine.arguments.contains("--seed-pr") {
                        HistorySeeder.seedPRProximity(into: container.mainContext)
                    }
                }
                #endif
        }
        .modelContainer(container)
    }
}

