//
//  SessionAnalyticsConcurrencyTests.swift
//  vivobodyTests
//
//  Guards the Sendable analytics boundary, SwiftData snapshot
//  detachment, and the lazy core/deep cache lifecycle.
//

import Foundation
import Testing
@testable import vivobody

private nonisolated func requireSendable<T: Sendable>(_: T.Type) {}

@MainActor
struct SessionAnalyticsConcurrencyTests {

    @Test
    nonisolated func analyticsBoundaryIsSendable() {
        requireSendable(AnalyticsSnapshot.self)
        requireSendable(AnalyticsAccumulator.self)
        requireSendable(SessionAnalytics.CoreReports.self)
        requireSendable(SessionAnalytics.DeepReports.self)
        requireSendable(SessionAnalytics.InsightsReports.self)
    }

    @Test func snapshotDoesNotRetainModelValues() {
        let exercise = Exercise(
            name: "Barbell Bench Press",
            group: .chest,
            plannedSets: 1,
            plannedReps: 8,
            plannedWeight: 135
        )
        exercise.sets[0].isCompleted = true
        let session = WorkoutSession(
            exercises: [exercise],
            startedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        session.completedAt = session.startedAt

        let snapshot = AnalyticsSnapshot(sessions: [session])
        exercise.sets[0].reps = 20
        exercise.name = "Changed after capture"

        let captured = snapshot.sessions[0].exercises[0]
        #expect(captured.name == "Barbell Bench Press")
        #expect(captured.sets[0].reps == 8)
    }

    @Test func deepReportsStayLazyUntilInsightsRequestsThem() async {
        let exercise = Exercise(
            name: "Barbell Bench Press",
            group: .chest,
            plannedSets: 1,
            plannedReps: 8,
            plannedWeight: 135
        )
        exercise.sets[0].isCompleted = true
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(exercises: [exercise], startedAt: now)
        session.completedAt = now
        let analytics = SessionAnalytics()

        analytics.requestCore(for: [session], now: now)
        await analytics.waitForPendingWork()

        #expect(analytics.hasCoreReports)
        #expect(analytics.deepReports == nil)
        #expect(analytics.insightsReports == nil)

        analytics.requestInsights(for: [session], now: now)
        await analytics.waitForPendingWork()

        #expect(analytics.deepReports != nil)
        #expect(analytics.insightsReports != nil)
    }
}
