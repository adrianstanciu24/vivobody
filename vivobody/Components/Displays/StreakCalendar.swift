//
//  StreakCalendar.swift
//  vivobody
//
//  The streak isn't a number with a flame next to it. It's a quiet
//  calendar of filled circles — one dot per workout day, an empty
//  outline on rest days, a ring around today. No shame for misses;
//  just the truth of the record.
//
//  Use:
//      StreakCalendar(workoutDates: dates)              // current month
//      StreakCalendar(workoutDates: dates, month: date) // any month
//

import SwiftUI

struct StreakCalendar: View {
    let workoutDates: Set<Date>
    var month: Date = Date()
    var fillColor: Color = Tint.primary

    private let cellWidth: CGFloat = 48
    private let dotSize: CGFloat = 36
    private let rowSpacing: CGFloat = 6

    private var calendar: Calendar { .current }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: month)?.start ?? month
    }

    private var monthEnd: Date {
        calendar.dateInterval(of: .month, for: month)?.end ?? month
    }

    private var workoutDays: Set<Date> {
        Set(workoutDates.map { calendar.startOfDay(for: $0) })
    }

    private var monthSessionCount: Int {
        workoutDays.filter { $0 >= monthStart && $0 < monthEnd }.count
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            VStack(spacing: rowSpacing) {
                weekdayRow
                ForEach(weeks.indices, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        ForEach(weeks[rowIndex].indices, id: \.self) { col in
                            let cell = weeks[rowIndex][col]
                            DayDot(
                                day: calendar.component(.day, from: cell.date),
                                isWorkout: workoutDays.contains(calendar.startOfDay(for: cell.date)),
                                isInMonth: cell.isInMonth,
                                isToday: calendar.isDateInToday(cell.date),
                                fillColor: fillColor,
                                size: dotSize
                            )
                            .frame(width: cellWidth)
                        }
                    }
                }
            }

            metadata
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: month)
    }

    private var header: some View {
        Text(monthLabel)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white)
            .contentTransition(.opacity)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.40))
                    .frame(width: cellWidth)
            }
        }
        .padding(.bottom, 2)
    }

    private var metadata: some View {
        HStack(spacing: 4) {
            DigitTicker(
                value: Double(monthSessionCount),
                font: .system(size: 13, weight: .semibold),
                color: .white.opacity(0.55)
            )
            Text(monthSessionCount == 1 ? "session" : "sessions")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Grid math

    private struct DayCell {
        let date: Date
        let isInMonth: Bool
    }

    private var weekdaySymbols: [String] { ["S", "M", "T", "W", "T", "F", "S"] }

    private var weeks: [[DayCell]] {
        // weekday: 1 = Sunday, 7 = Saturday (US convention).
        let leadingPadding = calendar.component(.weekday, from: monthStart) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let totalCells = ((leadingPadding + daysInMonth + 6) / 7) * 7

        guard let gridStart = calendar.date(byAdding: .day, value: -leadingPadding, to: monthStart) else {
            return []
        }

        var all: [DayCell] = []
        for i in 0..<totalCells {
            guard let d = calendar.date(byAdding: .day, value: i, to: gridStart) else { continue }
            let inMonth = d >= monthStart && d < monthEnd
            all.append(DayCell(date: d, isInMonth: inMonth))
        }

        return stride(from: 0, to: all.count, by: 7).map { Array(all[$0..<min($0 + 7, all.count)]) }
    }
}

// MARK: - DayDot

private struct DayDot: View {
    let day: Int
    let isWorkout: Bool
    let isInMonth: Bool
    let isToday: Bool
    let fillColor: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(isWorkout ? fillColor : Color.clear)
                .scaleEffect(isWorkout ? 1.0 : 0.6)
                .opacity(isWorkout ? 1.0 : 0.0)

            Circle()
                .stroke(strokeColor, lineWidth: strokeWidth)

            Text("\(day)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(numberColor)
        }
        .frame(width: size, height: size)
        .opacity(isInMonth ? 1.0 : 0.18)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isWorkout)
    }

    private var strokeColor: Color {
        if isToday {
            return Color.white.opacity(0.55)
        }
        if isWorkout {
            return Color.clear
        }
        return Color.white.opacity(0.10)
    }

    private var strokeWidth: CGFloat {
        isToday ? 1.5 : 1
    }

    private var numberColor: Color {
        if isWorkout {
            return Color.black.opacity(0.85)
        }
        return Color.white.opacity(isInMonth ? 0.55 : 0.45)
    }
}
