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

    /// Calendar days in the recent window with at least one archived
    /// session. Drives the StreakCalendar fills.
    var workoutDates: Set<Date> {
        Set(recentSessions.map {
            Calendar.current.startOfDay(for: $0.completedAt ?? $0.startedAt)
        })
    }

    /// Calendar days on which a PR was set. Passed to StreakCalendar
    /// so PR dots can pulsate. PR-session membership is the cached
    /// archive walk (see `ArchiveOverview.prSessionIDs`), joined to
    /// the recent window here.
    var prDates: Set<Date> {
        let prIDs = appState.analytics.prSessionIDs
        return Set(recentSessions.filter { prIDs.contains($0.id) }
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
        guard let lastID = latestSession?.id else { return false }
        return appState.analytics.prSessionIDs.contains(lastID)
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
