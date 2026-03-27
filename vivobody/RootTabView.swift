import SwiftData
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Workouts", systemImage: "figure.strengthtraining.traditional") {
                WorkoutLogView()
            }
            Tab("Exercises", systemImage: "dumbbell") {
                ExerciseLibraryView()
            }
            Tab("History", systemImage: "chart.bar") {
                HistoryView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(
            for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
            inMemory: true
        )
}
