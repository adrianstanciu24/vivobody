//
//  ConsistencyStrip.swift
//  vivobody
//
//  The two-week record, plotted a week to a row: oldest week on top,
//  today the last dot of the bottom row. A month grid spends most of
//  its cells on days that never held a workout, so at typical training
//  density it reads as mostly empty; two weeks carry the same streak
//  truth in a third of the height. The full month still exists, one
//  tap away in ConsistencyScreen.
//
//  Rows of seven, not one long line of fourteen: a week per row keeps
//  every column on the same weekday (so one header of initials labels
//  both weeks) and leaves the dot at full CadenceDot size instead of
//  shrinking it to fit fourteen columns across a phone.
//
//  Attendance is only the first dimension. `effortByDay` carries raw
//  per-day tonnage, normalized here against the heaviest day shown
//  (sqrt curve, so one monster session can't shrink the rest to
//  pips), and each trained ember's size follows it — the strip reads
//  as a landscape of effort, not a row of identical discs.
//  No effort data, no change: every trained day renders full size.
//
//  Use:
//      ConsistencyStrip(workoutDates: dates)
//      ConsistencyStrip(workoutDates: dates, prDates: prs, weeks: 2)
//      ConsistencyStrip(workoutDates: dates, effortByDay: tonnage)
//

import VivoKit
import SwiftUI

struct ConsistencyStrip: View {
    let workoutDates: Set<Date>
    var prDates: Set<Date> = []
    /// Raw effort per day (tonnage in canonical lb), normalized
    /// internally over the visible window. Days with a session but no
    /// known effort render at a floor so missing data never reads as
    /// a weak day.
    var effortByDay: [Date: Double] = [:]
    /// How many trailing weeks the strip covers, the current one last.
    var weeks: Int = 2
    var today: Date = Date()

    private var calendar: Calendar { .current }

    private var todayStart: Date { calendar.startOfDay(for: today) }

    private var days: Int { weeks * 7 }

    /// Trailing days split a week to a row, oldest row first, today the
    /// last cell of the last row. Because each row steps a whole week,
    /// every column holds one weekday all the way down.
    private var rows: [[Date]] {
        let all: [Date] = (0..<days).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: todayStart)
        }
        return stride(from: 0, to: all.count, by: 7).map {
            Array(all[$0..<min($0 + 7, all.count)])
        }
    }

    private var workoutDays: Set<Date> {
        Set(workoutDates.map { calendar.startOfDay(for: $0) })
    }

    private var prDays: Set<Date> {
        Set(prDates.map { calendar.startOfDay(for: $0) })
    }

    /// Effort normalized to 0...1 over the days actually on screen.
    /// sqrt compresses outliers so a single huge session can't dwarf
    /// the rest; days at or below zero (session logged, tonnage
    /// unknown) get a mid floor rather than the minimum. Empty when
    /// no effort data was supplied at all, which renders every ember
    /// at full size.
    private var normalizedEffort: [Date: Double] {
        guard !effortByDay.isEmpty else { return [:] }
        let shownDays = Set(rows.flatMap { $0 })
        let shown = effortByDay.filter { shownDays.contains($0.key) }
        guard let peak = shown.values.max(), peak > 0 else { return [:] }
        return shown.mapValues { $0 > 0 ? sqrt($0 / peak) : 0.6 }
    }

    private var sessionCount: Int {
        rows.flatMap { $0 }.filter { workoutDays.contains($0) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(spacing: Space.sm) {
                weekdayHeader
                ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                    weekRow(week)
                }
            }
            metadata
        }
    }

    /// Column labels taken from the current week, which every row above
    /// shares weekday for weekday.
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(rows.last ?? [], id: \.self) { day in
                Text(weekdayInitial(day))
                    .font(Typography.caption)
                    .foregroundStyle(
                        day == todayStart ? Ink.secondary : Ink.primary.opacity(Opacity.soft)
                    )
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func weekRow(_ week: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(week, id: \.self) { day in
                cell(day)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let trained = workoutDays.contains(day)
        let isPR = prDays.contains(day)
        let isToday = day == todayStart
        return CadenceDot(
            isWorkout: trained,
            isToday: isToday,
            isPast: day < todayStart,
            isPR: isPR,
            effort: normalizedEffort[day] ?? 1.0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayLabel(day, isToday: isToday))
        .accessibilityValue(trained ? trainedValue(day, isPR: isPR) : "Rest")
    }

    /// VoiceOver mirror of the ember's visual weight: the heavy/light
    /// qualifier only exists when effort data drives the sizing.
    private func trainedValue(_ day: Date, isPR: Bool) -> String {
        var parts = ["Trained"]
        if !normalizedEffort.isEmpty, let effort = normalizedEffort[day] {
            if effort >= 0.8 { parts.append("heavy day") }
            else if effort <= 0.45 { parts.append("light day") }
        }
        if isPR { parts.append("personal record") }
        return parts.joined(separator: ", ")
    }

    private var metadata: some View {
        HStack(spacing: 4) {
            DigitTicker(
                value: Double(sessionCount),
                font: Typography.sectionLabel,
                color: Ink.secondary
            )
            Text("\(sessionCount == 1 ? "session" : "sessions")  ·  last \(days) days")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(sessionCount) \(sessionCount == 1 ? "session" : "sessions") in the last \(days) days"
        )
    }

    private func weekdayInitial(_ day: Date) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        let index = calendar.component(.weekday, from: day) - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    private func dayLabel(_ day: Date, isToday: Bool) -> String {
        isToday ? "Today" : Self.dayFormatter.string(from: day)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()
}

#Preview("Two weeks") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let trained = [0, 1, 3, 5, 6, 9, 12].compactMap {
        calendar.date(byAdding: .day, value: -$0, to: today)
    }
    let tonnage: [Double] = [8_000, 4_200, 12_500, 6_800, 9_400, 5_100, 11_000]
    let effort = Dictionary(uniqueKeysWithValues: zip(trained, tonnage))
    ConsistencyStripPreviewContent(trained: trained, effort: effort)
}

/// Preview content lifted out of the `#Preview` builder so the varied
/// tonnage fixtures can be `let`-bound without tripping the result
/// builder's no-`return` rule.
private struct ConsistencyStripPreviewContent: View {
    let trained: [Date]
    let effort: [Date: Double]

    var body: some View {
        VStack {
            ConsistencyStrip(
                workoutDates: Set(trained),
                prDates: Set(trained.prefix(1)),
                effortByDay: effort
            )
            .padding(Space.xl)
            .contentCard()
        }
        .padding(Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
