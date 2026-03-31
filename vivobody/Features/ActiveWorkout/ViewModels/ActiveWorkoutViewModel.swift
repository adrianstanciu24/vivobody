import Foundation
import SwiftData

@Observable
final class ActiveWorkoutViewModel {
    private let modelContext: ModelContext
    let workout: Workout

    init(modelContext: ModelContext, workout: Workout) {
        self.modelContext = modelContext
        self.workout = workout
    }

    func addExercise(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(
            order: workout.exercises.count,
            exerciseCatalogIDSnapshot: exercise.catalogID,
            exerciseNameSnapshot: exercise.name,
            exercisePrimaryTagSnapshot: exercise.primaryTag,
            exerciseSecondaryTagsSnapshot: exercise.secondaryTags,
            exerciseMuscleGroupSnapshot: exercise.muscleGroup.displayName,
            workout: workout,
            exercise: exercise
        )
        modelContext.insert(workoutExercise)
    }

    func addSet(to workoutExercise: WorkoutExercise) {
        let exerciseSet = ExerciseSet(
            order: workoutExercise.sets.count,
            workoutExercise: workoutExercise
        )
        modelContext.insert(exerciseSet)
    }

    func completeWorkout() {
        workout.completedAt = .now
    }

    func discardWorkout() {
        modelContext.delete(workout)
    }
}
