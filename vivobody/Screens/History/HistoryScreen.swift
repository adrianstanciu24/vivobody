//
//  HistoryScreen.swift
//  vivobody
//
//  Live list of every archived workout — but framed as a journal,
//  not a stats table. Top of the screen carries a "This week" hero
//  card: a sparkline + the three weekly totals so the page has a
//  pulse before you start scrolling rows. Below it, sessions are
//  grouped by date bucket (Today / Yesterday / This Week / Last
//  Week / month) and rendered with two row styles, both built on
//  the same Liquid Glass language — restraint, typography, and
//  carved depth:
//
//    • Recent (today's sessions) — rich tile with a workout-
//      title header, meta column on the left, and a large
//      volume number carved into the glass on the right. Muscle
//      groups read as small monospaced labels beneath a hairline
//      divider, in their accent colors.
//    • Earlier — single-row layout: date + muscle summary + time
//      on the left, smaller carved volume on the right. Same
//      vocabulary, half the height.
//
//  PR sessions add a thin gold underline beneath the carved
//  volume — a typographic accent only, no badge chrome.
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                GlassSphere(size: 132, tint: Tint.primary)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 56, weight: .light))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Tint.primary, .white.opacity(0.30))
                    .symbolEffect(.breathe.pulse, options: .repeating)
            }
            .primaryGlow(Tint.primary, radius: 32, y: 0)

            VStack(spacing: 6) {
                Text("No workouts yet")
                    .sectionHeadingStyle()
                Text("Finish your first session and it lands here.")
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        let groups = groupedSessions
        let prSet = sessionsWithPR
        let streakSet = streakDaySessions

        return ScrollView {
            LazyVStack(spacing: 22) {
                if showsWeeklyHero {
                    WeeklyHeroCard(
                        comparison: sessions.weeklyComparison(),
                        weeklyVolumeSeries: sessions.weeklySeries(weeks: 8).map(\.volume),
                        currentStreakDays: currentStreakDays,
                        unit: unit
                    )
                }

                ForEach(Array(groups.enumerated()), id: \.element.id) { _, group in
                    DateGroupSection(
                        group: group,
                        unit: unit,
                        prSessions: prSet,
                        streakSessions: streakSet
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 28)
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

    /// IDs of sessions on a date that's part of a 2+ day streak
    /// (yesterday OR tomorrow also had at least one logged session).
    /// Surfaced as a flame badge so the user feels the rhythm of
    /// consecutive training days.
    private var streakDaySessions: Set<UUID> {
        let calendar = Calendar.current
        var sessionsByDay: [Date: [WorkoutSession]] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.completedAt ?? session.startedAt)
            sessionsByDay[day, default: []].append(session)
        }
        let workoutDays = Set(sessionsByDay.keys)

        var result: Set<UUID> = []
        for (day, daySessions) in sessionsByDay {
            guard
                let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)
            else { continue }
            if workoutDays.contains(yesterday) || workoutDays.contains(tomorrow) {
                for s in daySessions { result.insert(s.id) }
            }
        }
        return result
    }
}

// MARK: - Weekly hero card

/// "This week" hero card. Sparkline of the last 8 weeks of volume
/// on the left, three weekly stat columns on the right (workouts /
/// sets / volume). The whole card sits inside a primary-tinted
/// glass surface so the page reads as alive before the first row.
private struct WeeklyHeroCard: View {
    let comparison: WeeklyComparison
    let weeklyVolumeSeries: [Double]
    let currentStreakDays: Int
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.70))
                    .tracking(0.5)
                    .textCase(.uppercase)
                Spacer()
                if comparison.lastWeek.workouts > 0 || comparison.thisWeek.workouts > 0 {
                    Text("vs last week")
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.40))
                }
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(WeightFormatter.volumeValue(comparison.thisWeek.volume, unit: unit))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(unit.symbol)
                            .font(Typography.metricUnit)
                            .foregroundStyle(.white.opacity(0.50))
                    }
                    Text("Total volume")
                        .sectionLabelStyle(0.55)
                }

                Spacer(minLength: 8)

                if weeklyVolumeSeries.count >= 2 && weeklyVolumeSeries.contains(where: { $0 > 0 }) {
                    MiniChart(
                        values: weeklyVolumeSeries,
                        lineColor: Tint.primary,
                        fillColor: Tint.primary
                    )
                    .frame(width: 92, height: 38)
                }
            }

            HStack(spacing: 0) {
                heroStat(
                    value: "\(comparison.thisWeek.workouts)",
                    delta: comparison.workoutsDelta,
                    label: "Workouts"
                )
                heroDivider
                heroStat(
                    value: "\(comparison.thisWeek.sets)",
                    delta: comparison.setsDelta,
                    label: "Sets"
                )
                heroDivider
                heroStat(
                    value: streakLabel,
                    label: "Streak",
                    accentOverride: streakAccent
                )
            }
            .padding(.top, 2)
        }
        .padding(18)
        .glassCard(cornerRadius: 24, tint: Tint.primary)
        .primaryGlow(Tint.primary.opacity(0.55), radius: 22, y: 6)
    }

    private func heroStat(
        value: String,
        delta: Int = 0,
        label: String,
        accentOverride: Color? = nil
    ) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(accentOverride ?? .white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .sectionLabelStyle(0.55)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.5, height: 28)
    }

    private var streakLabel: String {
        currentStreakDays <= 0 ? "—" : "\(currentStreakDays)d"
    }

    private var streakAccent: Color? {
        currentStreakDays >= 2 ? Tint.primary : nil
    }
}

// MARK: - Date group section

private struct DateGroupSection: View {
    let group: HistoryDateGroup
    let unit: WeightUnit
    let prSessions: Set<UUID>
    let streakSessions: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(0.6)
                    .textCase(.uppercase)
                Spacer()
                Text(group.subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(group.sessions) { session in
                    NavigationLink {
                        SessionDetailScreen(session: session)
                    } label: {
                        if group.style == .rich {
                            RichSessionRow(
                                session: session,
                                unit: unit,
                                hasPR: prSessions.contains(session.id),
                                isStreakDay: streakSessions.contains(session.id)
                            )
                        } else {
                            CompactSessionRow(
                                session: session,
                                unit: unit,
                                hasPR: prSessions.contains(session.id),
                                isStreakDay: streakSessions.contains(session.id)
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Rich row (recent sessions)

/// Today's sessions get the editorial treatment: a clean glass
/// card with the volume number carved into its surface as the
/// hero. Identity comes from typographic hierarchy and material
/// depth, not from decoration. PR workouts add a thin gold
/// hairline beneath the carved volume — a typographic accent,
/// not a badge.
private struct RichSessionRow: View {
    let session: WorkoutSession
    let unit: WeightUnit
    let hasPR: Bool
    let isStreakDay: Bool

    private var muscleTags: [MuscleGroup] { session.distinctMuscleGroupsInOrder }

    private static let cornerRadius: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(alignment: .bottom, spacing: 14) {
                metaColumn
                Spacer(minLength: 8)
                CarvedVolumeText(
                    value: WeightFormatter.volumeValue(session.totalVolume, unit: unit),
                    unit: unit.symbol,
                    size: 38,
                    isPR: hasPR
                )
            }

            if !muscleTags.isEmpty {
                Divider().background(Color.white.opacity(0.06))
                muscleStrip
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: Self.cornerRadius)
        .topSpecularSheen(cornerRadius: Self.cornerRadius, intensity: 0.08, height: 0.42)
        .glassRimBevel(cornerRadius: Self.cornerRadius, outerWidth: 0.6, innerInset: 1.2)
        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(workoutTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
            Spacer(minLength: 4)
            if isStreakDay { streakIndicator }
            if hasPR { prLabel }
        }
    }

    private var metaColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(timeString.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1.2)
            HStack(spacing: 6) {
                Text("\(session.totalSets) \(session.totalSets == 1 ? "set" : "sets")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.70))
                    .monospacedDigit()
                if displayMinutes >= 1 {
                    metaDivider
                    Text("\(displayMinutes) min")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .monospacedDigit()
                }
            }
        }
    }

    private var metaDivider: some View {
        Text("·")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.30))
    }

    private var muscleStrip: some View {
        HStack(spacing: 14) {
            ForEach(muscleTags.prefix(4), id: \.self) { group in
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(group.accent.opacity(0.85))
                        .frame(width: 8, height: 2)
                    Text(group.displayName.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                        .tracking(0.8)
                }
            }
            if muscleTags.count > 4 {
                Text("+\(muscleTags.count - 4)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
            }
            Spacer(minLength: 0)
        }
    }

    private var prLabel: some View {
        Text("PR")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.0)
            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.30))
    }

    private var streakIndicator: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Tint.primary.opacity(0.85))
    }

    private var workoutTitle: String {
        switch muscleTags.count {
        case 0: return "Workout"
        case 1: return "\(muscleTags[0].displayName) day"
        case 2: return "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: return "Full body"
        }
    }

    private var displayMinutes: Int {
        Int(session.duration / 60)
    }

    private var timeString: String {
        let date = session.completedAt ?? session.startedAt
        return HistoryFormatters.time.string(from: date)
    }
}

// MARK: - Compact row (earlier sessions)

/// Earlier sessions get the same carved-glass vocabulary, just
/// tighter. Date / muscle / time stack on the left; the carved
/// volume number sits on the right as the visual anchor. No
/// decoration — identity comes from the typography and the glass
/// material's own rim lighting.
private struct CompactSessionRow: View {
    let session: WorkoutSession
    let unit: WeightUnit
    let hasPR: Bool
    let isStreakDay: Bool

    private var muscleTags: [MuscleGroup] { session.distinctMuscleGroupsInOrder }

    private static let cornerRadius: CGFloat = 18

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(dateLine)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    if isStreakDay {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Tint.primary.opacity(0.80))
                    }
                }

                HStack(spacing: 8) {
                    Text(muscleSummary.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(1.0)
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.25))
                    Text(timeString)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.40))
                        .tracking(0.4)
                }
            }

            Spacer(minLength: 8)

            CarvedVolumeText(
                value: WeightFormatter.volumeValue(session.totalVolume, unit: unit),
                unit: unit.symbol,
                size: 24,
                isPR: hasPR
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .glassCard(cornerRadius: Self.cornerRadius)
        .glassRimBevel(cornerRadius: Self.cornerRadius, outerWidth: 0.5, innerInset: 1.0)
    }

    /// Single-line muscle summary — abbreviated for compact rows.
    /// Two muscles get joined with "+"; three or more collapse to
    /// "Full body" so the row stays clean.
    private var muscleSummary: String {
        switch muscleTags.count {
        case 0: return "Workout"
        case 1: return muscleTags[0].displayName
        case 2: return "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: return "Full body"
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

private extension WorkoutSession {
    /// Distinct muscle groups touched by this session, in plan order
    /// (i.e. the order the user worked through them). Used by the
    /// row chrome to derive the workout title and the muscle-dot
    /// strip.
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

// MARK: - Carved volume text

/// "Pressed into the glass" numerical hero. The value is rendered
/// in tabular monospaced figures with a top-down vertical gradient
/// (darker top, brighter bottom) plus a thin dark shadow above and
/// a faint white halo below — together they read as a number
/// physically carved into the card surface, the way an engraved
/// metal plate catches light only on its lower lip.
///
/// Layout: large carved value, tiny unit subscript baseline-aligned
/// to the right. PR sessions add a hairline gold underline beneath
/// the digits — typographic accent only, no badge chrome.
private struct CarvedVolumeText: View {
    let value: String
    let unit: String
    var size: CGFloat = 36
    var isPR: Bool = false

    private static let prGold = Color(red: 1.0, green: 0.78, blue: 0.30)

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .kerning(-0.6)
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.58), location: 0.0),
                                .init(color: .white.opacity(0.94), location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.55), radius: 0.6, x: 0, y: -0.5)
                    .shadow(color: .white.opacity(0.10), radius: 0.4, x: 0, y: 0.8)

                Text(unit)
                    .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.40))
                    .padding(.bottom, 2)
            }

            if isPR {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Self.prGold.opacity(0.0), Self.prGold.opacity(0.85), Self.prGold.opacity(0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .frame(maxWidth: size * 1.6)
            }
        }
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

// MARK: - Detail

/// Pushed when the user taps a history row. Reuses WorkoutSummaryCard
/// — the same end-of-workout receipt, just looking at the past instead
/// of the present. The card reads the session's totals/exercises
/// directly, so no transformation is needed.
private struct SessionDetailScreen: View {
    let session: WorkoutSession

    var body: some View {
        ScrollView {
            WorkoutSummaryCard(session: session, isHistorical: true)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HistoryScreen(appState: AppState())
            .navigationTitle("History")
    }
    .preferredColorScheme(.dark)
}
