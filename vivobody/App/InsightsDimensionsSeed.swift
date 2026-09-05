//
//  InsightsDimensionsSeed.swift
//  vivobody
//
//  DEBUG history for plane gaps, passenger muscles, matched stamina trends,
//  a year-old session, and a held-back run. Independent of showcase totals.
//

import Foundation
import SwiftData

#if DEBUG
    enum InsightsDimensionsSeed {
        static func seed(in context: ModelContext, now: Date = Date()) {
            let existing = (try? context.fetchCount(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            ))) ?? 0
            guard existing == 0 else { return }
            for week in 0 ..< 8 {
                let daysAgo = week == 7 ? 370 : week * 7 + 2
                let date = now.addingTimeInterval(-Double(daysAgo) * 86400)
                let lastBenchReps = week < 4 ? 8 : 6
                let exercises = [
                    exercise("Barbell Bench Press", weight: 135, reps: [10, 9, lastBenchReps], order: 0),
                    exercise("Barbell Bent-Over Row", weight: 110, reps: [12, 11, 10], order: 1),
                    exercise("Barbell Back Squat", weight: 185, reps: [10, 8, 6], order: 2),
                ]
                let session = WorkoutSession(exercises: exercises, restDuration: 90, startedAt: date)
                session.completedAt = date.addingTimeInterval(3600)
                context.insert(session)
            }
            let heldBack = exercise("Barbell Split Squat", weight: 85, reps: [10, 8, 7], order: 0)
            heldBack.orderedSets.last?.repsInReserve = 4
            let session = WorkoutSession(exercises: [heldBack], startedAt: now.addingTimeInterval(-86400))
            session.completedAt = now.addingTimeInterval(-82800)
            context.insert(session)
            try? context.saveOrRollback()
        }

        private static func exercise(_ name: String, weight: Double, reps: [Int], order: Int) -> Exercise {
            let exercise = debugCatalogExercise(
                named: name, plannedSets: reps.count, plannedReps: reps[0],
                plannedWeight: weight, sortOrder: order
            )
            for (index, set) in exercise.orderedSets.enumerated() {
                set.reps = reps[index]
                set.isCompleted = true
                set.repsInReserve = index == 0 ? 2 : 1
                set.rirLogged = true
            }
            return exercise
        }
    }
#endif
