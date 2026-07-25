//
//  HistoryScreen.swift
//  vivobody
//
//  Live list of every archived workout, rendered as an instrument:
//  no cards, no carved glass — structure comes from type, whitespace,
//  and hairlines on black. The screen opens as a *training-week log*:
//  a seven-dot cadence strip (one dot per day, filled when you
//  trained, ringed on today), a colored trend delta, and a card-free
//  stat strip led by the streak. This is deliberately about *time*,
//  not tonnage — Me is the all-time volume odometer; History is the
//  rhythm. Below it, sessions are grouped by date bucket (Today /
//  Yesterday / This Week / Last Week / month) and laid out as
//  full-width hairline-separated rows:
//
//    • Today — elevated rows: workout title + meta on the left, a
//      larger volume numeral on the right.
//    • Earlier — same row, tighter: date + muscle summary + time on
//      the left, a smaller volume numeral on the right.
//
//  PR sessions render their volume numeral in the gold completion
//  accent — a typographic cue only, no badge chrome.
//
//  Tapping any row pushes a detail view that reuses
//  WorkoutSummaryCard — the same "receipt" the user saw at the end
//  of the workout, now as a permanent record.
//

import SwiftUI
import SwiftData

struct HistoryScreen: View {
    @Bindable var appState: AppState

    /// How many archived sessions are currently materialized. Grows a
    /// page at a time as the user scrolls toward the bottom, so the
    /// list never loads the whole archive up front. Rebuilding
    /// `HistoryContent` with the new limit re-creates its @Query with
    /// the larger fetch limit while the scroll position holds.
    @State private var limit = HistoryScreen.pageSize

    static let pageSize = 60

    var body: some View {
        HistoryContent(appState: appState, limit: limit) {
            limit += Self.pageSize
        }
    }
}

/// The History tab's real body. Split from `HistoryScreen` so the
/// session query can be reconstructed with a growing fetch limit —
/// a view cannot rebuild its own @Query from its own @State.
struct HistoryContent: View {
    var appState: AppState

    /// Current page ceiling; `sessions.count == limit` means the
    /// archive probably has more to load.
    let limit: Int
    let loadMore: () -> Void

    @AppStorage(SettingsKey.weightUnit)
    var unitRaw: String = SettingsDefaults.weightUnit

    var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// The newest `limit` completed (archived) sessions, most-recent
    /// first. Mid-flight sessions are still un-inserted and therefore
    /// invisible to this query.
    @Query var sessions: [WorkoutSession]

    /// Sessions from the start of last week onward (with a one-day
    /// pad for boundary-spanning workouts) — everything the weekly
    /// hero needs, without touching the older archive.
    @Query var recentSessions: [WorkoutSession]

    init(appState: AppState, limit: Int, loadMore: @escaping () -> Void) {
        self.appState = appState
        self.limit = limit
        self.loadMore = loadMore

        var paged = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        paged.fetchLimit = limit
        _sessions = Query(paged)

        let calendar = Calendar.current
        let thisWeekStart = calendar
            .dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let cutoff = calendar
            .date(byAdding: .day, value: -8, to: thisWeekStart) ?? thisWeekStart
        _recentSessions = Query(
            filter: #Predicate<WorkoutSession> {
                $0.completedAt != nil && $0.startedAt >= cutoff
            },
            sort: [SortDescriptor(\.completedAt, order: .reverse)]
        )
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .screenBackground()
    }

    var hasMoreSessions: Bool { sessions.count == limit }
}

#Preview {
    NavigationStack {
        HistoryScreen(appState: AppState())
            .navigationTitle("History")
    }
    .preferredColorScheme(.dark)
}
