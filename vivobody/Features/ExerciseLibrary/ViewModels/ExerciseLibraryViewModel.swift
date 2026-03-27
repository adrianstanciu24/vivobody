import Foundation
import SwiftData

@Observable
final class ExerciseLibraryViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func addExercise(name: String, muscleGroup: MuscleGroup, category: ExerciseCategory) {
        let exercise = Exercise(name: name, muscleGroup: muscleGroup, category: category)
        modelContext.insert(exercise)
    }

    func delete(_ exercise: Exercise) {
        modelContext.delete(exercise)
    }
}
