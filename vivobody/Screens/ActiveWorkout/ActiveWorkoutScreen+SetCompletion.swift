//
//  ActiveWorkoutScreen+SetCompletion.swift
//  vivobody
//
//  Active-workout adapter between immutable card intent and the controller's
//  atomic completion request. This screen resolves history, formats PR copy,
//  and remains the only owner that writes pager selection.
//

import SwiftUI

extension ActiveWorkoutScreen {
    var activeSetCompletionActions: ActiveSetCompletionActions {
        #if DEBUG
            if onCompleteSet == nil {
                return ActiveSetCompletionPreviewAdapter.actions(
                    session: session,
                    unit: unit,
                    reduceMotion: reduceMotion
                )
            }
        #endif
        return ActiveSetCompletionActions(
            commit: commitActiveSet,
            currentSelection: { session.activeExerciseIndex },
            applyRoute: applyActiveSetCompletionRoute,
            onCommitted: {}
        )
    }

    private func commitActiveSet(
        _ intent: ActiveSetCompletionIntent
    ) -> ActiveSetCompletionResult {
        guard let onCompleteSet else { return .persistenceUnavailable }
        let record = LivePersonalRecord.evaluate(
            intent.personalRecordCandidate,
            history: sessionAnalytics?.resolvedExerciseHistory(in: modelContext)
        )
        let payload = record.flatMap {
            ActivePersonalRecordPresentation.payload(
                for: $0,
                candidate: intent.personalRecordCandidate,
                unit: unit
            )
        }
        let request = ActiveSetCompletionRequest(
            sessionID: intent.sessionID,
            exerciseID: intent.exerciseID,
            expectedActiveSetID: intent.setID,
            personalRecord: payload
        )
        return onCompleteSet(request) { mutation in
            withAnimation(
                reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)
            ) {
                mutation()
            }
        }
    }

    private func applyActiveSetCompletionRoute(
        _ route: ActiveSetCompletionRoute
    ) {
        switch route {
        case .stay:
            break
        case let .immediate(targetIndex, animated):
            setActiveExerciseIndex(targetIndex, animated: animated)
        case let .guardedDelayed(targetIndex, playsHandoffFeedback):
            setActiveExerciseIndex(targetIndex, animated: true)
            if playsHandoffFeedback {
                Haptics.soft(playsSound: false)
            }
        }
    }

    private func setActiveExerciseIndex(_ index: Int, animated: Bool) {
        guard 0 ... session.orderedExercises.count ~= index else { return }
        withAnimation(animated && !reduceMotion
            ? .spring(response: 0.55, dampingFraction: 0.85)
            : nil)
        {
            session.activeExerciseIndex = index
        }
    }
}
