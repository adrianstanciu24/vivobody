//
//  WorkoutLiveActivityController.swift
//  vivobody
//
//  Starts, updates, and ends the Active Workout Live Activity from
//  the app process. Updates are local because workouts are edited
//  while the app is foregrounded/alive.
//

import ActivityKit
import Foundation

@MainActor
enum WorkoutLiveActivityController {
    static func start(for session: WorkoutSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard Activity<WorkoutActivityAttributes>.activities.isEmpty else {
            update(for: session)
            return
        }

        Task {
            do {
                _ = try Activity.request(
                    attributes: WorkoutActivityAttributes(
                        sessionStartedAt: session.startedAt,
                        totalExercises: session.orderedExercises.count
                    ),
                    content: ActivityContent(state: contentState(for: session), staleDate: nil),
                    pushType: nil
                )
            } catch {
                // Live Activity failure should never block logging.
            }
        }
    }

    static func update(for session: WorkoutSession) {
        let content = ActivityContent(state: contentState(for: session), staleDate: nil)
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    static func end(for session: WorkoutSession?) {
        let state = session.map(contentState(for:)) ?? inactiveState
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
    }

    private static func contentState(for session: WorkoutSession) -> WorkoutActivityAttributes.ContentState {
        let exercises = session.orderedExercises
        let safeIndex = min(max(session.activeExerciseIndex, 0), max(exercises.count - 1, 0))
        let exercise = exercises.indices.contains(safeIndex) ? exercises[safeIndex] : nil
        let activeIndex = exercise.flatMap { session.activeSetIndex(for: $0) } ?? 0
        let set = exercise.flatMap { session.activeSet(for: $0) }

        return WorkoutActivityAttributes.ContentState(
            exerciseName: exercise?.name ?? "Workout",
            exerciseIndex: safeIndex,
            setNumber: activeIndex + 1,
            plannedSets: exercise?.orderedSets.count ?? 0,
            setSpec: set.map { setSpec(for: $0, exercise: exercise) } ?? "",
            isResting: session.isResting,
            restEndsAt: session.restEndsAt,
            restDuration: session.restDuration,
            totalVolume: session.totalVolume,
            totalSetsCompleted: session.totalSets
        )
    }

    private static var inactiveState: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            exerciseName: "Workout",
            exerciseIndex: 0,
            setNumber: 0,
            plannedSets: 0,
            setSpec: "",
            isResting: false,
            restEndsAt: nil,
            restDuration: 0,
            totalVolume: 0,
            totalSetsCompleted: 0
        )
    }

    private static func setSpec(for set: WorkoutSet, exercise: Exercise?) -> String {
        guard let exercise else { return "" }
        let unit = WeightUnit.current
        switch exercise.trackingMode {
        case .reps:
            return "\(WeightFormatter.string(set.weight, unit: unit, includeUnit: false)) x \(set.reps)"
        case .duration:
            let duration = DurationFormatter.compact(set.duration)
            guard set.weight > 0 else { return duration }
            return "\(WeightFormatter.string(set.weight, unit: unit, includeUnit: false)) x \(duration)"
        }
    }
}
