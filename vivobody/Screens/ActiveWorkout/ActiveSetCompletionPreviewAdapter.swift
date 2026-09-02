//
//  ActiveSetCompletionPreviewAdapter.swift
//  vivobody
//
//  DEBUG-only in-memory completion adapter for standalone galleries and
//  previews. Production completion always crosses WorkoutSessionController's
//  persistence boundary.
//

#if DEBUG
    import SwiftUI
    import VivoKit

    @MainActor
    enum ActiveSetCompletionPreviewAdapter {
        static func actions(
            session: WorkoutSession,
            unit: WeightUnit,
            reduceMotion: Bool
        ) -> ActiveSetCompletionActions {
            ActiveSetCompletionActions(
                commit: { intent in
                    commit(
                        intent,
                        session: session,
                        unit: unit,
                        reduceMotion: reduceMotion
                    )
                },
                currentSelection: { session.activeExerciseIndex },
                applyRoute: { route in
                    apply(
                        route,
                        session: session,
                        reduceMotion: reduceMotion
                    )
                },
                onCommitted: {}
            )
        }

        private static func commit(
            _ intent: ActiveSetCompletionIntent,
            session: WorkoutSession,
            unit: WeightUnit,
            reduceMotion: Bool
        ) -> ActiveSetCompletionResult {
            guard session.id == intent.sessionID,
                  session.completedAt == nil
            else { return .staleRequest }
            guard let exercise = session.exercises.first(where: { $0.id == intent.exerciseID }),
                  session.activeSet(for: exercise)?.id == intent.setID
            else { return .invalidRequest }

            let record = LivePersonalRecord.evaluate(
                intent.personalRecordCandidate,
                history: [:]
            )
            let payload = record.flatMap {
                ActivePersonalRecordPresentation.payload(
                    for: $0,
                    candidate: intent.personalRecordCandidate,
                    unit: unit
                )
            }
            let outcome = withAnimation(
                reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)
            ) {
                session.completeActiveSet(for: exercise)
            }
            if let payload {
                session.pendingPRValue = payload.value
                session.pendingPRUnit = payload.unit
                session.pendingPRDetail = payload.detail
            }
            return .committed(
                CommittedActiveSetCompletion(
                    domainOutcome: outcome,
                    exercise: exercise,
                    session: session
                )
            )
        }

        private static func apply(
            _ route: ActiveSetCompletionRoute,
            session: WorkoutSession,
            reduceMotion: Bool
        ) {
            switch route {
            case .stay:
                break
            case let .immediate(targetIndex, animated):
                setSelection(
                    targetIndex,
                    animated: animated,
                    session: session,
                    reduceMotion: reduceMotion
                )
            case let .guardedDelayed(targetIndex, playsHandoffFeedback):
                setSelection(
                    targetIndex,
                    animated: true,
                    session: session,
                    reduceMotion: reduceMotion
                )
                if playsHandoffFeedback {
                    Haptics.soft(playsSound: false)
                }
            }
        }

        private static func setSelection(
            _ index: Int,
            animated: Bool,
            session: WorkoutSession,
            reduceMotion: Bool
        ) {
            guard 0 ... session.orderedExercises.count ~= index else { return }
            withAnimation(animated && !reduceMotion
                ? .spring(response: 0.55, dampingFraction: 0.85)
                : nil)
            {
                session.activeExerciseIndex = index
            }
        }
    }
#endif
