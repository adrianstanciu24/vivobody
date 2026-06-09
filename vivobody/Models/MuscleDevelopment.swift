//
//  MuscleDevelopment.swift
//  vivobody
//
//  A per-muscle DYNAMICAL-SYSTEMS model of training adaptation. It
//  answers "how DEVELOPED is each muscle, and is it still growing?" —
//  the thing a real body shows over months, not the pump from one
//  session — and drives the colouring of the 3D body model.
//
//  It is an impulse-response model in the lineage of the Banister
//  fitness–fatigue model, fused with three borrowed ideas:
//
//    1. Logistic / capacitor charging (Verhulst) — adaptation
//       approaches a ceiling and CANNOT be maxed by a single workout:
//           A ← A + (ceiling − A) · (1 − e^(−k·O))
//       The factor (1 − e^(−k·O)) ∈ [0,1) bounds each session's gain
//       no matter how large the stimulus, so colour builds over time.
//       The `ceiling` itself scales with the muscle's accustomed
//       ABSOLUTE load/volume (heavy work → higher ceiling), so a
//       light program plateaus dim and a heavy one plateaus bright.
//
//    2. Rescorla–Wagner prediction error (a.k.a. the repeated-bout
//       effect / habituation) — the body adapts to SURPRISE, not to
//       level. Overload is the stimulus that exceeds what the muscle
//       is accustomed to:
//           O = max(0, x − B),   B ← B + η·(x − B)
//       Repeat the identical session and B catches up to x, so O → 0
//       and growth stalls at a sub-maximal plateau. Progressive
//       overload keeps x ahead of B, so O stays alive and A climbs
//       toward the ceiling. This is the "same reps forever → you stop
//       growing" signal, derived rather than hard-coded.
//
//    3. Weber–Fechner (log perception) — stimulus enters as
//       x = ln(1 + sessionStimulus), so a +5% progression matters the
//       same whether the lift is light or heavy ("progressive overload
//       as a percentage").
//
//  Detraining is a GRACE-GATED exponential decay. The instantaneous
//  decay rate β(age) ramps from ~0 up to β₀ via a sigmoid centred at
//  `graceDays` (≈ 7), so a muscle holds its colour for about a week of
//  neglect, then fades — and fades faster the longer the layoff. The
//  decay over an interval is integrated in CLOSED FORM using the fact
//  that ∫ sigmoid = softplus, which makes it exact and order-
//  independent (advancing t₀→t₂ equals t₀→t₁→t₂).
//
//  Four channels come out, ready for the body-model colour + rim map
//  (see `MuscleColor` / `BodyModelScene`):
//    • adaptation ∈ [0,1] — development (drives lightness/brightness)
//    • momentum   ∈ [−1,1] — growth trend = fast minus slow adaptation
//                            (drives saturation: vivid while growing,
//                            desaturated at a plateau, cool when
//                            losing it). The fast-minus-slow trick
//                            mirrors fitness-minus-fatigue / MACD.
//    • fatigue    ∈ [0,1] — acute "just trained" glow, decays in days
//    • tightness  ∈ [0,1] — functional shortness. Accrues from
//                            contraction-biased loading (most on tonic
//                            muscles), paid down by mobility / full-ROM
//                            work, and only partly eased by rest (it
//                            floors above zero until actively
//                            stretched). Drives a cool strain rim.
//                            Mobility exercises — long ignored — finally
//                            act here: they relieve instead of grow.
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
    /// Days are the time unit throughout.
    struct Parameters {
        // — Growth —
        /// Hard maximum for adaptation. 1.0 keeps the channel in
        /// `0...1`; the *effective* ceiling per muscle is usually
        /// lower (see the ceiling-scaling knobs below).
        var cap: Double = 1.0
        /// Growth gain on overload. Larger ⇒ faster climb per unit of
        /// surprise. Tuned so a single session is always a fraction of
        /// the remaining gap, never the whole thing.
        var growthGain: Double = 0.5
        /// First-exposure overload gap (log units). A never-trained
        /// muscle starts with baseline `x − initialOverload`, granting
        /// a few sessions of "newbie gains" on even a constant load
        /// before B catches up and growth plateaus.
        var initialOverload: Double = 0.6
        /// Rescorla–Wagner baseline learning rate η ∈ (0,1]. How fast
        /// the habituation baseline chases the stimulus. Higher ⇒
        /// plateaus sooner on a fixed program.
        var habituationRate: Double = 0.30

        // — Ceiling scaling (absolute load/volume) —
        //
        // The effective ceiling a muscle can reach scales with the
        // ABSOLUTE work it's accustomed to, so heavy / high-volume
        // training reads as more developed than trivial loads. The
        // habituated log-stimulus `baseline` drives a smoothstep from
        // `ceilingFloor·cap` up to `cap`. Progression still drives the
        // APPROACH to this ceiling (prediction error); the ceiling
        // only sets how high a plateau can be — so "same reps → stop
        // growing" is preserved (you asymptote below a fixed ceiling).
        /// Lowest reachable ceiling, as a fraction of `cap`. Even
        /// featherweight work develops a muscle a little.
        var ceilingFloor: Double = 0.35
        /// Habituated log-stimulus at/below which the ceiling sits at
        /// the floor. ≈ log1p(300) — a very light session.
        var ceilingStimulusLow: Double = 5.7
        /// Habituated log-stimulus at/above which the ceiling reaches
        /// `cap`. ≈ log1p(4900) — heavy / high-volume work.
        var ceilingStimulusHigh: Double = 8.5

        // — Adaptation decay (detraining) —
        /// Asymptotic decay rate (per day) once well past the grace
        /// window. ln(2)/45 ⇒ ~45-day half-life of deep fade.
        var decayRate: Double = 0.693 / 45.0
        /// Centre of the decay ramp: days of neglect before fade
        /// really starts. This is the "holds for about a week" knob.
        var graceDays: Double = 7.0
        /// Width (days) of the sigmoid transition into decay.
        var graceWidth: Double = 3.0

        // — Slow adaptation (for momentum) —
        /// The slow tracker decays gentler than adaptation, so during
        /// a layoff A drops beneath A_slow and momentum goes negative.
        var slowDecayRate: Double = 0.693 / 120.0
        var slowGraceDays: Double = 14.0
        var slowGraceWidth: Double = 5.0
        /// Per-session pull of A_slow toward A. Smaller ⇒ A_slow lags
        /// further behind during growth ⇒ stronger positive momentum.
        var slowFollowRate: Double = 0.25
        /// Scale that maps raw momentum (A − A_slow) into `-1...1`.
        var momentumReference: Double = 0.15

        // — Fatigue (acute glow) —
        /// Half-life (days) of the post-session bloom. ~2 days ⇒ gone
        /// within a week.
        var fatigueHalfLifeDays: Double = 2.0
        /// Session stimulus that yields a near-full fatigue bump. The
        /// glow saturates as 1 − e^(−stimulus/scale).
        var fatigueScale: Double = 3000.0

        // — Tightness (functional shortness) —
        /// Growth gain on tightening. Multiplies the per-muscle
        /// log-loading × ROM-bias × susceptibility increment, so a
        /// hard contraction-biased session on a tonic muscle adds a
        /// noticeable-but-bounded amount of tightness.
        var tightenGain: Double = 0.022
        /// Relief gain on a lengthening (mobility / full-ROM) dose.
        /// Tightness is paid down multiplicatively: T ← T·e^(−relief·dose),
        /// so each ~30s stretch (dose ≈ 1) per involved muscle removes
        /// a meaningful slice.
        var mobilityRelief: Double = 0.55
        /// Fraction of a full-ROM strength set's movement that also
        /// counts as a (mild) lengthening dose — loaded stretching at
        /// the bottom of a deep squat / RDL keeps the muscle supple.
        var fullRomReliefFraction: Double = 0.12
        /// Asymptotic passive-relief rate (per day) once past the
        /// grace window — slow, so tightness lingers for weeks without
        /// active mobility. ln(2)/30 ⇒ ~30-day half-life of the part
        /// that rest can reach.
        var tightnessDecayRate: Double = 0.693 / 30.0
        /// Days of neglect before passive easing really starts.
        var tightnessGraceDays: Double = 3.0
        /// Width (days) of the passive-easing sigmoid.
        var tightnessGraceWidth: Double = 3.0
        /// Floor passive rest eases toward, as a fraction of the
        /// tightness at the layoff's start: rest alone never fully
        /// resolves adaptive shortening — only active lengthening does.
        var tightnessRestFloor: Double = 0.45
        /// Seconds of lengthening credited to one rep of a dynamic
        /// mobility / full-ROM movement, so rep-counted and timed work
        /// share the same dose unit (`secondsPerRepEquivalent` per
        /// dose). ~3s ⇒ 10 reps ≈ one 30s hold.
        var mobilityRepSeconds: Double = 3.0
        /// How strongly an underdeveloped posture antagonist amplifies
        /// a muscle's tightening (crossed-syndrome): tightening is
        /// scaled by up to `1 + posturalCouplingGain` when the agonist
        /// fully out-develops its opposite. 0 disables the coupling.
        var posturalCouplingGain: Double = 0.6

        // — Effort —
        /// One timed-hold second is worth this fraction of a rep.
        var secondsPerRepEquivalent: Double = 30.0
        /// Effort discount per step of reps-in-reserve (0…5).
        var effortPerReserveStep: Double = 0.06

        static let `default` = Parameters()
    }

    // MARK: - Per-muscle latent state

    /// The hidden state evolved per muscle. Not colour — colour is
    /// derived from this (see `channels`).
    struct Fiber {
        /// Development level, `0...cap`. The main colour driver.
        var adaptation: Double = 0
        /// Slow tracker of `adaptation`; its lag behind `adaptation`
        /// is the growth momentum.
        var adaptationSlow: Double = 0
        /// Habituated stimulus (log units) — what the muscle is used
        /// to. `nil` until first trained.
        var baseline: Double?
        /// Acute fatigue / pump, `0...1`. Fast-decaying.
        var fatigue: Double = 0
        /// Functional tightness, `0...1`. Accrues from contraction-
        /// biased loading, is paid down by mobility / full-ROM work,
        /// and eases only partway with passive rest (it floors above
        /// zero until actively stretched).
        var tightness: Double = 0
        /// When this muscle last received stimulus. Anchors the
        /// grace-gated decay age.
        var lastStimulated: Date?
    }

    // MARK: - Output channels

    /// The render-ready channels for one muscle.
    struct Channels: Equatable {
        var adaptation: Double   // 0...1  → lightness / development
        var momentum: Double     // -1...1 → saturation (growth trend)
        var fatigue: Double      // 0...1  → transient warm bloom
        var tightness: Double    // 0...1  → cool strain rim

        init(adaptation: Double, momentum: Double, fatigue: Double, tightness: Double = 0) {
            self.adaptation = adaptation
            self.momentum = momentum
            self.fatigue = fatigue
            self.tightness = tightness
        }
    }

    // MARK: - Full model state

    /// The evolving state of every trained muscle plus the clock of
    /// the last advance. Replaying a history produces one of these.
    struct State {
        var fibers: [Muscle: Fiber] = [:]
        /// Wall-clock time the state was last advanced to.
        var lastUpdate: Date?
        let parameters: Parameters

        init(parameters: Parameters = .default) {
            self.parameters = parameters
        }

        /// Development (adaptation) per muscle, `0...1`. Omits
        /// never-trained muscles.
        var intensities: [Muscle: Double] {
            fibers.compactMapValues { $0.adaptation > 0 ? min(1, $0.adaptation) : nil }
        }

        /// Growth momentum per muscle, normalised to `-1...1`.
        func momentum(_ muscle: Muscle) -> Double {
            guard let f = fibers[muscle] else { return 0 }
            let raw = f.adaptation - f.adaptationSlow
            return max(-1, min(1, raw / parameters.momentumReference))
        }

        /// All channels for one muscle (zeroed if untrained).
        func channels(_ muscle: Muscle) -> Channels {
            guard let f = fibers[muscle] else {
                return Channels(adaptation: 0, momentum: 0, fatigue: 0, tightness: 0)
            }
            let raw = f.adaptation - f.adaptationSlow
            return Channels(
                adaptation: min(1, max(0, f.adaptation)),
                momentum: max(-1, min(1, raw / parameters.momentumReference)),
                fatigue: min(1, max(0, f.fatigue)),
                tightness: min(1, max(0, f.tightness))
            )
        }
    }

    // MARK: - Public entry points

    /// Replay a full session history into a `State` as of `now`.
    /// Sessions may arrive in any order; they're sorted by their
    /// completion (or start) time. `bodyweight` (lb) scales unloaded
    /// movements via `ExerciseLoad`.
    static func simulate(
        from sessions: [WorkoutSession],
        bodyweight: Double = ExerciseLoad.defaultBodyweight,
        now: Date = Date(),
        parameters: Parameters = .default
    ) -> State {
        let bw = bodyweight > 0 ? bodyweight : ExerciseLoad.defaultBodyweight
        var state = State(parameters: parameters)

        let ordered = sessions.sorted {
            ($0.completedAt ?? $0.startedAt) < ($1.completedAt ?? $1.startedAt)
        }

        for session in ordered {
            let date = session.completedAt ?? session.startedAt
            advance(&state, to: date)
            applyImpulse(sessionImpulse(session, bodyweight: bw, parameters: parameters), at: date, to: &state)
        }

        // Fade from the last logged session up to the present moment.
        advance(&state, to: now)
        return state
    }

    /// Development intensities keyed by `BodyModel.scn` node name
    /// (adaptation channel only). Both `_L`/`_R` meshes share a value.
    static func nodeIntensities(
        from sessions: [WorkoutSession],
        bodyweight: Double = ExerciseLoad.defaultBodyweight,
        now: Date = Date(),
        parameters: Parameters = .default
    ) -> [String: CGFloat] {
        let state = simulate(from: sessions, bodyweight: bodyweight, now: now, parameters: parameters)
        var result: [String: CGFloat] = [:]
        for (muscle, value) in state.intensities {
            let v = CGFloat(value)
            for node in muscle.nodeNames { result[node] = v }
        }
        return result
    }

    /// All three channels keyed by `BodyModel.scn` node name — the
    /// input a 2-channel + bloom material map would consume.
    static func nodeChannels(
        from sessions: [WorkoutSession],
        bodyweight: Double = ExerciseLoad.defaultBodyweight,
        now: Date = Date(),
        parameters: Parameters = .default
    ) -> [String: Channels] {
        let state = simulate(from: sessions, bodyweight: bodyweight, now: now, parameters: parameters)
        var result: [String: Channels] = [:]
        for muscle in state.fibers.keys {
            let ch = state.channels(muscle)
            for node in muscle.nodeNames { result[node] = ch }
        }
        return result
    }

    // MARK: - Evolution: time advance (pure decay)

    /// Advance every fiber forward to `date`, applying grace-gated
    /// decay to adaptation and its slow tracker, and exponential decay
    /// to fatigue. No-op before the first event.
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
                fiber.adaptation *= decayFactor(
                    ageStart: ageStart, ageEnd: ageEnd,
                    rate: p.decayRate, graceDays: p.graceDays, width: p.graceWidth
                )
                fiber.adaptationSlow *= decayFactor(
                    ageStart: ageStart, ageEnd: ageEnd,
                    rate: p.slowDecayRate, graceDays: p.slowGraceDays, width: p.slowGraceWidth
                )

                // Tightness eases only partway with passive rest: it
                // relaxes toward a floor (a fraction of where the
                // layoff started), never to zero — only active
                // lengthening fully resolves it.
                if fiber.tightness > 0 {
                    let factor = decayFactor(
                        ageStart: ageStart, ageEnd: ageEnd,
                        rate: p.tightnessDecayRate,
                        graceDays: p.tightnessGraceDays, width: p.tightnessGraceWidth
                    )
                    let floor = p.tightnessRestFloor * fiber.tightness
                    fiber.tightness = floor + (fiber.tightness - floor) * factor
                }
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

    /// The effective ceiling a muscle can develop toward, scaled by
    /// its habituated absolute log-stimulus `baseline`: a smoothstep
    /// from `ceilingFloor·cap` (trivial loads) up to `cap` (heavy /
    /// high-volume work).
    private static func ceiling(forBaseline baseline: Double, _ p: Parameters) -> Double {
        let span = max(1e-9, p.ceilingStimulusHigh - p.ceilingStimulusLow)
        let s = smoothstep((baseline - p.ceilingStimulusLow) / span)
        return p.cap * (p.ceilingFloor + (1 - p.ceilingFloor) * s)
    }

    /// Hermite smoothstep clamped to `0...1`.
    private static func smoothstep(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        return t * t * (3 - 2 * t)
    }

    // MARK: - Evolution: stimulus event

    /// One session decomposed into the three impulses it delivers,
    /// pre-credited per muscle. `loadStimulus` is the tonnage that
    /// drives growth + fatigue (loading work only); `tightenLoad` is
    /// the ROM-biased loading that tightens; `lengthenDose` is the
    /// load-independent lengthening (mobility + a full-ROM credit)
    /// that relieves tightness.
    struct Impulse {
        var loadStimulus: [Muscle: Double] = [:]
        var tightenLoad: [Muscle: Double] = [:]
        var lengthenDose: [Muscle: Double] = [:]
    }

    /// Apply one session's full impulse at `date`: growth + fatigue
    /// from loading, then tightening, then lengthening relief — in
    /// that order, so a full-ROM lift's own relief can offset the
    /// tightness it just added. Assumes the state has been advanced to
    /// `date`.
    static func applyImpulse(_ impulse: Impulse, at date: Date, to state: inout State) {
        applyStimulus(impulse.loadStimulus, at: date, to: &state)

        let p = state.parameters

        // Tightening: contraction-biased loading, in log units (so a
        // huge session can't spike it), scaled by the muscle's
        // postural susceptibility and amplified when its posture
        // antagonist has been neglected.
        for (muscle, load) in impulse.tightenLoad where load > 0 {
            var fiber = state.fibers[muscle] ?? Fiber()
            let posture = posturalAmplifier(for: muscle, in: state, p)
            let increment = p.tightenGain * log1p(load) * muscle.tightnessSusceptibility * posture
            fiber.tightness = min(1, fiber.tightness + increment)
            if fiber.lastStimulated == nil { fiber.lastStimulated = date }
            state.fibers[muscle] = fiber
        }

        // Relief: mobility / full-ROM lengthening pays the debt down
        // multiplicatively. A muscle with no accrued tightness has
        // nothing to relieve, so stretching an untrained muscle is a
        // no-op (no fiber created).
        for (muscle, dose) in impulse.lengthenDose where dose > 0 {
            guard var fiber = state.fibers[muscle], fiber.tightness > 0 else { continue }
            fiber.tightness *= exp(-p.mobilityRelief * dose)
            state.fibers[muscle] = fiber
        }
    }

    /// Crossed-syndrome amplifier for a muscle's tightening: `1` when
    /// balanced (or there is no posture antagonist), rising to
    /// `1 + posturalCouplingGain` as the agonist out-develops its
    /// neglected opposite. Read after growth has been applied, so a
    /// muscle's own development this session counts.
    private static func posturalAmplifier(for muscle: Muscle, in state: State, _ p: Parameters) -> Double {
        guard p.posturalCouplingGain > 0, let antagonist = muscle.tightnessAntagonist else { return 1 }
        let agonist = state.fibers[muscle]?.adaptation ?? 0
        let opposed = state.fibers[antagonist]?.adaptation ?? 0
        let imbalance = max(0, min(1, agonist - opposed))
        return 1 + p.posturalCouplingGain * imbalance
    }

    /// Inject one session's per-muscle growth stimulus at `date`.
    /// Assumes the state has already been advanced to `date`.
    static func applyStimulus(
        _ stimulus: [Muscle: Double],
        at date: Date,
        to state: inout State
    ) {
        let p = state.parameters
        for (muscle, s) in stimulus where s > 0 {
            let x = log1p(s)                       // Weber–Fechner: log stimulus
            var fiber = state.fibers[muscle] ?? Fiber()

            // Prediction error vs. the habituated baseline. A fresh
            // muscle starts `initialOverload` below the stimulus so it
            // enjoys a few sessions of growth before B catches up.
            let baseline = fiber.baseline ?? (x - p.initialOverload)
            let overload = max(0, x - baseline)

            // Rescorla–Wagner: baseline chases the stimulus.
            let updatedBaseline = baseline + p.habituationRate * (x - baseline)
            fiber.baseline = updatedBaseline

            // Capacitor charge toward a ceiling that scales with the
            // muscle's accustomed absolute load — bounded per session
            // regardless of how big the overload is.
            let ceiling = ceiling(forBaseline: updatedBaseline, p)
            let gap = max(0, ceiling - fiber.adaptation)
            fiber.adaptation += gap * (1 - exp(-p.growthGain * overload))

            // Slow tracker lags adaptation ⇒ positive momentum while
            // growing; during layoffs it decays slower ⇒ negative.
            fiber.adaptationSlow += p.slowFollowRate * (fiber.adaptation - fiber.adaptationSlow)

            // Acute bloom, saturating in session magnitude.
            fiber.fatigue = min(1, fiber.fatigue + (1 - exp(-s / p.fatigueScale)))

            fiber.lastStimulated = date
            state.fibers[muscle] = fiber
        }
    }

    // MARK: - Stimulus from a session

    /// Per-muscle growth stimulus for one session: each LOADING
    /// exercise's completed effort credited to its muscles by their
    /// graded involvement weight (`Muscle.Involvement.weights`).
    /// Mobility work is excluded — it lengthens rather than loads.
    /// Effort is scored by tonnage:
    ///   reps     → Σ (load · reps · rirFactor)
    ///   duration → Σ (load · seconds / secondsPerRepEquivalent)
    /// where load = loggedWeight + bodyweightFraction · bodyweight.
    static func sessionStimulus(
        _ session: WorkoutSession,
        bodyweight: Double,
        parameters: Parameters = .default
    ) -> [Muscle: Double] {
        var stim: [Muscle: Double] = [:]
        for exercise in session.exercises where exercise.movementType == .strength {
            let involvement = exercise.muscleInvolvement
            guard !involvement.isEmpty else { continue }

            let effort = completedEffort(for: exercise, bodyweight: bodyweight, parameters: parameters)
            guard effort > 0 else { continue }

            for (muscle, weight) in involvement.weights {
                stim[muscle, default: 0] += effort * weight
            }
        }
        return stim
    }

    /// Decompose one session into its growth / tighten / lengthen
    /// impulses (see `Impulse`). Loading exercises feed growth and a
    /// ROM-biased tightening (plus a small full-ROM relief credit);
    /// mobility exercises feed lengthening relief only.
    static func sessionImpulse(
        _ session: WorkoutSession,
        bodyweight: Double,
        parameters p: Parameters = .default
    ) -> Impulse {
        var impulse = Impulse()
        for exercise in session.exercises {
            let weights = exercise.muscleInvolvement.weights
            guard !weights.isEmpty else { continue }

            switch exercise.movementType {
            case .strength:
                let effort = completedEffort(for: exercise, bodyweight: bodyweight, parameters: p)
                guard effort > 0 else { continue }
                let rom = tighteningBias(for: exercise)
                let lengthen = lengtheningCredit(for: exercise, parameters: p)
                for (muscle, weight) in weights {
                    impulse.loadStimulus[muscle, default: 0] += effort * weight
                    if rom > 0 { impulse.tightenLoad[muscle, default: 0] += effort * weight * rom }
                    if lengthen > 0 { impulse.lengthenDose[muscle, default: 0] += lengthen * weight }
                }
            case .mobility:
                let dose = movementDose(for: exercise, parameters: p)
                guard dose > 0 else { continue }
                for (muscle, weight) in weights {
                    impulse.lengthenDose[muscle, default: 0] += dose * weight
                }
            }
        }
        return impulse
    }

    /// How tightening one loading exercise is (`0...1`), the ROM bias
    /// applied to its loading effort. Timed isometrics hold a muscle
    /// under sustained contraction (worst); isolation / partial-ROM
    /// work is high; full-ROM compounds (hinge / squat / lunge) load
    /// through a long range and tighten least; other compounds sit in
    /// between. Derived from existing classification — no per-exercise
    /// authoring.
    private static func tighteningBias(for exercise: Exercise) -> Double {
        if exercise.trackingMode == .duration { return 1.0 }
        let classification = ExerciseClassification.forExerciseNamed(exercise.name)
        if let pattern = classification?.pattern, isLengthenedPattern(pattern) { return 0.3 }
        if classification?.mechanic == .isolation { return 0.9 }
        return 0.6
    }

    /// A full-ROM rep-counted strength lift also lengthens the muscle
    /// a little (loaded stretching at the bottom of a deep squat /
    /// RDL). Returns a (small) lengthening dose; zero for isometrics
    /// and non-lengthened patterns.
    private static func lengtheningCredit(for exercise: Exercise, parameters p: Parameters) -> Double {
        guard exercise.trackingMode == .reps,
              let pattern = ExerciseClassification.forExerciseNamed(exercise.name)?.pattern,
              isLengthenedPattern(pattern)
        else { return 0 }
        return movementDose(for: exercise, parameters: p) * p.fullRomReliefFraction
    }

    private static func isLengthenedPattern(_ pattern: MovementPattern) -> Bool {
        switch pattern {
        case .hinge, .squat, .lunge: return true
        default:                     return false
        }
    }

    /// Load-independent movement dose in 30-second-equivalent units —
    /// what relief scales with. A stretch's dose is how long it was
    /// held, not how heavy it was, so reps and timed holds share one
    /// unit via `mobilityRepSeconds`.
    private static func movementDose(for exercise: Exercise, parameters p: Parameters) -> Double {
        let completed = exercise.sets.filter(\.isCompleted)
        switch exercise.trackingMode {
        case .reps:
            let reps = completed.reduce(0.0) { $0 + Double($1.reps) }
            return reps * p.mobilityRepSeconds / p.secondsPerRepEquivalent
        case .duration:
            return completed.reduce(0.0) { $0 + $1.duration } / p.secondsPerRepEquivalent
        }
    }

    private static func completedEffort(
        for exercise: Exercise,
        bodyweight: Double,
        parameters p: Parameters
    ) -> Double {
        let completed = exercise.sets.filter(\.isCompleted)
        let bodyweightLoad = ExerciseLoad.bodyweightFraction(forExerciseNamed: exercise.name) * bodyweight

        switch exercise.trackingMode {
        case .reps:
            return completed.reduce(0) {
                $0 + ($1.weight + bodyweightLoad) * Double($1.reps)
                    * effortFactor(repsInReserve: $1.repsInReserve, step: p.effortPerReserveStep)
            }
        case .duration:
            return completed.reduce(0) {
                $0 + ($1.weight + bodyweightLoad) * ($1.duration / p.secondsPerRepEquivalent)
            }
        }
    }

    private static func effortFactor(repsInReserve rir: Int, step: Double) -> Double {
        let clamped = Double(min(max(rir, 0), 5))
        return 1.0 - step * clamped
    }
}
