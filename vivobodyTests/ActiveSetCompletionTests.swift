//
//  ActiveSetCompletionTests.swift
//  vivobodyTests
//
//  Guards the controller-owned active-set transaction: exact request
//  validation, one committed mutation, and full SwiftData rollback when the
//  completion cannot be persisted.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct ActiveSetCompletionTests {
    private struct Harness {
        let container: ModelContainer
        let context: ModelContext
        let controller: WorkoutSessionController
        let session: WorkoutSession
        let exercise: Exercise
    }

    @MainActor
    private final class ControlledSleeper {
        private struct Wait {
            let id: UUID
            let delay: ActiveSetCompletionDelay
            let continuation: CheckedContinuation<Void, any Error>
        }

        private var waits: [Wait] = []
        private(set) var suspensionCount = 0

        var pendingDelays: [ActiveSetCompletionDelay] {
            waits.map(\.delay)
        }

        func sleep(_ delay: ActiveSetCompletionDelay) async throws {
            try Task.checkCancellation()
            let id = UUID()
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    suspensionCount += 1
                    waits.append(
                        Wait(id: id, delay: delay, continuation: continuation)
                    )
                }
            } onCancel: {
                Task { @MainActor in
                    self.cancel(id: id)
                }
            }
        }

        func advance(_ delay: ActiveSetCompletionDelay) {
            guard let index = waits.firstIndex(where: { $0.delay == delay }) else {
                Issue.record("No pending \(delay) delay to advance")
                return
            }
            waits.remove(at: index).continuation.resume()
        }

        private func cancel(id: UUID) {
            guard let index = waits.firstIndex(where: { $0.id == id }) else { return }
            waits.remove(at: index).continuation.resume(throwing: CancellationError())
        }
    }

    private func exercise(
        id: UUID = UUID(),
        setCount: Int = 2
    ) -> Exercise {
        let exercise = Exercise(
            id: id,
            name: "Bench Press",
            catalogID: "bench-press",
            group: .chest,
            plannedSets: setCount,
            plannedReps: 8,
            plannedWeight: 135
        )
        exercise.orderedSets.first?.weight = 155
        exercise.orderedSets.first?.reps = 6
        return exercise
    }

    private func harness(exercise: Exercise? = nil) throws -> Harness {
        let configuration = ModelConfiguration(
            schema: VivobodyStore.schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: VivobodyStore.schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let exercise = exercise ?? self.exercise()
        let session = WorkoutSession(exercises: [exercise], restDuration: 90)
        context.insert(session)
        try context.save()
        let controller = WorkoutSessionController()
        controller.modelContext = context
        controller.activeSession = session
        return Harness(
            container: container,
            context: context,
            controller: controller,
            session: session,
            exercise: exercise
        )
    }

    private func request(
        for harness: Harness,
        sessionID: UUID? = nil,
        exerciseID: UUID? = nil,
        setID: UUID? = nil,
        personalRecord: ActiveSetPersonalRecordPayload? = nil
    ) throws -> ActiveSetCompletionRequest {
        try ActiveSetCompletionRequest(
            sessionID: sessionID ?? harness.session.id,
            exerciseID: exerciseID ?? harness.exercise.id,
            expectedActiveSetID: setID ?? #require(
                harness.session.activeSet(for: harness.exercise)?.id
            ),
            personalRecord: personalRecord
        )
    }

    private func intent(
        setID: UUID = UUID()
    ) -> ActiveSetCompletionIntent {
        ActiveSetCompletionIntent(
            sessionID: UUID(),
            exerciseID: UUID(),
            setID: setID,
            personalRecordCandidate: LivePersonalRecordCandidate(
                exerciseName: "Bench Press",
                catalogItemID: nil,
                catalogID: "bench-press",
                performanceSignature: ExercisePerformanceSignature(
                    modality: .dynamicStrength,
                    trackingMode: .reps,
                    loadMode: .external,
                    bodyweightFraction: 0
                ),
                loadProfile: ExerciseLoadProfile(
                    mode: .external,
                    bodyweightFraction: 0
                ),
                bodyweight: 0,
                loggedWeight: 135,
                repetitions: 8,
                duration: 0,
                priorInSessionPerformances: []
            )
        )
    }

    private func completion(
        outcome: CommittedSetCompletionOutcome,
        completedExerciseID: UUID,
        exercises: [ActiveSetCompletionExerciseSnapshot],
        isAllComplete: Bool = false
    ) -> CommittedActiveSetCompletion {
        CommittedActiveSetCompletion(
            completedExerciseID: completedExerciseID,
            outcome: outcome,
            orderedExercises: exercises,
            isAllComplete: isAllComplete
        )
    }

    private func waitUntil(
        _ description: String,
        condition: @escaping () -> Bool
    ) async {
        for _ in 0 ..< 200 {
            if condition() { return }
            await Task.yield()
        }
        Issue.record("Timed out waiting for \(description)")
    }

    @Test func completionCommitsCarryForwardRestAndPersonalRecordTogether() throws {
        let harness = try harness()
        let payload = ActiveSetPersonalRecordPayload(
            value: "155",
            unit: "lb",
            detail: "Bench Press · New max"
        )

        let completionRequest = try request(
            for: harness,
            personalRecord: payload
        )
        var personalRecordWasAbsentDuringMutation = false
        let result = harness.controller.completeActiveSet(
            completionRequest,
            performMutation: { mutation in
                let outcome = mutation()
                personalRecordWasAbsentDuringMutation =
                    harness.session.pendingPRValue == nil
                return outcome
            }
        )

        guard case let .committed(completion) = result else {
            Issue.record("Expected a committed result, got \(result)")
            return
        }
        #expect(completion.completedExerciseID == harness.exercise.id)
        #expect(completion.outcome == .rest)
        #expect(!completion.isAllComplete)
        #expect(completion.orderedExercises == [
            ActiveSetCompletionExerciseSnapshot(
                id: harness.exercise.id,
                supersetID: nil,
                isComplete: false
            ),
        ])
        #expect(harness.exercise.orderedSets[0].isCompleted)
        #expect(harness.exercise.orderedSets[1].weight == 155)
        #expect(harness.exercise.orderedSets[1].reps == 6)
        #expect(harness.session.isResting)
        #expect(harness.session.restStartedAt != nil)
        #expect(harness.session.restEndsAt != nil)
        #expect(harness.session.pendingPRValue == payload.value)
        #expect(harness.session.pendingPRUnit == payload.unit)
        #expect(harness.session.pendingPRDetail == payload.detail)
        #expect(personalRecordWasAbsentDuringMutation)
        #expect(!harness.context.hasChanges)
    }

    @Test func externalCompletionPersistsSupersetPositionBeforeExpanding() throws {
        let first = exercise()
        let second = Exercise(
            name: "Bent-Over Row",
            catalogID: "bent-over-row",
            group: .back,
            plannedSets: 2,
            plannedReps: 8,
            plannedWeight: 115,
            sortOrder: 1
        )
        let groupID = UUID()
        first.supersetID = groupID
        second.supersetID = groupID

        let configuration = ModelConfiguration(
            schema: VivobodyStore.schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: VivobodyStore.schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let session = WorkoutSession(exercises: [first, second])
        context.insert(session)
        try context.save()

        let appState = AppState()
        appState.selectedTab = .library
        let controller = appState.workout
        controller.modelContext = context
        controller.activeSession = session

        controller.completeActiveSet()

        #expect(first.orderedSets[0].isCompleted)
        #expect(session.activeExerciseIndex == 1)
        #expect(!session.isResting)
        #expect(controller.isWorkoutExpanded)
        #expect(appState.selectedTab == .today)
        #expect(!context.hasChanges)
    }

    @Test func externalCompletionStillExpandsWhenNoPendingSetExists() throws {
        let completedExercise = exercise(setCount: 1)
        completedExercise.orderedSets[0].isCompleted = true
        let configuration = ModelConfiguration(
            schema: VivobodyStore.schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: VivobodyStore.schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let session = WorkoutSession(exercises: [completedExercise])
        context.insert(session)
        try context.save()

        let appState = AppState()
        appState.selectedTab = .library
        let controller = appState.workout
        controller.modelContext = context
        controller.activeSession = session

        controller.completeActiveSet()

        #expect(controller.isWorkoutExpanded)
        #expect(appState.selectedTab == .today)
        #expect(!context.hasChanges)
    }

    @Test func staleInvalidAndMissingPersistenceRequestsDoNotMutate() throws {
        let harness = try harness()
        let activeSetID = try #require(
            harness.session.activeSet(for: harness.exercise)?.id
        )

        #expect(
            try harness.controller.completeActiveSet(
                request(for: harness, sessionID: UUID())
            ) == .staleRequest
        )
        #expect(
            try harness.controller.completeActiveSet(
                request(for: harness, exerciseID: UUID())
            ) == .invalidRequest
        )
        #expect(
            try harness.controller.completeActiveSet(
                request(for: harness, setID: UUID())
            ) == .invalidRequest
        )

        harness.controller.modelContext = nil
        #expect(
            try harness.controller.completeActiveSet(
                request(for: harness)
            ) == .persistenceUnavailable
        )
        #expect(harness.session.activeSet(for: harness.exercise)?.id == activeSetID)
        #expect(harness.exercise.orderedSets.allSatisfy { !$0.isCompleted })
        #expect(!harness.session.isResting)
        #expect(!harness.context.hasChanges)
        #expect(harness.controller.lastSaveError == nil)
    }

    @Test func saveFailureRollsBackEveryCompletionField() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ActiveSetCompletionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("completion.store")
        let sessionID = UUID()
        let exerciseID = UUID()
        let setID: UUID = try autoreleasepool {
            let configuration = ModelConfiguration(
                "completion",
                schema: VivobodyStore.schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: VivobodyStore.schema,
                configurations: [configuration]
            )
            let context = ModelContext(container)
            let exercise = exercise(id: exerciseID)
            let session = WorkoutSession(
                id: sessionID,
                exercises: [exercise],
                restDuration: 90
            )
            context.insert(session)
            try context.save()
            return try #require(session.activeSet(for: exercise)?.id)
        }

        try autoreleasepool {
            let configuration = ModelConfiguration(
                "completion",
                schema: VivobodyStore.schema,
                url: storeURL,
                allowsSave: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: VivobodyStore.schema,
                configurations: [configuration]
            )
            let context = ModelContext(container)
            let session = try #require(
                try context.fetch(FetchDescriptor<WorkoutSession>())
                    .first { $0.id == sessionID }
            )
            let exercise = try #require(
                session.exercises.first { $0.id == exerciseID }
            )
            let controller = WorkoutSessionController()
            controller.modelContext = context
            controller.activeSession = session
            let payload = ActiveSetPersonalRecordPayload(
                value: "155",
                unit: "lb",
                detail: "Bench Press · New max"
            )

            let result = controller.completeActiveSet(
                ActiveSetCompletionRequest(
                    sessionID: sessionID,
                    exerciseID: exerciseID,
                    expectedActiveSetID: setID,
                    personalRecord: payload
                )
            )

            #expect(result == .saveFailed)
            #expect(controller.lastSaveError != nil)
            #expect(!context.hasChanges)
            #expect(exercise.orderedSets.allSatisfy { !$0.isCompleted })
            #expect(exercise.orderedSets[1].weight == 135)
            #expect(exercise.orderedSets[1].reps == 8)
            #expect(!session.isResting)
            #expect(session.restStartedAt == nil)
            #expect(session.restEndsAt == nil)
            #expect(session.pendingPRValue == nil)
            #expect(session.pendingPRUnit == nil)
            #expect(session.pendingPRDetail == nil)
        }
    }

    @Test func routePlannerMapsEveryOutcomeAndSkipsFinishedSupersetSiblings() {
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()
        let groupID = UUID()
        let exercises = [
            ActiveSetCompletionExerciseSnapshot(
                id: firstID,
                supersetID: groupID,
                isComplete: true
            ),
            ActiveSetCompletionExerciseSnapshot(
                id: secondID,
                supersetID: groupID,
                isComplete: true
            ),
            ActiveSetCompletionExerciseSnapshot(
                id: thirdID,
                supersetID: nil,
                isComplete: false
            ),
        ]

        #expect(
            ActiveSetCompletionRoutePlanner.route(
                after: completion(
                    outcome: .none,
                    completedExerciseID: firstID,
                    exercises: exercises
                )
            ) == .stay
        )
        #expect(
            ActiveSetCompletionRoutePlanner.route(
                after: completion(
                    outcome: .rest,
                    completedExerciseID: firstID,
                    exercises: exercises
                )
            ) == .stay
        )
        #expect(
            ActiveSetCompletionRoutePlanner.route(
                after: completion(
                    outcome: .supersetPartner(secondID),
                    completedExerciseID: firstID,
                    exercises: exercises
                )
            ) == .guardedDelayed(targetIndex: 1, playsHandoffFeedback: true)
        )
        #expect(
            ActiveSetCompletionRoutePlanner.route(
                after: completion(
                    outcome: .supersetRoundRest(resume: firstID),
                    completedExerciseID: secondID,
                    exercises: exercises
                )
            ) == .immediate(targetIndex: 0, animated: false)
        )
        #expect(
            ActiveSetCompletionRoutePlanner.route(
                after: completion(
                    outcome: .exerciseComplete,
                    completedExerciseID: firstID,
                    exercises: exercises
                )
            ) == .guardedDelayed(targetIndex: 2, playsHandoffFeedback: false)
        )
        #expect(
            ActiveSetCompletionRoutePlanner.route(
                after: completion(
                    outcome: .exerciseComplete,
                    completedExerciseID: firstID,
                    exercises: exercises,
                    isAllComplete: true
                )
            ) == .immediate(targetIndex: 3, animated: true)
        )
    }

    @Test func coordinatorCancellationAtEitherDelayPreventsLateWork() async {
        let firstSleeper = ControlledSleeper()
        let firstCoordinator = ActiveSetCompletionCoordinator(sleep: firstSleeper.sleep)
        let firstIntent = intent()
        var firstCommitCount = 0
        var firstRoutes: [ActiveSetCompletionRoute] = []
        var preparedWithClosedGate = false
        firstCoordinator.start(
            setID: firstIntent.setID,
            prepare: {
                preparedWithClosedGate = !firstCoordinator.acceptsInput
                    && firstCoordinator.pendingSetID == firstIntent.setID
                return firstIntent
            },
            actions: ActiveSetCompletionActions(
                commit: { _ in
                    firstCommitCount += 1
                    return .saveFailed
                },
                currentSelection: { 0 },
                applyRoute: { firstRoutes.append($0) }
            )
        )
        await waitUntil("acknowledgement suspension") {
            firstSleeper.pendingDelays == [.acknowledgement]
        }
        #expect(preparedWithClosedGate)
        firstCoordinator.cancel()
        await Task.yield()
        #expect(firstCommitCount == 0)
        #expect(firstRoutes.isEmpty)
        #expect(firstCoordinator.pendingSetID == nil)
        #expect(firstCoordinator.acceptsInput)

        let secondSleeper = ControlledSleeper()
        let secondCoordinator = ActiveSetCompletionCoordinator(sleep: secondSleeper.sleep)
        let firstID = UUID()
        let secondID = UUID()
        let groupID = UUID()
        let delayedCompletion = completion(
            outcome: .supersetPartner(secondID),
            completedExerciseID: firstID,
            exercises: [
                ActiveSetCompletionExerciseSnapshot(
                    id: firstID,
                    supersetID: groupID,
                    isComplete: false
                ),
                ActiveSetCompletionExerciseSnapshot(
                    id: secondID,
                    supersetID: groupID,
                    isComplete: false
                ),
            ]
        )
        var secondRoutes: [ActiveSetCompletionRoute] = []
        let secondIntent = intent()
        secondCoordinator.start(
            setID: secondIntent.setID,
            prepare: { secondIntent },
            actions: ActiveSetCompletionActions(
                commit: { _ in .committed(delayedCompletion) },
                currentSelection: { 0 },
                applyRoute: { secondRoutes.append($0) }
            )
        )
        await waitUntil("second acknowledgement suspension") {
            secondSleeper.pendingDelays == [.acknowledgement]
        }
        secondSleeper.advance(.acknowledgement)
        await waitUntil("route suspension") {
            secondSleeper.pendingDelays == [.route]
        }
        #expect(secondCoordinator.acceptsInput)
        secondCoordinator.cancel()
        await Task.yield()
        #expect(secondRoutes.isEmpty)
    }

    @Test func coordinatorSupersedesEarlierAttemptAndRejectsFailedCommit() async {
        let sleeper = ControlledSleeper()
        let coordinator = ActiveSetCompletionCoordinator(sleep: sleeper.sleep)
        let first = intent()
        let second = intent()
        var committedSetIDs: [UUID] = []
        var routes: [ActiveSetCompletionRoute] = []
        var commitCleanupCount = 0
        var commitCleanupSawClosedGate = false
        let actions = ActiveSetCompletionActions(
            commit: { intent in
                committedSetIDs.append(intent.setID)
                return intent.setID == second.setID
                    ? .committed(
                        self.completion(
                            outcome: .rest,
                            completedExerciseID: intent.exerciseID,
                            exercises: []
                        )
                    )
                    : .saveFailed
            },
            currentSelection: { 0 },
            applyRoute: { routes.append($0) },
            onCommitted: {
                commitCleanupCount += 1
                commitCleanupSawClosedGate = !coordinator.acceptsInput
            }
        )

        coordinator.start(setID: first.setID, prepare: { first }, actions: actions)
        await waitUntil("first acknowledgement") {
            sleeper.pendingDelays.contains(.acknowledgement)
        }
        coordinator.start(setID: second.setID, prepare: { second }, actions: actions)
        await waitUntil("superseding acknowledgement") {
            sleeper.suspensionCount == 2
                && sleeper.pendingDelays == [.acknowledgement]
        }
        sleeper.advance(.acknowledgement)
        await waitUntil("superseding commit") {
            coordinator.pendingSetID == nil
        }

        #expect(committedSetIDs == [second.setID])
        #expect(routes == [.stay])
        #expect(coordinator.acceptsInput)
        #expect(commitCleanupCount == 1)
        #expect(commitCleanupSawClosedGate)

        let failed = intent()
        coordinator.start(
            setID: failed.setID,
            prepare: { failed },
            actions: ActiveSetCompletionActions(
                commit: { _ in .saveFailed },
                currentSelection: { 0 },
                applyRoute: { routes.append($0) }
            )
        )
        await waitUntil("failed acknowledgement") {
            sleeper.pendingDelays == [.acknowledgement]
        }
        sleeper.advance(.acknowledgement)
        await waitUntil("failed commit release") {
            coordinator.pendingSetID == nil
        }
        #expect(routes == [.stay])
        #expect(coordinator.acceptsInput)
        #expect(commitCleanupCount == 1)
    }

    @Test func manualSelectionDuringRouteDelayWins() async {
        let sleeper = ControlledSleeper()
        let coordinator = ActiveSetCompletionCoordinator(sleep: sleeper.sleep)
        let firstID = UUID()
        let secondID = UUID()
        let groupID = UUID()
        let committed = completion(
            outcome: .supersetPartner(secondID),
            completedExerciseID: firstID,
            exercises: [
                ActiveSetCompletionExerciseSnapshot(
                    id: firstID,
                    supersetID: groupID,
                    isComplete: false
                ),
                ActiveSetCompletionExerciseSnapshot(
                    id: secondID,
                    supersetID: groupID,
                    isComplete: false
                ),
            ]
        )
        var selection = 0
        var routes: [ActiveSetCompletionRoute] = []
        let intent = intent()
        coordinator.start(
            setID: intent.setID,
            prepare: { intent },
            actions: ActiveSetCompletionActions(
                commit: { _ in .committed(committed) },
                currentSelection: { selection },
                applyRoute: { routes.append($0) }
            )
        )
        await waitUntil("acknowledgement") {
            sleeper.pendingDelays == [.acknowledgement]
        }
        sleeper.advance(.acknowledgement)
        await waitUntil("guarded route") {
            sleeper.pendingDelays == [.route]
        }
        selection = 2
        sleeper.advance(.route)
        await waitUntil("manual-selection guard") {
            sleeper.pendingDelays.isEmpty
        }

        #expect(routes.isEmpty)
        #expect(selection == 2)
        #expect(coordinator.acceptsInput)
    }
}
