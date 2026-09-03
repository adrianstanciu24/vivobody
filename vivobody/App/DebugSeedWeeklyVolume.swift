//
//  DebugSeedWeeklyVolume.swift
//  vivobody
//
//  Debug-only fixture for the Exercise Detail "This week" card and the
//  hero-card frequency footer: a deterministic Barbell Bench Press
//  history with two sessions inside the 7-day volume window and two
//  older ones, so the card shows exact hard-set shares (6.0 primary /
//  3.0 per secondary) and the footer a known count (4 sessions) and
//  weekly rate (1.6×). The pure launch router selects this idempotent fixture;
//  its sessions use fixed evening timestamps and durations.
//

import Foundation
import SwiftData

#if DEBUG

    @MainActor
    enum DebugWeeklyVolumeSeeder {
        static func seed(
            in context: ModelContext,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            // Two sessions inside the 7-day window (3 completed sets
            // each), two older ones that feed only frequency, records,
            // and history. Loads rise toward the present so the recent
            // sessions carry the standing record.
            let plan: [(daysAgo: Int, weight: Double)] = [
                (2, 185), (4, 182.5), (10, 180), (17, 177.5),
            ]
            for (daysAgo, weight) in plan {
                let today = calendar.startOfDay(for: now)
                guard
                    let day = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                    let started = calendar.date(
                        bySettingHour: 18,
                        minute: 0,
                        second: 0,
                        of: day
                    )
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
