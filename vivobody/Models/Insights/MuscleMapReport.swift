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

enum MuscleEstimateConfidence: String, Sendable {
    case limited
    case moderate
    case high

    var displayName: String { rawValue.capitalized }
}

struct MuscleMapEntry: Identifiable {
    var id: Muscle { muscle }
    let muscle: Muscle
    let channels: MuscleMapChannels
    let band: MuscleDevelopmentBand
    let effectiveSets7d: Double
    let daysSinceLastTrained: Int?
    let topExercises: [String]
    let confidence: MuscleEstimateConfidence?
}

struct MuscleMapReport {
    let entries: [MuscleMapEntry]

    static func compute(
        sessions: [WorkoutSession],
        development: MuscleDevelopment.State,
        volume: [MuscleVolumeStat],
        now: Date = Date()
    ) -> MuscleMapReport {
        let volumeByMuscle = Dictionary(uniqueKeysWithValues: volume.map { ($0.muscle, $0) })
        var exerciseCredit: [Muscle: [String: Double]] = [:]
        var quality: [Muscle: (eligible: Int, complete: Int)] = [:]
        var calculator = SetStimulus.Calculator()
        let cutoff = now.addingTimeInterval(-90 * 86_400)

        let ordered = sessions.sorted {
            ($0.completedAt ?? $0.startedAt) < ($1.completedAt ?? $1.startedAt)
        }
        for session in ordered {
            let date = session.completedAt ?? session.startedAt
            for exercise in session.orderedExercises {
                let credit = calculator.credit(for: exercise, at: date)
                if date >= cutoff {
                    for (muscle, value) in credit where value > 0 {
                        exerciseCredit[muscle, default: [:]][exercise.name, default: 0] += value
                    }
                }

                for contribution in exercise.muscleInvolvement.contributions
                    where contribution.volumeCredit > 0 {
                    for set in exercise.sets where set.isAnalyticsEligible {
                        switch (exercise.modality, exercise.trackingMode) {
                        case (.dynamicStrength, .reps) where set.reps > 0:
                            quality[contribution.muscle, default: (0, 0)].eligible += 1
                            if set.rirLogged {
                                quality[contribution.muscle, default: (0, 0)].complete += 1
                            }
                        case (.isometricStrength, .duration) where set.duration > 0:
                            quality[contribution.muscle, default: (0, 0)].eligible += 1
                            quality[contribution.muscle, default: (0, 0)].complete += 1
                        default:
                            break
                        }
                    }
                }
            }
        }

        let entries = Muscle.allCases.map { muscle in
            let channels = development.channels(muscle)
            let top = (exerciseCredit[muscle] ?? [:])
                .sorted {
                    if $0.value == $1.value { return $0.key < $1.key }
                    return $0.value > $1.value
                }
                .prefix(3)
                .map(\.key)
            let counts = quality[muscle]
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
            return MuscleMapEntry(
                muscle: muscle,
                channels: channels,
                band: MuscleDevelopmentBand.resolve(channels),
                effectiveSets7d: weekly?.effectiveSets ?? 0,
                daysSinceLastTrained: weekly?.daysSinceLastTrained,
                topExercises: top,
                confidence: confidence
            )
        }
        return MuscleMapReport(entries: entries)
    }
}
