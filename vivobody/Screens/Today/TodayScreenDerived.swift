//
//  TodayScreenDerived.swift
//  vivobody
//
//  Derived/computed properties and static formatters extracted from
//  TodayScreen: sorted templates, workout/PR date sets, volume and
//  PR helpers, and the date formatters used by the journal sections.
//

import SwiftUI
import SwiftData

extension TodayScreen {
    // MARK: - Derived

    /// Templates ordered for the start sheet: most-recently-used
    /// first, then never-used templates in their Library sortOrder.
    /// A `@Query` predicate-based sort can't express this hybrid
    /// (lastUsedAt is optional), so it's resolved client-side.
    var sortedTemplates: [WorkoutTemplate] {
        templates.sorted { lhs, rhs in
            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case let (l?, r?):       return l > r
            case (.some, .none):     return true
            case (.none, .some):     return false
            case (.none, .none):     return lhs.sortOrder < rhs.sortOrder
            }
        }
    }

    /// Calendar days on which the user has at least one archived
    /// session. Drives the StreakCalendar fills.
    var workoutDates: Set<Date> {
        Set(completedSessions.map {
            Calendar.current.startOfDay(for: $0.completedAt ?? $0.startedAt)
        })
    }

    /// Calendar days on which a PR was set. Passed to StreakCalendar
    /// so PR dots can pulsate.
    var prDates: Set<Date> {
        Set(completedSessions.filter { prSessionIDs.contains($0.id) }
            .map { Calendar.current.startOfDay(for: $0.completedAt ?? $0.startedAt) })
    }

    func volumeLabel(_ value: Double) -> String {
        WeightFormatter.volumeValue(value, unit: unit)
    }

    /// Whether the most recent session set a new all-time record
    /// on any exercise — the same semantics as History's PR badge and
    /// the live PR-celebration overlay. When true, the Volume stat on
    /// the Last workout strip wears the completion accent.
    var lastWorkoutHasPR: Bool {
        guard let lastID = completedSessions.first?.id else { return false }
        return prSessionIDs.contains(lastID)
    }

    /// IDs of sessions in which at least one exercise hit a new
    /// all-time record at the moment it was logged. Reps exercises
    /// track top weight; duration exercises track longest hold. Walks
    /// the archive oldest-first by stable exercise identity. Matches
    /// `HistoryScreen.sessionsWithPR` exactly.
    var prSessionIDs: Set<UUID> {
        var bestByExercise: [String: Double] = [:]
        var prIDs: Set<UUID> = []
        for session in completedSessions.reversed() {
            for exercise in session.orderedExercises {
                let metric = prMetric(for: exercise)
                guard metric > 0 else { continue }
                let key = exercise.historyKey
                if metric > bestByExercise[key, default: 0] {
                    bestByExercise[key] = metric
                    prIDs.insert(session.id)
                }
            }
        }
        return prIDs
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

    // MARK: - Formatters

    /// Weekday + month/day for sessions older than yesterday. Today
    /// and yesterday are resolved by hand in `lastWorkoutMeta` —
    /// `doesRelativeDateFormatting` silently yields an empty string
    /// when paired with a custom `dateFormat`, which is why the date
    /// used to render blank.
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE  ·  MMM d"
        return f
    }()

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}
