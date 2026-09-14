//
//  MuscleMapReport.swift
//  vivobody
//
//  User-facing interpretation of the chronic 3D development map.
//  Colour remains a continuous estimate; this report adds coarse bands,
//  recent work, provenance, and log-confidence without encoding any of
//  those secondary dimensions into hue or brightness.
//

import Foundation

nonisolated enum MuscleEstimateConfidence: String {
    case limited
    case moderate
    case high

    var displayName: String {
        rawValue.capitalized
    }
}

nonisolated struct MuscleMapEntry: Identifiable {
    var id: Muscle {
        muscle
    }

    let muscle: Muscle
    let channels: MuscleMapChannels
    let band: MuscleDevelopmentBand
    /// Effective sets over the caller-selected volume window
    /// (SessionAnalytics passes a 14-day window).
    let effectiveSets14d: Double
    let daysSinceLastTrained: Int?
    let topExercises: [String]
    let confidence: MuscleEstimateConfidence?
}

nonisolated struct MuscleMapReport {
    let entries: [MuscleMapEntry]

    @MainActor
    static func compute(
        sessions: [WorkoutSession],
        development: MuscleDevelopment.State,
        volume: [MuscleVolumeStat],
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> MuscleMapReport {
        compute(
            accumulator: AnalyticsAccumulator.replay(
                AnalyticsSnapshot(sessions: sessions),
                isCancelled: isCancelled
            ),
            development: development,
            volume: volume,
            now: now,
            isCancelled: isCancelled
        )
    }

    /// Interpret the muscle map from the shared hard-set replay.
    static func compute(
        accumulator: AnalyticsAccumulator,
        development: MuscleDevelopment.State,
        volume: [MuscleVolumeStat],
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> MuscleMapReport {
        guard !isCancelled() else { return MuscleMapReport(entries: []) }
        let volumeByMuscle = Dictionary(uniqueKeysWithValues: volume.map { ($0.muscle, $0) })
        let cutoff = now.addingTimeInterval(-90 * 86400)
        guard let exerciseCredit = recentExerciseCredit(
            accumulator.sessions,
            cutoff: cutoff,
            isCancelled: isCancelled
        ) else { return MuscleMapReport(entries: []) }

        var entries: [MuscleMapEntry] = []
        entries.reserveCapacity(Muscle.allCases.count)
        for muscle in Muscle.allCases {
            guard !isCancelled() else { return MuscleMapReport(entries: []) }
            let channels = development.channels(muscle)
            let top = (exerciseCredit[muscle] ?? [:])
                .sorted(by: creditRanksBefore)
                .prefix(3)
                .map(\.key)
            guard !isCancelled() else { return MuscleMapReport(entries: []) }
            let counts = accumulator.muscleQuality[muscle]
            let confidence = confidence(channels: channels, counts: counts)
            let stat = volumeByMuscle[muscle]
            entries.append(MuscleMapEntry(
                muscle: muscle,
                channels: channels,
                band: MuscleDevelopmentBand.resolve(channels),
                effectiveSets14d: stat?.effectiveSets ?? 0,
                daysSinceLastTrained: stat?.daysSinceLastTrained,
                topExercises: top,
                confidence: confidence
            ))
        }
        return MuscleMapReport(entries: entries)
    }

    private static func recentExerciseCredit(
        _ sessions: [AnalyticsSessionReplay],
        cutoff: Date,
        isCancelled: @Sendable () -> Bool
    ) -> [Muscle: [String: Double]]? {
        var result: [Muscle: [String: Double]] = [:]
        for session in sessions where session.date >= cutoff {
            guard !isCancelled() else { return nil }
            for exercise in session.exercises {
                guard !isCancelled() else { return nil }
                for (muscle, value) in exercise.byMuscle where value > 0 {
                    guard !isCancelled() else { return nil }
                    result[muscle, default: [:]][exercise.name, default: 0] += value
                }
            }
        }
        return result
    }

    private static func creditRanksBefore(
        _ lhs: Dictionary<String, Double>.Element,
        _ rhs: Dictionary<String, Double>.Element
    ) -> Bool {
        lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
    }

    private static func confidence(
        channels: MuscleMapChannels,
        counts: AnalyticsMuscleQuality?
    ) -> MuscleEstimateConfidence? {
        guard channels.baseline != .noData, let counts, counts.eligible > 0 else { return nil }
        let coverage = Double(counts.complete) / Double(counts.eligible)
        if counts.eligible >= 6, coverage >= 0.8 { return .high }
        if counts.eligible >= 3, coverage >= 0.4 { return .moderate }
        return .limited
    }
}
