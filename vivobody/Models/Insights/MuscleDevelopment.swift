//
//  MuscleDevelopment.swift
//  vivobody
//
//  The per-muscle training-attention model that colours the 3D body.
//  It answers "how consistently has this muscle been trained lately?"
//  — a summary of the user's logged behaviour, not a claim about
//  their physiology.
//
//  The model is one well-understood primitive: a FREQUENCY-INVARIANT
//  estimate of recent weekly training volume, normalised against the
//  shared productive weekly set target. It shares its work currency
//  with `MuscleVolume` (each completed set counts 1.0, discounted only
//  by logged RIR, then credited to each primary or secondary muscle by
//  its volume-bearing role; see `SetStimulus`), so the body, the
//  volume bars, and the neglect list agree by construction.
//
//    • Each muscle carries `weeklyVolume` W — a smoothed estimate of
//      its hard sets per 7 days, kept as a constant-rate leaky
//      integrator:
//          on a session of s hard sets:  W += s · (7 / τ)
//          over an interval of Δt days:  W *= exp(−Δt / τ)
//      Under any training cadence the steady state depends only on the
//      AVERAGE weekly rate, not on how the volume is chunked into
//      sessions: 20 sets once a week and 10 sets twice a week converge
//      to (essentially) the same W.
//    • Decay is a plain exponential with time-constant τ (≈ 65 d, a
//      ~45-day half-life). It is exact and order-independent — the
//      semigroup exp(−(a+b)/τ) = exp(−a/τ)·exp(−b/τ) — so the model is
//      independent of how finely time is sliced, and it holds most of
//      a muscle's colour through a week of neglect, then fades.
//    • Intensity = min(1, W / V_opt), where `V_opt` is
//      `VolumeLandmark.default.optimalHigh` — one shared target for
//      every muscle. Linear on purpose: 0.5 means literally "half the
//      productive weekly target", and the `MuscleDevelopmentBand`
//      labels quarter it into Low / Building / Consistent / High.
//
//  The one-sentence read: colour = your estimated recent weekly
//  hard sets, versus the productive target.
//
//  One channel comes out, ready for the body-model colour map (see
//  `MuscleColor` / `BodyModelScene`):
//    • adaptation ∈ [0,1] — development (drives the tint ramp)
//
//  Known limitations (accepted — see specs/muscle-model-fixes.md):
//    • No left/right asymmetry. Development is per bilateral `Muscle`;
//      both `_L`/`_R` meshes share a value and the log can't record
//      side.
//    • Saturation. `adaptation` clamps at 1.0, so the colour can't
//      depict over-target volume; the weekly volume bars' `.high`
//      zone is the surface for excess.
//
//  The model is a PURE value type driven entirely by injected dates
//  (`session.completedAt`/`startedAt` and `now`), so its time-based
//  behaviour is fully reproducible in tests without a simulator —
//  fast-forward weeks by passing dates (see `MuscleDevelopmentTests`).
//

import CoreGraphics
import Foundation

nonisolated enum MuscleDevelopment {

    // MARK: - Tunable parameters

    /// Every rate and time-constant in one struct so the model can be
    /// calibrated (and swept in tests) without touching the math.
    /// Days are the time unit throughout; work is in hard sets.
    struct Parameters: Sendable {
        /// Relaxation time-constant (days) of the weekly-volume
        /// estimate. Governs how fast the colour tracks a change in
        /// training volume and how gently it fades on a layoff.
        /// ≈ 65 d is a ~45-day half-life (τ = halfLife / ln 2).
        var tau: Double = 65.0

        /// The one knob of per-set pricing (the RIR discount) —
        /// see `SetStimulus`.
        var stimulus: SetStimulus.Parameters = .default

        static let `default` = Parameters()
    }

    // MARK: - Per-muscle latent state

    /// The hidden state evolved per muscle. Not colour — colour is
    /// derived from this (see `State.channels`).
    struct Fiber: Sendable {
        /// Frequency-invariant estimate of recent effective sets per
        /// week. The colour driver, read through the landmark-
        /// normalised map.
        var weeklyVolume: Double = 0
    }

    // MARK: - Output channels

    /// The render-ready channels for one muscle. `nonisolated` so the
    /// pure value-type model (and its `Equatable` conformance) is
    /// usable off the main actor — replayed in tests and by
    /// `TrainingSignature` outside any isolation domain.
    typealias Channels = MuscleMapChannels

    // MARK: - Full model state

    /// The evolving state of every trained muscle plus the clock of
    /// the last advance. Replaying a history produces one of these;
    /// screens compute it ONCE per data change and every consumer
    /// derives from the same value.
    struct State: Sendable {
        var fibers: [Muscle: Fiber] = [:]
        /// Wall-clock time the state was last advanced to.
        var lastUpdate: Date?
        let parameters: Parameters

        init(parameters: Parameters = .default) {
            self.parameters = parameters
        }

        /// Intensity for a weekly-volume estimate, `0...1` — the
        /// estimate as a plain fraction of the shared productive
        /// weekly target, so "consistently at target" reads as 1.0.
        private func development(weeklyVolume: Double, for muscle: Muscle) -> Double {
            guard weeklyVolume > 0 else { return 0 }
            return Swift.min(1, weeklyVolume / VolumeLandmark.default.optimalHigh)
        }

        /// Development (adaptation) per muscle, `0...1`.
        func adaptation(_ muscle: Muscle) -> Double {
            guard let f = fibers[muscle] else { return 0 }
            return development(weeklyVolume: f.weeklyVolume, for: muscle)
        }

        /// Development per muscle, `0...1`. Omits never-trained (and
        /// fully-faded) muscles.
        var intensities: [Muscle: Double] {
            var result: [Muscle: Double] = [:]
            for (muscle, fiber) in fibers {
                let a = development(weeklyVolume: fiber.weeklyVolume, for: muscle)
                if a > 0 { result[muscle] = a }
            }
            return result
        }

        /// All channels for one muscle (zeroed if untrained).
        func channels(_ muscle: Muscle) -> Channels {
            guard let f = fibers[muscle] else {
                return .noData
            }
            return Channels(adaptation: development(weeklyVolume: f.weeklyVolume, for: muscle))
        }

        /// All channels keyed by `BodyModel.scn` node name — the input
        /// the body-model materials consume. Both `_L`/`_R` meshes
        /// share a value.
        var nodeChannels: [String: Channels] {
            var result: [String: Channels] = [:]
            for muscle in fibers.keys {
                let ch = channels(muscle)
                for node in muscle.nodeNames { result[node] = ch }
            }
            return result
        }
    }

    // MARK: - Public entry points

    /// Replay a full session history into a `State` as of `now`.
    /// Sessions may arrive in any order; they're sorted by their
    /// completion (or start) time.
    @MainActor
    static func simulate(
        from sessions: [WorkoutSession],
        now: Date = Date(),
        parameters: Parameters = .default,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> State {
        let accumulator = AnalyticsAccumulator.replay(
            AnalyticsSnapshot(sessions: sessions),
            stimulusParameters: parameters.stimulus,
            isCancelled: isCancelled
        )
        return simulate(
            from: accumulator,
            now: now,
            parameters: parameters,
            isCancelled: isCancelled
        )
    }

    /// Replay the already-priced stimulus timeline retained by
    /// SessionAnalytics. No SwiftData relationships or load-reference
    /// tables are traversed again here.
    static func simulate(
        from accumulator: AnalyticsAccumulator,
        now: Date = Date(),
        parameters: Parameters = .default,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> State {
        var state = State(parameters: parameters)

        for session in accumulator.sessions {
            guard !isCancelled() else { return state }
            // A report evaluated at `now` must not learn from a
            // scheduled or accidentally future-dated session.
            guard session.date <= now else { continue }
            advance(&state, to: session.date)
            var stimulus: [Muscle: Double] = [:]
            for exercise in session.exercises {
                guard !isCancelled() else { return state }
                for (muscle, sets) in exercise.byMuscle {
                    guard !isCancelled() else { return state }
                    stimulus[muscle, default: 0] += sets
                }
            }
            guard !isCancelled() else { return state }
            applyStimulus(stimulus, at: session.date, to: &state)
        }

        // Fade from the last logged session up to the present moment.
        guard !isCancelled() else { return state }
        advance(&state, to: now)
        return state
    }

    /// Development intensities keyed by `BodyModel.scn` node name
    /// (adaptation channel only). Both `_L`/`_R` meshes share a value.
    @MainActor
    static func nodeIntensities(
        from sessions: [WorkoutSession],
        now: Date = Date(),
        parameters: Parameters = .default
    ) -> [String: CGFloat] {
        let state = simulate(from: sessions, now: now, parameters: parameters)
        var result: [String: CGFloat] = [:]
        for (muscle, value) in state.intensities {
            let v = CGFloat(value)
            for node in muscle.nodeNames { result[node] = v }
        }
        return result
    }

    /// All channels keyed by `BodyModel.scn` node name. Convenience
    /// over `simulate(...).nodeChannels` for one-shot callers.
    @MainActor
    static func nodeChannels(
        from sessions: [WorkoutSession],
        now: Date = Date(),
        parameters: Parameters = .default
    ) -> [String: Channels] {
        simulate(from: sessions, now: now, parameters: parameters).nodeChannels
    }

    // MARK: - Evolution: time advance (pure decay)

    /// Advance every fiber forward to `date`, relaxing the weekly-
    /// volume estimate toward zero at the constant rate `1/τ`. No-op
    /// before the first event. Exact and order-independent: the
    /// surviving fraction over `[last, date]` is `exp(−Δt/τ)`, and
    /// `exp(−(a+b)/τ) = exp(−a/τ)·exp(−b/τ)`, so advancing in one step
    /// equals advancing through any intermediate stops.
    static func advance(_ state: inout State, to date: Date) {
        defer { state.lastUpdate = date }
        guard let last = state.lastUpdate else { return }
        let dtDays = max(0, date.timeIntervalSince(last)) / 86_400
        guard dtDays > 0 else { return }

        let factor = exp(-dtDays / state.parameters.tau)
        for (muscle, var fiber) in state.fibers {
            fiber.weeklyVolume *= factor
            state.fibers[muscle] = fiber
        }
    }

    // MARK: - Evolution: stimulus event

    /// Inject one session's per-muscle effective sets at `date` as a
    /// weekly-rate increment (`s · 7/τ`), the form that makes the
    /// steady state depend on the average weekly rate rather than the
    /// session cadence. Assumes the state has already been advanced to
    /// `date`.
    static func applyStimulus(
        _ stimulus: [Muscle: Double],
        at date: Date,
        to state: inout State
    ) {
        let scale = 7.0 / state.parameters.tau
        for (muscle, sets) in stimulus where sets > 0 {
            var fiber = state.fibers[muscle] ?? Fiber()
            fiber.weeklyVolume += sets * scale
            state.fibers[muscle] = fiber
        }
    }

    // MARK: - Stimulus from a session

    /// Per-muscle stimulus (hard sets) for one session. This is the
    /// same per-set credit `MuscleVolume` accrues — the weekly-rate
    /// scaling happens in `applyStimulus`, so the two surfaces share
    /// one definition of "a set of work."
    @MainActor
    static func sessionStimulus(
        _ session: WorkoutSession,
        parameters: Parameters = .default
    ) -> [Muscle: Double] {
        var stimulus: [Muscle: Double] = [:]
        for exercise in session.orderedExercises {
            for (muscle, sets) in SetStimulus.credit(
                for: exercise,
                parameters: parameters.stimulus
            ) {
                stimulus[muscle, default: 0] += sets
            }
        }
        return stimulus
    }
}
