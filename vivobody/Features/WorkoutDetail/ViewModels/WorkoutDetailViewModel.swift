import Foundation
import SwiftData

@Observable
final class WorkoutDetailViewModel {
    private let modelContext: ModelContext
    let workout: Workout

    var isEditing = false
    var editedNotes: String

    init(modelContext: ModelContext, workout: Workout) {
        self.modelContext = modelContext
        self.workout = workout
        editedNotes = workout.notes
    }

    var sortedExercises: [WorkoutExercise] {
        workout.exercises.sorted { $0.order < $1.order }
    }

    func startEditing() {
        editedNotes = workout.notes
        isEditing = true
    }

    func cancelEditing() {
        editedNotes = workout.notes
        isEditing = false
    }

    func saveEdits() {
        workout.notes = editedNotes
        isEditing = false
    }

    func updateSet(_ exerciseSet: ExerciseSet, reps: Int?, weight: Double?) {
        exerciseSet.reps = reps
        exerciseSet.weight = weight
    }

    func deleteExercise(_ workoutExercise: WorkoutExercise) {
        modelContext.delete(workoutExercise)
        for (index, exercise) in sortedExercises.enumerated() {
            exercise.order = index
        }
    }
}
