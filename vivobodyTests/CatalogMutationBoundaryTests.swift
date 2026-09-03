//
//  CatalogMutationBoundaryTests.swift
//  vivobodyTests
//
//  Characterizes catalog create, duplicate, edit, delete, and atomic-reset
//  transactions, including rollback and post-commit indexing order.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct CatalogMutationBoundaryTests {
    private enum ExpectedSaveError: Error {
        case failed
    }

    private func makeContext() throws -> ModelContext {
        let schema = VivobodyStore.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func makeDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "CatalogMutationBoundaryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }

    private func makeInput(
        name: String = "  Custom Press\n",
        group: MuscleGroup = .chest,
        defaultWeight: Double = 45,
        trackingMode: TrackingMode = .reps,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external,
        bodyweightFraction: Double = 0,
        defaultDuration: TimeInterval = 45,
        equipment: Equipment = .dumbbell,
        mechanic: Mechanic = .compound,
        trainingRole: TrainingRole = .push,
        pattern: MovementPattern? = .push,
        direction: PushPullDirection? = .horizontal,
        planes: [MovementPlane] = [.sagittal],
        laterality: Laterality = .bilateral,
        aliases: [String] = [" CP", "chest press custom ", "CP "]
    ) -> CatalogMutationInput {
        CatalogMutationInput(
            name: name,
            execution: nil,
            group: group,
            defaultWeight: defaultWeight,
            trackingMode: trackingMode,
            modality: modality,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction,
            defaultDuration: defaultDuration,
            equipment: equipment,
            mechanic: mechanic,
            trainingRole: trainingRole,
            pattern: pattern,
            direction: direction,
            planes: planes,
            laterality: laterality,
            muscleInvolvementSnapshot: Muscle.Involvement(contributions: [
                .init(muscle: .pectoralisMajorSternocostal, role: .primary),
                .init(muscle: .triceps, role: .secondary),
            ]).snapshot,
            aliases: aliases
        )
    }

    private func makeInput(
        from item: ExerciseCatalogItem,
        name: String? = nil,
        defaultWeight: Double? = nil,
        loadMode: ExerciseLoadMode? = nil,
        equipment: Equipment? = nil
    ) -> CatalogMutationInput {
        CatalogMutationInput(
            name: name ?? item.name,
            execution: item.execution,
            group: item.group,
            defaultWeight: defaultWeight ?? item.defaultWeight,
            trackingMode: item.trackingMode,
            modality: item.modality,
            loadMode: loadMode ?? item.loadMode,
            bodyweightFraction: item.bodyweightFraction,
            defaultDuration: item.defaultDuration,
            equipment: equipment ?? item.equipment,
            mechanic: item.mechanic,
            trainingRole: item.trainingRole ?? .other,
            pattern: item.pattern,
            direction: item.direction,
            planes: item.planes,
            laterality: item.laterality,
            muscleInvolvementSnapshot: item.muscleInvolvementSnapshot,
            aliases: item.aliases
        )
    }

    @Test func createCommitsBeforeIndexingAndReturnsCreatedItem() throws {
        let context = try makeContext()
        var events: [String] = []
        let effects = CatalogMutationEffects(
            indexExercise: { item in events.append("index:\(item.name)") },
            removeExercise: { _ in },
            reindexAll: { _, _ in }
        )
        let boundary = CatalogMutationBoundary(
            context: context,
            effects: effects,
            saveChanges: { context in
                try context.saveOrRollback()
                events.append("commit")
            }
        )

        let result = try boundary.save(makeInput(), target: .create, unit: .lb)
        let item = try #require(result.savedItem)

        #expect(events == ["commit", "index:Custom Press"])
        #expect(item.name == "Custom Press")
        #expect(item.isUserCreated)
        #expect(item.catalogID == nil)
        #expect(item.defaultReps == 8)
        #expect(item.aliases == ["CP", "chest press custom"])
        #expect(item.muscleInvolvement.primary == [.pectoralisMajorSternocostal])
        #expect(try context.fetchCount(FetchDescriptor<ExerciseCatalogItem>()) == 1)
    }

    @Test func validatedDraftBridgePersistsEverySemanticField() throws {
        let context = try makeContext()
        let execution = ExecutionInstructions(
            startingPosition: "Start",
            movement: "Move",
            endpoint: "Finish",
            returnPhase: "Return",
            controlledJoints: "Control",
            supportAndPosture: "Brace",
            disqualifyingCompensations: ["Do not swing"],
            sideOrDirection: "Repeat per side"
        )
        let involvement = Muscle.Involvement(contributions: [
            .init(muscle: .lats, role: .primary),
            .init(muscle: .bicepsBrachii, role: .secondary),
        ])
        let draft = CatalogDraft(
            name: "  Timed Pull  ",
            execution: execution,
            group: .back,
            defaultWeight: 33,
            trackingMode: .duration,
            modality: .isometricStrength,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 0.75,
            defaultDuration: 37,
            equipment: .bodyweight,
            mechanic: .compound,
            trainingRole: .pull,
            pattern: .pull,
            direction: .vertical,
            planes: [.frontal, .sagittal],
            laterality: .unilateral,
            muscleInvolvementSnapshot: involvement.snapshot,
            aliasesInput: "TP, Timed Vertical Pull"
        )
        let validation = CatalogDraftValidation(
            draft: draft,
            occupiedSearchTerms: []
        )
        let result = try CatalogMutationBoundary(context: context, effects: .none).save(
            draft.mutationInput(using: validation),
            target: .create,
            unit: .lb
        )
        let item = try #require(result.savedItem)

        #expect(validation.canSave)
        #expect(item.name == "Timed Pull")
        #expect(item.execution == execution)
        #expect(item.group == draft.group)
        #expect(item.defaultWeight == draft.defaultWeight)
        #expect(item.trackingMode == draft.trackingMode)
        #expect(item.modality == draft.modality)
        #expect(item.loadMode == draft.loadMode)
        #expect(item.bodyweightFraction == draft.bodyweightFraction)
        #expect(item.defaultDuration == draft.defaultDuration)
        #expect(item.equipment == draft.equipment)
        #expect(item.mechanic == draft.mechanic)
        #expect(item.trainingRole == draft.trainingRole)
        #expect(item.pattern == draft.pattern)
        #expect(item.direction == draft.direction)
        #expect(item.planes == [.sagittal, .frontal])
        #expect(item.laterality == draft.laterality)
        #expect(item.muscleInvolvementSnapshot == involvement.snapshot)
        #expect(item.aliases == ["TP", "Timed Vertical Pull"])
    }

    @Test func failedCreateRollsBackWithoutIndexing() throws {
        let context = try makeContext()
        var indexedNames: [String] = []
        let effects = CatalogMutationEffects(
            indexExercise: { indexedNames.append($0.name) },
            removeExercise: { _ in },
            reindexAll: { _, _ in }
        )
        let boundary = CatalogMutationBoundary(
            context: context,
            effects: effects,
            saveChanges: { _ in throw ExpectedSaveError.failed }
        )

        do {
            try boundary.save(makeInput(), target: .create, unit: .lb)
            Issue.record("Expected create to throw")
        } catch {
            #expect(error is ExpectedSaveError)
        }

        #expect(indexedNames.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseCatalogItem>()) == 0)
    }

    @Test func duplicateKeepsSourceRepDefaultAndGetsFreshIdentity() throws {
        let context = try makeContext()
        let source = ExerciseCatalogItem(
            catalogID: "source",
            name: "Source",
            group: .back,
            defaultWeight: 90,
            defaultReps: 5
        )
        context.insert(source)
        try context.saveOrRollback()

        let result = try CatalogMutationBoundary(
            context: context,
            effects: .none
        ).save(
            makeInput(name: "Source (Custom)"),
            target: .duplicate(source: source),
            unit: .lb
        )
        let copy = try #require(result.savedItem)

        #expect(copy.id != source.id)
        #expect(copy.catalogID == nil)
        #expect(copy.defaultReps == 5)
        #expect(copy.isUserCreated)
        #expect(copy.historyKey != source.historyKey)
    }

    @Test func failedDuplicateKeepsOnlySourceAndDoesNotIndex() throws {
        let context = try makeContext()
        let source = ExerciseCatalogItem(
            catalogID: "source",
            name: "Source",
            group: .back,
            defaultWeight: 90,
            defaultReps: 5
        )
        context.insert(source)
        try context.saveOrRollback()
        var indexedNames: [String] = []
        let effects = CatalogMutationEffects(
            indexExercise: { indexedNames.append($0.name) },
            removeExercise: { _ in },
            reindexAll: { _, _ in }
        )
        let boundary = CatalogMutationBoundary(
            context: context,
            effects: effects,
            saveChanges: { _ in throw ExpectedSaveError.failed }
        )

        do {
            try boundary.save(
                makeInput(name: "Source (Custom)"),
                target: .duplicate(source: source),
                unit: .lb
            )
            Issue.record("Expected duplicate to throw")
        } catch {
            #expect(error is ExpectedSaveError)
        }

        let stored = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(stored.map(\.id) == [source.id])
        #expect(indexedNames.isEmpty)
    }

    @Test func bundledEditChangesOnlyLoggingDefaults() throws {
        let context = try makeContext()
        let item = ExerciseCatalogItem(
            catalogID: "barbell-bench-press",
            familyID: "horizontal-press",
            name: "Barbell Bench Press",
            group: .chest,
            defaultWeight: 135,
            defaultWeightKg: 60,
            trainingRole: .push,
            aliases: ["Bench"]
        )
        context.insert(item)
        try context.saveOrRollback()

        let input = makeInput(
            name: "Renamed",
            group: .legs,
            defaultWeight: WeightFormatter.toCanonical(80, unit: .kg),
            defaultDuration: 75,
            aliases: ["Changed"]
        )

        let result = try CatalogMutationBoundary(
            context: context,
            effects: .none
        ).save(input, target: .edit(item: item), unit: .kg)

        guard case .edited = result else {
            Issue.record("Expected an edited result")
            return
        }
        #expect(item.name == "Barbell Bench Press")
        #expect(item.group == .chest)
        #expect(item.aliases == ["Bench"])
        #expect(item.defaultDuration == 75)
        let defaultWeightKg = try #require(item.defaultWeightKg)
        #expect(abs(defaultWeightKg - 80) < 0.0001)
    }

    @Test func failedBundledEditRestoresDefaultsWithoutIndexing() throws {
        let context = try makeContext()
        let item = ExerciseCatalogItem(
            catalogID: "barbell-bench-press",
            name: "Barbell Bench Press",
            group: .chest,
            defaultWeight: 135,
            defaultWeightKg: 60,
            defaultDuration: 45
        )
        context.insert(item)
        try context.saveOrRollback()
        var indexedNames: [String] = []
        let effects = CatalogMutationEffects(
            indexExercise: { indexedNames.append($0.name) },
            removeExercise: { _ in },
            reindexAll: { _, _ in }
        )
        let boundary = CatalogMutationBoundary(
            context: context,
            effects: effects,
            saveChanges: { _ in throw ExpectedSaveError.failed }
        )

        do {
            try boundary.save(
                makeInput(
                    defaultWeight: WeightFormatter.toCanonical(80, unit: .kg),
                    defaultDuration: 75
                ),
                target: .edit(item: item),
                unit: .kg
            )
            Issue.record("Expected bundled edit to throw")
        } catch {
            #expect(error is ExpectedSaveError)
        }

        let stored = try #require(
            try context.fetch(FetchDescriptor<ExerciseCatalogItem>()).first
        )
        #expect(stored.defaultWeight == 135)
        #expect(stored.defaultWeightKg == 60)
        #expect(stored.defaultDuration == 45)
        #expect(indexedNames.isEmpty)
    }

    @Test func customEditResetsMeasuredMaxOnlyWhenPerformanceSemanticsChange() throws {
        let context = try makeContext()
        let item = ExerciseCatalogItem(
            name: "Custom Lift",
            group: .chest,
            defaultWeight: 45,
            trainingRole: .push,
            isUserCreated: true
        )
        item.oneRepMax = 100
        context.insert(item)
        try context.saveOrRollback()

        let renamed = makeInput(from: item, name: "Custom Lift Renamed")
        try CatalogMutationBoundary(context: context, effects: .none)
            .save(renamed, target: .edit(item: item), unit: .lb)
        #expect(item.oneRepMax == 100)

        let changed = makeInput(
            from: item,
            defaultWeight: 90,
            loadMode: .nonComparable,
            equipment: .bodyweight
        )
        try CatalogMutationBoundary(context: context, effects: .none)
            .save(changed, target: .edit(item: item), unit: .lb)
        #expect(item.defaultWeight == 0)
        #expect(item.oneRepMax == nil)
    }

    @Test func failedEditRestoresPersistedValuesWithoutIndexing() throws {
        let context = try makeContext()
        let item = ExerciseCatalogItem(
            name: "Original",
            group: .chest,
            defaultWeight: 45,
            trainingRole: .push,
            isUserCreated: true
        )
        context.insert(item)
        try context.saveOrRollback()
        var indexedNames: [String] = []
        let effects = CatalogMutationEffects(
            indexExercise: { indexedNames.append($0.name) },
            removeExercise: { _ in },
            reindexAll: { _, _ in }
        )
        let boundary = CatalogMutationBoundary(
            context: context,
            effects: effects,
            saveChanges: { _ in throw ExpectedSaveError.failed }
        )

        do {
            try boundary.save(
                makeInput(from: item, name: "Changed"),
                target: .edit(item: item),
                unit: .lb
            )
            Issue.record("Expected edit to throw")
        } catch {
            #expect(error is ExpectedSaveError)
        }

        let stored = try #require(
            try context.fetch(FetchDescriptor<ExerciseCatalogItem>()).first
        )
        #expect(stored.name == "Original")
        #expect(indexedNames.isEmpty)
    }

    @Test func bundledDeleteCommitsBeforeTombstoneAndSpotlightRemoval() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        let item = ExerciseCatalogItem(
            catalogID: "barbell-bench-press",
            name: "Bench",
            group: .chest,
            defaultWeight: 135
        )
        context.insert(item)
        try context.saveOrRollback()

        var events: [String] = []
        let effects = CatalogMutationEffects(
            indexExercise: { _ in },
            removeExercise: { id in
                #expect(CatalogDeletionTombstones.ids(in: testDefaults.defaults)
                    .contains("barbell-bench-press"))
                events.append("remove:\(id)")
            },
            reindexAll: { _, _ in }
        )
        let result = try CatalogMutationBoundary(
            context: context,
            defaults: testDefaults.defaults,
            effects: effects,
            saveChanges: { context in
                try context.saveOrRollback()
                events.append("commit")
            }
        ).delete(item)

        guard case let .deleted(itemID) = result else {
            Issue.record("Expected a deleted result")
            return
        }
        #expect(events == ["commit", "remove:\(itemID)"])
        #expect(try context.fetchCount(FetchDescriptor<ExerciseCatalogItem>()) == 0)
    }

    @Test func failedDeleteRollsBackWithoutTombstoneOrSpotlightEffect() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        let item = ExerciseCatalogItem(
            catalogID: "barbell-bench-press",
            name: "Bench",
            group: .chest,
            defaultWeight: 135
        )
        context.insert(item)
        try context.saveOrRollback()
        var removedIDs: [UUID] = []
        let effects = CatalogMutationEffects(
            indexExercise: { _ in },
            removeExercise: { removedIDs.append($0) },
            reindexAll: { _, _ in }
        )
        let boundary = CatalogMutationBoundary(
            context: context,
            defaults: testDefaults.defaults,
            effects: effects,
            saveChanges: { _ in throw ExpectedSaveError.failed }
        )

        do {
            try boundary.delete(item)
            Issue.record("Expected delete to throw")
        } catch {
            #expect(error is ExpectedSaveError)
        }

        #expect(removedIDs.isEmpty)
        #expect(CatalogDeletionTombstones.ids(in: testDefaults.defaults).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseCatalogItem>()) == 1)
    }

    @Test func resetUsesOneCommitThenClearsTombstonesAndReindexes() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        let custom = ExerciseCatalogItem(
            name: "Custom",
            group: .arms,
            defaultWeight: 20,
            isUserCreated: true
        )
        let template = WorkoutTemplate(name: "Preserved Template")
        context.insert(custom)
        context.insert(template)
        try context.saveOrRollback()
        CatalogDeletionTombstones.record("barbell-bench-press", in: testDefaults.defaults)

        var commitCount = 0
        var reindexedItemCount = 0
        var reindexedTemplateNames: [String] = []
        let effects = CatalogMutationEffects(
            indexExercise: { _ in },
            removeExercise: { _ in },
            reindexAll: { templates, items in
                #expect(CatalogDeletionTombstones.ids(in: testDefaults.defaults).isEmpty)
                reindexedTemplateNames = templates.map(\.name)
                reindexedItemCount = items.count
            }
        )
        let result = try CatalogMutationBoundary(
            context: context,
            defaults: testDefaults.defaults,
            effects: effects,
            saveChanges: { context in
                commitCount += 1
                try context.saveOrRollback()
            },
            now: { Date(timeIntervalSince1970: 100) }
        ).resetToDefaults()

        guard case let .reset(insertedItemCount) = result else {
            Issue.record("Expected a reset result")
            return
        }
        let items = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(commitCount == 1)
        #expect(insertedItemCount == CatalogData.records.count)
        #expect(items.count == CatalogData.records.count)
        #expect(!items.contains { $0.isUserCreated })
        #expect(reindexedItemCount == CatalogData.records.count)
        #expect(reindexedTemplateNames == ["Preserved Template"])
    }

    @Test func failedResetRestoresCatalogAndKeepsTombstonesWithoutReindexing() throws {
        let context = try makeContext()
        let testDefaults = try makeDefaults()
        defer { testDefaults.defaults.removePersistentDomain(forName: testDefaults.suiteName) }
        let custom = ExerciseCatalogItem(
            name: "Keep Me",
            group: .arms,
            defaultWeight: 20,
            isUserCreated: true
        )
        context.insert(custom)
        try context.saveOrRollback()
        CatalogDeletionTombstones.record("barbell-bench-press", in: testDefaults.defaults)
        var reindexCount = 0
        let effects = CatalogMutationEffects(
            indexExercise: { _ in },
            removeExercise: { _ in },
            reindexAll: { _, _ in reindexCount += 1 }
        )
        let boundary = CatalogMutationBoundary(
            context: context,
            defaults: testDefaults.defaults,
            effects: effects,
            saveChanges: { _ in throw ExpectedSaveError.failed }
        )

        do {
            try boundary.resetToDefaults()
            Issue.record("Expected reset to throw")
        } catch {
            #expect(error is ExpectedSaveError)
        }

        let items = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        #expect(items.count == 1)
        #expect(items.first?.id == custom.id)
        #expect(CatalogDeletionTombstones.ids(in: testDefaults.defaults)
            == ["barbell-bench-press"])
        #expect(reindexCount == 0)
    }
}
