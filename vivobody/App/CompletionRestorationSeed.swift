//
//  CompletionRestorationSeed.swift
//  vivobody
//
//  DEBUG-only active-workout fixture whose edited first set makes completion
//  carry-forward and page/rest restoration observable through Baguette.
//

#if DEBUG
    import Foundation
    import SwiftData

    @MainActor
    enum CompletionRestorationSeed {
        static func prepareIfRequested(in context: ModelContext) {
            if CommandLine.arguments.contains("--ui-test-completion-restoration") {
                seed(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-skip-active-rest") {
                skipActiveRest(in: context)
            }
        }

        private static func seed(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let setup = Exercise(
                name: "Setup Exercise",
                group: .back,
                plannedSets: 1,
                plannedReps: 10,
                plannedWeight: 50,
                sortOrder: 0
            )
            let bench = Exercise(
                name: "Barbell Bench Press",
                catalogID: "barbell-bench-press",
                group: .chest,
                plannedSets: 2,
                plannedReps: 8,
                plannedWeight: 135,
                sortOrder: 1
            )
            bench.orderedSets[0].weight = 155
            bench.orderedSets[0].reps = 6
            let session = WorkoutSession(
                exercises: [setup, bench],
                restDuration: 300
            )
            session.activeExerciseIndex = 1
            context.insert(session)
            try? context.saveOrRollback()
        }

        private static func skipActiveRest(in context: ModelContext) {
            var descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            )
            descriptor.fetchLimit = 1
            guard let session = try? context.fetch(descriptor).first else { return }
            session.skipRest()
            session.pendingPRValue = nil
            session.pendingPRUnit = nil
            session.pendingPRDetail = nil
            try? context.saveOrRollback()
        }
    }
#endif
