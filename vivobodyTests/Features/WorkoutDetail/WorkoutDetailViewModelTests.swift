import Foundation
import SwiftData
import Testing
@testable import vivobody

struct WorkoutDetailViewModelTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func startEditingSetsFlag() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: .now, notes: "Push Day")
        context.insert(workout)
        let vm = WorkoutDetailViewModel(modelContext: context, workout: workout)

        #expect(!vm.isEditing)
        vm.startEditing()
        #expect(vm.isEditing)
        #expect(vm.editedNotes == "Push Day")
    }

    @Test func cancelEditingRevertsNotes() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: .now, notes: "Push Day")
        context.insert(workout)
        let vm = WorkoutDetailViewModel(modelContext: context, workout: workout)

        vm.startEditing()
        vm.editedNotes = "Changed"
        vm.cancelEditing()

        #expect(!vm.isEditing)
        #expect(vm.editedNotes == "Push Day")
        #expect(workout.notes == "Push Day")
    }

    @Test func saveEditsPersistsNotes() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: .now, notes: "Push Day")
        context.insert(workout)
        let vm = WorkoutDetailViewModel(modelContext: context, workout: workout)

        vm.startEditing()
        vm.editedNotes = "Pull Day"
        vm.saveEdits()

        #expect(!vm.isEditing)
        #expect(workout.notes == "Pull Day")
    }

    @Test func updateSetModifiesValues() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let workoutExercise = WorkoutExercise(order: 0, workout: workout)
        context.insert(workoutExercise)
        let exerciseSet = ExerciseSet(
            order: 0,
            reps: 8,
            weight: 135,
            isCompleted: true,
            workoutExercise: workoutExercise
        )
        context.insert(exerciseSet)
        try context.save()

        let vm = WorkoutDetailViewModel(modelContext: context, workout: workout)
        vm.updateSet(exerciseSet, reps: 10, weight: 155)

        #expect(exerciseSet.reps == 10)
        #expect(exerciseSet.weight == 155)
    }

    @Test func deleteExerciseRemovesFromWorkout() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let ex1 = WorkoutExercise(order: 0, exerciseNameSnapshot: "Bench", workout: workout)
        let ex2 = WorkoutExercise(order: 1, exerciseNameSnapshot: "Squat", workout: workout)
        context.insert(ex1)
        context.insert(ex2)
        try context.save()

        let vm = WorkoutDetailViewModel(modelContext: context, workout: workout)
        #expect(vm.sortedExercises.count == 2)

        vm.deleteExercise(ex1)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<WorkoutExercise>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.exerciseNameSnapshot == "Squat")
    }

    @Test func sortedExercisesReturnsByOrder() throws {
        let context = try makeContext()
        let workout = Workout(startedAt: .now)
        context.insert(workout)
        let ex1 = WorkoutExercise(order: 1, exerciseNameSnapshot: "Squat", workout: workout)
        let ex2 = WorkoutExercise(order: 0, exerciseNameSnapshot: "Bench", workout: workout)
        context.insert(ex1)
        context.insert(ex2)
        try context.save()

        let vm = WorkoutDetailViewModel(modelContext: context, workout: workout)
        let sorted = vm.sortedExercises

        #expect(sorted[0].exerciseNameSnapshot == "Bench")
        #expect(sorted[1].exerciseNameSnapshot == "Squat")
    }
}
