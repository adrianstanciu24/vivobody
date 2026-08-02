//
//  AnalyticsFeeder.swift
//  vivobody
//
//  The app's single full-archive query. Mounted once behind the tab
//  shell, it feeds SessionAnalytics whenever the archive changes so
//  every tab reads cached reports instead of holding its own
//  complete-history @Query. When the Insights tab is selected it
//  requests the deep tier too, preserving the
//  build-on-first-entry behavior. Renders nothing.
//

import SwiftUI
import SwiftData
import Foundation

struct AnalyticsFeeder: View {
    var appState: AppState

    @Environment(\.scenePhase) private var scenePhase
    @State private var temporalRefresh = 0

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
        let temporalRefresh: Int
    }

    var body: some View {
        let includesDeepReports =
            appState.selectedTab == .insights && !sessions.isEmpty
        Color.clear
            .task(
                id: FeedKey(
                    request: appState.analytics.requestKey(for: sessions),
                    includesDeepReports: includesDeepReports,
                    temporalRefresh: temporalRefresh
                )
            ) {
                appState.analyticsArchiveHasSessions = !sessions.isEmpty
                if includesDeepReports {
                    appState.analytics.requestInsights(for: sessions)
                } else {
                    appState.analytics.requestCore(for: sessions)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    // Re-evaluate the day-bearing request key whenever
                    // the app returns; a backgrounded midnight must not
                    // leave yesterday's rolling windows on screen.
                    temporalRefresh &+= 1
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            ) { _ in
                appState.analytics.invalidate()
                temporalRefresh &+= 1
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSSystemClockDidChange)
            ) { _ in
                appState.analytics.invalidate()
                temporalRefresh &+= 1
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
            ) { _ in
                appState.analytics.invalidate()
                temporalRefresh &+= 1
            }
    }
}
