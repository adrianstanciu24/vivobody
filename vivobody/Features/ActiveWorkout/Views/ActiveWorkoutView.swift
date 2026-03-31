import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(PersistenceController.self) private var persistence
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActiveWorkoutViewModel?
    let workout: Workout

    var body: some View {
        NavigationStack {
            Group {
                if workout.exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises Yet",
                        systemImage: "plus.circle",
                        description: Text("Add exercises to your workout.")
                    )
                } else {
                    List {
                        ForEach(workout.exercises.sorted { $0.order < $1.order }) { workoutExercise in
                            Section(workoutExercise.displayName.isEmpty ? "Unknown" : workoutExercise.displayName) {
                                ForEach(workoutExercise.sets.sorted { $0.order < $1.order }) { exerciseSet in
                                    ExerciseSetRowView(exerciseSet: exerciseSet)
                                }
                                Button("Add Set") {
                                    viewModel?.addSet(to: workoutExercise)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Active Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", action: discardWorkout)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish", action: finishWorkout)
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ActiveWorkoutViewModel(modelContext: persistence.modelContext, workout: workout)
            }
        }
    }

    private func discardWorkout() {
        viewModel?.discardWorkout()
        dismiss()
    }

    private func finishWorkout() {
        viewModel?.completeWorkout()
        dismiss()
    }
}

private struct ExerciseSetRowView: View {
    let exerciseSet: ExerciseSet

    var body: some View {
        HStack {
            Text("Set \(exerciseSet.order + 1)")
            Spacer()
            if let reps = exerciseSet.reps {
                Text("\(reps) reps")
            }
            if let weight = exerciseSet.weight {
                Text("\(weight, specifier: "%.1f") kg")
            }
        }
    }
}

#Preview {
    ActiveWorkoutView(workout: Workout(startedAt: .now))
        .withPersistence()
        .modelContainer(
            for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
            inMemory: true
        )
}
