import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    #Index<WorkoutTemplate>([\.createdAt])

    var name: String
    var muscleGroups: [MuscleGroup]
    var scheduleDays: [Int]
    var notes: String
    var createdAt: Date
    var lastUsedAt: Date?
    var timesUsed: Int

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]

    init(
        name: String,
        muscleGroups: [MuscleGroup] = [],
        scheduleDays: [Int] = [],
        notes: String = "",
        createdAt: Date = .now,
        lastUsedAt: Date? = nil,
        timesUsed: Int = 0
    ) {
        self.name = name
        self.muscleGroups = muscleGroups
        self.scheduleDays = scheduleDays
        self.notes = notes
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.timesUsed = timesUsed
        exercises = []
    }
}
