//
//  WorkoutLiveActivityController.swift
//  vivobody
//
//  Starts, updates, and ends the Active Workout Live Activity from
//  the app process. Semantic changes publish immediately. Rapid
//  settled scrub values use a separate trailing debounce, then enter
//  one serialized latest-value delivery pump so ActivityKit work can
//  never fan out into a task per detent.
//

import VivoKit
import ActivityKit
import Foundation

@MainActor
enum WorkoutLiveActivityController {
    private typealias ContentState = WorkoutActivityAttributes.ContentState

    private static let interactiveUpdateDelay = Duration.milliseconds(250)
    private static var pendingInteractiveTask: Task<Void, Never>?
    private static var pendingInteractiveState: ContentState?

    /// ActivityKit updates are delivered through one pump. While an update
    /// is awaiting the system, newer states replace the single queued value
    /// instead of spawning parallel tasks that can complete out of order.
    private static var updatePumpTask: Task<Void, Never>?
    private static var queuedUpdateState: ContentState?
    private static var inFlightUpdateState: ContentState?
    private static var lastDeliveredState: ContentState?
    private static var latestKnownState: ContentState?
    private static var deliveryGeneration = 0

    /// Starts always wait for the preceding end, and ends wait for any
    /// already-requested start. This prevents a delayed lifecycle Task from
    /// reviving or terminating the next workout's Live Activity.
    private static var startTask: Task<Void, Never>?
    private static var endTask: Task<Void, Never>?

    static func start(for session: WorkoutSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        cancelPendingInteractiveUpdate()

        let state = contentState(for: session)
        latestKnownState = state

        let attributes = WorkoutActivityAttributes(
            sessionStartedAt: session.startedAt,
            totalExercises: session.orderedExercises.count
        )
        let previousEnd = endTask
        startTask?.cancel()
        startTask = Task { @MainActor in
            if let previousEnd {
                await previousEnd.value
            }
            guard !Task.isCancelled else { return }

            let requestState = latestKnownState ?? state
            guard Activity<WorkoutActivityAttributes>.activities.isEmpty else {
                enqueueUpdate(requestState)
                return
            }

            do {
                _ = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: requestState, staleDate: nil),
                    pushType: nil
                )
                // If end() canceled us while ActivityKit was accepting the
                // request, its Task awaits this one and will end the newly
                // created activity. Do not publish any more updates here.
                guard !Task.isCancelled else { return }
                lastDeliveredState = requestState
                if let latestKnownState, latestKnownState != requestState {
                    enqueueUpdate(latestKnownState)
                }
            } catch {
                // Live Activity failure should never block logging.
            }
        }
    }

    /// Publish a semantic state change without debounce. This cancels any
    /// older interactive value waiting to be sent, while still using the
    /// serial pump to preserve ordering with an in-flight ActivityKit call.
    static func update(for session: WorkoutSession) {
        cancelPendingInteractiveUpdate()
        let state = contentState(for: session)
        latestKnownState = state
        enqueueUpdate(state)
    }

    /// Trailing debounce used only after a scrub has settled and saved.
    /// The immutable value snapshot is taken before sleeping; SwiftData
    /// models and ModelContext never cross an actor or suspension boundary.
    static func scheduleSettledScrubUpdate(for session: WorkoutSession) {
        let state = contentState(for: session)
        latestKnownState = state
        pendingInteractiveState = state
        pendingInteractiveTask?.cancel()
        pendingInteractiveTask = Task { @MainActor in
            do {
                try await Task.sleep(for: interactiveUpdateDelay)
            } catch {
                return
            }
            guard !Task.isCancelled, let state = pendingInteractiveState else { return }
            pendingInteractiveTask = nil
            pendingInteractiveState = nil
            enqueueUpdate(state)
        }
    }

    static func end(for session: WorkoutSession?) {
        cancelPendingInteractiveUpdate()
        queuedUpdateState = nil
        latestKnownState = nil
        lastDeliveredState = nil
        deliveryGeneration += 1

        let previousPump = updatePumpTask
        previousPump?.cancel()
        updatePumpTask = nil
        inFlightUpdateState = nil

        let previousStart = startTask
        previousStart?.cancel()
        startTask = nil
        let previousEnd = endTask

        let state = session.map(contentState(for:)) ?? inactiveState
        let content = ActivityContent(state: state, staleDate: nil)
        endTask = Task { @MainActor in
            if let previousEnd {
                await previousEnd.value
            }
            if let previousStart {
                await previousStart.value
            }
            if let previousPump {
                await previousPump.value
            }
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
    }

    private static func cancelPendingInteractiveUpdate() {
        pendingInteractiveTask?.cancel()
        pendingInteractiveTask = nil
        pendingInteractiveState = nil
    }

    private static func enqueueUpdate(_ state: ContentState) {
        if queuedUpdateState == state { return }
        if queuedUpdateState == nil {
            if inFlightUpdateState == state { return }
            if inFlightUpdateState == nil, lastDeliveredState == state { return }
        }

        queuedUpdateState = state
        startUpdatePumpIfNeeded()
    }

    private static func startUpdatePumpIfNeeded() {
        guard updatePumpTask == nil else { return }
        let generation = deliveryGeneration
        let pendingEnd = endTask
        let pendingStart = startTask

        updatePumpTask = Task { @MainActor in
            // A state for workout B must not be delivered to workout A's
            // activity while A is still ending. If B is still requesting
            // its activity, wait for that request before enumerating too.
            if let pendingEnd {
                await pendingEnd.value
            }
            if let pendingStart {
                await pendingStart.value
            }

            while !Task.isCancelled,
                  generation == deliveryGeneration,
                  let state = queuedUpdateState {
                queuedUpdateState = nil
                if lastDeliveredState == state { continue }

                inFlightUpdateState = state
                let content = ActivityContent(state: state, staleDate: nil)
                let activities = Activity<WorkoutActivityAttributes>.activities
                for activity in activities {
                    guard !Task.isCancelled, generation == deliveryGeneration else { break }
                    await activity.update(content)
                }

                guard !Task.isCancelled, generation == deliveryGeneration else { break }
                if !activities.isEmpty {
                    lastDeliveredState = state
                }
                inFlightUpdateState = nil
            }

            guard generation == deliveryGeneration else { return }
            inFlightUpdateState = nil
            updatePumpTask = nil
            if queuedUpdateState != nil {
                startUpdatePumpIfNeeded()
            }
        }
    }

    private static func contentState(for session: WorkoutSession) -> WorkoutActivityAttributes.ContentState {
        let exercises = session.orderedExercises
        let safeIndex = min(max(session.activeExerciseIndex, 0), max(exercises.count - 1, 0))
        let exercise = exercises.indices.contains(safeIndex) ? exercises[safeIndex] : nil
        let sets = exercise?.orderedSets ?? []
        let activeIndex = exercise.flatMap { session.activeSetIndex(for: $0) }
        // The pager can rest on a fully logged exercise (clamped down
        // from the summary card, or swiped back to). Reporting the first
        // incomplete set there would fabricate a phantom "Set 1", so
        // hold on the final set and flag the exercise as complete.
        let isExerciseComplete = exercise != nil && !sets.isEmpty && activeIndex == nil
        let set = activeIndex.map { sets[$0] } ?? sets.last

        return WorkoutActivityAttributes.ContentState(
            exerciseName: exercise?.name ?? "Workout",
            exerciseIndex: safeIndex,
            setNumber: (activeIndex ?? max(sets.count - 1, 0)) + 1,
            plannedSets: sets.count,
            setSpec: set.map { setSpec(for: $0, exercise: exercise) } ?? "",
            isResting: session.isResting,
            restEndsAt: session.restEndsAt,
            restDuration: session.restDuration,
            totalVolume: session.totalVolume,
            totalSetsCompleted: session.totalSets,
            isExerciseComplete: isExerciseComplete
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
            totalSetsCompleted: 0,
            isExerciseComplete: false
        )
    }

    private static func setSpec(for set: WorkoutSet, exercise: Exercise?) -> String {
        guard let exercise else { return "" }
        return SetSpecFormatter.format(
            weight: set.weight,
            reps: set.reps,
            duration: set.duration,
            trackingMode: exercise.trackingMode,
            loadMode: exercise.loadMode,
            unit: .current
        )
    }
}
