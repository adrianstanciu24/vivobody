import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Workout> { $0.completedAt != nil },
        sort: \Workout.startedAt,
        order: .reverse
    ) private var completedWorkouts: [Workout]
    @State private var viewModel: HistoryViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if completedWorkouts.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "chart.bar",
                        description: Text("Completed workouts will appear here.")
                    )
                } else {
                    List {
                        ForEach(completedWorkouts) { workout in
                            HistoryRowView(workout: workout)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
        .task {
            if viewModel == nil {
                viewModel = HistoryViewModel(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(
            for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
            inMemory: true
        )
}
