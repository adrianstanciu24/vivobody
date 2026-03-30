import Foundation
import SwiftData

@Model
final class TemplateExercise {
    #Index<TemplateExercise>([\.order])

    var order: Int
    var targetSets: Int
    var targetReps: Int
    var restSeconds: Int
    var template: WorkoutTemplate?
    var exercise: Exercise?

    init(
        order: Int = 0,
        targetSets: Int = 3,
        targetReps: Int = 10,
        restSeconds: Int = 120,
        template: WorkoutTemplate? = nil,
        exercise: Exercise? = nil
    ) {
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.restSeconds = restSeconds
        self.template = template
        self.exercise = exercise
    }
}
