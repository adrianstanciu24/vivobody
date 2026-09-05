//
//  ExerciseDetailReports.swift
//  vivobody
//
//  One immutable Exercise Detail analytics generation. SessionAnalytics
//  builds these indexes beside its core reports from the same accumulator
//  and clock; a screen lookup never replays or traverses the workout archive.
//

import Foundation

nonisolated struct ExerciseDetailReports {
    /// Exact clock used for every windowed and relative value in this payload.
    let generatedAt: Date
    let historyByKey: [String: ExerciseHistorySummary]
    let progressByKey: [String: ExerciseProgress]
    let strengthByKey: [String: StrengthOutlookStat]
    let effortByKey: [String: ExerciseEffortSummary]
    let rawVolumeByKey: [String: ExerciseVolumeContribution.RawContribution]
    let weeklyVolumeByMuscle: [Muscle: MuscleVolumeStat]
    let staminaByKey: [String: ExerciseStamina]

    static let empty = ExerciseDetailReports.empty(
        generatedAt: Date(timeIntervalSince1970: 0)
    )

    static func empty(generatedAt: Date) -> ExerciseDetailReports {
        ExerciseDetailReports(
            generatedAt: generatedAt,
            historyByKey: [:],
            progressByKey: [:],
            strengthByKey: [:],
            effortByKey: [:],
            rawVolumeByKey: [:],
            weeklyVolumeByMuscle: [:],
            staminaByKey: [:]
        )
    }

    /// Index the already-built core contracts and derive the two reports that
    /// are unique to Exercise Detail while the shared replay is still hot.
    static func make(
        from accumulator: AnalyticsAccumulator,
        history: [String: ExerciseHistorySummary],
        progress: [ExerciseProgress],
        strength: StrengthOutlookBoard,
        weeklyVolume: [MuscleVolumeStat],
        stamina: [String: ExerciseStamina] = [:],
        now: Date,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> ExerciseDetailReports {
        guard !isCancelled() else { return empty(generatedAt: now) }
        let effort = accumulator.effortSummariesByHistoryKey(
            isCancelled: isCancelled
        )
        guard !isCancelled() else { return empty(generatedAt: now) }
        let rawVolume = ExerciseVolumeContribution
            .rawContributionsByHistoryKey(
                accumulator: accumulator,
                now: now,
                isCancelled: isCancelled
            )
        guard !isCancelled() else { return empty(generatedAt: now) }

        return ExerciseDetailReports(
            generatedAt: now,
            historyByKey: history,
            progressByKey: index(progress, by: \.id),
            strengthByKey: index(strength.stats, by: \.historyKey),
            effortByKey: effort,
            rawVolumeByKey: rawVolume,
            weeklyVolumeByMuscle: index(weeklyVolume, by: \.muscle),
            staminaByKey: stamina
        )
    }

    private static func index<Value, Key: Hashable>(
        _ values: [Value],
        by keyPath: KeyPath<Value, Key>
    ) -> [Key: Value] {
        var result: [Key: Value] = [:]
        result.reserveCapacity(values.count)
        for value in values {
            result[value[keyPath: keyPath]] = value
        }
        return result
    }
}
