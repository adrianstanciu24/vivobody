//
//  AnalyticsFeeder.swift
//  vivobody
//
//  The app's archive-change observer. Mounted once behind the tab shell, it
//  wakes a long-lived ModelActor snapshot store after SwiftData saves, then
//  feeds immutable values to SessionAnalytics. When the Insights tab is
//  selected it requests the deep tier too. Renders nothing.
//

import Foundation
import SwiftData
import SwiftUI

struct AnalyticsFeeder: View {
    var appState: AppState
    let snapshotStore: AnalyticsSnapshotStore

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var temporalRefresh = 0
    @State private var saveRevision = 0

    /// Task identity: the analytics fingerprint plus which tier is
    /// wanted, so entering Insights re-fires without a data change.
    private struct FeedKey: Hashable {
        let includesDeepReports: Bool
        let temporalRefresh: Int
        let saveRevision: Int
        let invalidationRevision: Int
    }

    var body: some View {
        let includesDeepReports = appState.selectedTab == .insights
        Color.clear
            .task(
                id: FeedKey(
                    includesDeepReports: includesDeepReports,
                    temporalRefresh: temporalRefresh,
                    saveRevision: saveRevision,
                    invalidationRevision: appState.analytics.invalidationRevision
                )
            ) {
                guard let prepared = await prepareSnapshot(using: snapshotStore),
                      !Task.isCancelled
                else {
                    return
                }
                let snapshot = prepared.snapshot
                appState.analyticsArchiveHasSessions = !snapshot.sessions.isEmpty
                if includesDeepReports, !snapshot.sessions.isEmpty {
                    appState.analytics.requestInsights(
                        for: snapshot,
                        archiveRevision: prepared.archiveRevision
                    )
                } else {
                    appState.analytics.requestCore(
                        for: snapshot,
                        archiveRevision: prepared.archiveRevision
                    )
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: ModelContext.didSave,
                    object: modelContext
                )
            ) { _ in
                // The notification is only a wake-up signal. The ModelActor's
                // persistent-history token determines the exact delta and also
                // catches saves missed while this view was inactive.
                saveRevision &+= 1
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

    private func prepareSnapshot(
        using store: AnalyticsSnapshotStore
    ) async -> AnalyticsSnapshotStore.PreparedSnapshot? {
        for attempt in 0 ..< 2 {
            do {
                return try await store.prepare()
            } catch is CancellationError {
                return nil
            } catch {
                AppDiagnostics.analyticsSnapshotRefreshFailed(error: error)
                guard attempt == 0 else { return nil }
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return nil }
            }
        }
        return nil
    }
}
