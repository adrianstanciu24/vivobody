//
//  DebugForearmDevelopmentSeeder.swift
//  vivobody
//
//  Adds one current-catalog completed workout for forearm map verification.
//  Exercises pass through fresh template snapshots; existing history is retained.
//

import Foundation
import SwiftData

#if DEBUG
    @MainActor
    enum DebugForearmDevelopmentSeeder {
        static func seed(in context: ModelContext, now: Date = Date()) {
            let identifier = UUID(uuidString: "F0620000-0000-4000-8000-000000000001")!
            guard let existing = try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.id == identifier }
            )), existing.isEmpty else { return }

            let names = [
                "Conventional Barbell Deadlift",
                "Pull-Up",
                "Standing Dumbbell Overhead Press"
            ]
            let exercises = names.enumerated().map { order, name in
                let record = debugCatalogRecord(named: name)
                let template = debugCatalogTemplateExercise(
                    named: name, plannedSets: 3, plannedReps: 8,
                    plannedWeight: record.defaultWeight, sortOrder: order
                )
                let exercise = Exercise(from: template)
                for set in exercise.orderedSets {
                    set.isCompleted = true
                    set.repsInReserve = 0
                    set.rirLogged = true
                }
                return exercise
            }
            let session = WorkoutSession(
                id: identifier, exercises: exercises, restDuration: 90,
                bodyweightAtStart: 180, startedAt: now.addingTimeInterval(-3600)
            )
            session.completedAt = now.addingTimeInterval(-1800)
            context.insert(session)
            try? context.saveOrRollback()
        }
    }
#endif
