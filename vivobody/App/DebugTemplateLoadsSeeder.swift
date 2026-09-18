//
//  DebugTemplateLoadsSeeder.swift
//  vivobody
//
//  Deterministic template and completed-history evidence for load-policy editing.
//

import Foundation
import SwiftData

#if DEBUG
    @MainActor
    enum DebugTemplateLoadsSeeder {
        static func seed(in context: ModelContext) {
            guard ((try? context.fetchCount(FetchDescriptor<WorkoutTemplate>())) ?? 0) == 0 else { return }
            let lift = debugCatalogTemplateExercise(named: "Barbell Bench Press", plannedSets: 3,
                                                    plannedReps: 8, plannedWeight: 135, sortOrder: 0)
            if CommandLine.arguments.contains("--ui-test-remembered-template-load") {
                lift.loadPolicy = .lastWorkout
            }
            let template = WorkoutTemplate(name: "Load Test", exercises: [lift])
            template.scheduledWeekdays = [Calendar.current.component(.weekday, from: Date())]
            let exercise = debugCatalogExercise(named: "Barbell Bench Press", plannedSets: 0,
                                                plannedReps: 6, plannedWeight: 155, sortOrder: 0)
            exercise.sets = [
                WorkoutSet(weight: 155, reps: 6, isCompleted: true, sortOrder: 0),
                WorkoutSet(weight: 150, reps: 5, isCompleted: true, sortOrder: 1),
                WorkoutSet(weight: 999, reps: 1, isCompleted: false, sortOrder: 2),
            ]
            let date = Date().addingTimeInterval(-86400)
            let session = WorkoutSession(exercises: [exercise], startedAt: date)
            session.completedAt = date
            context.insert(session)
            context.insert(template)
            try? context.saveOrRollback()
        }
    }
#endif
