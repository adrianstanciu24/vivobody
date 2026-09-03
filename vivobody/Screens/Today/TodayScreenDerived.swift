//
//  TodayScreenDerived.swift
//  vivobody
//
//  Small root-owned adapters for Today's query ordering, immutable Up Next
//  snapshot, journal values, hero sizing, and date formatting.
//

import SwiftData
import SwiftUI

extension TodayScreen {
    // MARK: - Derived

    /// Templates ordered for the start sheet: most-recently-used
    /// first, then never-used templates in their Library sortOrder.
    /// A `@Query` predicate-based sort can't express this hybrid
    /// (lastUsedAt is optional), so it's resolved client-side.
    var sortedTemplates: [WorkoutTemplate] {
        templates.sorted { lhs, rhs in
            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case let (l?, r?): l > r
            case (.some, .none): true
            case (.none, .some): false
            case (.none, .none): lhs.sortOrder < rhs.sortOrder
            }
        }
    }

    /// Archived session timestamps in the recent window. The strip normalizes
    /// these into visual days while retaining an exact session count.
    var workoutDates: Set<Date> {
        Set(recentSessions.map { $0.completedAt ?? $0.startedAt })
    }

    /// Calendar days on which a PR was set. Passed to ConsistencyStrip
    /// so PR dots can pulsate. PR-session membership is the cached
    /// archive walk (see `ArchiveOverview.prSessionIDs`), joined to
    /// the recent window here.
    var prDates: Set<Date> {
        let prIDs = appState.analytics.prSessionIDs
        return Set(recentSessions.filter { prIDs.contains($0.id) }
            .map { Calendar.current.startOfDay(for: $0.completedAt ?? $0.startedAt) })
    }

    /// Whether the most recent session set a new all-time record
    /// on any exercise — the same semantics as History's PR badge and
    /// the live PR-celebration overlay. When true, the Volume stat on
    /// the Last workout strip wears the completion accent.
    var lastWorkoutHasPR: Bool {
        guard let lastID = latestSession?.id else { return false }
        return appState.analytics.prSessionIDs.contains(lastID)
    }

    /// Pair the live template needed for navigation with an immutable preview.
    /// The leaf view receives no SwiftData or analytics owner.
    func makeUpNextSelection(
        _ upNext: UpNext,
        outlook: StrengthOutlookBoard,
        defaultRestSeconds: Int
    ) -> (template: WorkoutTemplate, presentation: TodayUpNextPresentation)? {
        let template: WorkoutTemplate
        let daysUntil: Int
        let more: Int
        let shouldEaseOff: Bool

        switch upNext.kind {
        case let .scheduled(next, otherCount, easeOff):
            template = next
            daysUntil = 0
            more = otherCount
            shouldEaseOff = easeOff
        case let .rest(_, next, offset, otherCount):
            guard let next else { return nil }
            template = next
            daysUntil = offset
            more = otherCount
            shouldEaseOff = false
        case .unscheduled:
            return nil
        }

        let source = TodayUpNextPresentation.Source(
            template: template,
            daysUntil: daysUntil,
            otherScheduledCount: more,
            shouldEaseOff: shouldEaseOff,
            outlook: outlook
        )
        return (
            template,
            TodayUpNextPresentation(
                source: source,
                unit: unit,
                defaultRestSeconds: defaultRestSeconds
            )
        )
    }

    /// Frozen figure height with normal-size CTA and legend clearance.
    func bodyHeroHeight() -> CGFloat {
        let base = heroHeight
        guard base > 0 else { return 0 }
        if usesAccessibilityLayout {
            return min(base * 0.5, 420)
        }
        return max(
            base * Self.minimumHeroFraction,
            base * Self.heroFraction
                - Self.pinnedStartBarClearance
                - Self.developmentLegendClearance
        )
    }

    static let heroFraction: CGFloat = 0.98
    static let minimumHeroFraction: CGFloat = 0.68
    static let developmentLegendClearance: CGFloat = 88
    static let pinnedStartBarClearance: CGFloat = 104

    var pinnedStartBarScrollClearance: CGFloat {
        usesAccessibilityLayout ? 160 : Self.pinnedStartBarClearance
    }

    func streakText(_ streak: WorkoutStreak) -> String? {
        guard streak.current > 0 else { return nil }
        return "\(streak.current) \(streak.current == 1 ? "week" : "weeks") in a row"
    }

    func lastWorkoutMeta(for session: WorkoutSession) -> String {
        let date = session.completedAt ?? session.startedAt
        let calendar = Calendar.current
        let day: String = if calendar.isDateInToday(date) {
            "Today"
        } else if calendar.isDateInYesterday(date) {
            "Yesterday"
        } else {
            Self.dayFormatter.string(from: date)
        }
        return day + "  ·  " + Self.timeFormatter.string(from: date)
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
