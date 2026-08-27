//
//  HistoryComponents.swift
//  vivobody
//
//  Supporting view types for the History screen: the carded weekly
//  hero (volume-led), week cadence strip, carded date-group sections,
//  session rows, date grouping logic, and shared formatters.
//  Extracted from HistoryScreen.swift. The ember dot the strip plots
//  lives in Components/Displays/CadenceDot.swift — Today's consistency
//  strip draws the same day.
//

import SwiftData
import SwiftUI
import VivoKit

// MARK: - Weekly hero

/// The week as one physical object: the only surface on the screen,
/// so the log below reads as entries under it. Inside the card the
/// hierarchy is strict — a "This week" kicker with a colored trend
/// delta, then the week's tonnage as the huge lead numeral (the one
/// figure that must read from three feet), then the seven-dot
/// cadence strip (which days you showed up), then Avg RIR and the
/// workout count demoted to a compact secondary strip.
struct WeeklyHero: View {
    let comparison: WeeklyComparison
    let averageRIR: Double?
    let workoutDays: Set<Date>
    let prDays: Set<Date>
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header

            volumeHero

            WeekCadenceStrip(workoutDays: workoutDays, prDays: prDays)
                .padding(.top, Space.xs)

            StatStrip(
                stats: [
                    Stat(value: rirLabel, label: "Avg RIR", accent: isRIROnTarget),
                    Stat(value: "\(comparison.thisWeek.workouts)", label: "Workouts"),
                ],
                valueFont: Typography.statValueCompact,
                edgeAligned: true
            )
            .padding(.top, Space.sm)
        }
        .padding(Space.lg)
        .contentCard()
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
    }

    /// The week's lead numeral: total tonnage, set at display size so
    /// the hero has a focal point. The label underneath carries the
    /// volume-availability nuance ("Known volume" when partial).
    var volumeHero: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(weeklyVolumeValue)
                    .font(Typography.metricLg)
                    .monospacedDigit()
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let symbol = weeklyVolumeUnit {
                    Text(symbol)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            Text(weeklyVolumeLabel)
                .panelLegend()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(weeklyVolumeValue)\(weeklyVolumeUnit.map { " \($0)" } ?? ""), \(weeklyVolumeLabel)")
    }

    /// Direction-of-change against last week, as a colored numeral
    /// rather than a chart: orange when up, dim when flat/down.
    /// Hidden when there's no prior week to compare against.
    @ViewBuilder
    var trendDelta: some View {
        if comparison.thisWeek.volumeAvailability == .complete,
           comparison.lastWeek.volumeAvailability == .complete,
           comparison.lastWeek.volume > 0
        {
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
/// Monday-to-Sunday per the user's calendar. A trained day is an
/// ember: a radial-gradient orange disc with a soft glow. Everything
/// else whispers so the trained days own the row — a past rest day
/// is a small dim pip, a future rest day a faint hollow ring, an
/// empty today a bright orange ring. Days with a PR gently pulsate —
/// a soft ember breath that draws the eye to achievements. This is
/// the streak's calendar DNA compressed to a single, glanceable row —
/// History's signature.
struct WeekCadenceStrip: View {
    let workoutDays: Set<Date>
    let prDays: Set<Date>

    var calendar: Calendar {
        .current
    }

    var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return (0 ..< 7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
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
        let isWorkout = workoutDays.contains(start)
        let isPR = prDays.contains(start)

        return VStack(spacing: Space.sm) {
            Text(Self.weekdayLetter.string(from: day))
                .font(Typography.caption)
                .foregroundStyle(isWorkout ? Ink.secondary : Ink.primary.opacity(Opacity.soft))
            CadenceDot(
                isWorkout: isWorkout,
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

// MARK: - Date group section

/// One date bucket as a ledger block: the `SectionHeader` stays on
/// black, the bucket's rows sit together inside a single content
/// card with inset hairlines between them. Today's card uses the
/// bright surface so the freshest sessions lift off the screen.
struct DateGroupSection: View {
    let group: HistoryDateGroup
    let unit: WeightUnit
    let prSessions: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: group.title, trailing: group.subtitle)

            VStack(spacing: 0) {
                ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, session in
                    if index > 0 { rowDivider }
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
            .contentCard(bright: group.style == .rich)
        }
    }

    /// In-card hairline between rows, inset so it never runs into
    /// the card's rounded corners.
    var rowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .padding(.horizontal, Space.lg)
            .accessibilityHidden(true)
    }
}

// MARK: - PR tag

/// The lone accent in the history ledger: a small outlined "PR"
/// capsule marking a session or exercise that set a new all-time top
/// weight. Shared by the list rows and the session detail so the
/// signal reads identically in both places.
struct PRTag: View {
    var body: some View {
        Text("PR")
            .font(Typography.micro)
            .foregroundStyle(Tint.primary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 1)
            .overlay(Capsule().stroke(Tint.primaryDim, lineWidth: 1))
            .accessibilityLabel("Personal record")
    }
}

// MARK: - Superset tag

/// PRTag's sibling for superset membership: the same outlined capsule
/// carrying the chain glyph and the member's "A1"-style position tag,
/// so a linked exercise reads identically on the receipt, the cards,
/// and the history ledger.
struct SupersetTag: View {
    let tag: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "link")
            Text(tag)
                .monospacedDigit()
        }
        .font(Typography.micro)
        .foregroundStyle(Tint.primary)
        .padding(.horizontal, Space.sm)
        .padding(.vertical, 1)
        .overlay(Capsule().stroke(Tint.primaryDim, lineWidth: 1))
        .accessibilityLabel("Superset position \(tag)")
    }
}

// MARK: - Session row

/// One archived session as a row inside a date-group card. The left
/// column carries identity (a workout title for today, a date for
/// earlier sessions) plus a muscle/time meta line; the right column
/// anchors its honest receipt metric in monospace. `prominent` (today's
/// sessions) enlarges the numeral and promotes the title. A PR adds
/// the lone accent: a small outlined tag beside the title.
struct SessionRow: View {
    let session: WorkoutSession
    let unit: WeightUnit
    let hasPR: Bool
    let prominent: Bool

    var muscleTags: [MuscleGroup] {
        session.distinctMuscleGroupsInOrder
    }

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

            // The receipt metric is supporting context, not the headline — kept a calm
            // grayscale numeral so the workout's identity (name + muscle
            // fingerprint) leads. The accent lives only in the rare PR
            // badge, never on every line.
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(receiptMetric.value)
                    .font(prominent ? Typography.statValue : Typography.metricInline)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
                if let metricUnit = receiptMetric.unit {
                    Text(metricUnit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(receiptMetric.accessibilityLabel)

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: prominent ? 72 : Space.rowMin, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .contentShape(Rectangle())
        .accessibilityIdentifier("historySessionRow")
        .accessibilityElement(children: .combine)
    }

    /// The lone accent in the list: the shared outlined "PR" tag next
    /// to a session that set a new top weight. Replaces the old
    /// practice of flooding the whole volume numeral orange, which
    /// made every row shout.
    var prBadge: some View {
        PRTag()
    }

    /// Today's rows lead with the workout's muscle identity; earlier
    /// rows lead with their date.
    var titleLine: String {
        prominent ? workoutTitle : dateLine
    }

    private var receiptMetric: (value: String, unit: String?, accessibilityLabel: String) {
        guard session.hasReceiptTonnageAxis else {
            if session.totalReps > 0 {
                return ("\(session.totalReps)", "reps", "\(session.totalReps) reps")
            }
            let timed = DurationFormatter.compact(session.totalTimedWork)
            return (timed, nil, "\(timed) timed work")
        }

        let summary = session.receiptTonnageSummary
        switch summary.availability {
        case .complete:
            let value = WeightFormatter.volumeValue(summary.knownSubtotal, unit: unit)
            return (value, unit.symbol, "\(value) \(unit.symbol) volume")
        case .partial:
            let value = WeightFormatter.volumeValue(summary.knownSubtotal, unit: unit)
            return ("\(value)+", unit.symbol, "\(value) \(unit.symbol) known volume; total unavailable")
        case .unavailable:
            return ("—", nil, "Volume unavailable")
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
        case 0: "Workout"
        case 1: "\(muscleTags[0].displayName) day"
        case 2: "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: "Full body"
        }
    }

    /// Up to two muscle groups, in worked order, with a "+N" tail
    /// when the session spans more — capped short enough that the
    /// trailing time never truncates inside the card. Gives even a
    /// generic "Full body" row a legible signature of what was
    /// actually trained.
    var muscleFingerprint: String {
        let names = muscleTags.map(\.displayName)
        switch names.count {
        case 0: return "Workout"
        case 1, 2: return names.joined(separator: " · ")
        default: return names.prefix(2).joined(separator: " · ") + " +\(names.count - 2)"
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
            let isRich = if case .today = bucket { true } else { false }
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
        case .today: "today"
        case .yesterday: "yesterday"
        case .thisWeek: "thisWeek"
        case .lastWeek: "lastWeek"
        case let .month(date): "month-\(Int(date.timeIntervalSince1970))"
        }
    }

    fileprivate static func title(for bucket: Bucket) -> String {
        switch bucket {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "Earlier this week"
        case .lastWeek: return "Last week"
        case let .month(date):
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
