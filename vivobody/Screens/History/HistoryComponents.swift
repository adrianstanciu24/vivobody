//
//  HistoryComponents.swift
//  vivobody
//
//  Supporting view types for the History screen: the carded weekly
//  hero (volume-led), week cadence strip, PR and superset tags, and
//  date grouping logic. Date-group sections and session rows live in
//  HistoryDateGroupSection.swift. Extracted from HistoryScreen.swift. The ember dot the strip plots
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
        return rir.formatted(.number.precision(.fractionLength(1)))
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
            Text(day, format: .dateTime.weekday(.narrow))
                .font(Typography.caption)
                .foregroundStyle(isWorkout ? Ink.secondary : Ink.primary.opacity(Opacity.soft))
            CadenceDot(
                isWorkout: isWorkout,
                isPR: isPR
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide)))
        .accessibilityValue(isWorkout ? (isPR ? "Trained, personal record" : "Trained") : "Rest")
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
        var bucketIndex: [Bucket: Int] = [:]
        bucketIndex.reserveCapacity(min(sessions.count, 16))

        func appendSession(_ session: WorkoutSession, into bucket: Bucket) {
            if let idx = bucketIndex[bucket] {
                buckets[idx].1.append(session)
            } else {
                bucketIndex[bucket] = buckets.count
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
            let month = Date.FormatStyle.dateTime.month(.wide)
            return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
                ? date.formatted(month)
                : date.formatted(month.year())
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
