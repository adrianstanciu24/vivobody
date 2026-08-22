//
//  WorkoutExerciseReplacementTests.swift
//  vivobodyTests
//
//  Guards atomic replacement of a pending active-workout exercise: session
//  structure survives, candidate history/defaults seed fresh model rows, and
//  stale or already-started requests cannot mutate the persisted draft.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct WorkoutExerciseReplacementTests {
    private struct Harness {
        let container: ModelContainer
        let context: ModelContext
        let appState: AppState
        let session: WorkoutSession
    }

    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeContainer() throws -> ModelContainer {
        let schema = VivobodyStore.schema
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    private func candidate() -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            catalogID: "incline-dumbbell-bench-press",
            familyID: "diagonal-press",
            name: "Incline Dumbbell Bench Press",
            group: .chest,
            defaultWeight: 35,
            defaultReps: 10,
            equipment: .dumbbell,
            mechanic: .compound,
            trainingRole: .push,
            pattern: .push,
            direction: .diagonal,
            planes: [.sagittal, .transverse],
            laterality: .bilateral
        )
    }

    private func sourceExercise(
        id: UUID = UUID(),
        completedSetIndex: Int? = nil
    ) -> Exercise {
        let exercise = Exercise(
            id: id,
            name: "Source Barbell Press",
            catalogID: "source-barbell-press",
            familyID: "horizontal-press",
            group: .shoulders,
            plannedSets: 4,
            plannedReps: 3,
            plannedWeight: 999,
            classification: ExerciseClassification(
                equipment: .barbell,
                mechanic: .compound,
                trainingRole: .push,
                pattern: .push,
                direction: .horizontal,
                planes: [.transverse],
                laterality: .unilateral
            ),
            sortOrder: 4
        )
        for (index, set) in exercise.orderedSets.enumerated() {
            set.weight = 900 + Double(index)
            set.reps = index + 1
            set.repsInReserve = 0
            set.rirLogged = true
            set.isCompleted = index == completedSetIndex
        }
        return exercise
    }

    private func catalogExercise(
        from item: ExerciseCatalogItem,
        trackingMode: TrackingMode = .reps,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external
    ) -> Exercise {
        Exercise(
            name: item.name,
            catalogItemID: item.id,
            catalogID: item.catalogID,
            familyID: item.familyID,
            group: item.group,
            plannedSets: 0,
            plannedReps: item.defaultReps,
            plannedWeight: item.defaultWeightSeed,
            muscleInvolvement: item.muscleInvolvement,
            classification: item.classification,
            trackingMode: trackingMode,
            modality: modality,
            loadMode: loadMode,
            plannedDuration: item.defaultDuration
        )
    }

    private func appendSet(
        weight: Double,
        reps: Int,
        duration: TimeInterval = 0,
        completed: Bool,
        to exercise: Exercise
    ) {
        exercise.sets.append(
            WorkoutSet(
                weight: weight,
                reps: reps,
                duration: duration,
                isCompleted: completed,
                sortOrder: exercise.sets.count
            )
        )
    }

    private func archivedSession(
        exercise: Exercise,
        daysAfterBase: Double
    ) -> WorkoutSession {
        let date = baseDate.addingTimeInterval(daysAfterBase * 86400)
        let session = WorkoutSession(exercises: [exercise], startedAt: date)
        session.completedAt = date
        return session
    }

    private func harness(
        source: Exercise,
        candidate item: ExerciseCatalogItem,
        archives: [WorkoutSession] = []
    ) throws -> Harness {
        let container = try makeContainer()
        let context = ModelContext(container)
        let supersetID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        source.supersetID = supersetID

        let first = Exercise(
            name: "First Exercise",
            group: .back,
            plannedSets: 1,
            plannedWeight: 100,
            sortOrder: 1
        )
        let partner = Exercise(
            name: "Superset Partner",
            group: .arms,
            plannedSets: 4,
            plannedWeight: 20,
            sortOrder: 8
        )
        partner.supersetID = supersetID
        let session = WorkoutSession(
            exercises: [first, source, partner],
            startedAt: baseDate.addingTimeInterval(10 * 86400)
        )
        session.activeExerciseIndex = 2

        context.insert(item)
        for archive in archives {
            context.insert(archive)
        }
        context.insert(session)
        try context.save()

        let appState = AppState()
        appState.workout.modelContext = context
        appState.workout.activeSession = session
        return Harness(
            container: container,
            context: context,
            appState: appState,
            session: session
        )
    }

    private func assertReadOnlyStoreRollback(
        at storeURL: URL,
        schema: Schema,
        sessionID: UUID,
        sourceID: UUID
    ) throws {
        try autoreleasepool {
            let configuration = ModelConfiguration(
                "replacement",
                schema: schema,
                url: storeURL,
                allowsSave: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            let context = ModelContext(container)
            let session = try #require(
                try context.fetch(FetchDescriptor<WorkoutSession>())
                    .first { $0.id == sessionID }
            )
            let itemID = candidate().id
            let item = try #require(
                try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
                    .first { $0.id == itemID }
            )
            let originalExerciseIDs = Set(session.exercises.map(\.id))
            let originalSetIDs = try Set(
                #require(session.exercises.first { $0.id == sourceID }).sets.map(\.id)
            )
            let controller = WorkoutSessionController()
            controller.modelContext = context
            controller.activeSession = session

            let result = controller.replacePendingExercise(
                sessionID: sessionID,
                exerciseID: sourceID,
                with: item
            )

            #expect(result == .saveFailed)
            #expect(controller.lastSaveError != nil)
            #expect(!context.hasChanges)
            #expect(Set(session.exercises.map(\.id)) == originalExerciseIDs)
            let restored = try #require(session.exercises.first { $0.id == sourceID })
            #expect(Set(restored.sets.map(\.id)) == originalSetIDs)
            #expect(session.activeExerciseIndex == 0)
        }
    }

    @Test func replacementPreservesLiveSetCountAndUsesCompatibleCandidateHistory() throws {
        let item = candidate()
        let compatible = catalogExercise(from: item)
        appendSet(weight: 55, reps: 8, completed: true, to: compatible)
        appendSet(weight: 50, reps: 10, completed: true, to: compatible)
        appendSet(weight: 777, reps: 1, completed: false, to: compatible)

        let incompatible = catalogExercise(
            from: item,
            trackingMode: .duration,
            modality: .isometricStrength,
            loadMode: .nonComparable
        )
        appendSet(
            weight: 0,
            reps: 0,
            duration: 90,
            completed: true,
            to: incompatible
        )

        let sourceID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000000003"))
        let source = sourceExercise(id: sourceID)
        // History-backed and per-set exercises use zero as the uniform-plan
        // sentinel while their live relationship still owns the real set count.
        source.plannedSets = 0
        #expect(source.orderedSets.count == 4)
        let sourceSetIDs = Set(source.sets.map(\.id))
        let historySetIDs = Set(compatible.sets.map(\.id))
        let expectedSupersetID = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000002"))
        let harness = try harness(
            source: source,
            candidate: item,
            archives: [
                archivedSession(exercise: compatible, daysAfterBase: 1),
                archivedSession(exercise: incompatible, daysAfterBase: 2),
            ]
        )

        let result = harness.appState.workout.replacePendingExercise(
            sessionID: harness.session.id,
            exerciseID: sourceID,
            with: item
        )
        let replacementID: UUID
        switch result {
        case let .replaced(newExerciseID):
            replacementID = newExerciseID
        default:
            Issue.record("Expected a successful replacement, got \(result)")
            return
        }

        #expect(harness.session.activeExerciseIndex == 2)
        #expect(harness.session.orderedExercises.map(\.name) == [
            "First Exercise",
            "Incline Dumbbell Bench Press",
            "Superset Partner",
        ])
        let replacement = try #require(
            harness.session.exercises.first { $0.id == replacementID }
        )
        #expect(replacement.id != sourceID)
        #expect(replacement.sortOrder == 4)
        #expect(replacement.supersetID == expectedSupersetID)
        #expect(replacement.plannedSets == 4)
        #expect(replacement.orderedSets.count == 4)
        #expect(replacement.orderedSets.map(\.weight) == [55, 50, 50, 50])
        #expect(replacement.orderedSets.map(\.reps) == [8, 10, 10, 10])
        #expect(replacement.orderedSets.allSatisfy { !$0.isCompleted })
        #expect(replacement.orderedSets.allSatisfy { !$0.rirLogged })
        #expect(replacement.orderedSets.allSatisfy { $0.repsInReserve == 2 })
        #expect(replacement.orderedSets.map(\.plannedWeight) == [55, 50, 50, 50])
        #expect(sourceSetIDs.isDisjoint(with: Set(replacement.sets.map(\.id))))
        #expect(historySetIDs.isDisjoint(with: Set(replacement.sets.map(\.id))))

        #expect(replacement.catalogItemID == item.id)
        #expect(replacement.catalogID == item.catalogID)
        #expect(replacement.familyID == item.familyID)
        #expect(replacement.group == item.group)
        #expect(replacement.equipmentRaw == Equipment.dumbbell.rawValue)
        #expect(replacement.directionRaw == PushPullDirection.diagonal.rawValue)
        #expect(replacement.planeRaws == item.planes.map(\.rawValue))
        #expect(replacement.lateralityRaw == Laterality.bilateral.rawValue)
        #expect(!harness.session.exercises.contains { $0.id == sourceID })
        #expect(!harness.context.hasChanges)
    }

    @Test func replacementFactoryFallsBackToCandidateDefaultsWithFreshIdentity() {
        let item = candidate()
        let replacement = Exercise.replacement(
            from: item,
            history: nil,
            requestedSetCount: 2,
            sortOrder: 6
        )

        #expect(replacement.sortOrder == 6)
        #expect(replacement.plannedSets == 2)
        #expect(replacement.plannedWeight == item.defaultWeightSeed)
        #expect(replacement.plannedReps == item.defaultReps)
        #expect(replacement.orderedSets.count == 2)
        #expect(replacement.orderedSets.allSatisfy {
            $0.weight == item.defaultWeightSeed
                && $0.reps == item.defaultReps
                && $0.duration == item.defaultDuration
                && !$0.isCompleted
        })
        #expect(Set(replacement.sets.map(\.id)).count == 2)
    }

    @Test func replacementFactoryCannotCreateAnEmptyExercise() {
        let item = candidate()
        let replacement = Exercise.replacement(
            from: item,
            history: nil,
            requestedSetCount: 0,
            sortOrder: 0
        )

        #expect(replacement.plannedSets == 1)
        #expect(replacement.orderedSets.count == 1)
    }

    @Test func completedSourceBlocksWithoutMutatingTheDraft() throws {
        let item = candidate()
        let source = sourceExercise(completedSetIndex: 1)
        let harness = try harness(source: source, candidate: item)
        let exerciseIDs = Set(harness.session.exercises.map(\.id))
        let setIDs = Set(source.sets.map(\.id))

        let result = harness.appState.workout.replacePendingExercise(
            sessionID: harness.session.id,
            exerciseID: source.id,
            with: item
        )

        #expect(result == .blocked(.exerciseAlreadyStarted))
        #expect(Set(harness.session.exercises.map(\.id)) == exerciseIDs)
        #expect(Set(source.sets.map(\.id)) == setIDs)
        #expect(source.orderedSets[1].isCompleted)
        #expect(harness.session.activeExerciseIndex == 2)
        #expect(!harness.context.hasChanges)
        #expect(harness.appState.workout.lastSaveError == nil)
    }

    @Test func staleSessionAndMissingExerciseBlockBeforeMutation() throws {
        let item = candidate()
        let source = sourceExercise()
        let harness = try harness(source: source, candidate: item)
        let exerciseIDs = Set(harness.session.exercises.map(\.id))

        let staleResult = harness.appState.workout.replacePendingExercise(
            sessionID: UUID(),
            exerciseID: source.id,
            with: item
        )
        let missingResult = harness.appState.workout.replacePendingExercise(
            sessionID: harness.session.id,
            exerciseID: UUID(),
            with: item
        )

        #expect(staleResult == .blocked(.staleSession))
        #expect(missingResult == .blocked(.exerciseNotFound))
        #expect(Set(harness.session.exercises.map(\.id)) == exerciseIDs)
        #expect(harness.session.activeExerciseIndex == 2)
        #expect(!harness.context.hasChanges)
    }

    @Test func saveFailureRollsBackTheRelationshipSwap() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkoutExerciseReplacementTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let schema = VivobodyStore.schema
        let storeURL = temporaryDirectory.appendingPathComponent("replacement.store")
        let sessionID = try #require(UUID(uuidString: "40000000-0000-0000-0000-000000000004"))
        let sourceID = try #require(UUID(uuidString: "50000000-0000-0000-0000-000000000005"))
        try autoreleasepool {
            let writableConfiguration = ModelConfiguration(
                "replacement",
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let writableContainer = try ModelContainer(
                for: schema,
                configurations: [writableConfiguration]
            )
            let writableContext = ModelContext(writableContainer)
            let session = WorkoutSession(
                id: sessionID,
                exercises: [sourceExercise(id: sourceID)]
            )
            writableContext.insert(candidate())
            writableContext.insert(session)
            try writableContext.save()
        }

        try assertReadOnlyStoreRollback(
            at: storeURL,
            schema: schema,
            sessionID: sessionID,
            sourceID: sourceID
        )
    }
}
