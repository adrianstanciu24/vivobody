import Foundation
import SwiftData
import Testing
@testable import vivobody

struct ExerciseLibraryViewModelTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func addExerciseInsertsIntoContext() throws {
        let context = try makeContext()
        let vm = ExerciseLibraryViewModel(modelContext: context)

        vm.addExercise(name: "Deadlift", muscleGroup: .back, category: .barbell)
        try context.save()

        let count = try context.fetchCount(FetchDescriptor<Exercise>())
        #expect(count == 1)
    }

    @Test func deleteExerciseRemovesFromContext() throws {
        let context = try makeContext()
        let vm = ExerciseLibraryViewModel(modelContext: context)

        vm.addExercise(name: "Curl", muscleGroup: .biceps, category: .dumbbell)
        try context.save()

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        vm.delete(exercises[0])
        try context.save()

        let count = try context.fetchCount(FetchDescriptor<Exercise>())
        #expect(count == 0)
    }
}
