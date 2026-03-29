import SwiftData
import SwiftUI

struct WorkoutsHistoryView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var selectedFilter = "ALL"

    private var totalVolume: Int {
        workouts.reduce(0) { $0 + $1.totalVolume }
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

            if workouts.isEmpty {
                emptyState
            } else {
                workoutList
            }
        }
    }

    private var workoutList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                WorkoutsHistoryHeader()
                WorkoutsHistoryStatsRow(
                    sessions: workouts.count,
                    volume: totalVolume,
                    avgDuration: avgDuration
                )
                divider
                WorkoutsHistoryFilterPills(selectedFilter: $selectedFilter)
                divider

                ForEach(Array(groupedWorkouts.enumerated()), id: \.offset) { sectionIndex, section in
                    WorkoutsHistoryWeekSection(
                        label: section.0,
                        workouts: section.1,
                        highlightFirst: sectionIndex == 0
                    )
                    divider
                }

                VivoFooter()
            }
            .padding(.bottom, 32)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("NO WORKOUTS YET")
                .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
            Text("Start your first session from the Today tab")
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoSecondary)
            Spacer()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
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
            VivoStatColumn(value: "07", label: "PRs")
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

// MARK: - Week Section

struct WorkoutsHistoryWeekSection: View {
    let label: String
    let workouts: [Workout]
    var highlightFirst = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 12)
                .padding(.bottom, 10)

            ForEach(Array(workouts.enumerated()), id: \.element.persistentModelID) { index, workout in
                WorkoutSessionRow(
                    workout: workout,
                    highlight: highlightFirst && index == 0
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WorkoutsHistoryView()
        .modelContainer(
            for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
            inMemory: true
        )
}
