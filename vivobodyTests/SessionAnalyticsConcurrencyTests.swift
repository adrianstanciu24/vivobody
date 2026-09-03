//
//  SessionAnalyticsConcurrencyTests.swift
//  vivobodyTests
//
//  Characterizes the MainActor analytics cache state machine: detached
//  values, exact request identity, core/deep promotion, generation rejection,
//  failure retention, synchronous history fallback, and widget task joining.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody
import VivoKit

private nonisolated func requireSendable(_: (some Sendable).Type) {}

private struct ControlledAnalyticsFailure: Error {}

private actor ControlledAnalyticsWorking {
    private struct Waiter {
        let count: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private let live = SessionAnalytics.AnalyticsWorking.live()
    private var coreContinuations:
        [Int: CheckedContinuation<Void, any Error>] = [:]
    private var deepContinuations:
        [Int: CheckedContinuation<Void, any Error>] = [:]
    private var coreWaiters: [Waiter] = []
    private var deepWaiters: [Waiter] = []
    private(set) var coreCallCount = 0
    private(set) var deepCallCount = 0

    func working() -> SessionAnalytics.AnalyticsWorking {
        SessionAnalytics.AnalyticsWorking(
            makeCore: { input, now in
                try await self.makeCore(from: input, now: now)
            },
            makeDeep: { accumulator, now, consistency in
                try await self.makeDeep(
                    from: accumulator,
                    now: now,
                    consistency: consistency
                )
            }
        )
    }

    func waitForCoreCalls(_ count: Int) async {
        guard coreCallCount < count else { return }
        await withCheckedContinuation { continuation in
            coreWaiters.append(Waiter(count: count, continuation: continuation))
        }
    }

    func waitForDeepCalls(_ count: Int) async {
        guard deepCallCount < count else { return }
        await withCheckedContinuation { continuation in
            deepWaiters.append(Waiter(count: count, continuation: continuation))
        }
    }

    @discardableResult
    func succeedCore(_ call: Int) -> Bool {
        guard let continuation = coreContinuations.removeValue(forKey: call) else {
            return false
        }
        continuation.resume()
        return true
    }

    @discardableResult
    func failCore(_ call: Int) -> Bool {
        guard let continuation = coreContinuations.removeValue(forKey: call) else {
            return false
        }
        continuation.resume(throwing: ControlledAnalyticsFailure())
        return true
    }

    @discardableResult
    func cancelCore(_ call: Int) -> Bool {
        guard let continuation = coreContinuations.removeValue(forKey: call) else {
            return false
        }
        continuation.resume(throwing: CancellationError())
        return true
    }

    @discardableResult
    func succeedDeep(_ call: Int) -> Bool {
        guard let continuation = deepContinuations.removeValue(forKey: call) else {
            return false
        }
        continuation.resume()
        return true
    }

    @discardableResult
    func failDeep(_ call: Int) -> Bool {
        guard let continuation = deepContinuations.removeValue(forKey: call) else {
            return false
        }
        continuation.resume(throwing: ControlledAnalyticsFailure())
        return true
    }

    @discardableResult
    func cancelDeep(_ call: Int) -> Bool {
        guard let continuation = deepContinuations.removeValue(forKey: call) else {
            return false
        }
        continuation.resume(throwing: CancellationError())
        return true
    }

    private func makeCore(
        from input: AnalyticsSnapshot,
        now: Date
    ) async throws -> SessionAnalytics.AnalyticsWorking.CoreBuild {
        try await withCheckedThrowingContinuation { continuation in
            coreCallCount += 1
            coreContinuations[coreCallCount] = continuation
            resumeReadyWaiters(&coreWaiters, count: coreCallCount)
        }

        // Deliberately ignore inherited cancellation after the gate. This
        // forces stale results back to SessionAnalytics so its generation
        // checks—not the test double—prove publication safety.
        let live = live
        return try await Task.detached {
            try await live.makeCore(input, now)
        }.value
    }

    private func makeDeep(
        from accumulator: AnalyticsAccumulator,
        now: Date,
        consistency: ConsistencyReport
    ) async throws -> SessionAnalytics.DeepReports {
        try await withCheckedThrowingContinuation { continuation in
            deepCallCount += 1
            deepContinuations[deepCallCount] = continuation
            resumeReadyWaiters(&deepWaiters, count: deepCallCount)
        }

        let live = live
        return try await Task.detached {
            try await live.makeDeep(accumulator, now, consistency)
        }.value
    }

    private func resumeReadyWaiters(
        _ waiters: inout [Waiter],
        count: Int
    ) {
        var remaining: [Waiter] = []
        for waiter in waiters {
            if waiter.count <= count {
                waiter.continuation.resume()
            } else {
                remaining.append(waiter)
            }
        }
        waiters = remaining
    }
}

private actor CoherentAnalyticsWorking {
    private let live = SessionAnalytics.AnalyticsWorking.live()
    private let sentinel: AnalyticsSnapshot
    private(set) var coreCallCount = 0
    private(set) var deepCallCount = 0
    private(set) var deepSessionIDs: [UUID] = []
    private(set) var deepConsistencyDays = -1

    init(sentinel: AnalyticsSnapshot) {
        self.sentinel = sentinel
    }

    func working() -> SessionAnalytics.AnalyticsWorking {
        SessionAnalytics.AnalyticsWorking(
            makeCore: { _, now in
                try await self.makeSentinelCore(now: now)
            },
            makeDeep: { accumulator, now, consistency in
                try await self.makeDeep(
                    from: accumulator,
                    now: now,
                    consistency: consistency
                )
            }
        )
    }

    private func makeSentinelCore(
        now: Date
    ) async throws -> SessionAnalytics.AnalyticsWorking.CoreBuild {
        coreCallCount += 1
        return try await live.makeCore(sentinel, now)
    }

    private func makeDeep(
        from accumulator: AnalyticsAccumulator,
        now: Date,
        consistency: ConsistencyReport
    ) async throws -> SessionAnalytics.DeepReports {
        deepCallCount += 1
        deepSessionIDs = accumulator.sessions.map(\.session.id)
        deepConsistencyDays = consistency.daysTrainedInWindow
        return try await live.makeDeep(accumulator, now, consistency)
    }
}

@MainActor
struct SessionAnalyticsConcurrencyTests {
    private struct HistoryHarness {
        let container: ModelContainer
        let context: ModelContext
    }

    @Test
    nonisolated func analyticsBoundaryIsSendable() {
        requireSendable(AnalyticsSnapshot.self)
        requireSendable(AnalyticsAccumulator.self)
        requireSendable(ExerciseSetPrescription.self)
        requireSendable(ExerciseHistoryInstance.self)
        requireSendable(ExerciseHistorySummary.self)
        requireSendable(ExerciseDetailReports.self)
        requireSendable(SessionAnalytics.CoreReports.self)
        requireSendable(SessionAnalytics.DeepReports.self)
        requireSendable(SessionAnalytics.InsightsReports.self)
        requireSendable(SessionAnalytics.WidgetReports.self)
        requireSendable(SessionAnalytics.RequestKey.self)
        requireSendable(SessionAnalytics.AnalyticsWorking.self)
        requireSendable(SessionAnalytics.AnalyticsWorking.CoreBuild.self)
    }

    @Test func snapshotDoesNotRetainModelValues() {
        let exercise = exercise(name: "Barbell Bench Press", catalogID: "bench")
        let session = completedSession(
            exercise: exercise,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let snapshot = AnalyticsSnapshot(sessions: [session])

        exercise.sets[0].reps = 20
        exercise.name = "Changed after capture"

        let captured = snapshot.sessions[0].exercises[0]
        #expect(captured.name == "Barbell Bench Press")
        #expect(captured.catalogID == "bench")
        #expect(captured.sets[0].reps == 8)
    }

    @Test func requestKeyUsesFirstCompletionDayAndRevision() throws {
        let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
        let laterDate = firstDate.addingTimeInterval(3600)
        let first = completedSession(
            name: "First in caller order",
            catalogID: "first",
            completedAt: firstDate
        )
        let later = completedSession(
            name: "Chronologically later",
            catalogID: "later",
            completedAt: laterDate
        )
        let now = firstDate.addingTimeInterval(7200)
        let analytics = SessionAnalytics()

        let key = analytics.requestKey(for: [first, later], now: now)
        #expect(key.sessionCount == 2)
        #expect(key.newestCompletion == firstDate.timeIntervalSince1970)
        #expect(
            key.day == Calendar.current.startOfDay(for: now).timeIntervalSince1970
        )
        #expect(key.revision == 0)

        let nextDay = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        #expect(analytics.requestKey(for: [first, later], now: nextDay).day != key.day)
        analytics.invalidate()
        #expect(analytics.requestKey(for: [first, later], now: now).revision == 1)
    }

    @Test func repeatedSameKeyCoreRequestsBuildOnce() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = completedSession(
            name: "Single Core",
            catalogID: "single-core",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestCore(for: [session], now: now)
        await control.waitForCoreCalls(1)
        analytics.requestCore(for: [session], now: now)
        analytics.requestCore(for: [session], now: now)
        #expect(await control.coreCallCount == 1)

        #expect(await control.succeedCore(1))
        await analytics.waitForPendingWork()
        analytics.requestCore(for: [session], now: now)

        #expect(await control.coreCallCount == 1)
        #expect(!analytics.isCoreLoading)
        #expect(analytics.coreReports.overview.totalWorkouts == 1)
        #expect(analytics.deepReports == nil)
    }

    @Test func sameKeyDeepPromotionDuringCoreBuildStartsOneDeepTask() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = completedSession(
            name: "Promoted",
            catalogID: "promoted",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestCore(for: [session], now: now)
        await control.waitForCoreCalls(1)
        analytics.requestInsights(for: [session], now: now)
        analytics.requestInsights(for: [session], now: now)

        #expect(analytics.isCoreLoading)
        #expect(analytics.isDeepLoading)
        #expect(await control.deepCallCount == 0)

        #expect(await control.succeedCore(1))
        await control.waitForDeepCalls(1)
        analytics.requestInsights(for: [session], now: now)
        #expect(await control.deepCallCount == 1)
        #expect(await control.succeedDeep(1))
        await analytics.waitForPendingWork()

        #expect(analytics.hasCoreReports)
        #expect(analytics.hasInsightsReports)
        #expect(analytics.insightsReports?.core.overview.totalWorkouts == 1)
        #expect(await control.coreCallCount == 1)
        #expect(await control.deepCallCount == 1)
    }

    @Test func sameKeyDeepPromotionAfterCoreBuildAndRepeatsStayCached() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = completedSession(
            name: "Immediate Deep",
            catalogID: "immediate-deep",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestCore(for: [session], now: now)
        await control.waitForCoreCalls(1)
        #expect(await control.succeedCore(1))
        await analytics.waitForPendingWork()
        #expect(analytics.deepReports == nil)

        analytics.requestInsights(for: [session], now: now)
        await control.waitForDeepCalls(1)
        #expect(await control.coreCallCount == 1)
        #expect(await control.succeedDeep(1))
        await analytics.waitForPendingWork()

        analytics.requestInsights(for: [session], now: now)
        analytics.requestInsights(for: [session], now: now)
        #expect(await control.coreCallCount == 1)
        #expect(await control.deepCallCount == 1)
        #expect(analytics.hasInsightsReports)
    }

    @Test func supersededCoreCannotPublishAStaleGeneration() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = completedSession(
            name: "Superseded",
            catalogID: "superseded",
            completedAt: now.addingTimeInterval(-60)
        )
        let second = completedSession(
            name: "Current",
            catalogID: "current",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestCore(for: [first], now: now)
        await control.waitForCoreCalls(1)
        let staleCoreTask = analytics.pendingWorkTasks().core
        analytics.requestCore(for: [second, first], now: now)
        await control.waitForCoreCalls(2)

        #expect(await control.succeedCore(1))
        await staleCoreTask?.value
        #expect(analytics.isCoreLoading)
        #expect(!analytics.hasCoreReports)

        #expect(await control.succeedCore(2))
        await analytics.waitForPendingWork()
        #expect(analytics.coreReports.overview.totalWorkouts == 2)
        #expect(!analytics.isCoreLoading)
    }

    @Test func invalidateCancelsWorkAndRetainsLastCompleteReports() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = completedSession(
            name: "Retained",
            catalogID: "retained",
            completedAt: now.addingTimeInterval(-60)
        )
        let second = completedSession(
            name: "In Flight",
            catalogID: "in-flight",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestInsights(for: [first], now: now)
        await control.waitForCoreCalls(1)
        #expect(await control.succeedCore(1))
        await control.waitForDeepCalls(1)
        #expect(await control.succeedDeep(1))
        await analytics.waitForPendingWork()

        analytics.requestCore(for: [second, first], now: now)
        await control.waitForCoreCalls(2)
        let staleCoreTask = analytics.pendingWorkTasks().core
        let revision = analytics.invalidationRevision
        analytics.invalidate()

        #expect(analytics.invalidationRevision == revision + 1)
        #expect(!analytics.isCoreLoading)
        #expect(!analytics.isDeepLoading)
        #expect(!analytics.hasExerciseHistorySummaries)
        #expect(analytics.coreReports.overview.totalWorkouts == 1)
        #expect(analytics.insightsReports?.core.overview.totalWorkouts == 1)

        #expect(await control.succeedCore(2))
        await staleCoreTask?.value
        #expect(analytics.coreReports.overview.totalWorkouts == 1)

        analytics.requestCore(for: [second, first], now: now)
        await control.waitForCoreCalls(3)
        #expect(await control.succeedCore(3))
        await analytics.waitForPendingWork()
        #expect(analytics.coreReports.overview.totalWorkouts == 2)
    }

    @Test func currentCoreCancellationDoesNotRetryTheSameKey() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = completedSession(
            name: "Canceled Core",
            catalogID: "canceled-core",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestCore(for: [session], now: now)
        await control.waitForCoreCalls(1)
        #expect(await control.cancelCore(1))
        await analytics.waitForPendingWork()

        #expect(!analytics.isCoreLoading)
        #expect(!analytics.hasCoreReports)
        analytics.requestCore(for: [session], now: now)
        #expect(await control.coreCallCount == 1)
    }

    @Test func currentCoreFailureRetainsPriorReportsAndDoesNotRetry() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = completedSession(
            name: "Prior Core",
            catalogID: "prior-core",
            completedAt: now.addingTimeInterval(-60)
        )
        let second = completedSession(
            name: "Failed Core",
            catalogID: "failed-core",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestCore(for: [first], now: now)
        await control.waitForCoreCalls(1)
        #expect(await control.succeedCore(1))
        await analytics.waitForPendingWork()

        analytics.requestCore(for: [second, first], now: now)
        await control.waitForCoreCalls(2)
        #expect(await control.failCore(2))
        await analytics.waitForPendingWork()

        #expect(!analytics.isCoreLoading)
        #expect(analytics.coreReports.overview.totalWorkouts == 1)
        analytics.requestCore(for: [second, first], now: now)
        #expect(await control.coreCallCount == 2)
    }

    @Test func currentDeepCancellationCanRetryWithoutRebuildingCore() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = completedSession(
            name: "Canceled Deep",
            catalogID: "canceled-deep",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestInsights(for: [session], now: now)
        await control.waitForCoreCalls(1)
        #expect(await control.succeedCore(1))
        await control.waitForDeepCalls(1)
        #expect(await control.cancelDeep(1))
        await analytics.waitForPendingWork()

        #expect(!analytics.isDeepLoading)
        #expect(analytics.deepReports == nil)
        analytics.requestInsights(for: [session], now: now)
        await control.waitForDeepCalls(2)
        #expect(await control.succeedDeep(2))
        await analytics.waitForPendingWork()

        #expect(await control.coreCallCount == 1)
        #expect(await control.deepCallCount == 2)
        #expect(analytics.hasInsightsReports)
    }

    @Test func deepFailureRetainsCoherentPriorInsightsAndCanRetry() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = completedSession(
            name: "Prior Insights",
            catalogID: "prior-insights",
            completedAt: now.addingTimeInterval(-60)
        )
        let second = completedSession(
            name: "Retry Insights",
            catalogID: "retry-insights",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestInsights(for: [first], now: now)
        await control.waitForCoreCalls(1)
        #expect(await control.succeedCore(1))
        await control.waitForDeepCalls(1)
        #expect(await control.succeedDeep(1))
        await analytics.waitForPendingWork()

        analytics.requestInsights(for: [second, first], now: now)
        await control.waitForCoreCalls(2)
        #expect(await control.succeedCore(2))
        await control.waitForDeepCalls(2)
        #expect(await control.failDeep(2))
        await analytics.waitForPendingWork()

        #expect(analytics.coreReports.overview.totalWorkouts == 2)
        #expect(analytics.insightsReports?.core.overview.totalWorkouts == 1)
        #expect(!analytics.isDeepLoading)

        analytics.requestInsights(for: [second, first], now: now)
        await control.waitForDeepCalls(3)
        #expect(await control.succeedDeep(3))
        await analytics.waitForPendingWork()

        #expect(await control.coreCallCount == 2)
        #expect(await control.deepCallCount == 3)
        #expect(analytics.insightsReports?.core.overview.totalWorkouts == 2)
    }

    @Test func supersededDeepCannotPublishOrClearTheCurrentGeneration() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = completedSession(
            name: "Superseded Deep",
            catalogID: "superseded-deep",
            completedAt: now.addingTimeInterval(-60)
        )
        let second = completedSession(
            name: "Current Deep",
            catalogID: "current-deep",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestInsights(for: [first], now: now)
        await control.waitForCoreCalls(1)
        #expect(await control.succeedCore(1))
        await control.waitForDeepCalls(1)
        let staleDeepTask = analytics.pendingWorkTasks().deep

        analytics.requestInsights(for: [second, first], now: now)
        await control.waitForCoreCalls(2)
        #expect(await control.succeedCore(2))
        await control.waitForDeepCalls(2)

        #expect(await control.succeedDeep(1))
        await staleDeepTask?.value
        #expect(analytics.isDeepLoading)
        #expect(analytics.insightsReports == nil)

        #expect(await control.succeedDeep(2))
        await analytics.waitForPendingWork()
        #expect(analytics.insightsReports?.core.overview.totalWorkouts == 2)
        #expect(!analytics.isDeepLoading)
    }

    @Test func synchronousHistoryUsesPublishedCacheWithoutFetching() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = completedSession(
            name: "Cached History",
            catalogID: "cached-history",
            completedAt: now
        )
        let key = session.orderedExercises[0].historyKey
        var fetchCount = 0
        let analytics = SessionAnalytics(historyFetch: { _ in
            fetchCount += 1
            return []
        })
        analytics.requestCore(for: [session], now: now)
        await analytics.waitForPendingWork()

        let harness = try historyHarness()
        let history = try #require(
            analytics.resolvedExerciseHistory(in: harness.context)
        )
        #expect(history[key]?.sessionCount == 1)
        #expect(fetchCount == 0)
    }

    @Test func synchronousHistoryDistinguishesEmptyArchiveFromFetchFailure() throws {
        let harness = try historyHarness()
        var emptyFetchCount = 0
        let emptyAnalytics = SessionAnalytics(historyFetch: { _ in
            emptyFetchCount += 1
            return []
        })

        let first = try #require(
            emptyAnalytics.resolvedExerciseHistory(in: harness.context)
        )
        let second = try #require(
            emptyAnalytics.resolvedExerciseHistory(in: harness.context)
        )
        #expect(first.isEmpty)
        #expect(second.isEmpty)
        #expect(emptyFetchCount == 1)
        #expect(emptyAnalytics.hasExerciseHistorySummaries)

        var failedFetchCount = 0
        let failedAnalytics = SessionAnalytics(historyFetch: { _ in
            failedFetchCount += 1
            throw ControlledAnalyticsFailure()
        })
        #expect(failedAnalytics.resolvedExerciseHistory(in: harness.context) == nil)
        #expect(failedAnalytics.resolvedExerciseHistory(in: harness.context) == nil)
        #expect(failedFetchCount == 2)
        #expect(!failedAnalytics.hasExerciseHistorySummaries)
    }

    @Test func widgetResolutionJoinsCoreAndUsesItsProjection() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = completedSession(
            name: "Widget Join",
            catalogID: "widget-join",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())

        analytics.requestCore(for: [session], now: now)
        await control.waitForCoreCalls(1)
        let widgetTask = Task { @MainActor in
            await analytics.resolvedWidgetReports(for: [session], now: now)
        }
        #expect(await control.succeedCore(1))
        let reports = try #require(await widgetTask.value)

        #expect(await control.coreCallCount == 1)
        #expect(reports.load == analytics.coreReports.load)
        #expect(reports.consistency.daysTrained == 1)
    }

    @Test func widgetCallerCancellationReturnsNilWithoutCancelingSharedCore() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = completedSession(
            name: "Widget Cancellation",
            catalogID: "widget-cancellation",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())
        let widgetTask = Task { @MainActor in
            await analytics.resolvedWidgetReports(for: [session], now: now)
        }

        await control.waitForCoreCalls(1)
        widgetTask.cancel()
        #expect(await control.succeedCore(1))
        #expect(await widgetTask.value == nil)
        await analytics.waitForPendingWork()

        #expect(analytics.hasCoreReports)
        #expect(analytics.coreReports.overview.totalWorkouts == 1)
        #expect(await control.coreCallCount == 1)
    }

    @Test func widgetRejectsAReportWhenItsFingerprintIsSuperseded() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = completedSession(
            name: "Old Widget",
            catalogID: "old-widget",
            completedAt: now.addingTimeInterval(-60)
        )
        let second = completedSession(
            name: "Current Widget",
            catalogID: "current-widget",
            completedAt: now
        )
        let control = ControlledAnalyticsWorking()
        let analytics = await SessionAnalytics(working: control.working())
        let widgetTask = Task { @MainActor in
            await analytics.resolvedWidgetReports(for: [first], now: now)
        }

        await control.waitForCoreCalls(1)
        analytics.requestCore(for: [second, first], now: now)
        await control.waitForCoreCalls(2)
        #expect(await control.succeedCore(1))
        #expect(await widgetTask.value == nil)

        #expect(await control.succeedCore(2))
        await analytics.waitForPendingWork()
        #expect(analytics.coreReports.overview.totalWorkouts == 2)
    }

    @Test func coreAndDeepUseOneCoherentWorkerAccumulator() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let requested = completedSession(
            name: "Requested Input",
            catalogID: "requested-input",
            completedAt: now
        )
        let sentinel = completedSession(
            name: "Sentinel Replay",
            catalogID: "sentinel-replay",
            completedAt: now
        )
        let sentinelSnapshot = AnalyticsSnapshot(sessions: [sentinel])
        let probe = CoherentAnalyticsWorking(sentinel: sentinelSnapshot)
        let analytics = await SessionAnalytics(working: probe.working())

        analytics.requestInsights(for: [requested], now: now)
        await analytics.waitForPendingWork()

        #expect(await probe.coreCallCount == 1)
        #expect(await probe.deepCallCount == 1)
        #expect(await probe.deepSessionIDs == [sentinel.id])
        #expect(
            await probe.deepConsistencyDays
                == analytics.insightsReports?.core.consistency.daysTrainedInWindow
        )
        #expect(
            analytics.insightsReports?.core.exerciseHistory.keys.contains(
                sentinel.orderedExercises[0].historyKey
            ) == true
        )
        #expect(
            analytics.insightsReports?.core.exerciseHistory.keys.contains(
                requested.orderedExercises[0].historyKey
            ) == false
        )
    }

    private func exercise(
        name: String,
        catalogID: String
    ) -> Exercise {
        let exercise = Exercise(
            name: name,
            catalogID: catalogID,
            familyID: "analytics-characterization",
            group: .chest,
            plannedSets: 1,
            plannedReps: 8,
            plannedWeight: 135
        )
        exercise.sets[0].isCompleted = true
        return exercise
    }

    private func completedSession(
        name: String,
        catalogID: String,
        completedAt: Date
    ) -> WorkoutSession {
        completedSession(
            exercise: exercise(name: name, catalogID: catalogID),
            completedAt: completedAt
        )
    }

    private func completedSession(
        exercise: Exercise,
        completedAt: Date
    ) -> WorkoutSession {
        let session = WorkoutSession(
            exercises: [exercise],
            startedAt: completedAt.addingTimeInterval(-1800)
        )
        session.completedAt = completedAt
        return session
    }

    private func historyHarness() throws -> HistoryHarness {
        let configuration = ModelConfiguration(
            schema: VivobodyStore.schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: VivobodyStore.schema,
            configurations: [configuration]
        )
        return HistoryHarness(
            container: container,
            context: ModelContext(container)
        )
    }
}
