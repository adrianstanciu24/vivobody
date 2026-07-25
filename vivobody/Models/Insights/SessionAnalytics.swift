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
import SwiftUI

@MainActor
@Observable
final class SessionAnalytics {

    /// Reports shared by Today, Me, Insights, and exercise-library
    /// surfaces. Every stored value is safe to cross back from the
    /// background worker.
    nonisolated struct CoreReports: Sendable {
        let volume: [MuscleVolumeStat]
        let development: MuscleDevelopment.State
        let muscleMap: MuscleMapReport
        let strength: StrengthOutlookBoard
        let progress: [ExerciseProgress]
        let load: TrainingLoadReport
        let lastInstances: [String: LastExerciseInstance]
        let overview: ArchiveOverview

        nonisolated static func make(
            from common: AnalyticsAccumulator,
            now: Date
        ) -> CoreReports {
            let progress = common.progressByExercise
            let volume = common.muscleVolume(now: now)
            let development = MuscleDevelopment.simulate(
                from: common,
                now: now
            )
            return CoreReports(
                volume: volume,
                development: development,
                muscleMap: MuscleMapReport.compute(
                    accumulator: common,
                    development: development,
                    volume: volume,
                    now: now
                ),
                strength: StrengthOutlookBoard.compute(
                    progress: progress,
                    now: now
                ),
                progress: progress,
                load: common.trainingLoad(now: now),
                lastInstances: common.lastInstanceByExercise(),
                overview: common.archiveOverview(progress: progress, now: now)
            )
        }
    }

    /// Reports whose only app consumer is Insights.
    nonisolated struct DeepReports: Sendable {
        let dominance: ExerciseDominanceBoard
        let intensity: IntensityMix
        let intensityWeeks: [IntensityWeek]
        let migration: RepRangeMigrationReport
        let composition: CompositionSplit
        let symmetry: AntagonistBoard
        let consistency: ConsistencyReport

        nonisolated static func make(
            from common: AnalyticsAccumulator,
            now: Date
        ) -> DeepReports {
            DeepReports(
                dominance: common.exerciseDominance(now: now),
                intensity: common.intensityMix(now: now),
                intensityWeeks: common.weeklyIntensity(now: now),
                migration: common.repRangeMigration(now: now),
                composition: common.compoundIsolationSplit(now: now),
                symmetry: common.antagonistBalance(now: now),
                consistency: common.consistency(now: now)
            )
        }
    }

    /// One coherent Insights payload. Core and deep reports are
    /// published together only after both were built from the same
    /// fingerprint and accumulator.
    nonisolated struct InsightsReports: Sendable {
        let core: CoreReports
        let deep: DeepReports
    }

    /// Stable `.task(id:)` identity. The explicit revision changes on
    /// same-count/same-date archived-history corrections.
    nonisolated struct RequestKey: Hashable, Sendable {
        let sessionCount: Int
        let newestCompletion: TimeInterval
        let day: TimeInterval
        let revision: Int
    }

    private(set) var coreReports: CoreReports
    private(set) var deepReports: DeepReports?
    private(set) var insightsReports: InsightsReports?
    private(set) var isCoreLoading = false
    private(set) var isDeepLoading = false
    private(set) var invalidationRevision = 0

    var hasCoreReports: Bool { coreFingerprint != nil }
    var hasInsightsReports: Bool { insightsReports != nil }

    // Compatibility accessors keep non-Insights screens focused on the
    // report they consume. Deep access never starts computation; before
    // the first requested result it returns a lightweight empty value.
    var volume: [MuscleVolumeStat] { coreReports.volume }
    var development: MuscleDevelopment.State { coreReports.development }
    var muscleMap: MuscleMapReport { coreReports.muscleMap }
    var strength: StrengthOutlookBoard { coreReports.strength }
    var progress: [ExerciseProgress] { coreReports.progress }
    var load: TrainingLoadReport { coreReports.load }
    var lastInstances: [String: LastExerciseInstance] {
        coreReports.lastInstances
    }
    var overview: ArchiveOverview { coreReports.overview }
    /// IDs of sessions that set a strength PR when logged — badge
    /// membership for History rows and Today's calendar/last-workout.
    var prSessionIDs: Set<UUID> { coreReports.overview.prSessionIDs }
    /// Cached ambient-forge temperature shared by every tab backdrop.
    var forgeWarmth: Double { coreReports.overview.forgeWarmth }

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

    @ObservationIgnored private let worker = AnalyticsWorker()
    @ObservationIgnored private var coreTask: Task<Void, Never>?
    @ObservationIgnored private var deepTask: Task<Void, Never>?
    @ObservationIgnored private var requestedKey: RequestKey?
    @ObservationIgnored private var desiredDeepKey: RequestKey?
    @ObservationIgnored private var coreFingerprint: RequestKey?
    @ObservationIgnored private var deepFingerprint: RequestKey?
    @ObservationIgnored private var currentAccumulator: AnalyticsAccumulator?
    @ObservationIgnored private var currentAccumulatorKey: RequestKey?
    @ObservationIgnored private var currentNow: Date?
    @ObservationIgnored private var deepTaskKey: RequestKey?
    @ObservationIgnored private var generation = 0

    init() {
        let empty = AnalyticsAccumulator.replay(
            AnalyticsSnapshot(sessions: [AnalyticsSessionSnapshot]())
        )
        coreReports = CoreReports.make(from: empty, now: Date())
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
        deepTaskKey = nil
        coreTask?.cancel()
        deepTask?.cancel()
        coreTask = nil
        deepTask = nil
        isCoreLoading = false
        isDeepLoading = false
    }

    /// Test/support hook that waits for the currently requested core
    /// and any deep task it launches. Production views do not await it;
    /// they observe published reports instead.
    func waitForPendingWork() async {
        await coreTask?.value
        await deepTask?.value
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
               let currentNow {
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

        let worker = worker
        coreTask = Task { [weak self] in
            do {
                let build = try await worker.makeCore(
                    from: input,
                    now: now
                )
                guard !Task.isCancelled, let self else { return }
                guard
                    self.generation == requestGeneration,
                    self.requestedKey == key
                else { return }

                self.coreReports = build.reports
                self.coreFingerprint = key
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

        let worker = worker
        deepTask = Task { [weak self] in
            do {
                let reports = try await worker.makeDeep(
                    from: accumulator,
                    now: now
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

/// The only executor that performs report construction. Its inputs and
/// outputs are fully Sendable; no SwiftData object can reach this actor.
private actor AnalyticsWorker {
    nonisolated struct CoreBuild: Sendable {
        let accumulator: AnalyticsAccumulator
        let reports: SessionAnalytics.CoreReports
    }

    func makeCore(
        from input: AnalyticsSnapshot,
        now: Date
    ) async throws -> CoreBuild {
        let accumulator = AnalyticsAccumulator.replay(
            input,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let progress = accumulator.progressByExercise(
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let volume = accumulator.muscleVolume(
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let development = MuscleDevelopment.simulate(
            from: accumulator,
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let muscleMap = MuscleMapReport.compute(
            accumulator: accumulator,
            development: development,
            volume: volume,
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let strength = StrengthOutlookBoard.compute(
            progress: progress,
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let load = accumulator.trainingLoad(
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let lastInstances = accumulator.lastInstanceByExercise(
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let overview = accumulator.archiveOverview(
            progress: progress,
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let reports = SessionAnalytics.CoreReports(
            volume: volume,
            development: development,
            muscleMap: muscleMap,
            strength: strength,
            progress: progress,
            load: load,
            lastInstances: lastInstances,
            overview: overview
        )
        return CoreBuild(accumulator: accumulator, reports: reports)
    }

    func makeDeep(
        from accumulator: AnalyticsAccumulator,
        now: Date
    ) async throws -> SessionAnalytics.DeepReports {
        try Task.checkCancellation()
        let dominance = accumulator.exerciseDominance(
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let intensity = accumulator.intensityMix(
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let intensityWeeks = accumulator.weeklyIntensity(
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let migration = accumulator.repRangeMigration(
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let composition = accumulator.compoundIsolationSplit(
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let symmetry = accumulator.antagonistBalance(
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let consistency = accumulator.consistency(
            now: now,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        return SessionAnalytics.DeepReports(
            dominance: dominance,
            intensity: intensity,
            intensityWeeks: intensityWeeks,
            migration: migration,
            composition: composition,
            symmetry: symmetry,
            consistency: consistency
        )
    }
}

// MARK: - Environment injection

/// Lets views without direct AppState access (e.g. ExerciseDetailScreen
/// presented from a NavigationLink) share the cached analytics.
private struct SessionAnalyticsKey: EnvironmentKey {
    static let defaultValue: SessionAnalytics? = nil
}

extension EnvironmentValues {
    var sessionAnalytics: SessionAnalytics? {
        get { self[SessionAnalyticsKey.self] }
        set { self[SessionAnalyticsKey.self] = newValue }
    }
}
