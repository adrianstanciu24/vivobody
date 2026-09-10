//
//  DebugYearsSeeder.swift
//  Additive -years fixture: two calendar years of varied, catalog-backed training.
//  Calendar-date IDs and anchored weeks keep repeated launches deterministic.
//

import Foundation
import SwiftData

#if DEBUG
    @MainActor
    enum DebugYearsSeeder {
        /// The first three sessions cover squat, hinge, upper push/pull, core,
        /// and sagittal/frontal/transverse work even in a three-workout week.
        private static let workouts: [[(name: String, reps: Int, pounds: Double)]] = [
            [
                ("Barbell Back Squat", 8, 155),
                ("Barbell Bench Press", 8, 115),
                ("Cable Lat Pulldown", 10, 85),
                ("60%-Height Bodyweight Lateral Lunge", 12, 0),
                ("Bilateral Standing Shoulder-Pad Machine Calf Raise", 12, 80),
                ("Kneeling Cable Crunch", 12, 35),
            ],
            [
                ("Continuous Top-Start Barbell Romanian Deadlift", 10, 115),
                ("Seated Dumbbell Overhead Press", 10, 30),
                ("Barbell Bent-Over Row", 10, 95),
                ("Supine Reverse Crunch", 12, 0),
                ("Simultaneous Bilateral Dumbbell Lateral Raise", 12, 10),
                ("Supinated Straight-Bar Cable Curl", 12, 30),
            ],
            [
                ("Barbell Front Squat", 8, 105),
                ("Barbell Hip Thrust", 10, 135),
                ("Prone Dumbbell Reverse Fly", 12, 10),
                ("Kneeling Cable Crunch", 12, 35),
                ("Johnson SL160 Bilateral Seated Leg Curl", 12, 60),
                ("Bilateral Rope Cable Triceps Pushdown", 12, 30),
            ],
            [
                ("Barbell Bench Press", 10, 105),
                ("Cable Lat Pulldown", 12, 75),
                ("Simultaneous Bilateral Dumbbell Lateral Raise", 12, 10),
                ("High-Pulley Rope Face Pull with Deliberate External Rotation", 12, 25),
                ("Supinated Straight-Bar Cable Curl", 12, 30),
                ("Bilateral Rope Cable Triceps Pushdown", 12, 30),
            ],
            [
                ("Barbell Hip Thrust", 12, 115),
                ("60%-Height Bodyweight Lateral Lunge", 12, 0),
                ("Technogym Seated Hip Adduction Machine", 12, 50),
                ("Bilateral Seated Thigh-Pad Machine Calf Raise", 15, 60),
                ("Technogym Seated Hip Abduction Machine", 12, 50),
                ("Hanging Knee Raise", 12, 0),
            ],
        ]

        static func seed(in context: ModelContext, now: Date = Date()) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let today = calendar.startOfDay(for: now)
            guard let start = calendar.date(byAdding: .year, value: -2, to: today),
                  let anchor = calendar.date(from: DateComponents(year: 2020, month: 1, day: 6)),
                  let sessions = try? context.fetch(FetchDescriptor<WorkoutSession>())
            else { return }
            let existingIDs = Set(sessions.map(\.id))
            var day = start
            while day < today {
                let elapsed = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
                let week = elapsed / 7
                let weekday = (calendar.component(.weekday, from: day) + 5) % 7
                if let slot = trainingDays(week: week).firstIndex(of: weekday) {
                    let parts = calendar.dateComponents([.year, .month, .day], from: day)
                    let key = (parts.year ?? 0) * 10000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
                    let id = UUID(uuidString: String(format: "D2400000-0000-4000-8000-%012d", key))!
                    if !existingIDs.contains(id),
                       let started = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)
                    {
                        context.insert(makeSession(id: id, started: started, week: week, slot: slot))
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            try? context.saveOrRollback()
        }

        private static func trainingDays(week: Int) -> [Int] {
            // Monday-based; repeatable blocks include easier and busier weeks.
            let counts = [4, 4, 5, 3, 4, 5, 4, 3, 5, 4, 4, 3]
            switch counts[week % counts.count] {
            case 3: return [0, 2, 4]
            case 5: return [0, 1, 2, 4, 5]
            default: return [0, 1, 3, 5]
            }
        }

        private static func makeSession(id: UUID, started: Date, week: Int, slot: Int) -> WorkoutSession {
            let count = 4 + (week + slot) % 3
            let exercises = workouts[slot].prefix(count).enumerated().map { order, lift in
                // Small training cycles add progression, rep variation and deloads.
                let deload = week % 12 == 11
                let progression = Double(week % 26) * 1.25
                let weight = lift.pounds > 0 ? (lift.pounds + progression) * (deload ? 0.85 : 1) : 0
                let exercise = debugCatalogExercise(
                    named: lift.name, plannedSets: 3, plannedReps: lift.reps,
                    plannedWeight: (weight / 2.5).rounded() * 2.5, sortOrder: order
                )
                for (index, set) in exercise.orderedSets.enumerated() {
                    set.reps = lift.reps + week % 3 - index
                    set.repsInReserve = deload ? 3 : max(0, 2 - index)
                    set.rirLogged = true
                    set.isCompleted = true
                }
                return exercise
            }
            let session = WorkoutSession(id: id, exercises: exercises, restDuration: 90, startedAt: started)
            session.bodyweightAtStart = 175
            session.completedAt = started.addingTimeInterval(Double(count * 9 + week % 7) * 60)
            return session
        }
    }
#endif
