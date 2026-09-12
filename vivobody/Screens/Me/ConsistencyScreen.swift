//
//  ConsistencyScreen.swift
//  vivobody
//
//  The full consistency view, pushed from the Me tab. Current /
//  longest week-streak stats over a continuous vertical run of
//  StreakCalendar months, driven by the real archive — filled dots
//  are workout days, today wears a ring. No flames, no shame, just
//  the record.
//
//  The months read newest-first, so the freshest record is already
//  on screen and scrolling down walks backwards through the archive
//  (down is "further back," never an empty future). The run ends at
//  the month of the first logged session — nothing before you began.
//  A "Today" toolbar button returns to the current month from
//  anywhere in the run, the way the system calendar does.
//

import SwiftUI
import VivoKit

struct ConsistencyScreen: View {
    @Environment(\.sessionAnalytics) private var sessionAnalytics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let history = sessionAnalytics?.consistencyHistory
            ?? ConsistencyHistory.make(
                dates: [],
                now: Date(),
                calendar: .current
            )
        let streak = sessionAnalytics?.overview.streak
            ?? WorkoutStreak(current: 0, longest: 0)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Space.section) {
                    streakStrip(streak)

                    ForEach(Array(history.monthStartsNewestFirst.enumerated()), id: \.element) { index, month in
                        if index > 0 { SectionDivider() }
                        monthBlock(month, history: history)
                    }
                }
                .padding(.top, Space.lg)
                .padding(.bottom, Space.section + Space.md)
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .screenBackground()
            .navigationTitle("Consistency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    todayButton(proxy, months: history.monthStartsNewestFirst)
                }
            }
        }
    }

    /// One month of the run. Centred rather than leading-aligned so
    /// the seven-column grid sits square under its own title on every
    /// device width.
    private func monthBlock(
        _ month: Date,
        history: ConsistencyHistory
    ) -> some View {
        HStack {
            Spacer(minLength: 0)
            StreakCalendar(
                workoutDays: history.workoutDays,
                monthWorkoutCount: history.workoutDayCountByMonth[month] ?? 0,
                month: month
            )
            Spacer(minLength: 0)
        }
        .id(month)
    }

    private func todayButton(
        _ proxy: ScrollViewProxy,
        months: [Date]
    ) -> some View {
        Button("Today") {
            guard let current = months.first else { return }
            Haptics.soft()
            if reduceMotion {
                proxy.scrollTo(current, anchor: .top)
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    proxy.scrollTo(current, anchor: .top)
                }
            }
        }
        .font(Typography.sectionLabel)
        .accessibilityHint("Scrolls back to the current month")
    }

    private func streakStrip(_ streak: WorkoutStreak) -> some View {
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
}

#Preview {
    NavigationStack {
        ConsistencyScreen()
    }
    .preferredColorScheme(.dark)
}
