//
//  DebugArchivedHistorySeeder.swift
//  vivobody
//
//  Idempotent archived-workout fixtures with deterministic relative dates and
//  fixed durations for History, Today, Exercise Detail, and body-map evidence.
//

import Foundation
import SwiftData
import VivoKit

#if DEBUG

    @MainActor
    enum DebugArchivedHistorySeeder {
        static func handle(
            _ step: DebugLaunchStep,
            in context: ModelContext
        ) -> Bool {
            switch step {
            case .supersetHistory:
                seedSuperset(in: context)
            case .singleExerciseHistory:
                seedSingleExercise(in: context)
            case .weeklyVolume:
                DebugWeeklyVolumeSeeder.seed(in: context)
            default:
                return false
            }
            return true
        }

        static func seedGeneral(
            in context: ModelContext,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            guard !hasArchivedSessions(in: context) else { return }

            // Today stays relative so all three workouts are already complete.
            // Older dates anchor at 18:00, keeping their completion on the
            // requested calendar day even when verification launches at 23:59.
            let plans: [(daysAgo: Int, todayHoursAgo: Int, groups: [MuscleGroup])] = [
                (0, 1, [.chest, .back, .shoulders, .legs]),
                (0, 2, [.chest, .back, .shoulders, .legs]),
                (0, 3, [.chest, .back, .shoulders, .legs]),
                (1, 0, [.arms, .core]),
                (2, 0, [.chest, .shoulders]),
                (3, 0, [.legs]),
                (5, 0, [.back, .arms]),
                (8, 0, [.chest, .back, .legs]),
                (14, 0, [.shoulders, .arms]),
                (28, 0, [.legs, .core]),
            ]

            for (index, plan) in plans.enumerated() {
                guard let startedAt = generalStartDate(
                    daysAgo: plan.daysAgo,
                    todayHoursAgo: plan.todayHoursAgo,
                    now: now,
                    calendar: calendar
                ) else { continue }

                let overloadStep = Double(plans.count - 1 - index) * 2.5
                let exercises = plan.groups.enumerated().map { exerciseIndex, group in
                    let template = templateExercise(for: group)
                    let exercise = debugCatalogExercise(
                        named: template.name,
                        plannedSets: 3,
                        plannedReps: 8,
                        plannedWeight: template.weight + overloadStep,
                        sortOrder: exerciseIndex
                    )
                    exercise.sets.forEach { $0.isCompleted = true }
                    return exercise
                }

                let session = WorkoutSession(
                    exercises: exercises,
                    restDuration: 90,
                    startedAt: startedAt
                )
                session.completedAt = startedAt.addingTimeInterval(45 * 60)
                context.insert(session)
            }
            try? context.saveOrRollback()
        }

        /// Lopsided training blocks light every body-development render channel.
        static func seedShowcase(
            in context: ModelContext,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            guard !hasArchivedSessions(in: context) else { return }

            seedBlock(
                [("Barbell Back Squat", 185)],
                startDaysAgo: 120,
                endDaysAgo: 1,
                count: 55,
                overload: 555,
                sets: 6,
                reps: 6,
                now: now,
                calendar: calendar,
                context: context
            )
            seedBlock(
                [("Pressure-Biofeedback Side-Lying Hip Abduction", 90)],
                startDaysAgo: 30,
                endDaysAgo: 2,
                count: 6,
                overload: 20,
                sets: 3,
                reps: 15,
                now: now,
                calendar: calendar,
                context: context
            )
            seedBlock(
                [
                    ("Barbell Bench Press", 135),
                    ("Incline Barbell Bench Press", 95),
                    ("Seated Dumbbell Overhead Press", 75),
                ],
                startDaysAgo: 56,
                endDaysAgo: 6,
                count: 11,
                overload: 55,
                sets: 4,
                reps: 8,
                now: now,
                calendar: calendar,
                context: context
            )
            seedBlock(
                [("Standing Unilateral Machine Calf Raise", 70)],
                startDaysAgo: 30,
                endDaysAgo: 9,
                count: 4,
                overload: 15,
                sets: 3,
                reps: 10,
                now: now,
                calendar: calendar,
                context: context
            )
            seedBlock(
                [
                    ("Supinated Straight-Bar Cable Curl", 65),
                    ("Single-Arm Supinated Cable Triceps Pushdown", 55),
                ],
                startDaysAgo: 60,
                endDaysAgo: 6,
                count: 14,
                overload: 0,
                sets: 3,
                reps: 10,
                now: now,
                calendar: calendar,
                context: context
            )
            seedBlock(
                [("Barbell Bent-Over Row", 135)],
                startDaysAgo: 70,
                endDaysAgo: 28,
                count: 6,
                overload: 30,
                sets: 4,
                reps: 8,
                now: now,
                calendar: calendar,
                context: context
            )
            try? context.saveOrRollback()
        }

        /// Old Bench record plus a climbing-back block and today's template.
        static func seedPRProximity(
            in context: ModelContext,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            guard !hasArchivedSessions(in: context) else { return }

            let weights: [Double] = [185, 150, 155, 160, 165, 170, 175, 180]
            let daysAgo = [50, 44, 38, 32, 26, 20, 14, 8]
            for (weight, dayOffset) in zip(weights, daysAgo) {
                guard let startedAt = anchoredStartDate(
                    daysAgo: dayOffset,
                    now: now,
                    calendar: calendar
                ) else { continue }
                let exercise = debugCatalogExercise(
                    named: "Barbell Bench Press",
                    plannedSets: 1,
                    plannedReps: 5,
                    plannedWeight: weight,
                    sortOrder: 0
                )
                exercise.sets.forEach { $0.isCompleted = true }
                let session = WorkoutSession(
                    exercises: [exercise],
                    restDuration: 90,
                    startedAt: startedAt
                )
                session.completedAt = startedAt.addingTimeInterval(30 * 60)
                context.insert(session)
            }

            let template = WorkoutTemplate(name: "Bench Day", sortOrder: 0)
            template.scheduledWeekdays = [calendar.component(.weekday, from: now)]
            context.insert(template)
            template.exercises.append(debugCatalogTemplateExercise(
                named: "Barbell Bench Press",
                plannedSets: 5,
                plannedReps: 5,
                plannedWeight: 180,
                sortOrder: 0
            ))
            try? context.saveOrRollback()
        }

        /// Linked pair plus one straight exercise for the History ledger.
        private static func seedSuperset(
            in context: ModelContext,
            now: Date = Date()
        ) {
            guard !hasArchivedSessions(in: context) else { return }

            let bench = debugCatalogExercise(
                named: "Barbell Bench Press",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 135,
                sortOrder: 0
            )
            let row = debugCatalogExercise(
                named: "Barbell Bent-Over Row",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 115,
                sortOrder: 1
            )
            let pairID = UUID()
            bench.supersetID = pairID
            row.supersetID = pairID
            let curl = debugCatalogExercise(
                named: "Supinated Straight-Bar Cable Curl",
                plannedSets: 3,
                plannedReps: 10,
                plannedWeight: 65,
                sortOrder: 2
            )
            for exercise in [bench, row, curl] {
                exercise.sets.forEach { $0.isCompleted = true }
            }

            let completedAt = now.addingTimeInterval(-15 * 60)
            let session = WorkoutSession(
                exercises: [bench, row, curl],
                restDuration: 90,
                startedAt: completedAt.addingTimeInterval(-35 * 60)
            )
            session.completedAt = completedAt
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// One archived point for Exercise Detail's intentional pre-trend state.
        private static func seedSingleExercise(
            in context: ModelContext,
            now: Date = Date()
        ) {
            guard !hasArchivedSessions(in: context) else { return }

            let exercise = debugCatalogExercise(
                named: "Flat Dumbbell Fly",
                plannedSets: 1,
                plannedReps: 12,
                plannedWeight: 65 * WeightUnit.lbPerKg,
                sortOrder: 0
            )
            exercise.sets.first?.isCompleted = true
            let completedAt = now.addingTimeInterval(-15 * 60)
            let session = WorkoutSession(
                exercises: [exercise],
                restDuration: 90,
                startedAt: completedAt.addingTimeInterval(-35 * 60)
            )
            session.completedAt = completedAt
            context.insert(session)
            try? context.saveOrRollback()
        }

        private static func seedBlock(
            _ lifts: [(name: String, weight: Double)],
            startDaysAgo: Int,
            endDaysAgo: Int,
            count: Int,
            overload: Double,
            sets: Int,
            reps: Int,
            now: Date,
            calendar: Calendar,
            context: ModelContext
        ) {
            guard count > 0 else { return }
            for index in 0 ..< count {
                let fraction = count == 1 ? 1 : Double(index) / Double(count - 1)
                let daysAgo = Int((
                    Double(startDaysAgo) - fraction * Double(startDaysAgo - endDaysAgo)
                ).rounded())
                guard let startedAt = anchoredStartDate(
                    daysAgo: daysAgo,
                    now: now,
                    calendar: calendar
                ) else { continue }
                let exercises = lifts.enumerated().map { exerciseIndex, lift in
                    let exercise = debugCatalogExercise(
                        named: lift.name,
                        plannedSets: sets,
                        plannedReps: reps,
                        plannedWeight: lift.weight + fraction * overload,
                        sortOrder: exerciseIndex
                    )
                    exercise.sets.forEach { $0.isCompleted = true }
                    return exercise
                }
                let session = WorkoutSession(
                    exercises: exercises,
                    restDuration: 90,
                    startedAt: startedAt
                )
                session.completedAt = startedAt.addingTimeInterval(45 * 60)
                context.insert(session)
            }
        }

        private static func generalStartDate(
            daysAgo: Int,
            todayHoursAgo: Int,
            now: Date,
            calendar: Calendar
        ) -> Date? {
            if daysAgo == 0 {
                return calendar.date(byAdding: .hour, value: -todayHoursAgo, to: now)
            }
            return anchoredStartDate(daysAgo: daysAgo, now: now, calendar: calendar)
        }

        private static func anchoredStartDate(
            daysAgo: Int,
            now: Date,
            calendar: Calendar
        ) -> Date? {
            let today = calendar.startOfDay(for: now)
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)
            else { return nil }
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)
        }

        private static func hasArchivedSessions(in context: ModelContext) -> Bool {
            let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            ))) ?? []
            return !sessions.isEmpty
        }

        private static func templateExercise(
            for group: MuscleGroup
        ) -> (name: String, weight: Double) {
            switch group {
            case .chest: ("Barbell Bench Press", 135)
            case .back: ("Barbell Bent-Over Row", 115)
            case .shoulders: ("Seated Dumbbell Overhead Press", 95)
            case .legs: ("Barbell Back Squat", 185)
            case .arms: ("Supinated Straight-Bar Cable Curl", 65)
            case .core: ("30-Degree Curl-Up", 0)
            }
        }
    }

#endif
