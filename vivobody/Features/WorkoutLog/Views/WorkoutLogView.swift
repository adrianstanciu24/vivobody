import SwiftData
import SwiftUI

struct WorkoutLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var viewModel: WorkoutLogViewModel?
    @State private var activeWorkout: Workout?

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Tap + to start your first workout.")
                    )
                } else {
                    List {
                        ForEach(workouts) { workout in
                            WorkoutRowView(workout: workout)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel?.delete(workouts[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Workout", systemImage: "plus") {
                        activeWorkout = viewModel?.createWorkout()
                    }
                }
            }
            .sheet(item: $activeWorkout, content: ActiveWorkoutView.init)
        }
        .task {
            if viewModel == nil {
                viewModel = WorkoutLogViewModel(modelContext: modelContext)
            }
        }
    }
}

private struct WorkoutRowView: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.startedAt, format: .dateTime.month().day().year())
                .font(.headline)
            Text("\(workout.exercises.count) exercises")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WorkoutLogView()
        .modelContainer(
            for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
            inMemory: true
        )
}
