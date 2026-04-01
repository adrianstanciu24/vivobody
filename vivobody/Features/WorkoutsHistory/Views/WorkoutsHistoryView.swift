import SwiftData
import SwiftUI

struct WorkoutsHistoryView: View {
    @Environment(PersistenceController.self) private var persistence
    @Environment(WorkoutSession.self) private var session: WorkoutSession?
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var selectedTab = "HISTORY"
    @State private var selectedFilter = "ALL"
    @State private var workoutToDelete: Workout?
    @State private var selectedWorkout: Workout?
    @State private var showStartPicker = false

    private var totalVolume: Int {
        workouts.reduce(0) { $0 + $1.totalVolume }
    }

    private var thisWeekCount: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return workouts.count(where: { $0.startedAt >= startOfWeek })
    }

    private var avgDuration: Int {
        guard !workouts.isEmpty else { return 0 }
        let total = workouts.compactMap(\.duration).reduce(0, +)
        return Int(total) / 60 / max(1, workouts.count)
    }

    private var groupedWorkouts: [(String, [Workout])] {
        let calendar = Calendar.current
        let now = Date.now
        let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek) ?? now

        var thisWeek: [Workout] = []
        var lastWeek: [Workout] = []
        var older: [Workout] = []

        for workout in workouts {
            if workout.startedAt >= startOfThisWeek {
                thisWeek.append(workout)
            } else if workout.startedAt >= startOfLastWeek {
                lastWeek.append(workout)
            } else {
                older.append(workout)
            }
        }

        var sections: [(String, [Workout])] = []
        if !thisWeek.isEmpty { sections.append(("THIS WEEK", thisWeek)) }
        if !lastWeek.isEmpty { sections.append(("LAST WEEK", lastWeek)) }
        if !older.isEmpty { sections.append(("OLDER", older)) }
        return sections
    }

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                WorkoutsHistoryHeader()
                WorkoutsTabToggle(selectedTab: $selectedTab)
                divider

                if selectedTab == "HISTORY" {
                    if workouts.isEmpty {
                        emptyState
                    } else {
                        historyContent
                    }
                } else {
                    WorkoutTemplatesView()
                }
            }
        }
    }

    private var historyContent: some View {
        List {
            statsSection
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(Array(groupedWorkouts.enumerated()), id: \.offset) { sectionIndex, section in
                Section {
                    ForEach(
                        Array(section.1.enumerated()),
                        id: \.element.persistentModelID
                    ) { index, workout in
                        Button {
                            selectedWorkout = workout
                        } label: {
                            WorkoutSessionRow(
                                workout: workout,
                                highlight: sectionIndex == 0 && index == 0
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                workoutToDelete = workout
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    WorkoutsHistorySectionHeader(label: section.0)
                }
            }

            startWorkoutButton
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
        .alert("Delete Workout?", isPresented: Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { workoutToDelete = nil }
            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    persistence.delete(workout)
                }
                workoutToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workout: workout)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var statsSection: some View {
        VStack(spacing: 0) {
            WorkoutsHistoryStatsRow(
                sessions: workouts.count,
                volume: totalVolume,
                thisWeek: thisWeekCount,
                avgDuration: avgDuration
            )
            divider
            WorkoutsHistoryFilterPills(selectedFilter: $selectedFilter)
            divider
        }
    }

    private var startWorkoutButton: some View {
        Button { showStartPicker = true } label: {
            HStack(spacing: 8) {
                Text("+")
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
                Text("START WORKOUT")
                    .font(.vivoMono(VivoFont.monoCaption))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoMuted)
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
        .sheet(isPresented: $showStartPicker) {
            StartWorkoutPicker()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var emptyState: some View {
        WorkoutsHistoryEmptyStateView()
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

// MARK: - Tab Toggle

struct WorkoutsTabToggle: View {
    @Binding var selectedTab: String
    private let tabs = ["HISTORY", "TEMPLATES"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button { selectedTab = tab } label: {
                    Text(tab)
                        .font(.vivoMono(
                            VivoFont.monoSM,
                            weight: isSelected ? .bold : .regular
                        ))
                        .tracking(VivoTracking.tight)
                        .foregroundStyle(
                            isSelected ? Color.vivoBackground : Color.vivoSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: VivoRadius.card)
                                .fill(isSelected ? Color.vivoPrimary : Color.clear)
                        )
                        .overlay(
                            isSelected ? nil :
                                RoundedRectangle(cornerRadius: VivoRadius.card)
                                .stroke(Color.vivoSurface, lineWidth: 1.5)
                        )
                }
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, 12)
    }
}

// MARK: - Header

struct WorkoutsHistoryHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("12")
                .font(.vivoDisplay(VivoFont.titleXL, weight: .bold))
                .foregroundStyle(Color.vivoAccent)
            Text("Day Streak")
                .font(.vivoDisplay(VivoFont.titleXL, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 42)
        .padding(.bottom, 16)
    }
}

// MARK: - Stats Row

struct WorkoutsHistoryStatsRow: View {
    let sessions: Int
    let volume: Int
    let thisWeek: Int
    let avgDuration: Int

    private var volumeLabel: String {
        if volume >= 1000 {
            return "\(volume / 1000)K"
        }
        return "\(volume)"
    }

    var body: some View {
        HStack(spacing: 0) {
            VivoStatColumn(
                value: "\(sessions)", label: "SESSIONS",
                valueColor: .vivoAccent
            )
            verticalDivider
            VivoStatColumn(value: volumeLabel, label: "VOL. LB")
            verticalDivider
            VivoStatColumn(value: String(format: "%02d", thisWeek), label: "THIS WEEK")
            verticalDivider
            VivoStatColumn(value: "\(avgDuration)m", label: "AVG DUR.")
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(width: 1, height: 28)
    }
}

// MARK: - Filter Pills

struct WorkoutsHistoryFilterPills: View {
    @Binding var selectedFilter: String
    private let filters = ["ALL", "PUSH", "PULL", "LEGS", "FULL"]

    var body: some View {
        HStack(spacing: 20) {
            ForEach(filters, id: \.self) { filter in
                Button { selectedFilter = filter } label: {
                    Text(filter)
                        .font(.vivoMono(
                            VivoFont.monoSM,
                            weight: selectedFilter == filter ? .bold : .regular
                        ))
                        .tracking(VivoTracking.medium)
                        .foregroundStyle(
                            selectedFilter == filter ? Color.vivoAccent : Color.vivoMuted
                        )
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(pillBackground(selected: selectedFilter == filter))
                }
            }
            Spacer()
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func pillBackground(selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: VivoRadius.badge)
                .fill(Color.vivoAccent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                        .stroke(Color.vivoAccent, lineWidth: 1)
                )
        }
    }
}

// MARK: - Section Header

struct WorkoutsHistorySectionHeader: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 12, leading: VivoSpacing.screenH, bottom: 10, trailing: VivoSpacing.screenH))
    }
}

// MARK: - Preview

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
