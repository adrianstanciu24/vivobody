//
//  DebugAppStoreSeeder.swift
//  Explicit App Store capture fixtures layered over a fresh -years archive.
//  Only known synthetic IDs are adjusted; production analytics stay unchanged.
//

import Foundation
import SwiftData

#if DEBUG
    @MainActor
    enum DebugAppStoreSeeder {
        /// Routed only with --ui-test-reset -years --app-store-demo. Subsequent
        /// capture launches preserve the prepared store without reapplying it.
        static func prepareHistory(in context: ModelContext, now: Date = Date()) {
            let calendar = Calendar.current
            guard let sessions = try? context.fetch(FetchDescriptor<WorkoutSession>()),
                  let templates = try? context.fetch(FetchDescriptor<WorkoutTemplate>()),
                  let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now),
                  let previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start)
            else { return }

            let recent = sessions.filter {
                $0.id.uuidString.hasPrefix("D2400000-") &&
                    ($0.completedAt ?? .distantPast) >= previousStart
            }
            for session in recent {
                let exercises = session.orderedExercises
                session.exercises = Array(exercises.prefix(4))
                for extra in exercises.dropFirst(4) {
                    context.delete(extra)
                }
                for (index, exercise) in session.orderedExercises.enumerated() {
                    for (setIndex, set) in exercise.orderedSets.enumerated() {
                        // Four exercises × (0.8 + 0.8 + 0.9) = 10 hard sets.
                        // The first compound lift supplies genuine 1–5 rep work.
                        set.reps = index == 0 ? 5 : 8 + index * 2
                        set.repsInReserve = setIndex == 2 ? 1 : 2
                        set.rirLogged = true
                    }
                }
            }
            tuneWeeklyComparison(recent, thisWeek: thisWeek)
            prepareTemplates(templates, in: context)
            try? context.saveOrRollback()
        }

        private static func tuneWeeklyComparison(_ sessions: [WorkoutSession], thisWeek: DateInterval) {
            let current = sessions.filter { thisWeek.contains($0.completedAt ?? .distantPast) }
            let previous = sessions.filter { ($0.completedAt ?? .distantPast) < thisWeek.start }
            let currentVolume = current.comparableTonnageSummary.knownSubtotal
            let previousVolume = previous.comparableTonnageSummary.knownSubtotal
            let adjustable = previous.flatMap(\.exercises).filter { $0.loadMode == .external }
            let adjustableVolume = adjustable.reduce(0) { $0 + $1.comparableTonnageSummary.knownSubtotal }
            let fixedVolume = previousVolume - adjustableVolume
            guard currentVolume > 0, adjustableVolume > 0 else { return }
            let factor = (currentVolume / 1.10 - fixedVolume) / adjustableVolume
            guard factor > 0 else { return }
            for exercise in adjustable {
                for set in exercise.sets {
                    set.weight = (set.weight * factor / 2.5).rounded() * 2.5
                }
            }
        }

        private static func prepareTemplates(_ templates: [WorkoutTemplate], in context: ModelContext) {
            let plans = [
                ["Barbell Back Squat", "Barbell Hip Thrust", "Kneeling Cable Crunch"],
                ["Barbell Bench Press", "Seated Dumbbell Overhead Press", "Prone Dumbbell Reverse Fly"],
                ["Barbell Front Squat", "Barbell Hip Thrust", "Hanging Knee Raise"],
                ["Cable Lat Pulldown", "Barbell Bent-Over Row", "Hanging Knee Raise"],
            ]
            for (index, names) in plans.enumerated() {
                let id = UUID(uuidString: String(format: "D0600000-0000-4000-8000-%012d", index + 1))!
                guard let template = templates.first(where: { $0.id == id }) else { continue }
                let oldExercises = template.exercises
                template.exercises = names.enumerated().map { order, name in
                    debugCatalogTemplateExercise(
                        named: name, plannedSets: 3, plannedReps: 8,
                        plannedWeight: 0, sortOrder: order
                    )
                }
                for old in oldExercises {
                    context.delete(old)
                }
            }
        }

        static func seedWorkout(resting: Bool, in context: ModelContext) {
            guard let sessions = try? context.fetch(FetchDescriptor<WorkoutSession>()),
                  !sessions.contains(where: { $0.completedAt == nil })
            else { return }
            let exercise = debugCatalogExercise(
                named: "Barbell Bench Press", plannedSets: 3, plannedReps: 8,
                plannedWeight: 185, sortOrder: 0
            )
            exercise.orderedSets.first?.isCompleted = true
            let session = WorkoutSession(
                id: UUID(uuidString: "A5700000-0000-4000-8000-000000000001")!,
                exercises: [exercise], restDuration: 120, bodyweightAtStart: 175
            )
            if resting {
                session.isResting = true
                session.restStartedAt = Date().addingTimeInterval(-20)
                session.restEndsAt = session.restStartedAt?.addingTimeInterval(120)
            }
            context.insert(session)
            try? context.saveOrRollback()
        }
    }
#endif
