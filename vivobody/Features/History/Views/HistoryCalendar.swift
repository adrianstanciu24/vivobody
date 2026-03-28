import SwiftUI

struct HistoryCalendar: View {
    private let dayNames = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let daysInMonth = 31
    private let startWeekday = 5 // March 2026 starts on Sunday (index 6), but Sat=0 offset

    private let workoutDays: Set<Int> = [
        1, 2, 4, 5, 7, 8, 9, 11, 12, 13, 15, 16, 17, 18
    ]

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            monthNavigator
            dayHeaders
            calendarGrid
        }
    }

    private var sectionHeader: some View {
        Text("CALENDAR")
            .font(.vivoMono(12))
            .tracking(2)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 10)
    }

    private var monthNavigator: some View {
        HStack {
            Button {} label: {
                Text("‹")
                    .font(.vivoDisplay(18))
                    .foregroundStyle(Color.vivoSecondary)
                    .frame(width: 26, height: 32)
            }

            Spacer()

            HStack(spacing: 0) {
                Text("March")
                    .font(.vivoDisplay(18))
                    .foregroundStyle(Color.vivoPrimary)
                Text("2026")
                    .font(.vivoDisplay(18))
                    .foregroundStyle(Color.vivoSecondary)
                    .padding(.leading, 4)
            }

            Spacer()

            Button {} label: {
                Text("›")
                    .font(.vivoDisplay(18))
                    .foregroundStyle(Color.vivoSecondary)
                    .frame(width: 26, height: 32)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var dayHeaders: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: 0
        ) {
            ForEach(dayNames, id: \.self) { day in
                Text(day)
                    .font(.vivoMono(7))
                    .tracking(1)
                    .foregroundStyle(Color.vivoMuted)
                    .frame(height: 20)
            }
        }
        .padding(.horizontal, 24)
    }

    private var calendarGrid: some View {
        let offset = 5
        let totalCells = offset + daysInMonth + (7 - (offset + daysInMonth) % 7) % 7

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
            spacing: 2
        ) {
            ForEach(0 ..< totalCells, id: \.self) { index in
                let dayNumber = index - offset + 1
                if dayNumber >= 1, dayNumber <= daysInMonth {
                    calendarCell(day: dayNumber)
                } else {
                    Color.clear
                        .frame(height: 47)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func calendarCell(day: Int) -> some View {
        let hasWorkout = workoutDays.contains(day)
        let isToday = day == 18

        return VStack(spacing: 4) {
            Text(String(format: "%02d", day))
                .font(.vivoMono(11))
                .foregroundStyle(
                    isToday ? Color.vivoAccent :
                        hasWorkout ? Color.vivoPrimary : Color.vivoMuted
                )
            if hasWorkout {
                Circle()
                    .fill(isToday ? Color.vivoAccent : Color.vivoAccent.opacity(0.6))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 47)
        .frame(maxWidth: .infinity)
        .background(
            isToday
                ? RoundedRectangle(cornerRadius: 6)
                .stroke(Color.vivoAccent, lineWidth: 1)
                : nil
        )
    }
}

#Preview {
    HistoryCalendar()
        .background(Color.vivoBackground)
}
