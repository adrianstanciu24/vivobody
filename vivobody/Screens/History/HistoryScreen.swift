//
//  HistoryScreen.swift
//  vivobody
//
//  Live list of every archived workout, rendered as an instrument:
//  no cards, no carved glass — structure comes from type, whitespace,
//  and hairlines on black. The screen opens with the week's defining
//  numeral (Total volume) as a large monospaced hero, a colored
//  trend delta, and a card-free stat strip. Below it, sessions are
//  grouped by date bucket (Today / Yesterday / This Week / Last
//  Week / month) and laid out as full-width hairline-separated rows:
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
        .screenBackground()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Space.sm) {
            Text("No workouts yet")
                .sectionHeadingStyle()
            Text("Finish your first session and it lands here.")
                .font(Typography.body)
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
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
                        unit: unit
                    )
                    SectionDivider()
                }

                ForEach(Array(groups.enumerated()), id: \.element.id) { _, group in
                    DateGroupSection(
                        group: group,
                        unit: unit,
                        prSessions: prSet
                    )
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

    /// Length of the current consecutive-workout-day streak ending
    /// today or yesterday. "Today" is forgiving: if the user hasn't
    /// trained today yet, the streak continues counting from
    /// yesterday backward instead of resetting to zero. Returns 0
    /// when there's no streak (no workout today or yesterday).
    private var currentStreakDays: Int {
        let calendar = Calendar.current
        let workoutDays: Set<Date> = Set(
            sessions.map { calendar.startOfDay(for: $0.completedAt ?? $0.startedAt) }
        )
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

/// The week as an instrument: a "This week" kicker, the Total volume
/// numeral as the dominant monospaced hero, a colored trend delta
/// against last week, and a card-free stat strip (workouts / sets /
/// streak). No surface, no sparkline — type and a single hairline
/// carry it.
private struct WeeklyHero: View {
    let comparison: WeeklyComparison
    let currentStreakDays: Int
    let unit: WeightUnit

    private static let volumeHero = Font.system(size: 60, weight: .bold, design: .monospaced)
    private static let monoStat = Font.system(size: 28, weight: .bold, design: .monospaced)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "This week",
                trailing: comparison.lastWeek.workouts > 0 ? "vs last week" : nil
            )

            HStack(alignment: .lastTextBaseline, spacing: Space.md) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(WeightFormatter.volumeValue(comparison.thisWeek.volume, unit: unit))
                        .font(Self.volumeHero)
                        .foregroundStyle(Ink.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(unit.symbol)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer(minLength: Space.sm)
                trendDelta
            }

            Text("Total volume")
                .sectionLabelStyle(0.45)

            StatStrip(
                stats: [
                    Stat(value: "\(comparison.thisWeek.workouts)", label: "Workouts"),
                    Stat(value: "\(comparison.thisWeek.sets)", label: "Sets"),
                    Stat(value: streakLabel, label: "Streak", accent: currentStreakDays >= 2),
                ],
                valueFont: Self.monoStat
            )
            .padding(.top, Space.sm)
        }
    }

    /// Direction-of-change against last week, as a colored numeral
    /// rather than a chart: lime when up, dim when flat/down. Hidden
    /// when there's no prior week to compare against.
    @ViewBuilder
    private var trendDelta: some View {
        if comparison.lastWeek.volume > 0 {
            let pct = Int((comparison.volumeDelta / comparison.lastWeek.volume * 100).rounded())
            HStack(spacing: 2) {
                Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(abs(pct))%")
            }
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(pct >= 0 ? Tint.inProgress : Ink.tertiary)
        }
    }

    private var streakLabel: String {
        currentStreakDays <= 0 ? "—" : "\(currentStreakDays)d"
    }
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
                Text(titleLine)
                    .font(prominent ? Typography.title : Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                Text(metaLine)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Space.sm)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(WeightFormatter.volumeValue(session.totalVolume, unit: unit))
                    .font(.system(size: prominent ? 30 : 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(hasPR ? Tint.complete : Ink.primary)
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

    /// Today's rows lead with the workout's muscle identity; earlier
    /// rows lead with their date.
    private var titleLine: String {
        prominent ? workoutTitle : dateLine
    }

    /// Secondary line: today shows sets · minutes · time; earlier
    /// shows the muscle summary · time. Either way the numeral on the
    /// right stays the anchor.
    private var metaLine: String {
        if prominent {
            var parts = ["\(session.totalSets) \(session.totalSets == 1 ? "set" : "sets")"]
            if displayMinutes >= 1 { parts.append("\(displayMinutes) min") }
            parts.append(timeString)
            return parts.joined(separator: "  ·  ")
        } else {
            return "\(muscleSummary)  ·  \(timeString)"
        }
    }

    private var workoutTitle: String {
        switch muscleTags.count {
        case 0: return "Workout"
        case 1: return "\(muscleTags[0].displayName) day"
        case 2: return "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: return "Full body"
        }
    }

    private var muscleSummary: String {
        switch muscleTags.count {
        case 0: return "Workout"
        case 1: return muscleTags[0].displayName
        case 2: return "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: return "Full body"
        }
    }

    private var displayMinutes: Int { Int(session.duration / 60) }

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
