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

nonisolated enum MuscleEstimateConfidence: String, Sendable {
    case limited
    case moderate
    case high

    var displayName: String { rawValue.capitalized }
}

nonisolated struct MuscleMapEntry: Identifiable, Sendable {
    var id: Muscle { muscle }
    let muscle: Muscle
    let channels: MuscleMapChannels
    let band: MuscleDevelopmentBand
    let effectiveSets7d: Double
    let daysSinceLastTrained: Int?
    let topExercises: [String]
    let confidence: MuscleEstimateConfidence?
}

nonisolated struct MuscleMapReport: Sendable {
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
        var exerciseCredit: [Muscle: [String: Double]] = [:]
        let cutoff = now.addingTimeInterval(-90 * 86_400)

        sessionReplay: for session in accumulator.sessions {
            guard !isCancelled() else { return MuscleMapReport(entries: []) }
            for exercise in session.exercises {
                guard !isCancelled() else { break sessionReplay }
                if session.date >= cutoff {
                    for (muscle, value) in exercise.byMuscle where value > 0 {
                        guard !isCancelled() else { return MuscleMapReport(entries: []) }
                        exerciseCredit[muscle, default: [:]][exercise.name, default: 0] += value
                    }
                }
            }
        }

        var entries: [MuscleMapEntry] = []
        entries.reserveCapacity(Muscle.allCases.count)
        for muscle in Muscle.allCases {
            guard !isCancelled() else { return MuscleMapReport(entries: []) }
            let channels = development.channels(muscle)
            let top = (exerciseCredit[muscle] ?? [:])
                .sorted {
                    if $0.value == $1.value { return $0.key < $1.key }
                    return $0.value > $1.value
                }
                .prefix(3)
                .map(\.key)
            guard !isCancelled() else { return MuscleMapReport(entries: []) }
            let counts = accumulator.muscleQuality[muscle]
            let confidence: MuscleEstimateConfidence?
            if channels.baseline == .noData || counts == nil || counts?.eligible == 0 {
                confidence = nil
            } else {
                let coverage = Double(counts?.complete ?? 0) / Double(counts?.eligible ?? 1)
                if (counts?.eligible ?? 0) >= 6 && coverage >= 0.8 {
                    confidence = .high
                } else if (counts?.eligible ?? 0) >= 3 && coverage >= 0.4 {
                    confidence = .moderate
                } else {
                    confidence = .limited
                }
            }
            let weekly = volumeByMuscle[muscle]
            entries.append(MuscleMapEntry(
                muscle: muscle,
                channels: channels,
                band: MuscleDevelopmentBand.resolve(channels),
                effectiveSets7d: weekly?.effectiveSets ?? 0,
                daysSinceLastTrained: weekly?.daysSinceLastTrained,
                topExercises: top,
                confidence: confidence
            ))
        }
        return MuscleMapReport(entries: entries)
    }
}
