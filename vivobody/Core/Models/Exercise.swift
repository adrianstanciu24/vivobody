import Foundation
import SwiftData

@Model
final class Exercise {
    #Index<Exercise>([\.catalogID], [\.name])

    var catalogID: String
    var name: String
    var muscleGroup: MuscleGroup
    var category: ExerciseCategory
    var primaryTag: String
    var secondaryTags: String
    var motionFamily: String
    var isBilateral: Bool
    var notes: String

    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
    var workoutExercises: [WorkoutExercise]

    init(
        catalogID: String = "",
        name: String,
        muscleGroup: MuscleGroup = .other,
        category: ExerciseCategory = .other,
        primaryTag: String = "",
        secondaryTags: String = "",
        motionFamily: String = "",
        isBilateral: Bool = false,
        notes: String = ""
    ) {
        self.catalogID = catalogID
        self.name = name
        self.muscleGroup = muscleGroup
        self.category = category
        self.primaryTag = primaryTag
        self.secondaryTags = secondaryTags
        self.motionFamily = motionFamily
        self.isBilateral = isBilateral
        self.notes = notes
        workoutExercises = []
    }

    var tags: String {
        guard !secondaryTags.isEmpty else { return primaryTag }
        guard !primaryTag.isEmpty else { return secondaryTags }
        return "\(primaryTag) · \(secondaryTags)"
    }
}
