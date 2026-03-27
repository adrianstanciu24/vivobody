import Foundation
import SwiftData

@Observable
final class WorkoutLogViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createWorkout() -> Workout {
        let workout = Workout(startedAt: .now)
        modelContext.insert(workout)
        return workout
    }

    func delete(_ workout: Workout) {
        modelContext.delete(workout)
    }
}
