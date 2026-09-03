//
//  DebugTemplateSeeder.swift
//  vivobody
//
//  Idempotent scheduled and manual template-library fixtures. Scheduling is
//  derived from one injected reference date so every row agrees on "today".
//

import Foundation
import SwiftData

#if DEBUG

    @MainActor
    enum DebugTemplateSeeder {
        static func handle(
            _ step: DebugLaunchStep,
            in context: ModelContext
        ) -> Bool {
            guard step == .scheduledTemplate else { return false }
            seedScheduled(in: context)
            return true
        }

        static func seedLibrary(
            in context: ModelContext,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            guard templates(in: context).isEmpty else { return }

            let today = calendar.component(.weekday, from: now)
            let plusDays: (Int) -> Int = { ((today - 1 + $0) % 7) + 1 }

            let lower = WorkoutTemplate(name: "Lower Day B", sortOrder: 0)
            lower.scheduledWeekdays = [today, plusDays(3)].sorted()
            lower.exercises = [
                debugCatalogTemplateExercise(
                    named: "Barbell Back Squat",
                    plannedSets: 4,
                    plannedReps: 5,
                    plannedWeight: 185,
                    sortOrder: 0
                ),
                debugCatalogTemplateExercise(
                    named: "Barbell Hip Thrust",
                    plannedSets: 3,
                    plannedReps: 8,
                    plannedWeight: 135,
                    sortOrder: 1
                ),
                debugCatalogTemplateExercise(
                    named: "Barbell Front Squat",
                    plannedSets: 3,
                    plannedReps: 10,
                    plannedWeight: 135,
                    sortOrder: 2
                ),
            ]
            context.insert(lower)

            let upper = WorkoutTemplate(name: "Upper Day A", sortOrder: 1)
            upper.scheduledWeekdays = [plusDays(2), plusDays(5)].sorted()
            let upperBench = debugCatalogTemplateExercise(
                named: "Barbell Bench Press",
                plannedSets: 4,
                plannedReps: 6,
                plannedWeight: 155,
                sortOrder: 0
            )
            let upperRow = debugCatalogTemplateExercise(
                named: "Barbell Bent-Over Row",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 115,
                sortOrder: 1
            )
            let upperPair = UUID()
            upperBench.supersetID = upperPair
            upperRow.supersetID = upperPair
            upper.exercises = [
                upperBench,
                upperRow,
                debugCatalogTemplateExercise(
                    named: "Seated Dumbbell Overhead Press",
                    plannedSets: 3,
                    plannedReps: 8,
                    plannedWeight: 85,
                    sortOrder: 2
                ),
                debugCatalogTemplateExercise(
                    named: "Supinated Straight-Bar Cable Curl",
                    plannedSets: 3,
                    plannedReps: 10,
                    plannedWeight: 60,
                    sortOrder: 3
                ),
            ]
            context.insert(upper)

            let core = WorkoutTemplate(name: "Core A", sortOrder: 2)
            core.exercises = [
                debugCatalogTemplateExercise(
                    named: "30-Degree Curl-Up",
                    plannedSets: 3,
                    plannedReps: 12,
                    plannedWeight: 0,
                    sortOrder: 0
                ),
            ]
            context.insert(core)
            try? context.saveOrRollback()
        }

        private static func seedScheduled(
            in context: ModelContext,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            guard templates(in: context).isEmpty else { return }

            let template = WorkoutTemplate(
                name: "Scheduled Test",
                exercises: [
                    debugCatalogTemplateExercise(
                        named: "Barbell Bench Press",
                        plannedSets: 2,
                        plannedReps: 8,
                        plannedWeight: 135,
                        sortOrder: 0
                    ),
                ]
            )
            template.scheduledWeekdays = [calendar.component(.weekday, from: now)]
            context.insert(template)
            try? context.saveOrRollback()
        }

        private static func templates(in context: ModelContext) -> [WorkoutTemplate] {
            (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        }
    }

#endif
