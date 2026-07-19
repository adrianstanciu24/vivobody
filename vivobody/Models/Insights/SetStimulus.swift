//
//  SetStimulus.swift
//  vivobody
//
//  The shared work currency: HARD-SET EQUIVALENTS. One completed set
//  credits each involved muscle
//
//      role credit × effort(RIR) × lengthFactor × loadFactor
//
//  Every factor is ≤ 1 and anchored at 1.0 for a normal hard working
//  set (≥ 5 reps, ≥ 70% of your demonstrated e1RM, RIR ≤ 2 or
//  unlogged), so proper training earns exactly the raw set count the
//  volume landmarks were calibrated against — the multipliers only
//  demote junk: warm-up ramps, token weights, heavy singles, and sets
//  stopped far from failure. Absence of signal is always neutral:
//  unlogged RIR, unavailable/non-comparable load, and a lift's
//  first-ever valid instance all read 1.0 on the factors they can't
//  answer. Only completed dynamic-strength reps and completed
//  isometric-strength holds enter this currency.
//
//  The load factor is self-calibrating per exercise: dynamic sets use
//  Epley e1RM while loaded isometric sets use effective resistance.
//  Each metric has its own DECAYING MAX (~90-day half-life, so a
//  returning lifter isn't demoted against a year-old PR). References
//  update causally — a stronger set is judged against prior history,
//  then raises the bar for the next set — so `Calculator` must be fed
//  sessions in chronological order. Keyed by `Exercise.historyKey`:
//  stable catalog ID for bundled work and the full performance signature
//  for custom work, matching every other per-exercise surface.
//
//  `MuscleVolume` (weekly bars, neglect list) and `MuscleDevelopment`
//  (the 3D body) both consume this one calculator, so every surface
//  agrees on what "a set of work" is worth by construction. Pure
//  value types over injected dates — fully testable on a virtual
//  clock (see `SetStimulusTests`). Design + calibration rationale:
//  specs/hard-set-currency.md.
//

import Foundation

nonisolated enum SetStimulus {

    // MARK: - Tunable parameters

    /// Every knob of the per-set crediting in one struct so the
    /// currency can be calibrated (and swept in tests) without
    /// touching the math. Weights are canonical lb, times seconds,
    /// decay constants days.
    struct Parameters {
        /// Multiplicative penalty per RIR step beyond 2. RIR 0–2 all
        /// count as full hard sets (the "within a few reps of failure"
        /// band the landmarks assume); each rep further in reserve
        /// costs 20%.
        var effortDecayPerRIR: Double = 0.8

        /// Reps at which a set earns full rep credit. Below this the
        /// factor ramps linearly down to `repFloor` at 1 rep.
        var fullCreditReps: Int = 5

        /// Hold length at which a `.duration` set earns full credit.
        var fullCreditSeconds: TimeInterval = 20

        /// Rep-factor floor — a heavy single is genuinely half a hard
        /// set, not noise.
        var repFloor: Double = 0.5

        /// e1RM ratio below which the load factor sits at its floor…
        var rampLow: Double = 0.4
        /// …and at or above which load earns full credit (≥ 70% of
        /// demonstrated e1RM covers every sane working-set scheme).
        var rampHigh: Double = 0.7
        /// Load-factor floor for token weights.
        var loadFloor: Double = 0.3

        /// Time-constant (days) of the per-exercise load-reference
        /// decay — ≈ 130 d is a ~90-day half-life, so the bar relaxes
        /// toward what the lifter currently lifts after a layoff.
        var referenceTau: Double = 130.0

        /// Absolute floor on one set's credit (before involvement):
        /// any valid completed strength set registers, so "did
        /// something" never reads identical to "did nothing."
        var stimulusFloor: Double = 0.1

        static let `default` = Parameters()
    }

    // MARK: - Factor curves (pure)

    /// Proximity-to-failure multiplier. Neutral 1.0 when the RIR was
    /// never actually rated (`rirLogged == false`) — non-raters are
    /// never punished.
    static func effortFactor(rir: Int, logged: Bool, parameters: Parameters = .default) -> Double {
        guard logged else { return 1 }
        return pow(parameters.effortDecayPerRIR, Double(max(0, rir - 2)))
    }

    /// Set-length multiplier for `.reps` sets: 1.0 at
    /// `fullCreditReps`+, ramping down to `repFloor` at a single rep.
    static func repFactor(reps: Int, parameters: Parameters = .default) -> Double {
        let full = max(2, parameters.fullCreditReps)
        guard reps < full else { return 1 }
        let ramp = parameters.repFloor
            + (1 - parameters.repFloor) * Double(reps - 1) / Double(full - 1)
        return min(1, max(parameters.repFloor, ramp))
    }

    /// Set-length multiplier for `.duration` holds — the timed
    /// counterpart to `repFactor`.
    static func holdFactor(duration: TimeInterval, parameters: Parameters = .default) -> Double {
        guard parameters.fullCreditSeconds > 0 else { return 1 }
        return min(1, max(parameters.repFloor, duration / parameters.fullCreditSeconds))
    }

    /// Relative-load multiplier from the ratio of a set's comparable
    /// load metric to the lifter's decayed best on that exercise: floor
    /// at `rampLow`, full credit at `rampHigh`.
    static func loadFactor(e1RMRatio r: Double, parameters: Parameters = .default) -> Double {
        let span = parameters.rampHigh - parameters.rampLow
        guard span > 0 else { return r >= parameters.rampHigh ? 1 : parameters.loadFloor }
        let t = min(1, max(0, (r - parameters.rampLow) / span))
        return parameters.loadFloor + (1 - parameters.loadFloor) * t
    }

    /// Epley estimated 1-rep max — the same formula
    /// `ExerciseProgressPoint.estimated1RM` charts.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    // MARK: - Calculator

    /// Carries the per-exercise reference table across a
    /// CHRONOLOGICAL session replay and prices each exercise's
    /// completed sets in hard-set equivalents. A value type: copy it,
    /// replay alternate futures, nothing shared.
    struct Calculator {
        let parameters: Parameters

        /// Dynamic e1RM and isometric effective-load references stay
        /// separate because their values have different units even if
        /// an exercise's semantics are edited between sessions.
        private var dynamicReferences: [String: (metric: Double, at: Date)] = [:]
        private var isometricReferences: [String: (metric: Double, at: Date)] = [:]

        private enum HardSetKind {
            case dynamic
            case isometric
        }

        private enum ReferenceKind {
            case dynamic
            case isometric
        }

        init(parameters: Parameters = .default) {
            self.parameters = parameters
        }

        /// Hard-set-equivalent credit per volume-bearing muscle for one
        /// exercise's completed sets, judged against — then updating —
        /// the trailing reference. `date` is the owning session's
        /// clock. Stabilizers remain available to body visualization,
        /// but intentionally earn no hypertrophy-volume credit.
        mutating func credit(for exercise: Exercise, at date: Date) -> [Muscle: Double] {
            let volumeCredits = exercise.muscleInvolvement.volumeCredits.filter {
                $0.value > 0
            }
            guard !volumeCredits.isEmpty else { return [:] }

            let total = setEquivalentCredit(for: exercise, at: date)
            guard total > 0 else { return [:] }
            return volumeCredits.mapValues { total * $0 }
        }

        /// Whole-exercise hard-set equivalents before muscle
        /// involvement is applied. Training load uses this systemic
        /// total while muscle analytics use `credit(for:at:)`.
        mutating func setEquivalentCredit(for exercise: Exercise, at date: Date) -> Double {
            let kind: HardSetKind
            switch (exercise.modality, exercise.trackingMode) {
            case (.dynamicStrength, .reps):
                kind = .dynamic
            case (.isometricStrength, .duration):
                kind = .isometric
            default:
                return 0
            }

            return exercise.orderedSets
                .reduce(into: 0.0) { total, set in
                    total += hardSetEquivalent(
                        for: set,
                        kind: kind,
                        loadProfile: exercise.loadProfile,
                        bodyweight: exercise.loadBodyweight,
                        key: exercise.historyKey,
                        at: date
                    )
                }
        }

        // MARK: Per-set pricing

        private mutating func hardSetEquivalent(
            for set: WorkoutSet,
            kind: HardSetKind,
            loadProfile: ExerciseLoadProfile,
            bodyweight: Double,
            key: String,
            at date: Date
        ) -> Double {
            guard set.isAnalyticsEligible else { return 0 }

            let credit: Double
            switch kind {
            case .dynamic:
                guard set.reps > 0 else { return 0 }
                credit = SetStimulus.effortFactor(rir: set.repsInReserve, logged: set.rirLogged, parameters: parameters)
                    * SetStimulus.repFactor(reps: set.reps, parameters: parameters)
                    * dynamicLoadFactorUpdatingReference(
                        loggedWeight: set.weight,
                        reps: set.reps,
                        loadProfile: loadProfile,
                        bodyweight: bodyweight,
                        key: key,
                        at: date
                    )
            case .isometric:
                guard set.duration > 0 else { return 0 }
                credit = SetStimulus.holdFactor(duration: set.duration, parameters: parameters)
                    * isometricLoadFactorUpdatingReference(
                        loggedWeight: set.weight,
                        loadProfile: loadProfile,
                        bodyweight: bodyweight,
                        key: key,
                        at: date
                    )
            }
            return max(parameters.stimulusFloor, credit)
        }

        /// Judge a set against the exercise's decayed reference, then
        /// fold the set into it — in that order, so a PR set earns
        /// full credit and only raises the bar for what follows.
        private mutating func dynamicLoadFactorUpdatingReference(
            loggedWeight: Double,
            reps: Int,
            loadProfile: ExerciseLoadProfile,
            bodyweight: Double,
            key: String,
            at date: Date
        ) -> Double {
            // Non-comparable resistance carries no load signal and is
            // therefore neutral rather than arbitrarily penalized.
            guard let effectiveLoad = loadProfile.effectiveLoad(
                loggedWeight: loggedWeight,
                bodyweight: bodyweight
            ) else { return 1 }
            let e1RM = SetStimulus.estimatedOneRepMax(weight: effectiveLoad, reps: reps)
            // Unloaded external work carries no load signal.
            guard e1RM > 0 else { return 1 }

            return loadFactorUpdatingReference(
                metric: e1RM,
                key: key,
                at: date,
                kind: .dynamic
            )
        }

        /// Isometric strength has no meaningful rep-based e1RM, but a
        /// comparable effective resistance still distinguishes a loaded
        /// working hold from a token-load hold. Unavailable load (unknown
        /// bodyweight) and intentionally non-comparable resistance stay
        /// neutral and do not seed a misleading reference.
        private mutating func isometricLoadFactorUpdatingReference(
            loggedWeight: Double,
            loadProfile: ExerciseLoadProfile,
            bodyweight: Double,
            key: String,
            at date: Date
        ) -> Double {
            guard let effectiveLoad = loadProfile.effectiveLoad(
                loggedWeight: loggedWeight,
                bodyweight: bodyweight
            ), effectiveLoad > 0 else { return 1 }

            return loadFactorUpdatingReference(
                metric: effectiveLoad,
                key: key,
                at: date,
                kind: .isometric
            )
        }

        /// Judge a comparable metric against its same-kind decayed
        /// reference, then fold it in. Dynamic and isometric histories
        /// deliberately use different tables because one is e1RM and the
        /// other is effective load.
        private mutating func loadFactorUpdatingReference(
            metric: Double,
            key: String,
            at date: Date,
            kind: ReferenceKind
        ) -> Double {
            let existing: (metric: Double, at: Date)?
            switch kind {
            case .dynamic:
                existing = dynamicReferences[key]
            case .isometric:
                existing = isometricReferences[key]
            }

            guard let existing else {
                // First-ever instance: neutral, and it seeds the bar.
                setReference((metric: metric, at: date), for: key, kind: kind)
                return 1
            }

            let dtDays = max(0, date.timeIntervalSince(existing.at)) / 86_400
            let decayed = existing.metric * exp(-dtDays / parameters.referenceTau)
            let factor: Double
            if decayed > 0 {
                factor = SetStimulus.loadFactor(e1RMRatio: metric / decayed, parameters: parameters)
            } else {
                factor = 1
            }
            setReference(
                (metric: max(metric, decayed), at: date),
                for: key,
                kind: kind
            )
            return factor
        }

        private mutating func setReference(
            _ reference: (metric: Double, at: Date),
            for key: String,
            kind: ReferenceKind
        ) {
            switch kind {
            case .dynamic:
                dynamicReferences[key] = reference
            case .isometric:
                isometricReferences[key] = reference
            }
        }
    }
}
