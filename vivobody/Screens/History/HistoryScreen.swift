//
//  HistoryScreen.swift
//  vivobody
//
//  Live list of every archived workout — but framed as a journal,
//  not a stats table. Top of the screen carries a "This week" hero
//  card: a sparkline + the three weekly totals so the page has a
//  pulse before you start scrolling rows. Below it, sessions are
//  grouped by date bucket (Today / Yesterday / This Week / Last
//  Week / month) and rendered with two row styles:
//
//    • Recent (today's sessions) — full rich card on a clean
//      Liquid Glass surface, with a muscle-tinted left stripe,
//      hero volume number, and PR / streak badges in the corner.
//    • Earlier — compact row: colored left edge, date, volume,
//      muscle dots, time, chevron. Same identity, less weight.
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
        .background {
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Tint.primary.opacity(0.28), location: 0.0),
                        .init(color: Tint.primary.opacity(0.08), location: 0.55),
                        .init(color: Tint.primary.opacity(0.00), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Color.white.opacity(0.02)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .glassCard(cornerRadius: 24)
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

            VStack(spacing: 10) {
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

/// Today's sessions get the dramatic treatment: a clean Liquid
/// Glass card carrying a muscle-tinted left edge stripe, a hero
/// volume number, and any PR / streak badges in the top-right.
private struct RichSessionRow: View {
    let session: WorkoutSession
    let unit: WeightUnit
    let hasPR: Bool
    let isStreakDay: Bool

    private var muscleTags: [MuscleGroup] { session.distinctMuscleGroupsInOrder }
    private var dominant: MuscleGroup { muscleTags.first ?? .chest }
    private var accent: Color { dominant.accent }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Colored stripe down the left edge — the unique fingerprint
            // for this session's muscle mix.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.95), accent.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 14)
                .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 14) {
                header

                HStack(alignment: .lastTextBaseline, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(WeightFormatter.volumeValue(session.totalVolume, unit: unit))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(unit.symbol)
                                .font(Typography.metricUnit)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Text("Volume")
                            .sectionLabelStyle(0.55)
                    }

                    Spacer(minLength: 0)

                    secondaryStat(value: "\(session.totalSets)", label: session.totalSets == 1 ? "set" : "sets")

                    if displayMinutes >= 1 {
                        secondaryStat(value: "\(displayMinutes)", label: "min")
                    }
                }

                if !muscleTags.isEmpty {
                    muscleDots
                }
            }
            .padding(.vertical, 16)
            .padding(.leading, 14)
            .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22)
        .topSpecularSheen(cornerRadius: 22, intensity: 0.08, height: 0.42)
        .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(timeString)
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                if isStreakDay { streakBadge }
                if hasPR { prBadge }
            }
        }
    }

    private var prBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 9, weight: .bold))
            Text("PR")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.85, blue: 0.35), Color(red: 1.0, green: 0.70, blue: 0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
        .shadow(color: Color(red: 1.0, green: 0.78, blue: 0.30).opacity(0.45), radius: 6, y: 2)
    }

    private var streakBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("Streak")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Tint.primary.opacity(0.85))
        )
        .shadow(color: Tint.primary.opacity(0.50), radius: 6, y: 2)
    }

    private func secondaryStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .sectionLabelStyle(0.55)
        }
        .fixedSize()
    }

    private var muscleDots: some View {
        HStack(spacing: 8) {
            ForEach(muscleTags.prefix(4), id: \.self) { group in
                HStack(spacing: 5) {
                    Circle()
                        .fill(group.accent)
                        .frame(width: 7, height: 7)
                        .shadow(color: group.accent.opacity(0.65), radius: 3)
                    Text(group.displayName)
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.70))
                }
            }
            if muscleTags.count > 4 {
                Text("+\(muscleTags.count - 4)")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.40))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Derived

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

/// Earlier sessions get a single-line treatment: colored left edge,
/// relative day, volume, muscle dots, time, chevron. PR / streak
/// presence shows as a tiny indicator dot rather than a full badge
/// — every entry the same height, scannable.
private struct CompactSessionRow: View {
    let session: WorkoutSession
    let unit: WeightUnit
    let hasPR: Bool
    let isStreakDay: Bool

    private var muscleTags: [MuscleGroup] { session.distinctMuscleGroupsInOrder }
    private var dominant: MuscleGroup { muscleTags.first ?? .chest }
    private var accent: Color { dominant.accent }

    var body: some View {
        HStack(spacing: 0) {
            // Colored stripe — same idea as the rich row, just
            // shorter overall.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.90), accent.opacity(0.40)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(dateLine)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        if hasPR { tinyPRDot }
                        if isStreakDay { tinyFlame }
                    }
                    HStack(spacing: 6) {
                        ForEach(muscleTags.prefix(4), id: \.self) { group in
                            Circle()
                                .fill(group.accent)
                                .frame(width: 6, height: 6)
                        }
                        if muscleTags.count > 4 {
                            Text("+\(muscleTags.count - 4)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.40))
                        }
                        Text(timeString)
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.40))
                            .padding(.leading, 4)
                    }
                }

                Spacer(minLength: 8)

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(WeightFormatter.volumeValue(session.totalVolume, unit: unit))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(unit.symbol)
                        .font(Typography.metricUnit)
                        .foregroundStyle(.white.opacity(0.45))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.30))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(
                    colors: [accent.opacity(0.16), accent.opacity(0.02)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                Color.white.opacity(0.025)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .glassCard(cornerRadius: 16)
    }

    private var tinyPRDot: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.30))
    }

    private var tinyFlame: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Tint.primary)
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
