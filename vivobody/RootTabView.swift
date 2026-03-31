import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var session = WorkoutSession()
    @State private var showWorkout = false
    @State private var hasSyncedExerciseCatalog = false
    @State private var catalogSyncError: String?

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
        .withPersistence()
        .preferredColorScheme(.dark)
        .tint(Color.vivoAccent)
        .task {
            session.modelContext = modelContext

            guard !hasSyncedExerciseCatalog else { return }

            do {
                let store = try BundledExerciseProfileStore()
                try ExerciseCatalogSeeder(store: store).sync(modelContext: modelContext)
            } catch {
                catalogSyncError = error.localizedDescription
            }

            hasSyncedExerciseCatalog = true
        }
        .alert(
            "Exercise Catalog Error",
            isPresented: Binding(
                get: { catalogSyncError != nil },
                set: { if !$0 { catalogSyncError = nil } }
            )
        ) {} message: {
            Text(catalogSyncError ?? "Failed to load bundled exercises.")
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(
            for: [
                Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
                WorkoutTemplate.self, TemplateExercise.self
            ],
            inMemory: true
        )
}
