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

import SwiftData
import SwiftUI
import VivoKit

struct ConsistencyScreen: View {
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil }
    )
    private var completedSessions: [WorkoutSession]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var workoutDates: Set<Date> {
        let cal = Calendar.current
        return Set(completedSessions.compactMap { session in
            session.completedAt.map { cal.startOfDay(for: $0) }
        })
    }

    private var streak: WorkoutStreak {
        completedSessions.workoutStreak
    }

    /// Month starts from the current month back to the month holding
    /// the first recorded session — the record stops where the record
    /// starts. No padding months: a run of empty grids below your
    /// first workout is filler you have to scroll past, and it reads
    /// as absence rather than history.
    private var months: [Date] {
        let cal = Calendar.current
        let thisMonth = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        let firstMonth = workoutDates.min()
            .flatMap { cal.dateInterval(of: .month, for: $0)?.start } ?? thisMonth
        let span = max(cal.dateComponents([.month], from: firstMonth, to: thisMonth).month ?? 0, 0)
        return (0 ... span).compactMap {
            cal.date(byAdding: .month, value: -$0, to: thisMonth)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Space.section) {
                    streakStrip

                    ForEach(Array(months.enumerated()), id: \.element) { index, month in
                        if index > 0 { SectionDivider() }
                        monthBlock(month)
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
                    todayButton(proxy)
                }
            }
        }
    }

    /// One month of the run. Centred rather than leading-aligned so
    /// the seven-column grid sits square under its own title on every
    /// device width.
    private func monthBlock(_ month: Date) -> some View {
        HStack {
            Spacer(minLength: 0)
            StreakCalendar(workoutDates: workoutDates, month: month)
            Spacer(minLength: 0)
        }
        .id(month)
    }

    private func todayButton(_ proxy: ScrollViewProxy) -> some View {
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
}

#Preview {
    NavigationStack {
        ConsistencyScreen()
    }
    .preferredColorScheme(.dark)
}
