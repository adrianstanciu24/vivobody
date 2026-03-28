import SwiftData
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "flame") {
                TodayView()
            }
            Tab("Workouts", systemImage: "figure.strengthtraining.traditional") {
                WorkoutCompleteView()
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
        .preferredColorScheme(.dark)
        .tint(Color.vivoAccent)
    }
}

#Preview {
    RootTabView()
        .modelContainer(
            for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
            inMemory: true
        )
}
