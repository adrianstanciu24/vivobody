import SwiftData
import SwiftUI

struct RootTabView: View {
    @State private var session = WorkoutSession()
    @State private var showWorkout = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                Tab("Today", systemImage: "flame") {
                    TodayView()
                }
                Tab("Workouts", systemImage: "figure.strengthtraining.traditional") {
                    WorkoutsHistoryView()
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

            if session.isActive, !showWorkout {
                WorkoutMiniBar {
                    showWorkout = true
                }
                .padding(.bottom, 50)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isActive)
        .animation(.easeInOut(duration: 0.25), value: showWorkout)
        .onChange(of: session.isActive) { _, isActive in
            if isActive {
                showWorkout = true
            }
        }
        .sheet(isPresented: $showWorkout) {
            EmptyWorkoutView()
                .environment(session)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackgroundInteraction(.disabled)
                .interactiveDismissDisabled(false)
        }
        .environment(session)
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
