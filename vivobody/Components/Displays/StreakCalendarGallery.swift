//
//  StreakCalendarGallery.swift
//  vivobody
//
//  Navigate between months with chevrons. Tap TODAY to come home.
//  Sample dataset is ~75% adherence over the last 90 days so several
//  months in either direction look "lived in."
//

import SwiftUI

struct StreakCalendarGallery: View {
    @State private var monthOffset: Int = 0

    private static let workoutDates: Set<Date> = {
        let cal = Calendar.current
        var dates: Set<Date> = []
        let today = cal.startOfDay(for: Date())
        // Realistic ~4/week pattern with the occasional missed day.
        let pattern: [Int] = [
            0, 1, 3, 5, 6, 8, 10, 12, 13, 15, 17, 19, 20, 22, 24,
            26, 27, 29, 31, 33, 34, 36, 38, 40, 41, 43, 45, 47, 48,
            50, 52, 54, 55, 57, 59, 61, 62, 64, 66, 68, 69, 71, 73,
            75, 76, 78, 80, 82, 83, 85, 87, 89, 91, 93, 95, 96, 98,
            100, 102, 104, 105, 107, 109,
        ]
        for offset in pattern {
            if let d = cal.date(byAdding: .day, value: -offset, to: today) {
                dates.insert(d)
            }
        }
        return dates
    }()

    private var displayedMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            header
            monthBar

            HStack {
                Spacer(minLength: 0)
                StreakCalendar(
                    workoutDates: Self.workoutDates,
                    month: displayedMonth
                )
                Spacer(minLength: 0)
            }

            Spacer()
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.section)
        .padding(.bottom, Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STREAK CALENDAR")
                .font(Typography.metricMicro)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Show up, see it.")
                .font(Typography.display)
                .foregroundStyle(.white)
            Text("Filled dots are workout days. Today wears a ring. No flames, no shame — just record.")
                .font(Typography.sectionLabel)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 2)
        }
    }

    private var monthBar: some View {
        HStack(spacing: 0) {
            chevron(systemName: "chevron.left") {
                monthOffset -= 1
                Haptics.tick()
            }

            Spacer()

            Button {
                if monthOffset != 0 {
                    Haptics.soft()
                }
                monthOffset = 0
            } label: {
                Text("TODAY")
                    .font(Typography.metricMicro)
                    .tracking(2)
                    .foregroundStyle(monthOffset == 0 ? .white.opacity(0.35) : .white.opacity(0.75))
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.sm)
                    .background(
                        Capsule()
                            .fill(monthOffset == 0 ? Color.white.opacity(0.04) : Color.white.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .animation(.easeOut(duration: 0.2), value: monthOffset)

            Spacer()

            chevron(systemName: "chevron.right") {
                monthOffset += 1
                Haptics.tick()
            }
        }
    }

    private func chevron(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(Typography.sectionLabel)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.04))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Streak Calendar") {
    StreakCalendarGallery()
        .preferredColorScheme(.dark)
}

#Preview("Empty month") {
    VStack {
        StreakCalendar(workoutDates: [], month: Date())
    }
    .padding(Space.section)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
}

#Preview("Perfect month") {
    let cal = Calendar.current
    let monthStart = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
    let dates = (0..<31).compactMap { cal.date(byAdding: .day, value: $0, to: monthStart) }

    return VStack {
        StreakCalendar(workoutDates: Set(dates), month: Date())
    }
    .padding(Space.section)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
