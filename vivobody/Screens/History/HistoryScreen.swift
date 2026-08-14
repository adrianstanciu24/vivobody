//
//  HistoryScreen.swift
//  vivobody
//
//  Live list of every archived workout, rendered as a training log
//  with one focal object at the top: the week hero, the screen's
//  only standalone surface. Inside it the hierarchy is volume-led —
//  the week's tonnage as a huge monospaced numeral, then the
//  seven-dot cadence strip (ember dots on trained days, a ring on
//  today), then Avg RIR and workout count as compact secondary
//  stats. The colored trend delta stays pinned to the header.
//
//  Below the hero, sessions are grouped by date bucket (Today /
//  Yesterday / This Week / Last Week / month). Each bucket is a
//  ledger block: a SectionHeader on black, then the bucket's rows
//  inside one shared content card with inset hairlines — Today's
//  card uses the bright surface so the freshest sessions lift.
//
//    • Today — elevated rows: workout title + meta on the left, a
//      larger volume numeral on the right.
//    • Earlier — same row, tighter: date + muscle summary + time on
//      the left, a smaller volume numeral on the right.
//
//  PR sessions carry a small outlined "PR" tag beside the title —
//  the lone accent in the list, so it never dilutes.
//
//  Tapping any row pushes a detail view that reuses
//  WorkoutSummaryCard — the same "receipt" the user saw at the end
//  of the workout, now as a permanent record.
//

import SwiftData
import SwiftUI

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

    var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

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

    var hasMoreSessions: Bool {
        sessions.count == limit
    }
}

#Preview {
    NavigationStack {
        HistoryScreen(appState: AppState())
            .navigationTitle("History")
    }
    .preferredColorScheme(.dark)
}
