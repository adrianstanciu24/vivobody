import Foundation
import SwiftData
import Testing
@testable import vivobody

struct WorkoutLogViewModelTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func createWorkoutReturnsNewWorkout() throws {
        let context = try makeContext()
        let vm = WorkoutLogViewModel(modelContext: context)

        let workout = vm.createWorkout()
        #expect(workout.startedAt <= .now)
        #expect(workout.exercises.isEmpty)
    }

    @Test func deleteWorkoutRemovesFromContext() throws {
        let context = try makeContext()
        let vm = WorkoutLogViewModel(modelContext: context)

        let workout = vm.createWorkout()
        try context.save()

        let before = try context.fetchCount(FetchDescriptor<Workout>())
        #expect(before == 1)

        vm.delete(workout)
        try context.save()

        let after = try context.fetchCount(FetchDescriptor<Workout>())
        #expect(after == 0)
    }
}
