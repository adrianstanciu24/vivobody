//
//  DebugInsightsSeeder.swift
//  vivobody
//
//  DEBUG-only Insights fixture dispatch plus the focused power-only archive
//  used to verify factual and unavailable instrument branches together.
//

import Foundation
import SwiftData

#if DEBUG

    @MainActor
    enum DebugInsightsSeeder {
        static func handle(
            _ step: DebugLaunchStep,
            in context: ModelContext
        ) -> Bool {
            switch step {
            case .insightsEmptyInstruments:
                seedEmptyInstruments(in: context)
            case .insightsShowcase:
                InsightsShowcaseSeed.seed(in: context)
            case .meShowcase:
                MeShowcaseSeed.seed(in: context)
            default:
                return false
            }
            return true
        }

        private static func seedEmptyInstruments(
            in context: ModelContext,
            now: Date = Date()
        ) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let exercise = Exercise(
                name: "Box Jump",
                group: .legs,
                plannedSets: 1,
                plannedReps: 5,
                plannedWeight: 0,
                trackingMode: .reps,
                modality: .power,
                loadMode: .nonComparable,
                sortOrder: 0
            )
            exercise.sets.first?.isCompleted = true
            let completedAt = now.addingTimeInterval(-15 * 60)
            let session = WorkoutSession(
                exercises: [exercise],
                restDuration: 90,
                startedAt: completedAt.addingTimeInterval(-25 * 60)
            )
            session.completedAt = completedAt
            context.insert(session)
            try? context.saveOrRollback()
        }
    }

#endif
