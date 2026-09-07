//
//  DebugTrainingSeeder.swift
//  vivobody
//
//  Manual -debug fixture: four scheduled templates and six calendar months
//  of completed training. Stable IDs make repeated launches additive and safe.
//

import Foundation
import SwiftData

#if DEBUG
    @MainActor
    enum DebugTrainingSeeder {
        private struct Plan {
            let name: String
            let weekday: Int
            let lifts: [(name: String, reps: Int, pounds: Double)]
        }

        private static let plans: [Plan] = [
            Plan(name: "Lower A", weekday: 2, lifts: [
                ("Barbell Back Squat", 8, 185),
                ("Continuous Top-Start Barbell Romanian Deadlift", 10, 135),
                ("Upright Bilateral Lever-Machine Leg Extension", 12, 80),
                ("Bilateral Standing Shoulder-Pad Machine Calf Raise", 12, 100),
                ("Kneeling Cable Crunch", 12, 40),
            ]),
            Plan(name: "Upper Push", weekday: 3, lifts: [
                ("Barbell Bench Press", 8, 135),
                ("Seated Dumbbell Overhead Press", 10, 35),
                ("Simultaneous Bilateral Dumbbell Lateral Raise", 12, 15),
                ("Bilateral Rope Cable Triceps Pushdown", 12, 40),
                ("30-Degree Curl-Up", 12, 0),
            ]),
            Plan(name: "Lower B", weekday: 5, lifts: [
                ("Barbell Front Squat", 8, 135),
                ("Barbell Hip Thrust", 10, 155),
                ("Johnson SL160 Bilateral Seated Leg Curl", 12, 70),
                ("Bilateral Seated Thigh-Pad Machine Calf Raise", 12, 70),
                ("Supine Reverse Crunch", 12, 0),
            ]),
            Plan(name: "Upper Pull", weekday: 6, lifts: [
                ("Barbell Bent-Over Row", 8, 115),
                ("Cable Lat Pulldown", 10, 100),
                ("Shoulder-Width Straight-Arm Cable Pulldown", 12, 40),
                ("Supinated Straight-Bar Cable Curl", 12, 40),
                ("Hanging Knee Raise", 12, 0),
            ]),
        ]

        static func seed(
            in context: ModelContext,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            // Failed reads must never be mistaken for an empty store.
            guard let existingTemplates = try? context.fetch(FetchDescriptor<WorkoutTemplate>()),
                  let existingSessions = try? context.fetch(FetchDescriptor<WorkoutSession>()),
                  let start = calendar.date(byAdding: .month, value: -6, to: calendar.startOfDay(for: now))
            else { return }

            let sessionIDs = Set(existingSessions.map(\.id))
            let nextOrder = (existingTemplates.map(\.sortOrder).max() ?? -1) + 1
            let templates = plans.enumerated().map { index, plan in
                let id = fixtureID(suffix: index + 1)
                if let existing = existingTemplates.first(where: { $0.id == id }) {
                    addCore(to: existing, plan: plan)
                    return existing
                }
                let template = WorkoutTemplate(
                    id: id, name: plan.name, sortOrder: nextOrder + index, createdAt: start
                )
                template.scheduledWeekdays = [plan.weekday]
                template.exercises = plan.lifts.enumerated().map { order, lift in
                    debugCatalogTemplateExercise(
                        named: lift.name, plannedSets: 3, plannedReps: lift.reps,
                        plannedWeight: lift.pounds, sortOrder: order
                    )
                }
                context.insert(template)
                return template
            }

            updateExistingSessions(existingSessions, calendar: calendar)

            var day = start
            let today = calendar.startOfDay(for: now)
            while day < today {
                if let index = plans.firstIndex(where: { $0.weekday == calendar.component(.weekday, from: day) }),
                   let started = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)
                {
                    let parts = calendar.dateComponents([.year, .month, .day], from: day)
                    let dateKey = (parts.year ?? 0) * 10000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
                    let id = fixtureID(suffix: dateKey)
                    if !sessionIDs.contains(id) {
                        let elapsedDays = calendar.dateComponents([.day], from: start, to: day).day ?? 0
                        let session = makeSession(
                            plan: plans[index], id: id, started: started, week: elapsedDays / 7
                        )
                        context.insert(session)
                        if templates[index].lastUsedAt.map({ $0 < started }) ?? true {
                            templates[index].lastUsedAt = started
                        }
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            try? context.saveOrRollback()
        }

        private static func makeSession(plan: Plan, id: UUID, started: Date, week: Int) -> WorkoutSession {
            let exercises = plan.lifts.enumerated().map { order, lift in
                // Modest progression and rep variation make charts useful.
                let weight = lift.pounds > 0 ? lift.pounds + Double(week / 4) * 2.5 : 0
                let exercise = debugCatalogExercise(
                    named: lift.name, plannedSets: 3, plannedReps: lift.reps,
                    plannedWeight: weight, sortOrder: order
                )
                for (index, set) in exercise.orderedSets.enumerated() {
                    set.reps = lift.reps + week % 3 - index
                    set.repsInReserve = index == 0 ? 1 : 0
                    set.rirLogged = true
                    set.isCompleted = true
                }
                return exercise
            }
            let session = WorkoutSession(id: id, exercises: exercises, restDuration: 90, startedAt: started)
            session.completedAt = started.addingTimeInterval(50 * 60)
            return session
        }

        private static func addCore(to template: WorkoutTemplate, plan: Plan) {
            guard let core = plan.lifts.last,
                  !template.exercises.contains(where: { $0.catalogID == debugCatalogRecord(named: core.name).catalogID })
            else { return }
            template.exercises.append(debugCatalogTemplateExercise(
                named: core.name, plannedSets: 3, plannedReps: core.reps,
                plannedWeight: core.pounds,
                sortOrder: (template.exercises.map(\.sortOrder).max() ?? -1) + 1
            ))
        }

        /// Upgrade only this fixture's archived sessions, including older
        /// seeded days that have since fallen outside the rolling window.
        private static func updateExistingSessions(_ sessions: [WorkoutSession], calendar: Calendar) {
            for session in sessions where session.id.uuidString.hasPrefix("D0600000-0000-4000-8000-") {
                guard session.completedAt != nil,
                      let plan = plans.first(where: {
                          $0.weekday == calendar.component(.weekday, from: session.startedAt)
                      }),
                      let core = plan.lifts.last
                else { continue }
                if !session.exercises.contains(where: { $0.catalogID == debugCatalogRecord(named: core.name).catalogID }) {
                    let exercise = debugCatalogExercise(
                        named: core.name, plannedSets: 3, plannedReps: core.reps,
                        plannedWeight: core.pounds,
                        sortOrder: (session.exercises.map(\.sortOrder).max() ?? -1) + 1
                    )
                    for set in exercise.sets {
                        set.isCompleted = true
                    }
                    session.exercises.append(exercise)
                }
                for exercise in session.exercises {
                    for (index, set) in exercise.orderedSets.enumerated() {
                        set.repsInReserve = index == 0 ? 1 : 0
                        set.rirLogged = true
                    }
                }
            }
        }

        private static func fixtureID(suffix: Int) -> UUID {
            UUID(uuidString: String(format: "D0600000-0000-4000-8000-%012d", suffix))!
        }
    }
#endif
