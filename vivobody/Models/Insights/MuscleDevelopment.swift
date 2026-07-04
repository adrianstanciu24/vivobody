//
//  MuscleDevelopment.swift
//  vivobody
//
//  The per-muscle development model that colours the 3D body. It
//  answers "how DEVELOPED is each muscle?" — the thing a real body
//  shows over months, not the pump from one session.
//
//  The model is one well-understood primitive: a FREQUENCY-INVARIANT
//  estimate of recent weekly training volume, normalised against the
//  muscle's productive weekly set range. It shares its work currency
//  with `MuscleVolume` (one completed set credits each involved muscle
//  by its graded involvement weight — see
//  `Exercise.effectiveSetsByMuscle`), so the body, the volume bars,
//  and the neglect list agree by construction.
//
//    • Each muscle carries `weeklyVolume` W — a smoothed estimate of
//      its effective sets per 7 days, kept as a constant-rate leaky
//      integrator:
//          on a session of s effective sets:  W += s · (7 / τ)
//          over an interval of Δt days:        W *= exp(−Δt / τ)
//      Under any training cadence the steady state depends only on the
//      AVERAGE weekly rate, not on how the volume is chunked into
//      sessions: 20 sets once a week and 10 sets twice a week converge
//      to (essentially) the same W. The residual spread across
//      frequencies is ~3%, versus the ~67% of the old grace-gated
//      accumulator that rewarded frequency for its own sake.
//    • Decay is a plain exponential with time-constant τ (≈ 65 d, a
//      ~45-day half-life). It is exact and order-independent — the
//      semigroup exp(−(a+b)/τ) = exp(−a/τ)·exp(−b/τ) — so the model is
//      independent of how finely time is sliced, and it holds most of
//      a muscle's colour through a week of neglect, then fades.
//    • Development = min(1, (W / V_opt)^γ), where `V_opt` is the
//      muscle's `VolumeLandmark.optimalHigh` (the top of its
//      productive weekly band). Train at the top of the band and the
//      muscle converges to full vivid orange in months; train at half
//      the band and it plateaus around √½ of the way there. γ < 1
//      keeps early sessions visibly rewarded while vivid still takes
//      months.
//
//  The one-sentence read: colour = your estimated recent weekly
//  effective sets, versus your productive target.
//
//  One channel comes out, ready for the body-model colour map (see
//  `MuscleColor` / `BodyModelScene`):
//    • adaptation ∈ [0,1] — development (drives the tint ramp)
//
//  Known limitations (accepted — see specs/muscle-model-fixes.md):
//    • Load/progression blindness. A 5 lb set counts like a 50 lb set
//      (reps and RIR likewise); the body reads training consistency
//      and balance, while per-lift load progression has its own
//      surfaces (`ExerciseProgress`, strength trajectory).
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
    /// Days are the time unit throughout; work is in effective sets.
    struct Parameters {
        /// Concavity of the weekly-volume → development map. < 1
        /// rewards early sessions visibly (newbie gains) while keeping
        /// full vivid orange a months-long arc.
        var developmentGamma: Double = 0.5

        /// Relaxation time-constant (days) of the weekly-volume
        /// estimate. Governs how fast development tracks a change in
        /// training volume and how gently it fades on a layoff.
        /// ≈ 65 d is a ~45-day half-life (τ = halfLife / ln 2).
        var tau: Double = 65.0

        static let `default` = Parameters()
    }

    // MARK: - Per-muscle latent state

    /// The hidden state evolved per muscle. Not colour — colour is
    /// derived from this (see `State.channels`).
    struct Fiber {
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
    nonisolated struct Channels: Equatable {
        var adaptation: Double   // 0...1  → development tint ramp

        init(adaptation: Double) {
            self.adaptation = adaptation
        }
    }

    // MARK: - Full model state

    /// The evolving state of every trained muscle plus the clock of
    /// the last advance. Replaying a history produces one of these;
    /// screens compute it ONCE per data change and every consumer
    /// derives from the same value.
    struct State {
        var fibers: [Muscle: Fiber] = [:]
        /// Wall-clock time the state was last advanced to.
        var lastUpdate: Date?
        let parameters: Parameters

        init(parameters: Parameters = .default) {
            self.parameters = parameters
        }

        /// Development for a weekly-volume estimate, `0...1`. The
        /// estimate is normalised against the top of the muscle's
        /// productive weekly band, so "consistently optimal" reads as
        /// fully developed.
        private func development(weeklyVolume: Double, for muscle: Muscle) -> Double {
            guard weeklyVolume > 0 else { return 0 }
            let ratio = weeklyVolume / VolumeLandmark.landmark(for: muscle).optimalHigh
            return Swift.min(1, pow(ratio, parameters.developmentGamma))
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
                return Channels(adaptation: 0)
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
    static func simulate(
        from sessions: [WorkoutSession],
        now: Date = Date(),
        parameters: Parameters = .default
    ) -> State {
        var state = State(parameters: parameters)

        let ordered = sessions.sorted {
            ($0.completedAt ?? $0.startedAt) < ($1.completedAt ?? $1.startedAt)
        }

        for session in ordered {
            let date = session.completedAt ?? session.startedAt
            advance(&state, to: date)
            applyStimulus(sessionStimulus(session, parameters: parameters), at: date, to: &state)
        }

        // Fade from the last logged session up to the present moment.
        advance(&state, to: now)
        return state
    }

    /// Development intensities keyed by `BodyModel.scn` node name
    /// (adaptation channel only). Both `_L`/`_R` meshes share a value.
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

    /// Per-muscle growth stimulus (effective sets) for one session:
    /// each exercise's completed sets credited to its muscles by their
    /// graded involvement weight. This is the raw effective-set count
    /// `MuscleVolume` also uses — the weekly-rate scaling happens in
    /// `applyStimulus`, so the two surfaces share one definition of
    /// "a set of work."
    static func sessionStimulus(
        _ session: WorkoutSession,
        parameters: Parameters = .default
    ) -> [Muscle: Double] {
        var stimulus: [Muscle: Double] = [:]
        for exercise in session.exercises {
            for (muscle, sets) in exercise.effectiveSetsByMuscle {
                stimulus[muscle, default: 0] += sets
            }
        }
        return stimulus
    }
}
