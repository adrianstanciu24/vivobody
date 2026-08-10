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
//  Every day renders the same full-size ember: orange when trained,
//  gray when not, the glow ring pulsing on PR days. Attendance is
//  the only dimension — effort once sized the embers, but three
//  honest states read faster than a landscape of sizes.
//
//  Each cell hands its chronological position to CadenceDot as
//  `ignitionOrder`, so on appear the embers light oldest-first —
//  the two weeks catch fire left to right, today last.
//
//  Use:
//      ConsistencyStrip(workoutDates: dates)
//      ConsistencyStrip(workoutDates: dates, prDates: prs, weeks: 2)
//

import VivoKit
import SwiftUI

struct ConsistencyStrip: View {
    let workoutDates: Set<Date>
    var prDates: Set<Date> = []
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

    private var sessionCount: Int {
        rows.flatMap { $0 }.filter { workoutDays.contains($0) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(spacing: Space.sm) {
                weekdayHeader
                // Rows sit wider apart than the header: each ring
                // draws 3.5pt past its row's frame, so Space.lg here
                // leaves a clear vertical gap between the rings.
                VStack(spacing: Space.lg) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, week in
                        weekRow(week, rowIndex: rowIndex)
                    }
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

    private func weekRow(_ week: [Date], rowIndex: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(week.enumerated()), id: \.element) { columnIndex, day in
                cell(day, ignitionOrder: rowIndex * 7 + columnIndex)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func cell(_ day: Date, ignitionOrder: Int) -> some View {
        let trained = workoutDays.contains(day)
        let isPR = prDays.contains(day)
        let isToday = day == todayStart
        return CadenceDot(
            isWorkout: trained,
            isPR: isPR,
            ignitionOrder: ignitionOrder
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayLabel(day, isToday: isToday))
        .accessibilityValue(trained ? trainedValue(isPR: isPR) : "Rest")
    }

    private func trainedValue(isPR: Bool) -> String {
        isPR ? "Trained, personal record" : "Trained"
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
    VStack {
        ConsistencyStrip(
            workoutDates: Set(trained),
            prDates: Set(trained.prefix(1))
        )
        .padding(Space.xl)
        .contentCard()
    }
    .padding(Space.gutter)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
