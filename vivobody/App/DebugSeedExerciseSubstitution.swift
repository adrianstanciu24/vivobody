//
//  DebugSeedExerciseSubstitution.swift
//  vivobody
//
//  Deterministic zero-progress and empty-set workouts used to verify exercise
//  substitution and the active card's recovery state.
//

import Foundation
import SwiftData

#if DEBUG
    extension UITestSupport {
        static func seedExerciseSubstitutionIfRequested(
            in context: ModelContext
        ) {
            let seedsReplacement = CommandLine.arguments.contains(
                "--ui-test-active-replaceable"
            )
            let seedsEmptyState = CommandLine.arguments.contains(
                "--ui-test-active-zero-set"
            )
            guard seedsReplacement || seedsEmptyState else { return }
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let exercise = debugCatalogExercise(
                named: "Barbell Bench Press",
                plannedSets: seedsEmptyState ? 0 : 3,
                plannedReps: 8,
                plannedWeight: 135,
                sortOrder: 0
            )
            if seedsReplacement {
                // Regression fixture: live rows are authoritative even if a
                // cached uniform-plan count has drifted to zero.
                exercise.plannedSets = 0
            }
            context.insert(WorkoutSession(
                exercises: [exercise],
                restDuration: 90
            ))
            try? context.saveOrRollback()
        }
    }
#endif
