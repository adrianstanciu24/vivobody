//
//  TodayScreen.swift
//  vivobody
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

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

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
            // Order is deliberate: the workout you can start is at the
            // top, thumb-reachable, above the fold — "Today is the
            // workout queued up, one tap from starting." The calendar
            // and history are the journal underneath, reached by a
            // scroll once you've decided.
            VStack(alignment: .leading, spacing: Space.section) {
                dateStrip
                startSection
                if !templates.isEmpty {
                    templatesSection
                }
                SectionDivider()
                streakSection
                SectionDivider()
                lastWorkoutSection
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.lg)
        }
        .screenBackground()
        .onAppear { Haptics.prepare() }
    }

    // MARK: - Sections

    /// Small monospaced date caption that sits just below the system
    /// large title. The title says where you are ("Today"); this strip
    /// gives you the calendar context.
    private var dateStrip: some View {
        Text(Self.dayFormatter.string(from: Date()))
            .sectionLabelStyle(0.45)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Streak",
                trailing: workoutDates.isEmpty ? nil : "\(monthCount(in: Date())) this month"
            )
            streakHeading
            StreakCalendar(workoutDates: workoutDates, month: Date())
        }
    }

    private var streakHeading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(currentStreakDays)")
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(currentStreakDays > 0 ? Tint.inProgress : Ink.primary)
                .monospacedDigit()
            Text(currentStreakDays == 1 ? "day" : "days")
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
        }
    }

    private var startSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: startSectionTitle)

            Text(planSummary)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)

            PrimaryActionButton(
                title: startButtonTitle,
                subtitle: nil
            ) {
                appState.startTodaysWorkout(basedOn: completedSessions.first)
            }
            .padding(.top, Space.xs)

            // Secondary escape hatch — only shown when there's a
            // last session, since otherwise the primary already IS
            // "Start Workout" from the sample plan. Kept visually
            // quiet so it doesn't compete with the primary CTA.
            if hasLastSession {
                Button {
                    appState.startTodaysWorkout(basedOn: nil)
                } label: {
                    Text("Start a fresh workout instead")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Space.xs)
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
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Templates")

            VStack(spacing: 0) {
                ForEach(Array(sortedTemplates.enumerated()), id: \.element.id) { index, template in
                    if index > 0 { SectionDivider() }
                    templateRow(template)
                }
            }
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        Button {
            Haptics.soft()
            appState.startWorkoutFromTemplate(template)
        } label: {
            HStack(spacing: Space.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(Typography.title)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                    Text(templateSubtitle(template))
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: Space.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.quaternary)
            }
            .frame(minHeight: Space.rowMin)
            .padding(.vertical, Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start \(template.name)")
    }

    private func templateSubtitle(_ template: WorkoutTemplate) -> String {
        let count = template.orderedExercises.count
        let base = "\(count) ex · \(template.totalPlannedSets) sets"
        let groups = template.muscleGroups.prefix(3).map(\.displayName).joined(separator: " · ")
        return groups.isEmpty ? base : "\(base) · \(groups)"
    }

    private var lastWorkoutSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Last workout")

            if let session = completedSessions.first {
                lastWorkoutCard(for: session)
            } else {
                Text("Nothing logged yet — your first session lands here.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.tertiary)
            }
        }
    }

    private func lastWorkoutCard(for session: WorkoutSession) -> some View {
        let date = session.completedAt ?? session.startedAt
        return VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                Text(Self.relativeDayFormatter.string(from: date))
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Spacer()
                Text(Self.timeFormatter.string(from: date))
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
            }

            StatStrip(
                stats: [
                    Stat(value: "\(Int(session.duration / 60))", unit: "min", label: "Time"),
                    Stat(value: volumeLabel(session.totalVolume), unit: unit.symbol, label: "Volume"),
                    Stat(value: "\(session.totalSets)", label: "Sets"),
                ],
                valueFont: Self.monoStatValue
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static let monoStatValue = Font.system(size: 28, weight: .bold, design: .monospaced)

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
        hasLastSession ? "Repeat last workout" : "Today's workout"
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
        WeightFormatter.volumeValue(value, unit: unit)
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
}

#Preview("Today") {
    NavigationStack {
        TodayScreen(appState: AppState())
            .navigationTitle("Today")
    }
    .preferredColorScheme(.dark)
}
