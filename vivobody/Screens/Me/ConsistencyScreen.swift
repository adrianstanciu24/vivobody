//
//  ConsistencyScreen.swift
//  vivobody
//
//  The full consistency view, pushed from the Me tab. Current /
//  longest week-streak stats over a month-paging StreakCalendar
//  driven by the real archive — filled dots are workout days, today
//  wears a ring. No flames, no shame, just the record.
//

import SwiftUI
import SwiftData

struct ConsistencyScreen: View {
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil }
    )
    private var completedSessions: [WorkoutSession]

    @State private var monthOffset: Int = 0

    private var workoutDates: Set<Date> {
        let cal = Calendar.current
        return Set(completedSessions.compactMap { session in
            session.completedAt.map { cal.startOfDay(for: $0) }
        })
    }

    private var displayedMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var streak: WorkoutStreak { completedSessions.workoutStreak }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                streakStrip
                SectionDivider()
                monthBar
                HStack {
                    Spacer(minLength: 0)
                    StreakCalendar(workoutDates: workoutDates, month: displayedMonth)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.section + Space.md)
        }
        .background(Surface.background.ignoresSafeArea())
        .navigationTitle("Consistency")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var streakStrip: some View {
        StatStrip(stats: [
            Stat(
                value: "\(streak.current)",
                label: streak.current == 1 ? "week, current" : "weeks, current",
                accent: streak.current > 0
            ),
            Stat(
                value: "\(streak.longest)",
                label: streak.longest == 1 ? "week, longest" : "weeks, longest"
            ),
        ])
        .padding(Space.xl)
        .contentCard()
    }

    private var monthBar: some View {
        HStack(spacing: 0) {
            chevron(systemName: "chevron.left") {
                monthOffset -= 1
                Haptics.tick()
            }

            Spacer()

            Button {
                if monthOffset != 0 { Haptics.soft() }
                monthOffset = 0
            } label: {
                Text("Today")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(monthOffset == 0 ? Ink.tertiary : Ink.secondary)
                    .padding(.horizontal, Space.lg)
                    .frame(minHeight: 44)
                    .coloredGlassControl(
                        cornerRadius: Radius.pill,
                        fill: monthOffset == 0 ? nil : Tint.inProgress
                    )
            }
            .buttonStyle(.plain)
            .animation(.easeOut(duration: 0.2), value: monthOffset)
            .disabled(monthOffset == 0)

            Spacer()

            chevron(systemName: "chevron.right") {
                guard monthOffset < 0 else { return }
                monthOffset += 1
                Haptics.tick()
            }
            .opacity(monthOffset < 0 ? 1 : 0.3)
            .disabled(monthOffset >= 0)
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
                .foregroundStyle(Ink.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ConsistencyScreen()
    }
    .preferredColorScheme(.dark)
}
