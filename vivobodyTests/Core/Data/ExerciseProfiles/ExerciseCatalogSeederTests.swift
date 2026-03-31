import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct ExerciseCatalogSeederTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
            WorkoutTemplate.self, TemplateExercise.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeCatalogItem(
        id: String = "front_squat",
        name: String = "Front Squat",
        primaryTag: String = "QUADS"
    ) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            id: id,
            displayName: name,
            description: "Test item",
            motionFamily: "bilateral_squat",
            isBilateral: true,
            apiPath: "profiles_v2/exercises/\(id).api.json",
            muscleGroup: .legs,
            category: .barbell,
            primaryTag: primaryTag,
            secondaryTags: "BILATERAL SQUAT · BILATERAL"
        )
    }

    @Test func syncMigratesMatchingExercisesByName() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Front Squat", muscleGroup: .other)
        context.insert(exercise)

        try ExerciseCatalogSeeder(catalogItems: [makeCatalogItem()]).sync(modelContext: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 1)
        #expect(exercises.first?.catalogID == "front_squat")
        #expect(exercises.first?.primaryTag == "QUADS")
    }

    @Test func syncPrunesNonCatalogExercisesAndPreservesWorkoutSnapshots() throws {
        let context = try makeContext()
        let oldExercise = Exercise(name: "Old Curl", muscleGroup: .biceps)
        let workout = Workout()
        let workoutExercise = WorkoutExercise(order: 0, workout: workout, exercise: oldExercise)
        workout.exercises.append(workoutExercise)
        context.insert(oldExercise)
        context.insert(workout)

        let template = WorkoutTemplate(name: "Legacy Template")
        let templateExercise = TemplateExercise(
            order: 0,
            name: "Old Curl",
            primaryTag: "BICEPS",
            secondaryTags: "OTHER",
            template: template
        )
        template.exercises.append(templateExercise)
        context.insert(template)
        try context.save()

        try ExerciseCatalogSeeder(catalogItems: [makeCatalogItem()]).sync(modelContext: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let workoutExercises = try context.fetch(FetchDescriptor<WorkoutExercise>())
        let templateExercises = try context.fetch(FetchDescriptor<TemplateExercise>())

        #expect(exercises.count == 1)
        #expect(exercises.first?.catalogID == "front_squat")
        #expect(workoutExercises.count == 1)
        #expect(workoutExercises.first?.exercise == nil)
        #expect(workoutExercises.first?.exerciseNameSnapshot == "Old Curl")
        #expect(templateExercises.isEmpty)
    }

    @Test func bundledStoreLoadsCopiedProfiles() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourcesRoot = repoRoot
            .appendingPathComponent("vivobody/Resources/Generated/ExerciseProfiles")

        let store = BundledExerciseProfileStore(resourcesRoot: resourcesRoot)
        let catalog = try store.loadCatalog()

        #expect(catalog.count == 6)
        #expect(catalog.contains(where: { $0.id == "front_squat" }))
        #expect(catalog.contains(where: { $0.id == "romanian_deadlift" }))
    }
}
