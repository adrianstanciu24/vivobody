import Foundation
import SwiftData

@Model
final class WorkoutExercise {
    #Index<WorkoutExercise>([\.order])

    var order: Int
    var workout: Workout?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise)
    var sets: [ExerciseSet]

    init(order: Int = 0, workout: Workout? = nil, exercise: Exercise? = nil) {
        self.order = order
        self.workout = workout
        self.exercise = exercise
        sets = []
    }
}
