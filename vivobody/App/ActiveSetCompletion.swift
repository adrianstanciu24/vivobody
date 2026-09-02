//
//  ActiveSetCompletion.swift
//  vivobody
//
//  Typed boundary for completing one active-workout set. Requests identify
//  the exact tap-time session, exercise, and set; committed results contain
//  only immutable values safe for presentation routing after persistence.
//

import Foundation

/// Lets presentation scope animation to the domain mutation without pulling
/// controller-owned persistence or PR presentation state into that transaction.
typealias ActiveSetCompletionMutation = @MainActor (
    @MainActor () -> SetCompletionOutcome
) -> SetCompletionOutcome

nonisolated struct ActiveSetPersonalRecordPayload: Equatable {
    let value: String
    let unit: String?
    let detail: String
}

nonisolated struct ActiveSetCompletionRequest: Equatable {
    let sessionID: UUID
    let exerciseID: UUID
    let expectedActiveSetID: UUID
    let personalRecord: ActiveSetPersonalRecordPayload?
}

nonisolated struct ActiveSetCompletionExerciseSnapshot: Equatable {
    let id: UUID
    let supersetID: UUID?
    let isComplete: Bool
}

nonisolated enum CommittedSetCompletionOutcome: Equatable {
    case none
    case rest
    case exerciseComplete
    case supersetPartner(UUID)
    case supersetRoundRest(resume: UUID)
}

nonisolated struct CommittedActiveSetCompletion: Equatable {
    let completedExerciseID: UUID
    let outcome: CommittedSetCompletionOutcome
    let orderedExercises: [ActiveSetCompletionExerciseSnapshot]
    let isAllComplete: Bool

    @MainActor
    init(
        domainOutcome: SetCompletionOutcome,
        exercise: Exercise,
        session: WorkoutSession
    ) {
        completedExerciseID = exercise.id
        outcome = switch domainOutcome {
        case .none:
            .none
        case .rest:
            .rest
        case .exerciseComplete:
            .exerciseComplete
        case let .supersetPartner(partner):
            .supersetPartner(partner.id)
        case let .supersetRoundRest(resume):
            .supersetRoundRest(resume: resume.id)
        }
        orderedExercises = session.orderedExercises.map {
            ActiveSetCompletionExerciseSnapshot(
                id: $0.id,
                supersetID: $0.supersetID,
                isComplete: $0.orderedSets.allSatisfy(\.isCompleted)
            )
        }
        isAllComplete = session.isAllComplete
    }

    init(
        completedExerciseID: UUID,
        outcome: CommittedSetCompletionOutcome,
        orderedExercises: [ActiveSetCompletionExerciseSnapshot],
        isAllComplete: Bool
    ) {
        self.completedExerciseID = completedExerciseID
        self.outcome = outcome
        self.orderedExercises = orderedExercises
        self.isAllComplete = isAllComplete
    }
}

nonisolated enum ActiveSetCompletionResult: Equatable {
    case committed(CommittedActiveSetCompletion)
    case staleRequest
    case invalidRequest
    case persistenceUnavailable
    case saveFailed
}
