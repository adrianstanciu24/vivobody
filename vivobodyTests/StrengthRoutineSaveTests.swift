//
//  StrengthRoutineSaveTests.swift
//  vivobodyTests
//
//  Guards generated-routine materialization and its atomic SwiftData commit:
//  exact days and prescriptions persist together, while a failed save rolls
//  every inserted template back out of the context.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct StrengthRoutineSaveTests {
    private func makePlan() throws -> StrengthRoutinePlan {
        let input = StrengthRoutineBuilderInput(
            weekdays: [.monday, .wednesday],
            sessionDuration: .minutes30,
            goal: .balanced,
            availableEquipment: Set(Equipment.allCases)
        )
        let plan = StrengthRoutineBuilder.build(
            input: input,
            candidates: CatalogData.records.map { StrengthRoutineCandidate(record: $0) }
        )
        #expect(!plan.hasBlockingGaps)
        return plan
    }

    private func catalogItems(for plan: StrengthRoutinePlan) throws -> [ExerciseCatalogItem] {
        try plan.exercises.enumerated().map { index, exercise in
            let record = try #require(
                CatalogData.record(forCatalogID: exercise.catalogID)
            )
            return ExerciseCatalogItem(
                record: record,
                createdAt: Date(timeIntervalSince1970: Double(index))
            )
        }
    }

    private func materializedTemplates(
        startingSortOrder: Int = 0
    ) throws -> (plan: StrengthRoutinePlan, templates: [WorkoutTemplate]) {
        let plan = try makePlan()
        let templates = try StrengthRoutineTemplateBatch.materialize(
            plan: plan,
            catalogItems: catalogItems(for: plan),
            availableEquipment: Set(Equipment.allCases),
            startingSortOrder: startingSortOrder
        )
        return (plan, templates)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = VivobodyStore.schema
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        return ModelContext(container)
    }

    @Test func completeBatchPersistsExactSchedulesAndPrescriptions() throws {
        let (plan, templates) = try materializedTemplates(startingSortOrder: 7)
        let context = try makeInMemoryContext()

        try StrengthRoutineTemplateBatch.insertAndSave(templates, in: context)

        let descriptor = FetchDescriptor<WorkoutTemplate>(
            sortBy: [SortDescriptor(\WorkoutTemplate.sortOrder)]
        )
        let persisted = try context.fetch(descriptor)
        #expect(persisted.count == plan.days.count)
        #expect(persisted.map(\.sortOrder) == [7, 8])
        #expect(persisted.map(\.scheduledWeekdays) == [[2], [4]])

        for (template, day) in zip(persisted, plan.days) {
            #expect(template.name == day.title)
            let plannedExercises = day.slots.compactMap(\.exercise)
            let savedExercises = template.orderedExercises
            #expect(savedExercises.count == plannedExercises.count)

            for (saved, planned) in zip(savedExercises, plannedExercises) {
                #expect(saved.catalogID == planned.catalogID)
                #expect(saved.name == planned.name)
                #expect(saved.plannedSets == planned.prescription.sets)
                if let targetReps = planned.prescription.targetReps {
                    #expect(saved.plannedReps == targetReps)
                }
                if let targetDuration = planned.prescription.targetDurationSeconds {
                    #expect(saved.plannedDuration == TimeInterval(targetDuration))
                }
                #expect(saved.plannedWeight == 0)
            }
        }
    }

    @Test func bodyweightRemainsValidWithoutExternalEquipmentSelection() throws {
        let record = try #require(CatalogData.record(forCatalogID: "plank"))
        let candidate = StrengthRoutineCandidate(record: record)
        let slotID = StrengthRoutineSlotID(weekday: .monday, kind: .core)
        let plan = StrengthRoutinePlan(
            days: [
                StrengthRoutineDay(
                    weekday: .monday,
                    title: "Bodyweight",
                    slots: [
                        StrengthRoutineSlot(
                            id: slotID,
                            kind: .core,
                            exercise: StrengthRoutineExercise(
                                candidate: candidate,
                                prescription: StrengthRoutinePolicy.prescription(
                                    for: candidate,
                                    goal: .balanced
                                ),
                                selectionReasons: [.muscleCoverage(.core)]
                            )
                        ),
                    ]
                ),
            ],
            gaps: []
        )

        let templates = try StrengthRoutineTemplateBatch.materialize(
            plan: plan,
            catalogItems: [
                ExerciseCatalogItem(
                    record: record,
                    createdAt: Date(timeIntervalSince1970: 0)
                ),
            ],
            availableEquipment: [],
            startingSortOrder: 0
        )

        #expect(templates.first?.orderedExercises.first?.catalogID == "plank")
    }

    @Test func staleCatalogIdentityBlocksMaterializationBeforeInsert() throws {
        let plan = try makePlan()
        var items = try catalogItems(for: plan)
        items.removeFirst()

        var didThrow = false
        do {
            _ = try StrengthRoutineTemplateBatch.materialize(
                plan: plan,
                catalogItems: items,
                availableEquipment: Set(Equipment.allCases),
                startingSortOrder: 0
            )
        } catch StrengthRoutineSaveFailure.catalogChanged {
            didThrow = true
        }
        #expect(didThrow)
    }

    @Test func failedBatchSaveRollsBackEveryInsertedTemplate() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StrengthRoutineSaveTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let schema = VivobodyStore.schema
        let storeURL = temporaryDirectory.appendingPathComponent("routine.store")
        try autoreleasepool {
            let writableConfiguration = ModelConfiguration(
                "routine-builder",
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
            writableContext.insert(WorkoutTemplate(name: "Existing", sortOrder: 0))
            try writableContext.save()
        }

        try autoreleasepool {
            let readOnlyConfiguration = ModelConfiguration(
                "routine-builder",
                schema: schema,
                url: storeURL,
                allowsSave: false,
                cloudKitDatabase: .none
            )
            let readOnlyContainer = try ModelContainer(
                for: schema,
                configurations: [readOnlyConfiguration]
            )
            let context = ModelContext(readOnlyContainer)
            let (_, templates) = try materializedTemplates(startingSortOrder: 1)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutTemplate>()) == 1)

            var didThrow = false
            do {
                try StrengthRoutineTemplateBatch.insertAndSave(templates, in: context)
            } catch {
                didThrow = true
            }

            #expect(didThrow)
            #expect(!context.hasChanges)
        }

        try autoreleasepool {
            let verificationConfiguration = ModelConfiguration(
                "routine-builder",
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let verificationContainer = try ModelContainer(
                for: schema,
                configurations: [verificationConfiguration]
            )
            let context = ModelContext(verificationContainer)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutTemplate>()) == 1)
        }
    }
}
