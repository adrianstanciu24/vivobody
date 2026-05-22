//
//  TodayScreen.swift
//  workapp
//
//  The app's home tab. Quiet, scannable, anchored by the big
//  "Start Workout" call-to-action. Composes three previously-built
//  atoms into their first real screen home:
//    • StreakCalendar — the current month with workout dots
//    • PrimaryActionButton — the START WORKOUT call-to-action
//    • DigitTicker — used inside the LastWorkout stats strip
//
//  The screen reads AppState directly (workout dates, streak count,
//  last completed session) and emits a single intent: start today's
//  workout. The shell handles presentation.
//

import SwiftUI
import SwiftData

struct TodayScreen: View {
    @Bindable var appState: AppState

    /// All archived sessions, most-recent first. Drives the streak
    /// calendar, the "X this month" stat, and the "Last Workout"
    /// card. SwiftUI re-renders this screen automatically when a new
    /// session is inserted into the context (i.e. on workout archive).
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    private var completedSessions: [WorkoutSession]

    /// All saved templates. Sorted on-the-fly into a most-recently-
    /// used-first list for the chip strip; the raw @Query order
    /// doesn't matter beyond identity.
    @Query private var templates: [WorkoutTemplate]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                dateStrip
                streakSection
                startSection
                if !templates.isEmpty {
                    templatesSection
                }
                lastWorkoutSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    // MARK: - Sections

    /// Small monospaced date caption that sits just below the system
    /// large title. The title says where you are ("Today"); this strip
    /// gives you the calendar context.
    private var dateStrip: some View {
        Text(Self.dayFormatter.string(from: Date()).uppercased())
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                streakHeading
                Spacer()
                if !workoutDates.isEmpty {
                    Text("\(monthCount(in: Date())) THIS MONTH")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.40))
                }
            }

            StreakCalendar(
                workoutDates: workoutDates,
                month: Date()
            )
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var streakHeading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("STREAK")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            Text("·")
                .foregroundStyle(.white.opacity(0.30))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(currentStreakDays)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("DAYS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(startSectionTitle)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            HStack(spacing: 14) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                Text(planSummary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }

            PrimaryActionButton(
                title: startButtonTitle,
                subtitle: nil
            ) {
                appState.startTodaysWorkout(basedOn: completedSessions.first)
            }
            .padding(.top, 4)

            // Secondary escape hatch — only shown when there's a
            // last session, since otherwise the primary already IS
            // "Start Workout" from the sample plan. Kept visually
            // quiet so it doesn't compete with the primary CTA.
            if hasLastSession {
                Button {
                    appState.startTodaysWorkout(basedOn: nil)
                } label: {
                    Text("Start a fresh workout instead")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.50))
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Horizontal chip strip of saved templates. Tap a chip → start
    /// that template directly (same path as Library detail's Start
    /// button). Sorted most-recently-used first, with never-used
    /// templates trailing in their original Library order.
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TEMPLATES")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(sortedTemplates) { template in
                        templateChip(template)
                    }
                }
            }
        }
    }

    private func templateChip(_ template: WorkoutTemplate) -> some View {
        Button {
            Haptics.soft()
            appState.startWorkoutFromTemplate(template)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(template.orderedExercises.count) ex · \(template.totalPlannedSets) sets")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))

                HStack(spacing: 4) {
                    ForEach(template.muscleGroups.prefix(4), id: \.self) { group in
                        Circle()
                            .fill(group.accent)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(14)
            .frame(width: 150, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start \(template.name)")
    }

    private var lastWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST WORKOUT")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            if let session = completedSessions.first {
                lastWorkoutCard(for: session)
            } else {
                Text("Nothing logged yet — your first session lands here.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.40))
            }
        }
    }

    private func lastWorkoutCard(for session: WorkoutSession) -> some View {
        let date = session.completedAt ?? session.startedAt
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(Self.relativeDayFormatter.string(from: date))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(Self.timeFormatter.string(from: date))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 0) {
                stat(value: "\(Int(session.duration / 60))", unit: "min", label: "TIME")
                statDivider
                stat(value: volumeLabel(session.totalVolume), unit: "lb", label: "VOLUME")
                statDivider
                stat(value: "\(session.totalSets)", unit: nil, label: "SETS")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func stat(value: String, unit: String?, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.5, height: 36)
    }

    // MARK: - Derived

    /// Whether the user has any prior session to base today's
    /// workout on. When true, the start section presents itself as
    /// "Repeat Last Workout" using the most recent session's
    /// structure; when false, it falls back to the seeded sample plan.
    private var hasLastSession: Bool { completedSessions.first != nil }

    /// Templates ordered for the chip strip: most-recently-used
    /// first, then never-used templates in their Library sortOrder.
    /// A `@Query` predicate-based sort can't express this hybrid
    /// (lastUsedAt is optional), so it's resolved client-side.
    private var sortedTemplates: [WorkoutTemplate] {
        templates.sorted { lhs, rhs in
            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case let (l?, r?):       return l > r
            case (.some, .none):     return true
            case (.none, .some):     return false
            case (.none, .none):     return lhs.sortOrder < rhs.sortOrder
            }
        }
    }

    /// The exercises that will populate the about-to-start session.
    /// Mirrors `appState.startTodaysWorkout(basedOn:)`'s logic so the
    /// plan summary on screen matches what the start button will do.
    private var planSourceExercises: [Exercise] {
        if let last = completedSessions.first, !last.orderedExercises.isEmpty {
            return last.orderedExercises
        }
        return appState.todaysPlan
    }

    private var planSummary: String {
        let exercises = planSourceExercises
        let groups = Set(exercises.map(\.group))
        let groupNames = groups.map(\.displayName).joined(separator: " · ")
        return "\(exercises.count) exercises  ·  \(groupNames)"
    }

    private var startSectionTitle: String {
        hasLastSession ? "REPEAT LAST WORKOUT" : "TODAY'S WORKOUT"
    }

    private var startButtonTitle: String {
        hasLastSession ? "Repeat Last Workout" : "Start Workout"
    }

    /// Calendar days on which the user has at least one archived
    /// session. Drives the StreakCalendar fills.
    private var workoutDates: Set<Date> {
        Set(completedSessions.map {
            Calendar.current.startOfDay(for: $0.completedAt ?? $0.startedAt)
        })
    }

    /// Consecutive days back from today (or yesterday) with a
    /// completed session. Today is allowed to be missing — the
    /// streak then counts from yesterday so an unworked morning
    /// doesn't visually reset the count.
    private var currentStreakDays: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dates = workoutDates

        var cursor = today
        if !dates.contains(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while dates.contains(cursor) {
            count += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    private func monthCount(in date: Date) -> Int {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: date) else { return 0 }
        return workoutDates.filter { $0 >= interval.start && $0 < interval.end }.count
    }

    private func volumeLabel(_ value: Double) -> String {
        Self.volumeFormatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
    }

    // MARK: - Formatters

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE  ·  MMM d"
        return f
    }()

    private static let relativeDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE  ·  MMM d"
        f.doesRelativeDateFormatting = true
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let volumeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f
    }()
}

#Preview("Today") {
    NavigationStack {
        TodayScreen(appState: AppState())
            .navigationTitle("Today")
    }
    .preferredColorScheme(.dark)
}
