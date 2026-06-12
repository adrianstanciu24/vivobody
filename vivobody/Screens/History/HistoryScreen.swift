//
//  HistoryScreen.swift
//  vivobody
//
//  Live list of every archived workout, rendered as an instrument:
//  no cards, no carved glass — structure comes from type, whitespace,
//  and hairlines on black. The screen opens as a *training-week log*:
//  a seven-dot cadence strip (one dot per day, filled when you
//  trained, ringed on today), a colored trend delta, and a card-free
//  stat strip led by the streak. This is deliberately about *time*,
//  not tonnage — Me is the all-time volume odometer; History is the
//  rhythm. Below it, sessions are grouped by date bucket (Today /
//  Yesterday / This Week / Last Week / month) and laid out as
//  full-width hairline-separated rows:
//
//    • Today — elevated rows: workout title + meta on the left, a
//      larger volume numeral on the right.
//    • Earlier — same row, tighter: date + muscle summary + time on
//      the left, a smaller volume numeral on the right.
//
//  PR sessions render their volume numeral in the gold completion
//  accent — a typographic cue only, no badge chrome.
//
//  Tapping any row pushes a detail view that reuses
//  WorkoutSummaryCard — the same "receipt" the user saw at the end
//  of the workout, now as a permanent record.
//

import SwiftUI
import SwiftData

struct HistoryScreen: View {
    @Bindable var appState: AppState

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Every completed (archived) session. SwiftData orders results
    /// by completedAt descending, so the most-recent workout sits
    /// at the top. Mid-flight sessions are still un-inserted and
    /// therefore invisible to this query.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    private var sessions: [WorkoutSession]

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .forgeBackground()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "No workouts yet",
            systemImage: "figure.strengthtraining.traditional",
            description: Text("Finish your first session and it lands here.")
        )
    }

    // MARK: - Content

    private var content: some View {
        let groups = groupedSessions
        let prSet = sessionsWithPR

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.section) {
                if showsWeeklyHero {
                    WeeklyHero(
                        comparison: sessions.weeklyComparison(),
                        currentStreakDays: currentStreakDays,
                        workoutDays: workoutDays,
                        unit: unit
                    )
                    .settleIn(0)
                    SectionDivider()
                }

                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    DateGroupSection(
                        group: group,
                        unit: unit,
                        prSessions: prSet
                    )
                    .settleIn(index + 1)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xxl)
        }
    }

    // MARK: - Derived

    /// Hero card only appears once the user has any logged activity
    /// in the current or prior week. Avoids a "0 / 0 / 0" tile
    /// for brand-new users on session #1.
    private var showsWeeklyHero: Bool {
        sessions.weeklyComparison().hasAnyActivity
    }

    /// Grouped sessions, ordered most-recent bucket first. Buckets:
    /// Today, Yesterday, Earlier this week, Last week, then by
    /// calendar month for anything older.
    private var groupedSessions: [HistoryDateGroup] {
        HistoryDateGroup.build(from: sessions)
    }

    /// IDs of sessions in which at least one exercise hit a new
    /// all-time top-weight at the moment it was logged. Walks the
    /// archive in chronological order, tracking the running max per
    /// exercise name. Matches the PR-celebration semantics the user
    /// already saw live.
    private var sessionsWithPR: Set<UUID> {
        var bestByExercise: [String: Double] = [:]
        var prIDs: Set<UUID> = []

        // sessions are sorted newest-first; iterate oldest-first.
        let chronological = sessions.reversed()
        for session in chronological {
            for exercise in session.orderedExercises {
                let topWeight = exercise.sets
                    .filter(\.isCompleted)
                    .map(\.weight)
                    .max() ?? 0
                guard topWeight > 0 else { continue }
                let key = exercise.name.lowercased()
                let prev = bestByExercise[key, default: 0]
                if topWeight > prev {
                    bestByExercise[key] = topWeight
                    prIDs.insert(session.id)
                }
            }
        }
        return prIDs
    }

    /// Every calendar day (start-of-day) on which at least one
    /// session was logged. Drives both the streak math and the
    /// week-cadence strip in the hero.
    private var workoutDays: Set<Date> {
        let calendar = Calendar.current
        return Set(sessions.map { calendar.startOfDay(for: $0.completedAt ?? $0.startedAt) })
    }

    /// Length of the current consecutive-workout-day streak ending
    /// today or yesterday. "Today" is forgiving: if the user hasn't
    /// trained today yet, the streak continues counting from
    /// yesterday backward instead of resetting to zero. Returns 0
    /// when there's no streak (no workout today or yesterday).
    private var currentStreakDays: Int {
        let calendar = Calendar.current
        let workoutDays = self.workoutDays
        guard !workoutDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        // Anchor: today if trained today, else yesterday if trained
        // yesterday, else no active streak.
        var cursor: Date
        if workoutDays.contains(today) {
            cursor = today
        } else if workoutDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var count = 0
        while workoutDays.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

}

// MARK: - Weekly hero

/// The week as a *log*, not a ledger: a "This week" kicker with a
/// colored trend delta, then the seven-dot cadence strip as the
/// dominant element (which days you showed up), then a card-free
/// stat strip led by the streak. Volume lives here too, but demoted
/// to a single cell — the hero is time, not tonnage. That's what
/// keeps History from reading as a recolored copy of Me's all-time
/// volume odometer.
private struct WeeklyHero: View {
    let comparison: WeeklyComparison
    let currentStreakDays: Int
    let workoutDays: Set<Date>
    let unit: WeightUnit

    private static let monoStat = Font.system(size: 28, weight: .bold, design: .monospaced)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header

            WeekCadenceStrip(workoutDays: workoutDays)
                .padding(.top, Space.xs)

            StatStrip(
                stats: [
                    Stat(value: streakLabel, label: "Streak", accent: currentStreakDays >= 2),
                    Stat(value: "\(comparison.thisWeek.workouts)", label: "Workouts"),
                    Stat(
                        value: WeightFormatter.volumeValue(comparison.thisWeek.volume, unit: unit),
                        unit: unit.symbol,
                        label: "Volume"
                    ),
                ],
                valueFont: Self.monoStat
            )
            .padding(.top, Space.sm)
        }
    }

    /// "This week" with the volume trend pinned to the right — the
    /// week's one editorial signal, kept as a colored numeral rather
    /// than a chart.
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("This week")
                .font(Typography.title)
                .foregroundStyle(Ink.primary.opacity(0.92))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.sm)
            trendDelta
        }
        .padding(.top, Space.sm)
    }

    /// Direction-of-change against last week, as a colored numeral
    /// rather than a chart: orange when up, dim when flat/down.
    /// Hidden when there's no prior week to compare against.
    @ViewBuilder
    private var trendDelta: some View {
        if comparison.lastWeek.volume > 0 {
            let pct = Int((comparison.volumeDelta / comparison.lastWeek.volume * 100).rounded())
            HStack(spacing: 3) {
                Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(abs(pct))% vs last week")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(pct >= 0 ? Tint.inProgress : Ink.tertiary)
        }
    }

    private var streakLabel: String {
        currentStreakDays <= 0 ? "—" : "\(currentStreakDays)d"
    }
}

// MARK: - Week cadence strip

/// Seven dots — the current locale week, Sunday-to-Saturday or
/// Monday-to-Sunday per the user's calendar. A filled orange dot is
/// a day you trained; a faint ring is a rest day; today wears a
/// brighter ring so "where am I in the week" reads at a glance.
/// Future days in the week are dimmed. This is the streak's calendar
/// DNA compressed to a single, glanceable row — History's signature.
private struct WeekCadenceStrip: View {
    let workoutDays: Set<Date>

    private var calendar: Calendar { .current }

    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                cell(for: day)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func cell(for day: Date) -> some View {
        let start = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: Date())
        let isWorkout = workoutDays.contains(start)
        let isToday = calendar.isDateInToday(day)
        let isFuture = start > today

        return VStack(spacing: Space.sm) {
            Text(Self.weekdayLetter.string(from: day))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Ink.primary.opacity(0.40))
            ZStack {
                Circle()
                    .fill(isWorkout ? Tint.primary : Color.clear)
                Circle()
                    .stroke(ringColor(isWorkout: isWorkout, isToday: isToday), lineWidth: isToday ? 1.5 : 1)
            }
            .frame(width: 30, height: 30)
            .opacity(isFuture ? 0.30 : 1.0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityDay.string(from: day))
        .accessibilityValue(isWorkout ? "Trained" : "Rest")
    }

    private func ringColor(isWorkout: Bool, isToday: Bool) -> Color {
        if isToday { return Ink.primary.opacity(0.55) }
        if isWorkout { return .clear }
        return Surface.edge
    }

    private static let weekdayLetter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f
    }()

    private static let accessibilityDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
}

// MARK: - Date group section

private struct DateGroupSection: View {
    let group: HistoryDateGroup
    let unit: WeightUnit
    let prSessions: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: group.title, trailing: group.subtitle)

            VStack(spacing: 0) {
                ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, session in
                    if index > 0 { SectionDivider() }
                    NavigationLink {
                        SessionDetailScreen(session: session)
                    } label: {
                        SessionRow(
                            session: session,
                            unit: unit,
                            hasPR: prSessions.contains(session.id),
                            prominent: group.style == .rich
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Session row

/// One archived session as a full-width hairline row — no card, no
/// carved glass. The left column carries identity (a workout title
/// for today, a date for earlier sessions) plus a muscle/time meta
/// line; the right column anchors the volume numeral in monospace.
/// `prominent` (today's sessions) enlarges the numeral and promotes
/// the title. A PR renders its numeral in the gold completion accent.
private struct SessionRow: View {
    let session: WorkoutSession
    let unit: WeightUnit
    let hasPR: Bool
    let prominent: Bool

    private var muscleTags: [MuscleGroup] { session.distinctMuscleGroupsInOrder }

    var body: some View {
        HStack(alignment: .center, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.sm) {
                    Text(titleLine)
                        .font(prominent ? Typography.title : Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                    if hasPR { prBadge }
                }
                Text(metaLine)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.sm)

            // Volume is the row's metric, not its headline — kept a calm
            // grayscale numeral so the workout's identity (name + muscle
            // fingerprint) leads. The accent lives only in the rare PR
            // badge, never on every line.
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(WeightFormatter.volumeValue(session.totalVolume, unit: unit))
                    .font(.system(size: prominent ? 24 : 19, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
                Text(unit.symbol)
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.quaternary)
        }
        .frame(maxWidth: .infinity, minHeight: prominent ? 72 : Space.rowMin, alignment: .leading)
        .padding(.vertical, Space.md)
        .contentShape(Rectangle())
    }

    /// The lone accent in the list: a small outlined "PR" tag next to
    /// a session that set a new top weight. Replaces the old practice
    /// of flooding the whole volume numeral orange, which made every
    /// row shout.
    private var prBadge: some View {
        Text("PR")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(Tint.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .overlay(Capsule().stroke(Tint.primaryDim, lineWidth: 1))
            .accessibilityLabel("Personal record")
    }

    /// Today's rows lead with the workout's muscle identity; earlier
    /// rows lead with their date.
    private var titleLine: String {
        prominent ? workoutTitle : dateLine
    }

    /// Secondary line: the session's muscle fingerprint followed by
    /// the time it was logged. The fingerprint is what stops a column
    /// of "Full body" rows from reading as identical — you can see at
    /// a glance which regions each session actually hit — while the
    /// time distinguishes multiple sessions on the same day.
    private var metaLine: String {
        "\(muscleFingerprint)  ·  \(timeString)"
    }

    private var workoutTitle: String {
        switch muscleTags.count {
        case 0: return "Workout"
        case 1: return "\(muscleTags[0].displayName) day"
        case 2: return "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: return "Full body"
        }
    }

    /// Up to three muscle groups, in worked order, with a "+N" tail
    /// when the session spans more. Gives even a generic "Full body"
    /// row a legible signature of what was actually trained.
    private var muscleFingerprint: String {
        let names = muscleTags.map(\.displayName)
        switch names.count {
        case 0: return "Workout"
        case 1, 2, 3: return names.joined(separator: " · ")
        default: return names.prefix(3).joined(separator: " · ") + " +\(names.count - 3)"
        }
    }

    private var dateLine: String {
        let date = session.completedAt ?? session.startedAt
        return HistoryFormatters.compactDay.string(from: date)
    }

    private var timeString: String {
        let date = session.completedAt ?? session.startedAt
        return HistoryFormatters.time.string(from: date)
    }
}

// MARK: - Date grouping

/// One contiguous bucket of sessions in the history list. Carries
/// its own header (e.g. "TODAY · 2 sessions") plus the row style
/// the section should render with.
struct HistoryDateGroup: Identifiable {
    enum Style { case rich, compact }

    let id: String
    let title: String
    let subtitle: String
    let style: Style
    let sessions: [WorkoutSession]

    /// Internal classification key for grouping sessions into the
    /// five bucket flavors we render. Hashable so we can look up
    /// existing buckets without re-iterating the accumulator.
    fileprivate enum Bucket: Hashable {
        case today, yesterday, thisWeek, lastWeek, month(Date)
    }

    /// Build a list of groups from the most-recent-first session list.
    /// Today's sessions get the rich style; everything else compact.
    static func build(
        from sessions: [WorkoutSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [HistoryDateGroup] {
        guard !sessions.isEmpty else { return [] }

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let thisWeekRange = calendar.dateInterval(of: .weekOfYear, for: now)
        let lastWeekRange: DateInterval? = {
            guard let thisWeek = thisWeekRange,
                  let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start)
            else { return nil }
            return calendar.dateInterval(of: .weekOfYear, for: lastWeekStart)
        }()

        var buckets: [(Bucket, [WorkoutSession])] = []

        func appendSession(_ session: WorkoutSession, into bucket: Bucket) {
            if let idx = buckets.firstIndex(where: { $0.0 == bucket }) {
                buckets[idx].1.append(session)
            } else {
                buckets.append((bucket, [session]))
            }
        }

        for session in sessions {
            let date = session.completedAt ?? session.startedAt
            let day = calendar.startOfDay(for: date)
            let bucket: Bucket
            if day == today {
                bucket = .today
            } else if day == yesterday {
                bucket = .yesterday
            } else if let thisWeek = thisWeekRange, thisWeek.contains(date) {
                bucket = .thisWeek
            } else if let lastWeek = lastWeekRange, lastWeek.contains(date) {
                bucket = .lastWeek
            } else {
                let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
                bucket = .month(monthStart)
            }
            appendSession(session, into: bucket)
        }

        return buckets.map { bucket, bucketSessions in
            let isRich: Bool
            if case .today = bucket { isRich = true } else { isRich = false }
            return HistoryDateGroup(
                id: id(for: bucket),
                title: title(for: bucket),
                subtitle: subtitle(for: bucketSessions),
                style: isRich ? .rich : .compact,
                sessions: bucketSessions
            )
        }
    }

    private static func id(for bucket: Bucket) -> String {
        switch bucket {
        case .today: return "today"
        case .yesterday: return "yesterday"
        case .thisWeek: return "thisWeek"
        case .lastWeek: return "lastWeek"
        case .month(let date): return "month-\(Int(date.timeIntervalSince1970))"
        }
    }

    private static func title(for bucket: Bucket) -> String {
        switch bucket {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "Earlier this week"
        case .lastWeek: return "Last week"
        case .month(let date):
            let f = DateFormatter()
            f.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) ? "LLLL" : "LLLL yyyy"
            return f.string(from: date)
        }
    }

    private static func subtitle(for sessions: [WorkoutSession]) -> String {
        let count = sessions.count
        return count == 1 ? "1 session" : "\(count) sessions"
    }
}

// MARK: - Helpers

extension WorkoutSession {
    /// Distinct muscle groups touched by this session, in plan order
    /// (i.e. the order the user worked through them). Used by the
    /// row chrome to derive the workout title and the muscle-dot
    /// strip — and by the session detail screen for the same.
    var distinctMuscleGroupsInOrder: [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        var ordered: [MuscleGroup] = []
        for exercise in orderedExercises {
            if seen.insert(exercise.group).inserted {
                ordered.append(exercise.group)
            }
        }
        return ordered
    }
}

private enum HistoryFormatters {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    static let compactDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f
    }()
}

#Preview {
    NavigationStack {
        HistoryScreen(appState: AppState())
            .navigationTitle("History")
    }
    .preferredColorScheme(.dark)
}
