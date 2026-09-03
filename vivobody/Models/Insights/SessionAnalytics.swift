//
//  SessionAnalytics.swift
//  vivobody
//
//  Observable two-tier coordinator for session-derived analytics.
//  SwiftData models are copied into AnalyticsSnapshot on MainActor;
//  an AnalyticsWorker actor then sorts and prices that immutable input
//  once, builds the core reports, and reuses the retained accumulator
//  only when Insights requests its deep tier. Superseded generations
//  are cancelled and rejected on return, while the last complete
//  reports remain visible during refreshes.
//

import Foundation
import Observation
import SwiftData
import SwiftUI
import VivoKit

@MainActor
@Observable
final class SessionAnalytics {
    /// Stable `.task(id:)` identity. The explicit revision changes on
    /// same-count/same-date archived-history corrections.
    nonisolated struct RequestKey: Hashable {
        let sessionCount: Int
        let newestCompletion: TimeInterval
        let day: TimeInterval
        let revision: Int
    }

    private(set) var coreReports: CoreReports
    private(set) var deepReports: DeepReports?
    private(set) var insightsReports: InsightsReports?
    private(set) var widgetReports: WidgetReports
    private(set) var isCoreLoading = false
    private(set) var isDeepLoading = false
    private(set) var invalidationRevision = 0
    private(set) var exerciseHistorySummaries:
        [String: ExerciseHistorySummary] = [:]

    var hasCoreReports: Bool {
        coreFingerprint != nil
    }

    var hasInsightsReports: Bool {
        insightsReports != nil
    }

    var hasExerciseHistorySummaries: Bool {
        exerciseHistoryFingerprint != nil
    }

    /// Compatibility accessors keep non-Insights screens focused on the
    /// report they consume. Deep access never starts computation; before
    /// the first requested result it returns a lightweight empty value.
    var volume: [MuscleVolumeStat] {
        coreReports.volume
    }

    var development: MuscleDevelopment.State {
        coreReports.development
    }

    var muscleMap: MuscleMapReport {
        coreReports.muscleMap
    }

    var strength: StrengthOutlookBoard {
        coreReports.strength
    }

    var progress: [ExerciseProgress] {
        coreReports.progress
    }

    var load: TrainingLoadReport {
        coreReports.load
    }

    var lastInstances: [String: LastExerciseInstance] {
        exerciseHistorySummaries.compactMapValues {
            $0.lastExerciseInstance
        }
    }

    var overview: ArchiveOverview {
        coreReports.overview
    }

    /// IDs of sessions that set a strength PR when logged — badge
    /// membership for History rows and Today's calendar/last-workout.
    var prSessionIDs: Set<UUID> {
        coreReports.overview.prSessionIDs
    }

    /// Cached ambient-forge temperature shared by every tab backdrop.
    var forgeWarmth: Double {
        coreReports.overview.forgeWarmth
    }

    var dominance: ExerciseDominanceBoard {
        deepReports?.dominance ?? Self.emptyDeepReports.dominance
    }

    var intensity: IntensityMix {
        deepReports?.intensity ?? Self.emptyDeepReports.intensity
    }

    var intensityWeeks: [IntensityWeek] {
        deepReports?.intensityWeeks ?? Self.emptyDeepReports.intensityWeeks
    }

    var migration: RepRangeMigrationReport {
        deepReports?.migration ?? Self.emptyDeepReports.migration
    }

    var composition: CompositionSplit {
        deepReports?.composition ?? Self.emptyDeepReports.composition
    }

    var symmetry: AntagonistBoard {
        deepReports?.symmetry ?? Self.emptyDeepReports.symmetry
    }

    var consistency: ConsistencyReport {
        deepReports?.consistency ?? Self.emptyDeepReports.consistency
    }

    @ObservationIgnored private let working: AnalyticsWorking
    @ObservationIgnored private let historyFetch:
        (ModelContext) throws -> [WorkoutSession]
    @ObservationIgnored private var coreTask: Task<Void, Never>?
    @ObservationIgnored private var deepTask: Task<Void, Never>?
    @ObservationIgnored private var requestedKey: RequestKey?
    @ObservationIgnored private var desiredDeepKey: RequestKey?
    @ObservationIgnored private var coreFingerprint: RequestKey?
    @ObservationIgnored private var deepFingerprint: RequestKey?
    @ObservationIgnored private var exerciseHistoryFingerprint: RequestKey?
    @ObservationIgnored private var widgetFingerprint: RequestKey?
    @ObservationIgnored private var currentAccumulator: AnalyticsAccumulator?
    @ObservationIgnored private var currentAccumulatorKey: RequestKey?
    @ObservationIgnored private var currentNow: Date?
    @ObservationIgnored private var deepTaskKey: RequestKey?
    @ObservationIgnored private var generation = 0

    init(
        working: AnalyticsWorking = .live(),
        historyFetch: ((ModelContext) throws -> [WorkoutSession])? = nil
    ) {
        self.working = working
        self.historyFetch = historyFetch ?? { context in
            let descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil },
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            )
            return try context.fetch(descriptor)
        }
        let empty = AnalyticsAccumulator.replay(
            AnalyticsSnapshot(sessions: [AnalyticsSessionSnapshot]())
        )
        let initialCore = CoreReports.make(from: empty, now: Date())
        coreReports = initialCore
        widgetReports = Self.makeWidgetReports(
            core: initialCore
        )
        exerciseHistorySummaries = initialCore.exerciseHistory
        deepReports = nil
        insightsReports = nil
    }

    /// Constant-time identity for a view's analytics request. Every
    /// analytics-facing query is newest-first, so the first completion
    /// supplies the high-water mark without rescanning history during
    /// each SwiftUI body evaluation. Archived sessions are ordinarily
    /// immutable; correction flows call `invalidate()`.
    func requestKey(
        for sessions: [WorkoutSession],
        now: Date = Date()
    ) -> RequestKey {
        let newest = sessions.first?.completedAt?.timeIntervalSince1970 ?? 0
        let day = Calendar.current
            .startOfDay(for: now)
            .timeIntervalSince1970
        return RequestKey(
            sessionCount: sessions.count,
            newestCompletion: newest,
            day: day,
            revision: invalidationRevision
        )
    }

    /// Request reports used outside Insights. Snapshot construction is
    /// the only full model-graph traversal on MainActor.
    func requestCore(
        for sessions: [WorkoutSession],
        now: Date = Date()
    ) {
        request(for: sessions, now: now, includesDeepReports: false)
    }

    /// Request the core tier plus the lazy Insights-only tier.
    func requestInsights(
        for sessions: [WorkoutSession],
        now: Date = Date()
    ) {
        request(for: sessions, now: now, includesDeepReports: true)
    }

    /// Forces the next visible consumer to build a new generation even
    /// when an archived correction leaves count and completion time
    /// unchanged. Existing reports remain visible until replacement.
    func invalidate() {
        invalidationRevision &+= 1
        generation &+= 1
        requestedKey = nil
        desiredDeepKey = nil
        currentAccumulator = nil
        currentAccumulatorKey = nil
        currentNow = nil
        exerciseHistoryFingerprint = nil
        widgetFingerprint = nil
        deepTaskKey = nil
        coreTask?.cancel()
        deepTask?.cancel()
        coreTask = nil
        deepTask = nil
        isCoreLoading = false
        isDeepLoading = false
    }

    /// Return a known-current history index, synchronously priming it
    /// from the archive only when the background analytics feed has not
    /// published yet or an explicit correction invalidated it. This is
    /// the one fallback fetch for latency-sensitive startup/PR paths;
    /// `nil` means the read failed, while an empty dictionary means the
    /// archive was read successfully and truly contains no history.
    func resolvedExerciseHistory(
        in context: ModelContext
    ) -> [String: ExerciseHistorySummary]? {
        if exerciseHistoryFingerprint != nil {
            return exerciseHistorySummaries
        }

        guard let sessions = try? historyFetch(context) else {
            return nil
        }
        let history = AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: sessions)
        ).exerciseHistoryByExercise()
        exerciseHistorySummaries = history
        exerciseHistoryFingerprint = requestKey(for: sessions)
        return history
    }

    /// Test/support hook that waits for the currently requested core
    /// and any deep task it launches. Production views do not await it;
    /// they observe published reports instead.
    func waitForPendingWork() async {
        await coreTask?.value
        await deepTask?.value
    }

    /// Capture the current task identities before a request supersedes them.
    /// Concurrency tests await these handles to prove stale work reached the
    /// coordinator's generation guard without relying on scheduler timing.
    func pendingWorkTasks() -> (
        core: Task<Void, Never>?,
        deep: Task<Void, Never>?
    ) {
        (coreTask, deepTask)
    }

    /// Return widget analytics for the requested archive generation.
    /// If the core tier is already current this is an O(1) cache read;
    /// otherwise it joins the same actor-backed build used by screens.
    func resolvedWidgetReports(
        for sessions: [WorkoutSession],
        now: Date = Date()
    ) async -> WidgetReports? {
        let key = requestKey(for: sessions, now: now)
        requestCore(for: sessions, now: now)
        await coreTask?.value
        guard !Task.isCancelled, widgetFingerprint == key else {
            return nil
        }
        return widgetReports
    }

    private func request(
        for sessions: [WorkoutSession],
        now: Date,
        includesDeepReports: Bool
    ) {
        let key = requestKey(for: sessions, now: now)

        if requestedKey == key {
            guard includesDeepReports else { return }
            desiredDeepKey = key
            if coreFingerprint == key,
               currentAccumulatorKey == key,
               let currentAccumulator,
               let currentNow
            {
                startDeepReports(
                    from: currentAccumulator,
                    core: coreReports,
                    key: key,
                    now: currentNow,
                    generation: generation
                )
            } else {
                isDeepLoading = true
            }
            return
        }

        let input = AnalyticsSnapshot(sessions: sessions)
        generation &+= 1
        let requestGeneration = generation

        requestedKey = key
        desiredDeepKey = includesDeepReports ? key : nil
        currentAccumulator = nil
        currentAccumulatorKey = nil
        currentNow = nil
        deepTaskKey = nil
        coreTask?.cancel()
        deepTask?.cancel()
        isCoreLoading = true
        isDeepLoading = includesDeepReports

        let working = working
        coreTask = Task { [weak self] in
            do {
                let build = try await working.makeCore(input, now)
                guard !Task.isCancelled, let self else { return }
                guard
                    self.generation == requestGeneration,
                    self.requestedKey == key
                else { return }

                self.coreReports = build.reports
                self.coreFingerprint = key
                self.widgetReports = build.widgetReports
                self.widgetFingerprint = key
                self.exerciseHistorySummaries = build.reports.exerciseHistory
                self.exerciseHistoryFingerprint = key
                self.currentAccumulator = build.accumulator
                self.currentAccumulatorKey = key
                self.currentNow = now
                self.isCoreLoading = false
                self.coreTask = nil

                if self.desiredDeepKey == key {
                    self.startDeepReports(
                        from: build.accumulator,
                        core: build.reports,
                        key: key,
                        now: now,
                        generation: requestGeneration
                    )
                } else {
                    self.isDeepLoading = false
                }
            } catch is CancellationError {
                guard let self, self.generation == requestGeneration else {
                    return
                }
                self.isCoreLoading = false
            } catch {
                guard let self, self.generation == requestGeneration else {
                    return
                }
                self.isCoreLoading = false
            }
        }
    }

    private func startDeepReports(
        from accumulator: AnalyticsAccumulator,
        core: CoreReports,
        key: RequestKey,
        now: Date,
        generation requestGeneration: Int
    ) {
        if deepFingerprint == key, insightsReports != nil {
            isDeepLoading = false
            return
        }
        guard deepTaskKey != key else { return }

        deepTask?.cancel()
        deepTaskKey = key
        isDeepLoading = true

        let working = working
        deepTask = Task { [weak self] in
            do {
                let reports = try await working.makeDeep(
                    accumulator,
                    now,
                    core.consistency
                )
                guard !Task.isCancelled, let self else { return }
                guard
                    self.generation == requestGeneration,
                    self.requestedKey == key,
                    self.desiredDeepKey == key
                else { return }

                self.deepReports = reports
                self.deepFingerprint = key
                self.insightsReports = InsightsReports(
                    core: core,
                    deep: reports
                )
                self.isDeepLoading = false
                self.deepTask = nil
                self.deepTaskKey = nil
            } catch is CancellationError {
                guard let self, self.generation == requestGeneration else {
                    return
                }
                self.isDeepLoading = false
                self.deepTaskKey = nil
            } catch {
                guard let self, self.generation == requestGeneration else {
                    return
                }
                self.isDeepLoading = false
                self.deepTaskKey = nil
            }
        }
    }

    private static let emptyDeepReports: DeepReports = {
        let empty = AnalyticsAccumulator.replay(
            AnalyticsSnapshot(sessions: [AnalyticsSessionSnapshot]())
        )
        return DeepReports.make(from: empty, now: Date())
    }()
}

extension EnvironmentValues {
    @Entry var sessionAnalytics: SessionAnalytics? = nil
}
