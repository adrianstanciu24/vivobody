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

            // Older sessions are lighter, recent ones heavier — plan
            // index 0 is the most recent, so the bonus grows as the
            // index shrinks. (Coupling weight to `i` directly would
            // invert progression and read as detraining.)
            let overloadStep = Double(plans.count - 1 - i) * 2.5

            let exercises: [Exercise] = plan.groups.enumerated().map { idx, group in
                let template = templateExercise(for: group, variant: i)
                let exercise = Exercise(
                    name: template.name,
                    group: group,
                    plannedSets: 3,
                    plannedReps: 8,
                    plannedWeight: template.weight + overloadStep,
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

// Temporary dense seed to reproduce a data-heavy Insights screen
// (over-volume muscle, every region populated, strength history).
private enum InsightsSeeder {
    static func seed(into context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let now = Date()
        let calendar = Calendar.current

        // (name, group, baseWeight). Hitting every region so the
        // balance list is long and the symmetry pairs all populate.
        let days: [(daysAgo: Int, lifts: [(String, MuscleGroup, Double)])] = [
            (0,  [("Bench Press", .chest, 155), ("Incline Dumbbell Press", .chest, 60), ("Cable Fly", .chest, 30), ("Dip", .chest, 0), ("Tricep Pushdown", .arms, 50), ("Single-Arm Half-Kneeling Cable Lateral Raise", .shoulders, 25)]),
            (1,  [("Back Squat", .legs, 225), ("Romanian Deadlift", .legs, 185), ("Leg Press", .legs, 360), ("Standing Calf Raise", .legs, 200), ("Hanging Leg Raise", .core, 0), ("Single-Arm Half-Kneeling Cable Lateral Raise", .shoulders, 27.5)]),
            (2,  [("Pull-Up", .back, 0), ("Barbell Row", .back, 135), ("Lat Pulldown", .back, 120), ("Barbell Curl", .arms, 75), ("Hammer Curl", .arms, 40), ("Single-Arm Half-Kneeling Cable Lateral Raise", .shoulders, 30)]),
            (3,  [("Overhead Press", .shoulders, 105), ("Lateral Raise", .shoulders, 20), ("Face Pull", .shoulders, 40), ("Incline Bench Press", .chest, 135), ("Dumbbell Fly", .chest, 35)]),
            (5,  [("Bench Press", .chest, 150), ("Dumbbell Bench Press", .chest, 65), ("Pec Deck", .chest, 90), ("Skullcrusher", .arms, 60)]),
            (6,  [("Deadlift", .back, 315), ("Front Squat", .legs, 155), ("Leg Curl", .legs, 90), ("Seated Calf Raise", .legs, 110), ("Plank", .core, 0)]),
            (7,  [("Seated Cable Row", .back, 140), ("Chin-Up", .back, 0), ("Preacher Curl", .arms, 65), ("Wrist Curl", .arms, 45)]),
            (9,  [("Bench Press", .chest, 150), ("Overhead Press", .shoulders, 100), ("Lateral Raise", .shoulders, 17.5)]),
            (11, [("Back Squat", .legs, 215), ("Hip Thrust", .legs, 225), ("Walking Lunge", .legs, 40), ("Russian Twist", .core, 25)]),
            (13, [("Barbell Row", .back, 130), ("Lat Pulldown", .back, 115), ("Dumbbell Curl", .arms, 35)]),
            (15, [("Incline Bench Press", .chest, 130), ("Dip", .chest, 0), ("Rope Pushdown", .arms, 45)]),
            (18, [("Deadlift", .back, 305), ("Leg Press", .legs, 340), ("Standing Calf Raise", .legs, 190)]),
            (21, [("Overhead Press", .shoulders, 95), ("Arnold Press", .shoulders, 45), ("Rear Delt Fly", .shoulders, 20)]),
            (25, [("Bench Press", .chest, 145), ("Barbell Row", .back, 125), ("Back Squat", .legs, 205)]),
            (30, [("Pull-Up", .back, 0), ("Barbell Curl", .arms, 70), ("Cable Curl", .arms, 30)]),
            (35, [("Front Squat", .legs, 145), ("Romanian Deadlift", .legs, 175), ("Hanging Leg Raise", .core, 0)]),
            (42, [("Bench Press", .chest, 140), ("Overhead Press", .shoulders, 90)]),
            (50, [("Deadlift", .back, 295), ("Back Squat", .legs, 195)]),
        ]

        for plan in days {
            guard
                let day = calendar.date(byAdding: .day, value: -plan.daysAgo, to: now),
                let started = calendar.date(byAdding: .hour, value: -2, to: day)
            else { continue }

            let exercises: [Exercise] = plan.lifts.enumerated().map { idx, lift in
                let exercise = Exercise(
                    name: lift.0,
                    group: lift.1,
                    plannedSets: 4,
                    plannedReps: 8,
                    plannedWeight: lift.2,
                    sortOrder: idx
                )
                for set in exercise.sets { set.isCompleted = true }
                return exercise
            }

            let session = WorkoutSession(exercises: exercises, restDuration: 90, startedAt: started)
            session.completedAt = started.addingTimeInterval(45 * 60)
            context.insert(session)
        }
        try? context.save()
    }
}
#endif
