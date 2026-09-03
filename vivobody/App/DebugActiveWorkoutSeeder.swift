//
//  DebugActiveWorkoutSeeder.swift
//  vivobody
//
//  Deterministic active-workout fixture family used by semantic and visual
//  verification. Each fixture remains idempotent against an existing session.
//

import Foundation
import SwiftData
import VivoKit

#if DEBUG

    @MainActor
    enum DebugActiveWorkoutSeeder {
        static func handleCore(
            _ step: DebugLaunchStep,
            in context: ModelContext
        ) -> Bool {
            switch step {
            case let .exerciseSubstitution(request):
                DebugExerciseSubstitutionSeeder.seed(request, in: context)
            case .activeAssistance:
                DebugAssistanceSeeder.seed(in: context)
            case .completionRestoration:
                CompletionRestorationSeed.seed(in: context)
            case .skipActiveRest:
                CompletionRestorationSeed.skipActiveRest(in: context)
            case let .activePartial(showsReceiptSummary):
                seedPartial(showsReceiptSummary: showsReceiptSummary, in: context)
            case .activeCompleteSummary:
                seedCompleteSummary(in: context)
            default:
                return false
            }
            return true
        }

        static func handleInstrument(
            _ step: DebugLaunchStep,
            in context: ModelContext
        ) -> Bool {
            switch step {
            case .activeBodyweight:
                seedBodyweight(in: context)
            case .activeBodyweightDuration:
                seedBodyweightDuration(in: context)
            case let .activeLoadPresentation(fixture):
                seedLoadPresentation(fixture, in: context)
            case .activeSuperset:
                seedSuperset(in: context)
            case .activeSupersetPower:
                seedSupersetPower(in: context)
            default:
                return false
            }
            return true
        }

        private static func seedPartial(
            showsReceiptSummary: Bool,
            in context: ModelContext
        ) {
            guard !hasActiveSession(in: context) else { return }

            let exercise = debugCatalogExercise(
                named: "Barbell Bench Press",
                plannedSets: 2,
                plannedReps: 8,
                plannedWeight: 135,
                sortOrder: 0
            )
            exercise.orderedSets.first?.isCompleted = true
            let session = WorkoutSession(exercises: [exercise], restDuration: 90)
            if showsReceiptSummary {
                session.activeExerciseIndex = 1
            }
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// Completed receipt with a varied set-load path for the cumulative
        /// current-versus-average chart. Archived history is seeded separately
        /// so the same fixture can also prove the no-baseline state.
        private static func seedCompleteSummary(in context: ModelContext) {
            guard !hasActiveSession(in: context) else { return }

            let exercise = debugCatalogExercise(
                named: "Barbell Bench Press",
                plannedSets: 4,
                plannedReps: 8,
                plannedWeight: 135,
                sortOrder: 0
            )
            let prescriptions: [(weight: Double, reps: Int)] = [
                (135, 8),
                (145, 8),
                (155, 6),
                (165, 5),
            ]
            for (set, prescription) in zip(exercise.orderedSets, prescriptions) {
                set.weight = prescription.weight
                set.reps = prescription.reps
                set.isCompleted = true
            }

            let session = WorkoutSession(exercises: [exercise], restDuration: 90)
            session.activeExerciseIndex = 1
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// Bodyweight-reps fixture: zero added load is interpreted through the
        /// exercise's snapshotted bodyweight load profile.
        private static func seedBodyweight(in context: ModelContext) {
            guard !hasActiveSession(in: context) else { return }

            let exercise = debugCatalogExercise(
                named: "Pull-Up",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 0,
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

        /// Duration counterpart where time remains the hero while bodyweight
        /// and added-load semantics remain explicit beneath it.
        private static func seedBodyweightDuration(in context: ModelContext) {
            guard !hasActiveSession(in: context) else { return }

            let exercise = Exercise(
                name: "Weighted Hang Fixture",
                group: .arms,
                plannedSets: 3,
                plannedReps: 0,
                plannedWeight: 0,
                trackingMode: .duration,
                modality: .isometricStrength,
                loadMode: .bodyweightAdded,
                bodyweightFraction: 1,
                plannedDuration: 30,
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

        /// Covers non-comparable resistance and unloaded bodyweight UI. The
        /// no-load variants retain stale draft values to prove normalization.
        private static func seedLoadPresentation(
            _ fixture: DebugActiveLoadFixture,
            in context: ModelContext
        ) {
            guard !hasActiveSession(in: context) else { return }

            let name: String
            let plannedReps: Int
            let seedsStaleLoad: Bool
            switch fixture {
            case .band:
                name = "Standing Band Fly"
                plannedReps = 15
                seedsStaleLoad = false
            case .noLoad:
                name = "Bodyweight Forward Lunge"
                plannedReps = 12
                seedsStaleLoad = true
            case .abWheel:
                name = "Kneeling Ab-Wheel Rollout"
                plannedReps = 12
                seedsStaleLoad = true
            }

            let exercise = debugCatalogExercise(
                named: name,
                plannedSets: 3,
                plannedReps: plannedReps,
                plannedWeight: 0,
                sortOrder: 0
            )
            if seedsStaleLoad {
                exercise.plannedWeight = 45
                for set in exercise.sets {
                    set.weight = 45
                    set.plannedWeight = 45
                }
            }
            context.insert(WorkoutSession(exercises: [exercise], restDuration: 90))
            try? context.saveOrRollback()
        }

        /// Linked strength pair followed by one straight-sets exercise.
        private static func seedSuperset(in context: ModelContext) {
            guard !hasActiveSession(in: context) else { return }

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
            context.insert(WorkoutSession(
                exercises: [bench, row, curl],
                restDuration: 90
            ))
            try? context.saveOrRollback()
        }

        /// Strength-plus-power pair where the partner logs reps without RIR.
        private static func seedSupersetPower(in context: ModelContext) {
            guard !hasActiveSession(in: context) else { return }

            let pressAround = debugCatalogExercise(
                named: "Flat Dumbbell Fly",
                plannedSets: 3,
                plannedReps: 12,
                plannedWeight: 30 * WeightUnit.lbPerKg,
                sortOrder: 0
            )
            let clapPushUp = debugCatalogExercise(
                named: "Barbell Push Press",
                plannedSets: 3,
                plannedReps: 10,
                plannedWeight: 25 * WeightUnit.lbPerKg,
                sortOrder: 1
            )
            let pairID = UUID()
            pressAround.supersetID = pairID
            clapPushUp.supersetID = pairID

            context.insert(WorkoutSession(
                exercises: [pressAround, clapPushUp],
                restDuration: 90
            ))
            try? context.saveOrRollback()
        }

        private static func hasActiveSession(in context: ModelContext) -> Bool {
            let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            ))) ?? []
            return !sessions.isEmpty
        }
    }

#endif
