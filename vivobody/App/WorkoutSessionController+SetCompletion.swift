//
//  WorkoutSessionController+SetCompletion.swift
//  vivobody
//
//  Owns the validated, atomic active-set completion transaction. Domain
//  mutation and an optional prepared PR payload save together; callers receive
//  immutable routing evidence only after persistence succeeds.
//

import Foundation
import SwiftData

extension WorkoutSessionController {
    @discardableResult
    func completeActiveSet(
        _ request: ActiveSetCompletionRequest,
        performMutation: ActiveSetCompletionMutation = { mutation in mutation() }
    ) -> ActiveSetCompletionResult {
        completeActiveSet(
            request,
            performMutation: performMutation,
            beforeSave: nil
        )
    }

    /// External/widget completion shares the transaction while retaining its
    /// pre-presentation superset positioning. No animation runs while the
    /// expanded workout is absent.
    func completeActiveSet() {
        guard let session = activeSession else { return }
        let exercises = session.orderedExercises
        guard exercises.indices.contains(session.activeExerciseIndex) else { return }
        let exercise = exercises[session.activeExerciseIndex]
        guard let set = session.activeSet(for: exercise) else {
            guard saveActiveSessionChanges(for: session.id) else { return }
            presentActiveWorkoutAfterExternalCompletion()
            return
        }

        let request = ActiveSetCompletionRequest(
            sessionID: session.id,
            exerciseID: exercise.id,
            expectedActiveSetID: set.id,
            personalRecord: nil
        )
        let result = completeActiveSet(
            request,
            beforeSave: { completion in
                let targetID: UUID? = switch completion.outcome {
                case let .supersetPartner(id):
                    id
                case let .supersetRoundRest(resume: id):
                    id
                case .none, .rest, .exerciseComplete:
                    nil
                }
                if let targetID,
                   let index = session.orderedExercises.firstIndex(where: { $0.id == targetID })
                {
                    session.activeExerciseIndex = index
                }
            }
        )
        guard case .committed = result else { return }
        presentActiveWorkoutAfterExternalCompletion()
    }

    private func presentActiveWorkoutAfterExternalCompletion() {
        appState?.selectedTab = .today
        isWorkoutExpanded = true
    }

    private func completeActiveSet(
        _ request: ActiveSetCompletionRequest,
        performMutation: ActiveSetCompletionMutation = { mutation in mutation() },
        beforeSave: ((CommittedActiveSetCompletion) -> Void)?
    ) -> ActiveSetCompletionResult {
        guard !isDiscardPending,
              let session = activeSession,
              session.id == request.sessionID,
              session.completedAt == nil
        else { return .staleRequest }
        guard modelContext != nil else { return .persistenceUnavailable }
        guard let exercise = session.exercises.first(where: { $0.id == request.exerciseID }),
              session.activeSet(for: exercise)?.id == request.expectedActiveSetID
        else { return .invalidRequest }

        let rollbackSnapshot = ActiveSetCompletionRollbackSnapshot(session: session)
        let domainOutcome = performMutation {
            session.completeActiveSet(for: exercise)
        }
        if let payload = request.personalRecord {
            session.pendingPRValue = payload.value
            session.pendingPRUnit = payload.unit
            session.pendingPRDetail = payload.detail
        }
        let completion = CommittedActiveSetCompletion(
            domainOutcome: domainOutcome,
            exercise: exercise,
            session: session
        )
        beforeSave?(completion)

        guard saveActiveSessionChanges(for: request.sessionID) else {
            // SwiftData's rollback clears change tracking after a failed save,
            // but loaded model instances can retain their mutated values.
            // Restore this transaction's complete graph explicitly, then clear
            // the restoration writes so the draft is clean and retryable.
            rollbackSnapshot.restore()
            modelContext?.rollback()
            return .saveFailed
        }
        return .committed(completion)
    }
}

@MainActor
private struct ActiveSetCompletionRollbackSnapshot {
    private struct ExerciseState {
        let exercise: Exercise
        let plannedWeight: Double
    }

    private struct SetState {
        let set: WorkoutSet
        let weight: Double
        let repetitions: Int
        let duration: TimeInterval
        let isCompleted: Bool
        let plannedWeight: Double
    }

    private let session: WorkoutSession
    private let isResting: Bool
    private let restStartedAt: Date?
    private let restEndsAt: Date?
    private let activeExerciseIndex: Int
    private let pendingPersonalRecordValue: String?
    private let pendingPersonalRecordUnit: String?
    private let pendingPersonalRecordDetail: String?
    private let exercises: [ExerciseState]
    private let sets: [SetState]

    init(session: WorkoutSession) {
        self.session = session
        isResting = session.isResting
        restStartedAt = session.restStartedAt
        restEndsAt = session.restEndsAt
        activeExerciseIndex = session.activeExerciseIndex
        pendingPersonalRecordValue = session.pendingPRValue
        pendingPersonalRecordUnit = session.pendingPRUnit
        pendingPersonalRecordDetail = session.pendingPRDetail
        exercises = session.exercises.map {
            ExerciseState(exercise: $0, plannedWeight: $0.plannedWeight)
        }
        sets = session.exercises.flatMap(\.sets).map {
            SetState(
                set: $0,
                weight: $0.weight,
                repetitions: $0.reps,
                duration: $0.duration,
                isCompleted: $0.isCompleted,
                plannedWeight: $0.plannedWeight
            )
        }
    }

    func restore() {
        session.isResting = isResting
        session.restStartedAt = restStartedAt
        session.restEndsAt = restEndsAt
        session.activeExerciseIndex = activeExerciseIndex
        session.pendingPRValue = pendingPersonalRecordValue
        session.pendingPRUnit = pendingPersonalRecordUnit
        session.pendingPRDetail = pendingPersonalRecordDetail
        for state in exercises {
            state.exercise.plannedWeight = state.plannedWeight
        }
        for state in sets {
            state.set.weight = state.weight
            state.set.reps = state.repetitions
            state.set.duration = state.duration
            state.set.isCompleted = state.isCompleted
            state.set.plannedWeight = state.plannedWeight
        }
    }
}
