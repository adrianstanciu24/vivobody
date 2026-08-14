//
//  SessionSideEffects.swift
//  vivobody
//
//  Single fan-out point for workout session lifecycle events.
//  Every restore / start / update / archive / discard routes through here
//  so adding a future subscriber (watch sync, Analytics, etc.) is
//  one new line in one file, not a scattergun edit across AppState,
//  AppRoot, and every active-workout screen.
//

import SwiftData

/// The moments in a session's lifetime that trigger side effects.
enum SessionEvent {
    /// A new draft session was inserted and saved.
    case started
    /// A set was completed or rest state changed mid-workout.
    case updated
    /// The final value of a scrub interaction was persisted.
    /// Expensive external presentation updates coalesce independently.
    case scrubSettled
    /// The session was stamped `completedAt` and archived to history.
    case archived
    /// The session was thrown away without archiving.
    case discarded
}

@MainActor
enum SessionSideEffects {
    /// Reconcile external active-workout presentation with the session that
    /// survived relaunch. A missing session also clears any stale ActivityKit
    /// state and publishes an empty active-workout widget snapshot.
    static func restore(
        _ session: WorkoutSession?,
        in context: ModelContext
    ) {
        if let session {
            WorkoutLiveActivityController.start(for: session)
        } else {
            WorkoutLiveActivityController.end(for: nil)
        }
        WidgetSnapshotWriter.writeActiveWorkout(in: context)
    }

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

        case .scrubSettled:
            WorkoutLiveActivityController.scheduleSettledScrubUpdate(for: session)
            WidgetSnapshotWriter.writeActiveWorkout(in: context)

        case .archived:
            WorkoutLiveActivityController.end(for: session)
            HealthKitWorkoutService.saveWorkout(for: session, in: context)
            WidgetSnapshotWriter.writeAll(in: context)
            ReviewRequestController.requestReviewIfEligible(afterArchiving: session, in: context)

        case .discarded:
            WorkoutLiveActivityController.end(for: session)
            WidgetSnapshotWriter.writeAll(in: context)
        }
    }
}
