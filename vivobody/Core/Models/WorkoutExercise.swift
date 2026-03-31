import Foundation
import SwiftData

@Model
final class WorkoutExercise {
    #Index<WorkoutExercise>([\.order])

    var order: Int
    var exerciseCatalogIDSnapshot: String
    var exerciseNameSnapshot: String
    var exercisePrimaryTagSnapshot: String
    var exerciseSecondaryTagsSnapshot: String
    var exerciseMuscleGroupSnapshot: String
    var workout: Workout?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise)
    var sets: [ExerciseSet]

    init(
        order: Int = 0,
        exerciseCatalogIDSnapshot: String = "",
        exerciseNameSnapshot: String = "",
        exercisePrimaryTagSnapshot: String = "",
        exerciseSecondaryTagsSnapshot: String = "",
        exerciseMuscleGroupSnapshot: String = "",
        workout: Workout? = nil,
        exercise: Exercise? = nil
    ) {
        self.order = order
        self.exerciseCatalogIDSnapshot = exerciseCatalogIDSnapshot
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.exercisePrimaryTagSnapshot = exercisePrimaryTagSnapshot
        self.exerciseSecondaryTagsSnapshot = exerciseSecondaryTagsSnapshot
        self.exerciseMuscleGroupSnapshot = exerciseMuscleGroupSnapshot
        self.workout = workout
        self.exercise = exercise
        sets = []
    }

    var displayName: String {
        exercise?.name ?? exerciseNameSnapshot
    }

    var displayMuscleGroup: String {
        if let exercise {
            return exercise.muscleGroup.displayName
        }

        return exerciseMuscleGroupSnapshot.isEmpty ? MuscleGroup.other.displayName : exerciseMuscleGroupSnapshot
    }
}
