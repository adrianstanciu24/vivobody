//
//  AnalyticsWorker.swift
//  vivobody
//
//  Sendable analytics execution seam and actor that replays immutable
//  snapshots, checks cancellation, and constructs core and deep reports.
//

import Foundation

extension SessionAnalytics {
    /// Sendable execution seam. Live instances share one private worker.
    nonisolated struct AnalyticsWorking {
        nonisolated struct CoreBuild {
            let accumulator: AnalyticsAccumulator
            let reports: CoreReports
            let widgetReports: WidgetReports
        }

        let makeCore: @Sendable (
            AnalyticsSnapshot,
            Date
        ) async throws -> CoreBuild
        let makeDeep: @Sendable (
            AnalyticsAccumulator,
            Date,
            ConsistencyReport
        ) async throws -> DeepReports

        nonisolated static func live() -> AnalyticsWorking {
            let worker = AnalyticsWorker()
            return AnalyticsWorking(
                makeCore: { input, now in
                    try await worker.makeCore(from: input, now: now)
                },
                makeDeep: { accumulator, now, consistency in
                    try await worker.makeDeep(
                        from: accumulator,
                        now: now,
                        consistency: consistency
                    )
                }
            )
        }
    }
}

/// The only executor that performs report construction. Its inputs and
/// outputs are fully Sendable; no SwiftData object can reach this actor.
private actor AnalyticsWorker {
    func makeCore(
        from input: AnalyticsSnapshot,
        now: Date
    ) async throws -> SessionAnalytics.AnalyticsWorking.CoreBuild {
        let accumulator = AnalyticsAccumulator.replay(
            input,
            isCancelled: { Task.isCancelled }
        )
        try Task.checkCancellation()
        let reports = try SessionAnalytics.CoreReports.make(
            from: accumulator,
            now: now,
            isCancelled: { Task.isCancelled },
            checkpoint: { try Task.checkCancellation() }
        )
        let widgetReports = SessionAnalytics.makeWidgetReports(
            core: reports
        )
        try Task.checkCancellation()
        return SessionAnalytics.AnalyticsWorking.CoreBuild(
            accumulator: accumulator,
            reports: reports,
            widgetReports: widgetReports
        )
    }

    func makeDeep(
        from accumulator: AnalyticsAccumulator,
        now: Date,
        consistency: ConsistencyReport
    ) async throws -> SessionAnalytics.DeepReports {
        try Task.checkCancellation()
        return try SessionAnalytics.DeepReports.make(
            from: accumulator,
            now: now,
            consistency: consistency,
            isCancelled: { Task.isCancelled },
            checkpoint: { try Task.checkCancellation() }
        )
    }
}
