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

    @AppStorage(SettingsKey.weightUnit)
    var unitRaw: String = SettingsDefaults.weightUnit

    var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Every completed (archived) session. SwiftData orders results
    /// by completedAt descending, so the most-recent workout sits
    /// at the top. Mid-flight sessions are still un-inserted and
    /// therefore invisible to this query.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    var sessions: [WorkoutSession]

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .forgeBackground()
    }

}

#Preview {
    NavigationStack {
        HistoryScreen(appState: AppState())
            .navigationTitle("History")
    }
    .preferredColorScheme(.dark)
}
