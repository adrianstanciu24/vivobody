import Foundation
import SwiftData
import Testing
@testable import vivobody

struct ActiveWorkoutViewModelTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func addExerciseAppendsToWorkout() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let vm = ActiveWorkoutViewModel(modelContext: context, workout: workout)

        let exercise = Exercise(name: "Bench Press", muscleGroup: .chest, category: .barbell)
        context.insert(exercise)

        vm.addExercise(exercise)
        try context.save()

        #expect(workout.exercises.count == 1)
    }

    @Test func addSetAppendsToWorkoutExercise() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let vm = ActiveWorkoutViewModel(modelContext: context, workout: workout)

        let exercise = Exercise(name: "Squat", muscleGroup: .legs, category: .barbell)
        context.insert(exercise)
        vm.addExercise(exercise)
        try context.save()

        let workoutExercise = try #require(workout.exercises.first)
        vm.addSet(to: workoutExercise)
        try context.save()

        #expect(workoutExercise.sets.count == 1)
    }

    @Test func completeWorkoutSetsCompletedAt() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let vm = ActiveWorkoutViewModel(modelContext: context, workout: workout)

        #expect(!workout.isCompleted)
        vm.completeWorkout()
        #expect(workout.isCompleted)
    }

    @Test func discardWorkoutDeletesFromContext() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        try context.save()
        let vm = ActiveWorkoutViewModel(modelContext: context, workout: workout)

        vm.discardWorkout()
        try context.save()

        let count = try context.fetchCount(FetchDescriptor<Workout>())
        #expect(count == 0)
    }
}
