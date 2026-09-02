//
//  ActiveSetCompletionRoute.swift
//  vivobody
//
//  Pure mapping from a committed set-completion snapshot to pager intent.
//  ActiveWorkoutScreen remains the only owner that writes the visible page.
//

import Foundation

nonisolated enum ActiveSetCompletionRoute: Equatable {
    case stay
    case immediate(targetIndex: Int, animated: Bool)
    case guardedDelayed(targetIndex: Int, playsHandoffFeedback: Bool)
}

nonisolated enum ActiveSetCompletionRoutePlanner {
    static func route(
        after completion: CommittedActiveSetCompletion
    ) -> ActiveSetCompletionRoute {
        switch completion.outcome {
        case .none, .rest:
            .stay

        case let .supersetPartner(id):
            index(of: id, in: completion)
                .map { .guardedDelayed(targetIndex: $0, playsHandoffFeedback: true) }
                ?? .stay

        case let .supersetRoundRest(resume: id):
            index(of: id, in: completion)
                .map { .immediate(targetIndex: $0, animated: false) }
                ?? .stay

        case .exerciseComplete:
            routeAfterExerciseCompletion(completion)
        }
    }

    private static func routeAfterExerciseCompletion(
        _ completion: CommittedActiveSetCompletion
    ) -> ActiveSetCompletionRoute {
        if completion.isAllComplete {
            return .immediate(
                targetIndex: completion.orderedExercises.count,
                animated: true
            )
        }
        guard let currentIndex = index(
            of: completion.completedExerciseID,
            in: completion
        ) else { return .stay }

        let completed = completion.orderedExercises[currentIndex]
        var nextIndex = currentIndex + 1
        while nextIndex < completion.orderedExercises.count,
              completed.supersetID != nil,
              completion.orderedExercises[nextIndex].supersetID == completed.supersetID,
              completion.orderedExercises[nextIndex].isComplete
        {
            nextIndex += 1
        }
        return .guardedDelayed(
            targetIndex: nextIndex,
            playsHandoffFeedback: false
        )
    }

    private static func index(
        of id: UUID,
        in completion: CommittedActiveSetCompletion
    ) -> Int? {
        completion.orderedExercises.firstIndex { $0.id == id }
    }
}
