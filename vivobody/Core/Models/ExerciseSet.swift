import Foundation
import SwiftData

@Model
final class ExerciseSet {
    #Index<ExerciseSet>([\.order])

    var order: Int
    var reps: Int?
    var weight: Double?
    var durationSeconds: Int?
    var rir: Int?
    var rom: String
    var tempo: String
    var grip: String
    var stance: String
    var isCompleted: Bool
    var workoutExercise: WorkoutExercise?

    init(
        order: Int = 0,
        reps: Int? = nil,
        weight: Double? = nil,
        durationSeconds: Int? = nil,
        rir: Int? = nil,
        rom: String = "FULL",
        tempo: String = "CONTROLLED",
        grip: String = "NORMAL",
        stance: String = "NORMAL",
        isCompleted: Bool = false,
        workoutExercise: WorkoutExercise? = nil
    ) {
        self.order = order
        self.reps = reps
        self.weight = weight
        self.durationSeconds = durationSeconds
        self.rir = rir
        self.rom = rom
        self.tempo = tempo
        self.grip = grip
        self.stance = stance
        self.isCompleted = isCompleted
        self.workoutExercise = workoutExercise
    }
}
