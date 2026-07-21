//
//  HistoryComponents.swift
//  vivobody
//
//  Supporting view types for the History screen: weekly hero, week
//  cadence strip, cadence dot, date-group sections, session rows,
//  date grouping logic, and shared formatters. Extracted from
//  HistoryScreen.swift.
//

import VivoKit
import SwiftUI
import SwiftData

// MARK: - Weekly hero

/// The week as a *log*, not a ledger: a "This week" kicker with a
/// colored trend delta, then the seven-dot cadence strip as the
/// dominant element (which days you showed up), then a card-free
/// stat strip led by the streak. Volume lives here too, but demoted
/// to a single cell — the hero is time, not tonnage. That's what
/// keeps History from reading as a recolored copy of Me's all-time
/// volume odometer.
struct WeeklyHero: View {
    let comparison: WeeklyComparison
    let averageRIR: Double?
    let workoutDays: Set<Date>
    let prDays: Set<Date>
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header

            WeekCadenceStrip(workoutDays: workoutDays, prDays: prDays)
                .padding(.top, Space.xs)

            StatStrip(
                stats: [
                    Stat(value: rirLabel, label: "Avg RIR", accent: isRIROnTarget),
                    Stat(value: "\(comparison.thisWeek.workouts)", label: "Workouts"),
                    Stat(
                        value: weeklyVolumeValue,
                        unit: weeklyVolumeUnit,
                        label: weeklyVolumeLabel
                    ),
                ],
                valueFont: Typography.statValue
            )
            .padding(.top, Space.sm)
        }
    }

    /// "This week" with the volume trend pinned to the right — the
    /// week's one editorial signal, kept as a colored numeral rather
    /// than a chart.
    var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("This week")
                .font(Typography.title)
                .foregroundStyle(Ink.primary.opacity(Opacity.strong))
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
    var trendDelta: some View {
        if comparison.thisWeek.volumeAvailability == .complete,
           comparison.lastWeek.volumeAvailability == .complete,
           comparison.lastWeek.volume > 0 {
            let pct = Int((comparison.volumeDelta / comparison.lastWeek.volume * 100).rounded())
            HStack(spacing: 3) {
                Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .accessibilityHidden(true)
                Text("\(abs(pct))% vs last week")
            }
            .font(Typography.sectionLabel)
            .foregroundStyle(pct >= 0 ? Tint.inProgress : Ink.tertiary)
        }
    }

    var rirLabel: String {
        guard let rir = averageRIR else { return "—" }
        return String(format: "%.1f", rir)
    }

    var isRIROnTarget: Bool {
        guard let rir = averageRIR else { return false }
        return rir >= 1.0 && rir <= 3.0
    }

    private var weeklyVolumeValue: String {
        let value = WeightFormatter.volumeValue(comparison.thisWeek.volume, unit: unit)
        return comparison.thisWeek.volumeAvailability == .partial ? "\(value)+" :
            (comparison.thisWeek.volumeAvailability == .unavailable ? "—" : value)
    }

    private var weeklyVolumeUnit: String? {
        comparison.thisWeek.volumeAvailability == .unavailable ? nil : unit.symbol
    }

    private var weeklyVolumeLabel: String {
        switch comparison.thisWeek.volumeAvailability {
        case .complete: "Volume"
        case .partial: "Known volume"
        case .unavailable: "Volume unavailable"
        }
    }
}

// MARK: - Week cadence strip

/// Seven dots — the current locale week, Sunday-to-Saturday or
/// Monday-to-Sunday per the user's calendar. A filled orange dot is
/// a day you trained; a dim filled circle is a past rest day (the
/// day is gone, you didn't train); a hollow ring is a future rest
/// day (still ahead, nothing logged yet); an empty today wears an
/// orange ring. Days with a PR gently pulsate — a soft ember breath that
/// draws the eye to achievements. This is the streak's calendar DNA
/// compressed to a single, glanceable row — History's signature.
struct WeekCadenceStrip: View {
    let workoutDays: Set<Date>
    let prDays: Set<Date>

    var calendar: Calendar { .current }

    var weekDays: [Date] {
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

    func cell(for day: Date) -> some View {
        let start = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: Date())
        let isWorkout = workoutDays.contains(start)
        let isToday = calendar.isDateInToday(day)
        let isPast = start < today
        let isPR = prDays.contains(start)

        return VStack(spacing: Space.sm) {
            Text(Self.weekdayLetter.string(from: day))
                .font(Typography.caption)
                .foregroundStyle(Ink.primary.opacity(Opacity.soft))
            CadenceDot(
                isWorkout: isWorkout,
                isToday: isToday,
                isPast: isPast,
                isPR: isPR
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityDay.string(from: day))
        .accessibilityValue(isWorkout ? (isPR ? "Trained, personal record" : "Trained") : "Rest")
    }

    static let weekdayLetter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f
    }()

    static let accessibilityDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
}

/// A single cadence dot. PR days gently pulsate — a soft scale breath
/// plus an ember-colored glow that appears and disappears, matching
/// the forge's living-motion vocabulary. Non-PR days are static.
/// Reduce Motion users see a static dot.
struct CadenceDot: View {
    let isWorkout: Bool
    let isToday: Bool
    let isPast: Bool
    let isPR: Bool

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var pulse = false

    var shouldPulse: Bool { isPR && !reduceMotion }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
            Circle()
                .stroke(ringColor, lineWidth: isToday ? 1.5 : 1)
        }
        .frame(width: 30, height: 30)
        .scaleEffect(shouldPulse ? (pulse ? 1.06 : 1.0) : 1.0)
        .shadow(
            color: shouldPulse ? Tint.primary.opacity(pulse ? 0.35 : 0) : .clear,
            radius: pulse ? 8 : 0
        )
        .onAppear {
            guard shouldPulse else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    /// Trained days fill bright orange; past rest days fill dim;
    /// today and future rest days stay clear.
    var fillColor: Color {
        if isWorkout { return Tint.primary }
        if isPast { return Surface.edge }
        return .clear
    }

    /// An empty today wears the in-progress orange ring; future rest
    /// days keep the hairline ring; trained and past rest days need no ring.
    var ringColor: Color {
        if isToday && !isWorkout { return Tint.inProgress }
        if isToday { return Ink.primary.opacity(Opacity.medium) }
        if isWorkout { return .clear }
        return Surface.edge
    }
}

// MARK: - Date group section

struct DateGroupSection: View {
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
                    .accessibilityHint("Opens workout details")
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
struct SessionRow: View {
    let session: WorkoutSession
    let unit: WeightUnit
    let hasPR: Bool
    let prominent: Bool

    var muscleTags: [MuscleGroup] { session.distinctMuscleGroupsInOrder }

    var body: some View {
        HStack(alignment: .center, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.sm) {
                    Text(titleLine)
                        .font(prominent ? Typography.title : Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if hasPR { prBadge }
                }
                Text(metaLine)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: Space.sm)

            // Volume is the row's metric, not its headline — kept a calm
            // grayscale numeral so the workout's identity (name + muscle
            // fingerprint) leads. The accent lives only in the rare PR
            // badge, never on every line.
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(volumeValue)
                    .font(prominent ? Typography.statValue : Typography.metricInline)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
                if session.comparableTonnageSummary.availability != .unavailable {
                    Text(unit.symbol)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(volumeAccessibilityLabel)

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: prominent ? 72 : Space.rowMin, alignment: .leading)
        .padding(.vertical, Space.md)
        .contentShape(Rectangle())
        .accessibilityIdentifier("historySessionRow")
        .accessibilityElement(children: .combine)
    }

    /// The lone accent in the list: a small outlined "PR" tag next to
    /// a session that set a new top weight. Replaces the old practice
    /// of flooding the whole volume numeral orange, which made every
    /// row shout.
    var prBadge: some View {
        Text("PR")
            .font(Typography.micro)
            .foregroundStyle(Tint.primary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 1)
            .overlay(Capsule().stroke(Tint.primaryDim, lineWidth: 1))
            .accessibilityLabel("Personal record")
    }

    /// Today's rows lead with the workout's muscle identity; earlier
    /// rows lead with their date.
    var titleLine: String {
        prominent ? workoutTitle : dateLine
    }

    private var volumeValue: String {
        let summary = session.comparableTonnageSummary
        switch summary.availability {
        case .complete:
            return WeightFormatter.volumeValue(summary.knownSubtotal, unit: unit)
        case .partial:
            return "\(WeightFormatter.volumeValue(summary.knownSubtotal, unit: unit))+"
        case .unavailable:
            return "—"
        }
    }

    private var volumeAccessibilityLabel: String {
        let summary = session.comparableTonnageSummary
        switch summary.availability {
        case .complete:
            return "\(volumeValue) \(unit.symbol) volume"
        case .partial:
            return "\(WeightFormatter.volumeValue(summary.knownSubtotal, unit: unit)) \(unit.symbol) known volume; total unavailable"
        case .unavailable:
            return "Volume unavailable"
        }
    }

    /// Secondary line: the session's muscle fingerprint followed by
    /// the time it was logged. The fingerprint is what stops a column
    /// of "Full body" rows from reading as identical — you can see at
    /// a glance which regions each session actually hit — while the
    /// time distinguishes multiple sessions on the same day.
    var metaLine: String {
        "\(muscleFingerprint)  ·  \(timeString)"
    }

    var workoutTitle: String {
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
    var muscleFingerprint: String {
        let names = muscleTags.map(\.displayName)
        switch names.count {
        case 0: return "Workout"
        case 1, 2, 3: return names.joined(separator: " · ")
        default: return names.prefix(3).joined(separator: " · ") + " +\(names.count - 3)"
        }
    }

    var dateLine: String {
        let date = session.completedAt ?? session.startedAt
        return HistoryFormatters.compactDay.string(from: date)
    }

    var timeString: String {
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

    fileprivate static func id(for bucket: Bucket) -> String {
        switch bucket {
        case .today: return "today"
        case .yesterday: return "yesterday"
        case .thisWeek: return "thisWeek"
        case .lastWeek: return "lastWeek"
        case .month(let date): return "month-\(Int(date.timeIntervalSince1970))"
        }
    }

    fileprivate static func title(for bucket: Bucket) -> String {
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

    static func subtitle(for sessions: [WorkoutSession]) -> String {
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

enum HistoryFormatters {
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
