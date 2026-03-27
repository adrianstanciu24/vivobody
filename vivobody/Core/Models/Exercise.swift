import Foundation
import SwiftData

@Model
final class Exercise {
    #Index<Exercise>([\.name])

    var name: String
    var muscleGroup: MuscleGroup
    var category: ExerciseCategory
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.exercise)
    var workoutExercises: [WorkoutExercise]

    init(
        name: String,
        muscleGroup: MuscleGroup = .other,
        category: ExerciseCategory = .other,
        notes: String = ""
    ) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.category = category
        self.notes = notes
        workoutExercises = []
    }
}
