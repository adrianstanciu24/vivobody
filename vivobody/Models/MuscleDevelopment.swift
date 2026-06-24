//
//  MuscleDevelopment.swift
//  vivobody
//
//  The per-muscle development model that colours the 3D body. It
//  answers "how DEVELOPED is each muscle, and is it still growing?" —
//  the thing a real body shows over months, not the pump from one
//  session.
//
//  The model is one well-understood primitive: a LEAKY INTEGRATOR of
//  effective sets, normalised against the muscle's weekly volume
//  landmark. It shares its work currency with `MuscleVolume` (one
//  completed set credits each involved muscle by its graded
//  involvement weight — see `Exercise.effectiveSetsByMuscle`), so the
//  body, the volume bars, and the neglect list agree by construction.
//
//    • Each session adds its effective sets to a per-muscle
//      accumulator `V`.
//    • `V` decays with the GRACE-GATED exponential the model has
//      always used: the instantaneous rate β(age) ramps from ~0 up to
//      β₀ via a sigmoid centred at `graceDays` (≈ 7), so a muscle
//      holds its colour for about a week of neglect, then fades. The
//      decay over an interval is integrated in CLOSED FORM
//      (∫ sigmoid = softplus), making it exact and order-independent.
//    • Development = (V / V_ref)^γ, clamped to 1, where `V_ref` is
//      the steady state `V` reaches under weekly training at the TOP
//      of the muscle's productive band (`VolumeLandmark.optimalHigh`).
//      Train at the top of the band consistently and the muscle
//      converges to full vivid orange; train at half the band and it
//      plateaus at √½ of the way there. γ < 1 keeps early sessions
//      visibly rewarded while vivid still takes months.
//
//  The one-sentence read: colour = how consistently you've kept this
//  muscle near its productive weekly set range.
//
//  Three channels come out, ready for the body-model colour map (see
//  `MuscleColor` / `BodyModelScene`):
//    • adaptation ∈ [0,1] — development (drives the tint ramp)
//    • momentum   ∈ [−1,1] — growth trend, read as the gap between
//                            the fast accumulator and a slow tracker
//                            of it (the fitness-minus-fatigue / MACD
//                            trick): positive while building,
//                            negative during a layoff.
//    • fatigue    ∈ [0,1] — acute "just trained", a saturating bump
//                            in session sets that halves every ~2 days
//
//  Deliberately NOT modelled (see specs/simplify-muscle-model.md):
//  load progression. A 5 lb set counts like a 50 lb set — the body
//  reads training consistency and balance; per-lift load progression
//  has its own surfaces (`ExerciseProgress`, strength trajectory).
//
//  The model is a PURE value type driven entirely by injected dates
//  (`session.completedAt`/`startedAt` and `now`), so its time-based
//  behaviour is fully reproducible in tests without a simulator —
//  fast-forward weeks by passing dates (see `MuscleDevelopmentTests`).
//

import CoreGraphics
import Foundation

enum MuscleDevelopment {

    // MARK: - Tunable parameters

    /// Every rate and time-constant in one struct so the model can be
    /// calibrated (and swept in tests) without touching the math.
    /// Days are the time unit throughout; work is in effective sets.
    struct Parameters {
        // — Development —
        /// Concavity of the volume → development map. < 1 rewards
        /// early sessions visibly (newbie gains) while keeping full
        /// vivid orange a months-long arc.
        var developmentGamma: Double = 0.5

        // — Volume decay (detraining) —
        /// Asymptotic decay rate (per day) of the accumulator once
        /// well past the grace window. ln(2)/45 ⇒ ~45-day half-life
        /// of the underlying volume (the visible colour fades gentler
        /// still, since γ square-roots the surviving fraction).
        var decayRate: Double = 0.693 / 45.0
        /// Centre of the decay ramp: days of neglect before fade
        /// really starts. This is the "holds for about a week" knob.
        var graceDays: Double = 7.0
        /// Width (days) of the sigmoid transition into decay.
        var graceWidth: Double = 3.0

        // — Slow tracker (momentum) —
        /// The slow accumulator decays gentler than the fast one, so
        /// during a layoff V drops beneath V_slow and momentum goes
        /// negative.
        var slowDecayRate: Double = 0.693 / 120.0
        var slowGraceDays: Double = 14.0
        var slowGraceWidth: Double = 5.0
        /// Per-session pull of V_slow toward V. Smaller ⇒ V_slow lags
        /// further behind during growth ⇒ stronger positive momentum.
        var slowFollowRate: Double = 0.25
        /// Development-gap that maps to full-scale momentum (±1).
        var momentumReference: Double = 0.05

        // — Fatigue (acute "just trained") —
        /// Half-life (days) of the post-session bump. ~2 days ⇒ gone
        /// within a week.
        var fatigueHalfLifeDays: Double = 2.0
        /// Session effective-sets that yield a near-full fatigue bump.
        /// The bump saturates as 1 − e^(−sets/scale).
        var fatigueSetScale: Double = 4.0

        static let `default` = Parameters()
    }

    // MARK: - Per-muscle latent state

    /// The hidden state evolved per muscle. Not colour — colour is
    /// derived from this (see `State.channels`).
    struct Fiber {
        /// Decayed accumulator of effective sets. The main colour
        /// driver, read through the landmark-normalised map.
        var volume: Double = 0
        /// Slow tracker of `volume`; its lag behind `volume` is the
        /// growth momentum.
        var volumeSlow: Double = 0
        /// Acute fatigue / pump, `0...1`. Fast-decaying.
        var fatigue: Double = 0
        /// When this muscle last received stimulus. Anchors the
        /// grace-gated decay age.
        var lastStimulated: Date?
    }

    // MARK: - Output channels

    /// The render-ready channels for one muscle.
    struct Channels: Equatable {
        var adaptation: Double   // 0...1  → development tint ramp
        var momentum: Double     // -1...1 → growth trend
        var fatigue: Double      // 0...1  → acute "just trained"

        init(adaptation: Double, momentum: Double, fatigue: Double) {
            self.adaptation = adaptation
            self.momentum = momentum
            self.fatigue = fatigue
        }
    }

    // MARK: - Full model state

    /// The evolving state of every trained muscle plus the clock of
    /// the last advance. Replaying a history produces one of these;
    /// screens compute it ONCE per data change and every consumer
    /// (body model, readiness, momentum, forecast) derives
    /// from the same value.
    struct State {
        var fibers: [Muscle: Fiber] = [:]
        /// Wall-clock time the state was last advanced to.
        var lastUpdate: Date?
        let parameters: Parameters

        init(parameters: Parameters = .default) {
            self.parameters = parameters
        }

        /// The steady state `volume` reaches under weekly training at
        /// the top of the muscle's productive band — the denominator
        /// that makes "consistently optimal" read as fully developed.
        /// Derived from the decay knobs and the landmark table; no
        /// constant of its own.
        func referenceVolume(for muscle: Muscle) -> Double {
            let weeklySurvival = MuscleDevelopment.decayFactor(
                ageStart: 0, ageEnd: 7,
                rate: parameters.decayRate,
                graceDays: parameters.graceDays, width: parameters.graceWidth
            )
            return VolumeLandmark.landmark(for: muscle).optimalHigh
                / Swift.max(1e-9, 1 - weeklySurvival)
        }

        /// Development for an accumulator value, `0...1`.
        private func development(volume: Double, for muscle: Muscle) -> Double {
            guard volume > 0 else { return 0 }
            let ratio = volume / referenceVolume(for: muscle)
            return Swift.min(1, pow(ratio, parameters.developmentGamma))
        }

        /// Development (adaptation) per muscle, `0...1`.
        func adaptation(_ muscle: Muscle) -> Double {
            guard let f = fibers[muscle] else { return 0 }
            return development(volume: f.volume, for: muscle)
        }

        /// Development per muscle, `0...1`. Omits never-trained (and
        /// fully-faded) muscles.
        var intensities: [Muscle: Double] {
            var result: [Muscle: Double] = [:]
            for (muscle, fiber) in fibers {
                let a = development(volume: fiber.volume, for: muscle)
                if a > 0 { result[muscle] = a }
            }
            return result
        }

        /// Growth momentum per muscle, normalised to `-1...1`: the
        /// development gap between the fast accumulator and its slow
        /// tracker.
        func momentum(_ muscle: Muscle) -> Double {
            guard let f = fibers[muscle] else { return 0 }
            let raw = development(volume: f.volume, for: muscle)
                - development(volume: f.volumeSlow, for: muscle)
            return Swift.max(-1, Swift.min(1, raw / parameters.momentumReference))
        }

        /// All channels for one muscle (zeroed if untrained).
        func channels(_ muscle: Muscle) -> Channels {
            guard let f = fibers[muscle] else {
                return Channels(adaptation: 0, momentum: 0, fatigue: 0)
            }
            return Channels(
                adaptation: development(volume: f.volume, for: muscle),
                momentum: momentum(muscle),
                fatigue: Swift.min(1, Swift.max(0, f.fatigue))
            )
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

    /// Advance every fiber forward to `date`, applying grace-gated
    /// decay to the volume accumulator and its slow tracker, plus
    /// exponential decay to fatigue. No-op before the first event.
    static func advance(_ state: inout State, to date: Date) {
        defer { state.lastUpdate = date }
        guard let last = state.lastUpdate else { return }
        let dtDays = max(0, date.timeIntervalSince(last)) / 86_400
        guard dtDays > 0 else { return }

        let p = state.parameters
        let fatigueFactor = pow(0.5, dtDays / p.fatigueHalfLifeDays)

        for (muscle, var fiber) in state.fibers {
            fiber.fatigue *= fatigueFactor

            if let ts = fiber.lastStimulated {
                let ageStart = max(0, last.timeIntervalSince(ts)) / 86_400
                let ageEnd = max(0, date.timeIntervalSince(ts)) / 86_400
                fiber.volume *= decayFactor(
                    ageStart: ageStart, ageEnd: ageEnd,
                    rate: p.decayRate, graceDays: p.graceDays, width: p.graceWidth
                )
                fiber.volumeSlow *= decayFactor(
                    ageStart: ageStart, ageEnd: ageEnd,
                    rate: p.slowDecayRate, graceDays: p.slowGraceDays, width: p.slowGraceWidth
                )
            }
            state.fibers[muscle] = fiber
        }
    }

    /// Multiplicative decay over `[ageStart, ageEnd]` days of neglect,
    /// with rate β(age) = rate · sigmoid((age − graceDays)/width).
    ///
    /// Closed form: ∫ sigmoid((a−g)/w) da = w · softplus((a−g)/w), so
    /// the integrated decay exponent is
    ///     rate · w · [softplus((ageEnd−g)/w) − softplus((ageStart−g)/w)]
    /// and the surviving fraction is e^(−exponent). Exact and additive
    /// across sub-intervals (the decay semigroup property), which is
    /// what makes the model independent of how finely time is sliced.
    static func decayFactor(
        ageStart: Double, ageEnd: Double,
        rate: Double, graceDays: Double, width: Double
    ) -> Double {
        guard ageEnd > ageStart else { return 1 }
        let s0 = softplus((ageStart - graceDays) / width)
        let s1 = softplus((ageEnd - graceDays) / width)
        let exponent = rate * width * (s1 - s0)
        return exp(-exponent)
    }

    /// Numerically-stable softplus, ln(1 + e^z). The antiderivative of
    /// the logistic sigmoid.
    private static func softplus(_ z: Double) -> Double {
        z > 30 ? z : (z < -30 ? 0 : log1p(exp(z)))
    }

    // MARK: - Evolution: stimulus event

    /// Inject one session's per-muscle effective sets at `date`.
    /// Assumes the state has already been advanced to `date`.
    static func applyStimulus(
        _ stimulus: [Muscle: Double],
        at date: Date,
        to state: inout State
    ) {
        let p = state.parameters
        for (muscle, sets) in stimulus where sets > 0 {
            var fiber = state.fibers[muscle] ?? Fiber()

            fiber.volume += sets

            // Slow tracker lags the accumulator ⇒ positive momentum
            // while building; during layoffs it decays slower ⇒
            // negative.
            fiber.volumeSlow += p.slowFollowRate * (fiber.volume - fiber.volumeSlow)

            // Acute bump, saturating in session sets.
            fiber.fatigue = min(1, fiber.fatigue + (1 - exp(-sets / p.fatigueSetScale)))

            fiber.lastStimulated = date
            state.fibers[muscle] = fiber
        }
    }

    // MARK: - Stimulus from a session

    /// Per-muscle growth stimulus (effective sets) for one session:
    /// each exercise's completed sets credited to its muscles by their
    /// graded involvement weight.
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
