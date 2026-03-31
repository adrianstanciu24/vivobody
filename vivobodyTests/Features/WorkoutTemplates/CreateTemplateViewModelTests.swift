import Foundation
import SwiftData
import Testing
@testable import vivobody

struct CreateTemplateViewModelTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutTemplate.self, TemplateExercise.self,
            Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func saveCreatesNewTemplate() throws {
        let context = try makeContext()
        let vm = CreateTemplateViewModel(modelContext: context)

        let draft = TemplateDraft(
            name: "Push Day",
            selectedMuscles: ["CHEST", "SHOULDERS"],
            scheduleDays: [1, 3],
            notes: "Focus on compound lifts",
            exercises: [
                TemplateExerciseItem(
                    catalogID: "front_squat",
                    name: "Front Squat",
                    primaryTag: "QUADS",
                    secondaryTags: "BILATERAL SQUAT · BILATERAL",
                    sets: 4,
                    targetReps: 8,
                    restLabel: "2:00"
                )
            ]
        )
        vm.save(existingTemplate: nil, draft: draft)
        try context.save()

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(templates.count == 1)
        #expect(templates[0].name == "Push Day")
        #expect(templates[0].exercises.count == 1)
        #expect(templates[0].scheduleDays == [1, 3])
    }

    @Test func saveUpdatesExistingTemplate() throws {
        let context = try makeContext()
        let vm = CreateTemplateViewModel(modelContext: context)

        let template = WorkoutTemplate(name: "Old Name")
        context.insert(template)
        try context.save()

        let draft = TemplateDraft(
            name: "New Name",
            selectedMuscles: ["BACK"],
            scheduleDays: [2],
            notes: "",
            exercises: []
        )
        vm.save(existingTemplate: template, draft: draft)
        try context.save()

        #expect(template.name == "New Name")
        #expect(template.scheduleDays == [2])
    }

    @Test func muscleGroupParsingReturnsCorrectGroups() {
        #expect(CreateTemplateViewModel.muscleGroup(from: "CHEST") == .chest)
        #expect(CreateTemplateViewModel.muscleGroup(from: "BACK") == .back)
        #expect(CreateTemplateViewModel.muscleGroup(from: "SHOULDERS") == .shoulders)
        #expect(CreateTemplateViewModel.muscleGroup(from: "QUADS") == .legs)
        #expect(CreateTemplateViewModel.muscleGroup(from: "UNKNOWN") == nil)
    }
}
