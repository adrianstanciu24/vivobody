//
//  HistoryScreenSections.swift
//  vivobody
//
//  Section view builders and derived/computed properties for
//  HistoryContent, extracted from the main file. The body and
//  stored properties remain in HistoryScreen.swift; the rendering
//  helpers and derived state live here.
//

import SwiftData
import SwiftUI
import VivoKit

extension HistoryContent {
    // MARK: - Empty state

    var emptyState: some View {
        ContentUnavailableView(
            "No workouts yet",
            systemImage: "figure.strengthtraining.traditional",
            description: Text("Finish your first session and it lands here.")
        )
    }

    // MARK: - Content

    var content: some View {
        let groups = groupedSessions
        let prSet = sessionsWithPR

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.section) {
                if showsWeeklyHero {
                    WeeklyHero(
                        comparison: recentSessions.weeklyComparison(),
                        averageRIR: thisWeekAverageRIR,
                        workoutDays: workoutDays,
                        prDays: prDays,
                        unit: unit
                    )
                    .settleIn(0)
                }

                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    DateGroupSection(
                        group: group,
                        unit: unit,
                        prSessions: prSet
                    )
                    .settleIn(index + 1)
                }

                // Keyset-style paging: the trigger materializes only
                // once the lazy stack actually reaches the bottom of
                // the loaded window, then the parent raises the fetch
                // limit by one page.
                if hasMoreSessions {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.lg)
                        .onAppear(perform: loadMore)
                        .accessibilityLabel("Loading older workouts")
                }
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    // MARK: - Derived

    /// Hero card only appears once the user has any logged activity
    /// in the current or prior week. Avoids a "0 / 0 / 0" tile
    /// for brand-new users on session #1.
    var showsWeeklyHero: Bool {
        recentSessions.weeklyComparison().hasAnyActivity
    }

    /// Grouped sessions, ordered most-recent bucket first. Buckets:
    /// Today, Yesterday, Earlier this week, Last week, then by
    /// calendar month for anything older.
    var groupedSessions: [HistoryDateGroup] {
        HistoryDateGroup.build(from: sessions)
    }

    /// IDs of sessions in which at least one exercise hit a new
    /// all-time strength record at the moment it was logged — read
    /// from the shared analytics cache, which performs the archive
    /// walk once per data change instead of on every render.
    var sessionsWithPR: Set<UUID> {
        appState.analytics.prSessionIDs
    }

    /// Every recent calendar day (start-of-day) on which at least one
    /// session was logged. Drives the week-cadence strip in the hero,
    /// which only renders the current week.
    var workoutDays: Set<Date> {
        let calendar = Calendar.current
        return Set(recentSessions.map { calendar.startOfDay(for: $0.completedAt ?? $0.startedAt) })
    }

    /// Days (start-of-day) on which a PR was set. Passed to the
    /// cadence strip so PR dots can pulsate.
    var prDays: Set<Date> {
        let calendar = Calendar.current
        let prIDs = sessionsWithPR
        return Set(recentSessions.filter { prIDs.contains($0.id) }
            .map { calendar.startOfDay(for: $0.completedAt ?? $0.startedAt) })
    }

    /// Mean reps-in-reserve over this week's completed reps-mode
    /// sets. Nil when no rated sets exist in the current calendar
    /// week. Matches the ConsistencyReport computation but scoped to
    /// the current week only.
    var thisWeekAverageRIR: Double? {
        let cal = Calendar.current
        guard let weekRange = cal.dateInterval(of: .weekOfYear, for: Date()) else { return nil }

        var rirSum = 0
        var rirCount = 0
        for session in recentSessions {
            let date = session.completedAt ?? session.startedAt
            guard date >= weekRange.start, date < weekRange.end else { continue }
            for exercise in session.exercises
                where exercise.modality == .dynamicStrength && exercise.trackingMode == .reps
            {
                for set in exercise.sets
                    where set.isAnalyticsEligible && set.reps > 0 && set.rirLogged
                {
                    rirSum += set.repsInReserve
                    rirCount += 1
                }
            }
        }
        guard rirCount > 0 else { return nil }
        return Double(rirSum) / Double(rirCount)
    }
}
