//
//  SessionSideEffects.swift
//  vivobody
//
//  Single fan-out point for workout session lifecycle events.
//  Every start / update / archive / discard routes through here
//  so adding a future subscriber (watch sync, Analytics, etc.) is
//  one new line in one file, not a scattergun edit across AppState,
//  AppRoot, and every active-workout screen.
//

import SwiftData

/// The four moments in a session's lifetime that trigger side effects.
enum SessionEvent {
    /// A new draft session was inserted and saved.
    case started
    /// A set was completed or rest state changed mid-workout.
    case updated
    /// The session was stamped `completedAt` and archived to history.
    case archived
    /// The session was thrown away without archiving.
    case discarded
}

@MainActor
enum SessionSideEffects {
    static func handle(
        _ event: SessionEvent,
        session: WorkoutSession,
        in context: ModelContext
    ) {
        switch event {
        case .started:
            WorkoutLiveActivityController.start(for: session)
            WidgetSnapshotWriter.writeAll(in: context)
            RestNotificationController.requestAuthorizationIfNeeded()

        case .updated:
            WorkoutLiveActivityController.update(for: session)
            WidgetSnapshotWriter.writeActiveWorkout(in: context)

        case .archived:
            WorkoutLiveActivityController.end(for: session)
            HealthKitWorkoutService.saveWorkout(for: session, in: context)
            WidgetSnapshotWriter.writeAll(in: context)

        case .discarded:
            WorkoutLiveActivityController.end(for: session)
            WidgetSnapshotWriter.writeAll(in: context)
        }
    }
}
