//
//  DebugSeedAssistance.swift
//  vivobody
//
//  Deterministic assisted-machine workout fixture for visual and semantic
//  verification of subtractive Assistance logging.
//

import Foundation
import SwiftData

#if DEBUG
    @MainActor
    enum DebugAssistanceSeeder {
        static func seed(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let exercise = debugCatalogExercise(
                named: "Assisted Pull-Up Machine",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 50,
                sortOrder: 0
            )
            let session = WorkoutSession(
                exercises: [exercise],
                restDuration: 90,
                bodyweightAtStart: 180
            )
            context.insert(session)
            try? context.saveOrRollback()
        }
    }
#endif
