import SwiftData
import SwiftUI

struct WorkoutsHistoryView: View {
    @Environment(PersistenceController.self) private var persistence
    @Environment(WorkoutSession.self) private var session: WorkoutSession?
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var selectedTab: WorkoutTab = .history
    @State private var workoutToDelete: Workout?
    @State private var selectedWorkout: Workout?
    @State private var showStartPicker = false
    @State private var showDeleteAlert = false
    @State private var cachedStats = WorkoutStats()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabToggleDivider

                Group {
                    if selectedTab == .history {
                        if workouts.isEmpty {
                            WorkoutsHistoryEmptyStateView(tabToggle: EmptyView())
                        } else {
                            historyList
                        }
                    } else {
                        WorkoutTemplatesView(header: EmptyView())
                    }
                }
            }
            .background(Color.vivoBackground)
            .navigationTitle("Workouts")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onChange(of: workouts) { _, newWorkouts in
            cachedStats = WorkoutStats(from: newWorkouts)
        }
        .task {
            cachedStats = WorkoutStats(from: workouts)
        }
    }

    private var tabToggleDivider: some View {
        VStack(spacing: 0) {
            WorkoutsTabToggleBar(selectedTab: $selectedTab)
            Rectangle()
                .fill(Color.vivoSurface)
                .frame(height: 1)
                .padding(.horizontal, VivoSpacing.screenH)
        }
    }

    private var historyList: some View {
        List {
            WorkoutsHistoryStatsSection(stats: cachedStats)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(cachedStats.grouped, id: \.label) { section in
                Section {
                    ForEach(section.workouts) { workout in
                        WorkoutsHistoryWorkoutRow(
                            workout: workout,
                            highlight: workout.id == workouts.first?.id,
                            onSelect: { selectedWorkout = workout },
                            onDelete: {
                                workoutToDelete = workout
                                showDeleteAlert = true
                            }
                        )
                    }
                } header: {
                    WorkoutsHistorySectionHeader(label: section.label)
                }
            }

            WorkoutsHistoryStartButton(showPicker: $showStartPicker)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            VivoFooter()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog(
            "Delete Workout?",
            isPresented: $showDeleteAlert,
            presenting: workoutToDelete
        ) { workout in
            Button("Delete", role: .destructive) {
                persistence.delete(workout)
                workoutToDelete = nil
            }
        } message: { _ in
            Text("This action cannot be undone.")
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workout: workout)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Cached Stats

struct WorkoutStats {
    var sessions: Int = 0
    var totalVolume: Int = 0
    var thisWeek: Int = 0
    var avgDuration: Int = 0
    var grouped: [WorkoutSection] = []

    init() {}

    init(from workouts: [Workout]) {
        sessions = workouts.count
        totalVolume = workouts.reduce(0) { $0 + $1.totalVolume }

        let calendar = Calendar.current
        let now = Date.now
        let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek) ?? now

        thisWeek = workouts.count(where: { $0.startedAt >= startOfThisWeek })

        if !workouts.isEmpty {
            let total = workouts.compactMap(\.duration).reduce(0, +)
            avgDuration = Int(total) / 60 / max(1, workouts.count)
        }

        var thisWeekList: [Workout] = []
        var lastWeekList: [Workout] = []
        var olderList: [Workout] = []

        for workout in workouts {
            if workout.startedAt >= startOfThisWeek {
                thisWeekList.append(workout)
            } else if workout.startedAt >= startOfLastWeek {
                lastWeekList.append(workout)
            } else {
                olderList.append(workout)
            }
        }

        var sections: [WorkoutSection] = []
        if !thisWeekList.isEmpty { sections.append(WorkoutSection(label: "THIS WEEK", workouts: thisWeekList)) }
        if !lastWeekList.isEmpty { sections.append(WorkoutSection(label: "LAST WEEK", workouts: lastWeekList)) }
        if !olderList.isEmpty { sections.append(WorkoutSection(label: "OLDER", workouts: olderList)) }
        grouped = sections
    }
}

struct WorkoutSection: Identifiable {
    let label: String
    let workouts: [Workout]
    var id: String {
        label
    }
}

// MARK: - Stats Section

struct WorkoutsHistoryStatsSection: View {
    let stats: WorkoutStats

    var body: some View {
        VStack(spacing: 0) {
            WorkoutsHistoryStatsRow(
                sessions: stats.sessions,
                volume: stats.totalVolume,
                thisWeek: stats.thisWeek,
                avgDuration: stats.avgDuration
            )
            divider
            WorkoutsHistorySearchBar()
            divider
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

// MARK: - Workout Row

struct WorkoutsHistoryWorkoutRow: View {
    let workout: Workout
    var highlight = false
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            WorkoutSessionRow(workout: workout, highlight: highlight)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Start Button

struct WorkoutsHistoryStartButton: View {
    @Binding var showPicker: Bool

    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 8) {
                Text("+")
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoAccent)
                Text("START WORKOUT")
                    .font(.vivoMono(VivoFont.monoCaption))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoAccent)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .stroke(
                        Color.vivoSurface,
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
            )
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 12)
        .sheet(isPresented: $showPicker) {
            StartWorkoutPicker()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    WorkoutsHistoryView()
        .modelContainer(
            for: [
                Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
                WorkoutTemplate.self, TemplateExercise.self
            ],
            inMemory: true
        )
}
