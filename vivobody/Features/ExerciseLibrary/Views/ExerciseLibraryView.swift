import SwiftData
import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var viewModel: ExerciseLibraryViewModel?
    @State private var isAddingExercise = false

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Tap + to add your first exercise.")
                    )
                } else {
                    List {
                        ForEach(exercises) { exercise in
                            ExerciseRowView(exercise: exercise)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel?.delete(exercises[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Exercise", systemImage: "plus") {
                        isAddingExercise = true
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ExerciseLibraryViewModel(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    ExerciseLibraryView()
        .modelContainer(
            for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
            inMemory: true
        )
}
