import Foundation
import SwiftData

@Model
final class Workout {
    #Index<Workout>([\.startedAt], [\.completedAt])

    var startedAt: Date
    var completedAt: Date?
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]

    init(startedAt: Date = .now, notes: String = "") {
        self.startedAt = startedAt
        self.notes = notes
        exercises = []
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var duration: TimeInterval? {
        guard let completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }
}
