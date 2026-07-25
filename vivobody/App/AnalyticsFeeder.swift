//
//  AnalyticsFeeder.swift
//  vivobody
//
//  The app's single full-archive query. Mounted once behind the tab
//  shell, it feeds SessionAnalytics whenever the archive changes so
//  every tab reads cached reports instead of holding its own
//  complete-history @Query. When the Insights tab is selected it
//  requests the deep tier too, preserving the old build-on-first-entry
//  behavior. Renders nothing.
//

import SwiftUI
import SwiftData

struct AnalyticsFeeder: View {
    var appState: AppState

    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    private var sessions: [WorkoutSession]

    /// Task identity: the analytics fingerprint plus which tier is
    /// wanted, so entering Insights re-fires without a data change.
    private struct FeedKey: Hashable {
        let request: SessionAnalytics.RequestKey
        let includesDeepReports: Bool
    }

    var body: some View {
        let includesDeepReports =
            appState.selectedTab == .insights && !sessions.isEmpty
        Color.clear
            .task(
                id: FeedKey(
                    request: appState.analytics.requestKey(for: sessions),
                    includesDeepReports: includesDeepReports
                )
            ) {
                if includesDeepReports {
                    appState.analytics.requestInsights(for: sessions)
                } else {
                    appState.analytics.requestCore(for: sessions)
                }
            }
    }
}
