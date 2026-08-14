//
//  AnalyticsAccumulator.swift
//  vivobody
//
//  Shared chronological replay for analytics that use hard-set
//  credit. It sorts history once and prices every exercise once via
//  the stateless `SetStimulus` pricing, retaining immutable
//  per-session/per-exercise results for volume, development, training
//  load, the muscle map, and symmetry. The chronological sort exists
//  for consumers that integrate over time (the development decay
//  model, weekly load windows) — pricing itself carries no
//  cross-session state. It accepts only AnalyticsSnapshot values, so
//  sorting, pricing, and every report derived from the replay can run
//  away from the main actor. A MainActor model adapter exists only for
//  legacy report APIs and tests.
//

import Foundation

/// Data-quality coverage used by the muscle-map confidence read.
nonisolated struct AnalyticsMuscleQuality {
    var eligible: Int = 0
    var complete: Int = 0
}

/// Display metadata from the first occurrence in the caller's input
/// order. Some legacy APIs intentionally preserve that choice even
/// though report events themselves are replayed chronologically.
nonisolated struct AnalyticsExerciseMetadata {
    let catalogID: String?
    let catalogItemID: UUID?
    let name: String
    let group: MuscleGroup
}

/// A single exercise with its hard-set pricing computed exactly once.
nonisolated struct AnalyticsExerciseReplay {
    let exercise: AnalyticsExerciseSnapshot
    let setEquivalent: Double
    let byMuscle: [Muscle: Double]

    nonisolated var name: String {
        exercise.name
    }

    nonisolated var classification: ExerciseClassification? {
        exercise.classification
    }
}

/// One completed workout in chronological order.
nonisolated struct AnalyticsSessionReplay {
    let session: AnalyticsSessionSnapshot
    let exercises: [AnalyticsExerciseReplay]
    let totalSetEquivalent: Double
    let heavySets: Double

    nonisolated var date: Date {
        session.date
    }

    nonisolated var isCompleted: Bool {
        session.isCompleted
    }
}

nonisolated struct AnalyticsAccumulator {
    let sessions: [AnalyticsSessionReplay]
    let muscleQuality: [Muscle: AnalyticsMuscleQuality]
    let exerciseMetadata: [String: AnalyticsExerciseMetadata]

    /// Sort and price the archive once. All callers then derive their
    /// report-specific windows from these replayed values without
    /// touching SwiftData relationships again.
    static func replay(
        _ input: AnalyticsSnapshot,
        stimulusParameters: SetStimulus.Parameters = .default,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> AnalyticsAccumulator {
        replay(
            input,
            stimulusParameters: stimulusParameters,
            pricesStimulus: true,
            sortsChronologically: true,
            isCancelled: isCancelled
        )
    }

    /// Lightweight value replay for standalone progress/history APIs
    /// that do not consume hard-set currency. It preserves caller order
    /// and avoids both sorting and stimulus pricing outside the shared
    /// SessionAnalytics pipeline.
    static func history(_ input: AnalyticsSnapshot) -> AnalyticsAccumulator {
        replay(
            input,
            stimulusParameters: .default,
            pricesStimulus: false,
            sortsChronologically: false,
            isCancelled: { false }
        )
    }

    private static func replay(
        _ input: AnalyticsSnapshot,
        stimulusParameters: SetStimulus.Parameters,
        pricesStimulus: Bool,
        sortsChronologically: Bool,
        isCancelled: @Sendable () -> Bool
    ) -> AnalyticsAccumulator {
        guard !isCancelled() else {
            return AnalyticsAccumulator(
                sessions: [],
                muscleQuality: [:],
                exerciseMetadata: [:]
            )
        }
        let ordered = sortsChronologically
            ? input.sessions.sorted { $0.date < $1.date }
            : input.sessions
        guard !isCancelled() else {
            return AnalyticsAccumulator(
                sessions: [],
                muscleQuality: [:],
                exerciseMetadata: [:]
            )
        }
        var quality: [Muscle: AnalyticsMuscleQuality] = [:]
        var metadata: [String: AnalyticsExerciseMetadata] = [:]
        var replayed: [AnalyticsSessionReplay] = []
        replayed.reserveCapacity(ordered.count)

        metadataReplay: for session in input.sessions {
            guard !isCancelled() else { break }
            for exercise in session.exercises {
                guard !isCancelled() else { break metadataReplay }
                guard metadata[exercise.historyKey] == nil else { continue }
                metadata[exercise.historyKey] = AnalyticsExerciseMetadata(
                    catalogID: exercise.catalogID,
                    catalogItemID: exercise.catalogItemID,
                    name: exercise.name,
                    group: exercise.group
                )
            }
        }

        for session in ordered {
            guard !isCancelled() else { break }
            var exerciseEvents: [AnalyticsExerciseReplay] = []
            exerciseEvents.reserveCapacity(session.exercises.count)
            var sessionTotal = 0.0
            var heavySets = 0.0

            for exercise in session.exercises {
                guard !isCancelled() else { break }
                let priced = pricesStimulus
                    ? SetStimulus.price(for: exercise, parameters: stimulusParameters)
                    : SetStimulus.ExerciseCredit(
                        setEquivalent: 0,
                        byMuscle: [:]
                    )
                sessionTotal += priced.setEquivalent

                if pricesStimulus,
                   exercise.modality == .dynamicStrength,
                   exercise.trackingMode == .reps
                {
                    heavySets += Double(
                        exercise.sets.count(where: {
                            $0.isAnalyticsEligible && (1 ... 5).contains($0.reps)
                        })
                    )
                }

                for muscle in exercise.volumeCredits.keys where pricesStimulus {
                    for set in exercise.sets where set.isAnalyticsEligible {
                        switch (exercise.modality, exercise.trackingMode) {
                        case (.dynamicStrength, .reps) where set.reps > 0:
                            quality[muscle, default: AnalyticsMuscleQuality()].eligible += 1
                            if set.rirLogged {
                                quality[muscle, default: AnalyticsMuscleQuality()].complete += 1
                            }
                        case (.isometricStrength, .duration) where set.duration > 0:
                            quality[muscle, default: AnalyticsMuscleQuality()].eligible += 1
                            quality[muscle, default: AnalyticsMuscleQuality()].complete += 1
                        default:
                            break
                        }
                    }
                }

                exerciseEvents.append(
                    AnalyticsExerciseReplay(
                        exercise: exercise,
                        setEquivalent: priced.setEquivalent,
                        byMuscle: priced.byMuscle,
                    )
                )
            }

            replayed.append(
                AnalyticsSessionReplay(
                    session: session,
                    exercises: exerciseEvents,
                    totalSetEquivalent: sessionTotal,
                    heavySets: heavySets
                )
            )
        }

        return AnalyticsAccumulator(
            sessions: replayed,
            muscleQuality: quality,
            exerciseMetadata: metadata
        )
    }

    /// Compatibility bridge for report-level APIs and existing tests.
    /// Model access and snapshot construction finish on MainActor before
    /// the pure replay begins.
    @MainActor
    static func replay(
        _ input: [WorkoutSession],
        stimulusParameters: SetStimulus.Parameters = .default
    ) -> AnalyticsAccumulator {
        replay(
            AnalyticsSnapshot(sessions: input),
            stimulusParameters: stimulusParameters,
            isCancelled: { false }
        )
    }
}
