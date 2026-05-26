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
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .preferredColorScheme(.dark)
                .warmUpKeyboardOnce()
                .task {
                    if CommandLine.arguments.contains("--seed-history") {
                        HistorySeeder.seed(into: container.mainContext)
                    }
                }
        }
        .modelContainer(container)
    }
}

#if DEBUG
private enum HistorySeeder {
    static func seed(into context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let now = Date()
        let calendar = Calendar.current

        // Mix of muscle group combinations and date offsets so the
        // redesigned History screen exercises every layout branch:
        // today (rich), yesterday, this week, last week, older month.
        let plans: [(daysAgo: Int, hoursOffset: Int, groups: [MuscleGroup])] = [
            (0,  -1, [.chest, .back, .shoulders, .legs]),
            (0,  -2, [.chest, .back, .shoulders, .legs]),
            (0,  -3, [.chest, .back, .shoulders, .legs]),
            (1,   0, [.arms, .core]),
            (2,   0, [.chest, .shoulders]),
            (3,   0, [.legs]),
            (5,   0, [.back, .arms]),
            (8,   0, [.chest, .back, .legs]),
            (14,  0, [.shoulders, .arms]),
            (28,  0, [.legs, .core]),
        ]

        for (i, plan) in plans.enumerated() {
            guard
                let day = calendar.date(byAdding: .day, value: -plan.daysAgo, to: now),
                let started = calendar.date(byAdding: .hour, value: plan.hoursOffset, to: day)
            else { continue }

            let exercises: [Exercise] = plan.groups.enumerated().map { idx, group in
                let template = templateExercise(for: group, variant: i)
                let exercise = Exercise(
                    name: template.name,
                    group: group,
                    plannedSets: 3,
                    plannedReps: 8,
                    plannedWeight: template.weight + Double(i) * 2.5,
                    sortOrder: idx
                )
                for set in exercise.sets { set.isCompleted = true }
                return exercise
            }

            let session = WorkoutSession(exercises: exercises, restDuration: 90, startedAt: started)
            session.completedAt = started.addingTimeInterval(40 * 60 + Double.random(in: 0...600))
            context.insert(session)
        }
        try? context.save()
    }

    private static func templateExercise(for group: MuscleGroup, variant: Int) -> (name: String, weight: Double) {
        switch group {
        case .chest:     return ("Bench Press", 135)
        case .back:      return ("Barbell Row", 115)
        case .shoulders: return ("Overhead Press", 95)
        case .legs:      return ("Back Squat", 185)
        case .arms:      return ("Barbell Curl", 65)
        case .core:      return ("Hanging Leg Raise", 0)
        }
    }
}
#endif
