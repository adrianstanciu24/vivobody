import Foundation
import SwiftData
import Testing
@testable import vivobody

struct HistoryViewModelTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func completedWorkoutsCountReturnsZeroWhenEmpty() throws {
        let context = try makeContext()
        let vm = HistoryViewModel(modelContext: context)

        #expect(vm.completedWorkoutsCount() == 0)
    }

    @Test func completedWorkoutsCountReturnsCorrectValue() throws {
        let context = try makeContext()
        let vm = HistoryViewModel(modelContext: context)

        let completed = Workout(startedAt: .now)
        completed.completedAt = .now
        context.insert(completed)

        let incomplete = Workout(startedAt: .now)
        context.insert(incomplete)

        try context.save()

        #expect(vm.completedWorkoutsCount() == 1)
    }
}
