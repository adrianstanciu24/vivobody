//
//  SetStimulus.swift
//  vivobody
//
//  The shared work currency: COMPLETED HARD SETS. One completed set
//  credits each involved muscle
//
//      role credit × effort(RIR)
//
//  A completed working set is worth exactly 1.0. The only discount is
//  the user's own logged proximity-to-failure: RIR 0–2 counts whole
//  (the "within a few reps of failure" band the volume landmarks
//  assume) and each rep further in reserve costs 20%. An unlogged RIR
//  is not a reading and stays neutral — non-raters are never punished.
//  Only completed dynamic-strength reps and completed
//  isometric-strength holds enter this currency; power, conditioning,
//  and mobility work earns none.
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
//  (the 3D body) both consume this one pricing function, so every
//  surface agrees on what "a set of work" is worth by construction.
//

import Foundation

nonisolated enum SetStimulus {

    // MARK: - Tunable parameters

    /// The one knob of per-set crediting, kept in a struct so tests
    /// can sweep it and callers can thread a calibration through the
    /// shared replay without touching the math.
    struct Parameters: Sendable {
        /// Multiplicative penalty per RIR step beyond 2. RIR 0–2 all
        /// count as full hard sets; each rep further in reserve costs
        /// 20%.
        var effortDecayPerRIR: Double = 0.8

        static let `default` = Parameters()
    }

    // MARK: - Effort curve (pure)

    /// Proximity-to-failure multiplier. Neutral 1.0 when the RIR was
    /// never actually rated (`rirLogged == false`).
    static func effortFactor(rir: Int, logged: Bool, parameters: Parameters = .default) -> Double {
        guard logged else { return 1 }
        return pow(parameters.effortDecayPerRIR, Double(max(0, rir - 2)))
    }

    // MARK: - Exercise pricing

    /// The two views of one exercise's priced work: the systemic
    /// total (training load) and the role-weighted per-muscle credit
    /// (volume bars, 3D body).
    struct ExerciseCredit: Sendable {
        let setEquivalent: Double
        let byMuscle: [Muscle: Double]
    }

    /// Price one exercise's completed sets. Stabilizers remain
    /// available to body visualization, but intentionally earn no
    /// hypertrophy-volume credit (`volumeCredits` omits them).
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

    /// Whole-exercise hard-set total before muscle involvement is
    /// applied. Training load uses this systemic value.
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
