//
//  DebugSeedWeeklyVolume.swift
//  vivobody
//
//  Debug-only fixture for the Exercise Detail "This week" card and the
//  hero-card frequency footer: a deterministic Barbell Bench Press
//  history with two sessions inside the 7-day volume window and two
//  older ones, so the card shows exact hard-set shares (6.0 primary /
//  3.0 per secondary) and the footer a known count (4 sessions) and
//  weekly rate (1.6×). Driven by `--ui-test-weekly-volume` and
//  idempotent like the other seeders. Kept out of DebugSeed.swift,
//  which is at its source-size allowance.
//

import Foundation
import SwiftData

#if DEBUG

    enum DebugWeeklyVolumeSeeder {
        static func seedIfRequested(in context: ModelContext) {
            guard CommandLine.arguments.contains("--ui-test-weekly-volume") else { return }
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let now = Date()
            let calendar = Calendar.current

            // Two sessions inside the 7-day window (3 completed sets
            // each), two older ones that feed only frequency, records,
            // and history. Loads rise toward the present so the recent
            // sessions carry the standing record.
            let plan: [(daysAgo: Int, weight: Double)] = [
                (2, 185), (4, 182.5), (10, 180), (17, 177.5),
            ]
            for (daysAgo, weight) in plan {
                guard
                    let day = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                    let started = calendar.date(byAdding: .hour, value: -1, to: day)
                else { continue }
                let exercise = debugCatalogExercise(
                    named: "Barbell Bench Press",
                    plannedSets: 3,
                    plannedReps: 8,
                    plannedWeight: weight,
                    sortOrder: 0
                )
                for set in exercise.sets {
                    set.isCompleted = true
                }
                let session = WorkoutSession(
                    exercises: [exercise],
                    restDuration: 90,
                    startedAt: started
                )
                session.completedAt = started.addingTimeInterval(40 * 60)
                context.insert(session)
            }
            try? context.saveOrRollback()
        }
    }

#endif
