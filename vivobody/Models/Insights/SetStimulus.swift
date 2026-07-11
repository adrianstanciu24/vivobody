//
//  SetStimulus.swift
//  vivobody
//
//  The shared work currency: HARD-SET EQUIVALENTS. One completed set
//  credits each involved muscle
//
//      involvement × effort(RIR) × repFactor(reps|duration) × loadFactor
//
//  Every factor is ≤ 1 and anchored at 1.0 for a normal hard working
//  set (≥ 5 reps, ≥ 70% of your demonstrated e1RM, RIR ≤ 2 or
//  unlogged), so proper training earns exactly the raw set count the
//  volume landmarks were calibrated against — the multipliers only
//  demote junk: warm-up ramps, token weights, heavy singles, and sets
//  stopped far from failure. Absence of signal is always neutral:
//  unlogged RIR, bodyweight sets (weight 0), timed holds, and a
//  lift's first-ever instance all read 1.0 on the factors they can't
//  answer.
//
//  The load factor is self-calibrating per exercise: a set's Epley
//  e1RM is judged against a DECAYING MAX of that lift's own history
//  (~90-day half-life, so a returning lifter isn't demoted against a
//  year-old PR). References update causally — a PR set is judged
//  against prior history, then raises the bar for the next set — so
//  `Calculator` must be fed sessions in chronological order. Keyed by
//  `Exercise.historyKey` (stable catalog ID, name fallback), the same
//  identity every per-exercise surface uses.
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

        /// Time-constant (days) of the per-exercise reference e1RM
        /// decay — ≈ 130 d is a ~90-day half-life, so the bar relaxes
        /// toward what the lifter currently lifts after a layoff.
        var referenceTau: Double = 130.0

        /// Absolute floor on one set's credit (before involvement):
        /// any completed set registers, so "did something" never
        /// reads identical to "did nothing."
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

    /// Relative-load multiplier from the ratio of a set's e1RM to the
    /// lifter's (decayed) best on that exercise: floor at `rampLow`,
    /// full credit at `rampHigh`.
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

        /// Decaying-max reference e1RM per exercise identity, with
        /// the wall-clock time it was last touched.
        private var references: [String: (e1RM: Double, at: Date)] = [:]

        init(parameters: Parameters = .default) {
            self.parameters = parameters
        }

        /// Hard-set-equivalent credit per involved muscle for one
        /// exercise's completed sets, judged against — then updating —
        /// the trailing reference. `date` is the owning session's
        /// clock.
        mutating func credit(for exercise: Exercise, at date: Date) -> [Muscle: Double] {
            let weights = exercise.muscleInvolvement.weights
            guard !weights.isEmpty else { return [:] }

            var total = 0.0
            for set in exercise.orderedSets where set.isCompleted {
                total += hardSetEquivalent(for: set, mode: exercise.trackingMode, key: exercise.historyKey, at: date)
            }
            guard total > 0 else { return [:] }
            return weights.mapValues { total * $0 }
        }

        // MARK: Per-set pricing

        private mutating func hardSetEquivalent(
            for set: WorkoutSet,
            mode: TrackingMode,
            key: String,
            at date: Date
        ) -> Double {
            let credit: Double
            switch mode {
            case .duration:
                // Holds carry no RIR and e1RM is a rep construct —
                // only the length factor applies.
                credit = SetStimulus.holdFactor(duration: set.duration, parameters: parameters)
            case .reps:
                credit = SetStimulus.effortFactor(rir: set.repsInReserve, logged: set.rirLogged, parameters: parameters)
                    * SetStimulus.repFactor(reps: set.reps, parameters: parameters)
                    * loadFactorUpdatingReference(weight: set.weight, reps: set.reps, key: key, at: date)
            }
            return max(parameters.stimulusFloor, credit)
        }

        /// Judge a set against the exercise's decayed reference, then
        /// fold the set into it — in that order, so a PR set earns
        /// full credit and only raises the bar for what follows.
        private mutating func loadFactorUpdatingReference(
            weight: Double,
            reps: Int,
            key: String,
            at date: Date
        ) -> Double {
            let e1RM = SetStimulus.estimatedOneRepMax(weight: weight, reps: reps)
            // Bodyweight / unloaded sets carry no load signal.
            guard e1RM > 0 else { return 1 }

            guard let existing = references[key] else {
                // First-ever instance: neutral, and it seeds the bar.
                references[key] = (e1RM, date)
                return 1
            }

            let dtDays = max(0, date.timeIntervalSince(existing.at)) / 86_400
            let decayed = existing.e1RM * exp(-dtDays / parameters.referenceTau)
            let factor: Double
            if decayed > 0 {
                factor = SetStimulus.loadFactor(e1RMRatio: e1RM / decayed, parameters: parameters)
            } else {
                factor = 1
            }
            references[key] = (max(e1RM, decayed), date)
            return factor
        }
    }
}
