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
    var prDates: Set<Date> = []
    var month: Date = Date()
    var fillColor: Color = Tint.primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private var prDays: Set<Date> {
        Set(prDates.map { calendar.startOfDay(for: $0) })
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
        VStack(alignment: .leading, spacing: Space.xl) {
            header

            VStack(spacing: rowSpacing) {
                weekdayRow
                ForEach(weeks.indices, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        ForEach(weeks[rowIndex].indices, id: \.self) { col in
                            let cell = weeks[rowIndex][col]
                            let dayStart = calendar.startOfDay(for: cell.date)
                            let isWorkoutDay = workoutDays.contains(dayStart)
                            let isPRDay = prDays.contains(dayStart)
                            DayDot(
                                day: calendar.component(.day, from: cell.date),
                                isWorkout: isWorkoutDay,
                                isInMonth: cell.isInMonth,
                                isToday: calendar.isDateInToday(cell.date),
                                isPast: dayStart < calendar.startOfDay(for: Date()),
                                isPR: isPRDay,
                                fillColor: fillColor,
                                size: dotSize
                            )
                            .frame(width: cellWidth)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(dayAccessibilityLabel(
                                date: cell.date,
                                isWorkout: isWorkoutDay,
                                isPR: isPRDay,
                                isInMonth: cell.isInMonth
                            ))
                        }
                    }
                }
            }

            metadata
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82), value: month)
    }

    private var header: some View {
        Text(monthLabel)
            .font(Typography.title)
            .foregroundStyle(Ink.primary)
            .contentTransition(.opacity)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .frame(width: cellWidth)
            }
        }
        .padding(.bottom, 2)
        .accessibilityHidden(true)
    }

    private var metadata: some View {
        HStack(spacing: 4) {
            DigitTicker(
                value: Double(monthSessionCount),
                font: Typography.sectionLabel,
                color: Ink.secondary
            )
            Text(monthSessionCount == 1 ? "session" : "sessions")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.secondary)
        }
    }

    // MARK: - Grid math

    /// VoiceOver label for a single calendar day: "[month] [day], [workout/rest], [PR if applicable]".
    /// Out-of-month days are announced with just the date so they don't
    /// clutter the calendar's actual month.
    private func dayAccessibilityLabel(date: Date, isWorkout: Bool, isPR: Bool, isInMonth: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        let datePart = f.string(from: date)
        var parts = [datePart]
        if isInMonth {
            parts.append(isWorkout ? "workout" : "rest")
            if isPR { parts.append("personal record") }
        }
        return parts.joined(separator: ", ")
    }

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
    let isPast: Bool
    let isPR: Bool
    let fillColor: Color
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var overdrive = false
    @State private var breathDim = false

    private var shouldPulse: Bool { isPR && !reduceMotion }

    var body: some View {
        ZStack {
            if isToday {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [fillColor.opacity(0.22), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.7
                        )
                    )
                    .frame(width: size * 1.35, height: size * 1.35)
            }

            Circle()
                .fill(dotFillColor)
                .scaleEffect(reduceMotion ? 1.0 : dotFillScale)
                .opacity(dotFillOpacity)
                .brightness(overdrive ? 0.28 : 0)
                .shadow(color: overdrive ? fillColor.opacity(0.6) : .clear, radius: overdrive ? 6 : 0)

            Circle()
                .stroke(strokeColor, lineWidth: strokeWidth)
                .opacity(isToday ? (breathDim ? 0.6 : 1.0) : 1.0)

            Text("\(day)")
                .font(Typography.metricMicro)
                .foregroundStyle(numberColor)
        }
        .frame(width: size, height: size)
        .opacity(isInMonth ? 1.0 : 0.18)
        .scaleEffect(shouldPulse ? (pulse ? 1.06 : 1.0) : 1.0)
        .shadow(
            color: shouldPulse ? fillColor.opacity(pulse ? 0.35 : 0) : .clear,
            radius: pulse ? 8 : 0
        )
        .onAppear {
            if isWorkout && !reduceMotion { fireOverdrive() }
            if isToday && !reduceMotion { startBreathing() }
            guard shouldPulse else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: isWorkout) { _, lit in
            if lit && !reduceMotion { fireOverdrive() }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.75), value: isWorkout)
    }

    private func fireOverdrive() {
        withAnimation(.easeOut(duration: 0.09)) { overdrive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(130))
            withAnimation(.easeOut(duration: 0.7)) { overdrive = false }
        }
    }

    private func startBreathing() {
        breathDim = false
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            breathDim = true
        }
    }

    /// Workout days fill bright orange; past rest days fill dim so
    /// they read as "gone, missed"; today and future rest days stay
    /// clear (the ring carries the shape).
    private var dotFillColor: Color {
        if isWorkout { return fillColor }
        if isPast { return Surface.edge }
        return .clear
    }

    private var dotFillScale: CGFloat {
        isWorkout || isPast ? 1.0 : 0.6
    }

    private var dotFillOpacity: Double {
        isWorkout || isPast ? 1.0 : 0.0
    }

    /// Today wears a brighter ring; future rest days keep the hairline
    /// ring; trained and past rest days need no ring (the fill carries
    /// the shape).
    private var strokeColor: Color {
        if isToday { return Ink.secondary }
        if isWorkout { return Color.clear }
        if isPast { return Color.clear }
        return Surface.edge
    }

    private var strokeWidth: CGFloat {
        isToday ? 1.5 : 1
    }

    private var numberColor: Color {
        if isWorkout {
            return Tint.onAccent.opacity(Opacity.strong)
        }
        return isInMonth ? Ink.secondary : Ink.tertiary
    }
}
