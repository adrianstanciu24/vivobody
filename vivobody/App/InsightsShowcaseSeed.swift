//
//  InsightsShowcaseSeed.swift
//  vivobody
//
//  Focused deterministic history used to verify every Insights instrument.
//  Debug-only fixture data stays isolated from the general UI-test launcher.
//

import Foundation
import SwiftData

#if DEBUG

    enum InsightsShowcaseSeed {
        /// Ten weeks at two workouts per week establish load, rhythm, rep
        /// migration, composition, and several balance beams without pulling
        /// the much larger body-development fixture into Insights verification.
        static func seed(
            in context: ModelContext,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            for week in 0 ..< 10 {
                let reps = switch week {
                case 0 ... 2: 5
                case 3 ... 5: 9
                default: 14
                }
                let recentProgress = Double(9 - week) * 2.5

                seedSession(
                    daysAgo: week * 7 + 2,
                    plans: [
                        ("Barbell Bench Press", 4, reps, 135 + recentProgress),
                        ("Barbell Bent-Over Row", 2, reps, 115 + recentProgress),
                        ("Seated Dumbbell Overhead Press", 3, reps, 70 + recentProgress),
                        ("Wide-Grip Lat Pulldown", 2, reps, 110 + recentProgress),
                    ],
                    calendar: calendar,
                    now: now,
                    context: context
                )

                seedSession(
                    daysAgo: week * 7 + 5,
                    plans: [
                        ("Barbell Back Squat", 4, reps, 185 + recentProgress * 2),
                        ("25% Body-Mass Barbell Good Morning", 3, reps, 75 + recentProgress),
                        ("Barbell Split Squat", 2, reps, 85 + recentProgress),
                        ("Supinated Straight-Bar Cable Curl", 3, reps, 55 + recentProgress),
                        ("Single-Arm Supinated Cable Triceps Pushdown", 2, reps, 45 + recentProgress),
                    ],
                    calendar: calendar,
                    now: now,
                    context: context
                )
            }

            try? context.saveOrRollback()
        }

        private static func seedSession(
            daysAgo: Int,
            plans: [(name: String, sets: Int, reps: Int, weight: Double)],
            calendar: Calendar,
            now: Date,
            context: ModelContext
        ) {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                  let startedAt = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)
            else { return }

            let exercises = plans.enumerated().map { index, plan in
                let exercise = debugCatalogExercise(
                    named: plan.name,
                    plannedSets: plan.sets,
                    plannedReps: plan.reps,
                    plannedWeight: plan.weight,
                    sortOrder: index
                )
                for (setIndex, set) in exercise.orderedSets.enumerated() {
                    set.isCompleted = true
                    set.repsInReserve = 1 + (setIndex % 3)
                    set.rirLogged = true
                }
                return exercise
            }

            let session = WorkoutSession(
                exercises: exercises,
                restDuration: 90,
                startedAt: startedAt
            )
            session.completedAt = startedAt.addingTimeInterval(52 * 60)
            context.insert(session)
        }
    }

#endif
