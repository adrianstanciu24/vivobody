//
//  SetStimulus.swift
//  vivobody
//
//  The shared muscle-work currency: COMPLETED HARD SETS. One completed
//  set credits each involved muscle
//
//      role credit × effort(RIR)
//
//  Logged RIR 0/1/2/3/4/5+ credits 1.0/0.9/0.8/0.7/0.6/0.4.
//  These are product effort weights, not measured muscle-growth ratios.
//  Legacy sets without a logged rating retain neutral credit.
//  Only completed dynamic-strength reps and completed
//  isometric-strength holds enter this currency; power earns none.
//
//  Deliberately absent (removed 2026-08, see
//  specs/muscle-attention-simplification.md): per-exercise decaying
//  load references, rep/hold length ramps, and floors. The muscle map
//  is an estimate of where training attention has gone, built from a
//  diary of named exercises and the catalog's authored roles — factor
//  curves tuned finer than that input's accuracy were precision the
//  data could not back. Pricing is now a pure per-set function with no
//  cross-session state, so no consumer needs a chronological replay to
//  price work.
//
//  `MuscleVolume` (weekly bars, neglect list) and `MuscleDevelopment`
//  (the 3D body) both consume this one pricing function, so every muscle
//  surface agrees on what "a set of work" is worth by construction.
//  Training Load uses comparable volume load when available and keeps
//  these hard sets as a driver and fallback measure.
//

import Foundation

nonisolated enum SetStimulus {
    // MARK: - Tunable parameters

    /// Shared effort policy threaded through the analytics replay.
    struct Parameters {
        let effortCredits: [Double] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.4]

        static let `default` = Parameters()
    }

    // MARK: - Effort curve (pure)

    /// Selected RIR maps to a bounded score; all values of 5 or more
    /// share the last bucket. Legacy unrated sets retain neutral credit.
    static func effortFactor(rir: Int, logged: Bool, parameters: Parameters = .default) -> Double {
        guard logged else { return 1 }
        return parameters.effortCredits[min(max(rir, 0), 5)]
    }

    // MARK: - Exercise pricing

    /// The two views of one exercise's hard-set work: the whole-exercise
    /// total used by Training Load's driver and fallback, and the
    /// role-weighted per-muscle credit used by volume bars and the 3D body.
    struct ExerciseCredit {
        let setEquivalent: Double
        let byMuscle: [Muscle: Double]
    }

    /// Price one exercise's completed sets using primary, secondary,
    /// and stabilizer weights from the shared role policy.
    static func price(
        for exercise: AnalyticsExerciseSnapshot,
        parameters: Parameters = .default
    ) -> ExerciseCredit {
        let total = setEquivalentCredit(for: exercise, parameters: parameters)
        guard total > 0 else {
            return ExerciseCredit(setEquivalent: total, byMuscle: [:])
        }
        return ExerciseCredit(
            setEquivalent: total,
            byMuscle: exercise.volumeCredits.mapValues { total * $0 }
        )
    }

    /// Hard-set credit per volume-bearing muscle for one exercise's
    /// completed sets.
    static func credit(
        for exercise: AnalyticsExerciseSnapshot,
        parameters: Parameters = .default
    ) -> [Muscle: Double] {
        price(for: exercise, parameters: parameters).byMuscle
    }

    /// Whole-exercise hard-set total before muscle involvement is applied.
    /// Training Load uses this only as a visible driver and fallback measure.
    static func setEquivalentCredit(
        for exercise: AnalyticsExerciseSnapshot,
        parameters: Parameters = .default
    ) -> Double {
        let countsDuration: Bool
        switch (exercise.modality, exercise.trackingMode) {
        case (.dynamicStrength, .reps):
            countsDuration = false
        case (.isometricStrength, .duration):
            countsDuration = true
        default:
            return 0
        }

        return exercise.sets.reduce(into: 0.0) { total, set in
            guard set.isAnalyticsEligible else { return }
            if countsDuration {
                guard set.duration > 0 else { return }
            } else {
                guard set.reps > 0 else { return }
            }
            total += effortFactor(
                rir: set.repsInReserve,
                logged: set.rirLogged,
                parameters: parameters
            )
        }
    }

    // MARK: - MainActor model conveniences

    /// Price a live SwiftData exercise directly — used by tests and
    /// one-shot summaries that never build an AnalyticsSnapshot.
    @MainActor
    static func credit(
        for exercise: Exercise,
        parameters: Parameters = .default
    ) -> [Muscle: Double] {
        credit(
            for: AnalyticsExerciseSnapshot(
                exercise,
                bodyweightAtSession: exercise.loadBodyweight
            ),
            parameters: parameters
        )
    }

    @MainActor
    static func setEquivalentCredit(
        for exercise: Exercise,
        parameters: Parameters = .default
    ) -> Double {
        setEquivalentCredit(
            for: AnalyticsExerciseSnapshot(
                exercise,
                bodyweightAtSession: exercise.loadBodyweight
            ),
            parameters: parameters
        )
    }
}
