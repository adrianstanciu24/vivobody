import Foundation
import SwiftData

@Model
final class ExerciseSet {
    #Index<ExerciseSet>([\.order])

    var order: Int
    var reps: Int?
    var weight: Double?
    var durationSeconds: Int?
    var isCompleted: Bool
    var workoutExercise: WorkoutExercise?

    init(
        order: Int = 0,
        reps: Int? = nil,
        weight: Double? = nil,
        durationSeconds: Int? = nil,
        isCompleted: Bool = false,
        workoutExercise: WorkoutExercise? = nil
    ) {
        self.order = order
        self.reps = reps
        self.weight = weight
        self.durationSeconds = durationSeconds
        self.isCompleted = isCompleted
        self.workoutExercise = workoutExercise
    }
}
