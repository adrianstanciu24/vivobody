//
//  HistoryScreenSections.swift
//  vivobody
//
//  Section view builders and derived/computed properties for
//  HistoryScreen, extracted from the main file. The body and
//  stored properties remain in HistoryScreen.swift; the rendering
//  helpers and derived state live here.
//

import SwiftUI
import SwiftData

extension HistoryScreen {
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
                        comparison: sessions.weeklyComparison(),
                        averageRIR: thisWeekAverageRIR,
                        workoutDays: workoutDays,
                        prDays: prDays,
                        unit: unit
                    )
                    .settleIn(0)
                    SectionDivider()
                }

                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    DateGroupSection(
                        group: group,
                        unit: unit,
                        prSessions: prSet
                    )
                    .settleIn(index + 1)
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
        sessions.weeklyComparison().hasAnyActivity
    }

    /// Grouped sessions, ordered most-recent bucket first. Buckets:
    /// Today, Yesterday, Earlier this week, Last week, then by
    /// calendar month for anything older.
    var groupedSessions: [HistoryDateGroup] {
        HistoryDateGroup.build(from: sessions)
    }

    /// IDs of sessions in which at least one exercise hit a new
    /// all-time record at the moment it was logged. Reps exercises
    /// track top weight; duration exercises track longest hold. Walks
    /// the archive in chronological order, keyed by stable exercise
    /// identity.
    var sessionsWithPR: Set<UUID> {
        var bestByExercise: [String: Double] = [:]
        var prIDs: Set<UUID> = []

        // sessions are sorted newest-first; iterate oldest-first.
        let chronological = sessions.reversed()
        for session in chronological {
            for exercise in session.orderedExercises {
                let metric = prMetric(for: exercise)
                guard metric > 0 else { continue }
                let key = exercise.historyKey
                let prev = bestByExercise[key, default: 0]
                if metric > prev {
                    bestByExercise[key] = metric
                    prIDs.insert(session.id)
                }
            }
        }
        return prIDs
    }

    /// Every calendar day (start-of-day) on which at least one
    /// session was logged. Drives both the streak math and the
    /// week-cadence strip in the hero.
    var workoutDays: Set<Date> {
        let calendar = Calendar.current
        return Set(sessions.map { calendar.startOfDay(for: $0.completedAt ?? $0.startedAt) })
    }

    /// Days (start-of-day) on which a PR was set. Passed to the
    /// cadence strip so PR dots can pulsate.
    var prDays: Set<Date> {
        let calendar = Calendar.current
        return Set(sessions.filter { sessionsWithPR.contains($0.id) }
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
        for session in sessions {
            let date = session.completedAt ?? session.startedAt
            guard date >= weekRange.start && date < weekRange.end else { continue }
            for exercise in session.exercises where exercise.trackingMode == .reps {
                for set in exercise.sets where set.isCompleted && set.rirLogged {
                    rirSum += set.repsInReserve
                    rirCount += 1
                }
            }
        }
        guard rirCount > 0 else { return nil }
        return Double(rirSum) / Double(rirCount)
    }

    func prMetric(for exercise: Exercise) -> Double {
        let completed = exercise.sets.filter(\.isCompleted)
        switch exercise.trackingMode {
        case .reps:
            return completed.map(\.weight).max() ?? 0
        case .duration:
            return completed.map(\.duration).max() ?? 0
        }
    }
}
