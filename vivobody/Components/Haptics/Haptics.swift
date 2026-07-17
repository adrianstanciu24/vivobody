//
//  Haptics.swift
//  vivobody
//
//  The haptics engine. Every component depends on this.
//
//  Two layers:
//    • UIFeedbackGenerator — sub-frame latency atoms (tick, thunk, slam).
//    • CHHapticEngine     — custom patterns (crescendo, breath, swell).
//
//  Sound is opt-in for ordinary atoms and always present only for
//  signature patterns / notifications. Navigation and routine taps
//  stay haptic-only; scrub mechanisms, value-choice selections, and
//  meaningful state changes carry audio. Sound calls sit before the
//  haptics guard so the two Me-tab toggles remain independent.
//

import CoreHaptics
import UIKit

@MainActor
enum Haptics {

    // MARK: - Cached generators

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let selectionGen = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - Core Haptics engine

    private static var engine: CHHapticEngine?
    private static var engineNeedsStart = true

    static var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Master mute. Reflects the Me-tab Haptics toggle. Read fresh on
    /// every emission so toggling takes effect immediately without
    /// requiring any view to re-publish state. UserDefaults reads are
    /// in-memory after the first hit, so this is effectively free.
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.hapticsEnabled) as? Bool
            ?? SettingsDefaults.hapticsEnabled
    }

    // MARK: - Lifecycle

    /// Call at app launch and on every foreground transition.
    static func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        selectionGen.prepare()
        notification.prepare()
        startEngineIfNeeded()
        Sounds.prepare()
    }

    private static func startEngineIfNeeded() {
        guard supportsHaptics else { return }

        if engine == nil {
            do {
                let e = try CHHapticEngine()
                // Engine can stop on backgrounding, AirPlay route changes, etc.
                // Re-flag for start; don't auto-restart here to avoid loops.
                e.stoppedHandler = { _ in
                    Task { @MainActor in engineNeedsStart = true }
                }
                // System reset (e.g. media services reset) requires fresh start.
                e.resetHandler = {
                    Task { @MainActor in
                        engineNeedsStart = true
                        startEngineIfNeeded()
                    }
                }
                engine = e
            } catch {
                engine = nil
                return
            }
        }

        guard engineNeedsStart, let engine else { return }
        do {
            try engine.start()
            engineNeedsStart = false
        } catch {
            // Will retry on next pattern play.
        }
    }

    // MARK: - Atoms

    /// Which voice a tick speaks in. `.standard` is the light
    /// encoder blip (reps, sets, durations); `.deep` is an octave
    /// lower with more body, reserved for load — a heavy thing
    /// moving should sound like one. The haptic is identical.
    enum TickTone {
        case standard
        case deep
    }

    /// Light tick — scrubber increments, hover transitions.
    ///
    /// `pitch` (-1…1, default 0) shifts the tick's sound up or down
    /// about half an octave. Scrubbers pass their step delta so ticks
    /// rise while the value climbs and fall while it drops, OP-1
    /// encoder style. The haptic itself is pitch-agnostic.
    static func tick(
        pitch: Double = 0,
        tone: TickTone = .standard,
        playsSound: Bool = false
    ) {
        if playsSound {
            Sounds.play(tone == .deep ? .tickDeep : .tick, pitch: pitch)
        }
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.6)
        lightImpact.prepare()
    }

    /// One isolated scroll detent plus the normal precise
    /// haptic. Every crossed value boundary is one complete event.
    static func scrubTick(tone: TickTone = .standard) {
        Sounds.playScrubDetent(deep: tone == .deep)
        guard isEnabled else { return }
        rigidImpact.impactOccurred(intensity: 0.48)
        rigidImpact.prepare()
    }

    /// Medium thunk — the workhorse. Set complete, primary action.
    /// `pitch` (-1…1, default 0) deepens or lightens the sound only;
    /// the haptic is pitch-agnostic.
    static func thunk(pitch: Double = 0, playsSound: Bool = false) {
        if playsSound { Sounds.play(.thunk, pitch: pitch) }
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    /// Heavy slam — PRs, final set. Use sparingly so it stays meaningful.
    static func slam() {
        Sounds.play(.slam)
        guard isEnabled else { return }
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }

    /// Raised voice for the top-of-range wall. Scrubbers pass this
    /// when the value slams into its MAXIMUM so "can't go higher"
    /// reads differently from "can't go lower" (which keeps the
    /// default 0) — same sound, two heights. One shared constant so
    /// load, reps, and every other scrubber hit the same two notes.
    static let ceilingPitch: Double = 0.5

    /// Rigid tap — hard edges (can't decrement below zero, end of list).
    /// `pitch` (-1…1, default 0) shifts the sound up or down; pass
    /// `ceilingPitch` at a range's top wall. The haptic is
    /// pitch-agnostic.
    static func rigid(pitch: Double = 0, playsSound: Bool = false) {
        if playsSound { Sounds.play(.rigid, pitch: pitch) }
        guard isEnabled else { return }
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }

    /// Soft tap — subtle transitions, ambient confirmation.
    static func soft(playsSound: Bool = false) {
        if playsSound { Sounds.play(.soft) }
        guard isEnabled else { return }
        softImpact.impactOccurred()
        softImpact.prepare()
    }

    /// Selection change — for pickers, segmented controls, wheel rolls.
    /// `pitch` (-1…1, default 0) deepens or lightens the sound only;
    /// the haptic is pitch-agnostic.
    static func selection(pitch: Double = 0, playsSound: Bool = false) {
        if playsSound { Sounds.play(.selection, pitch: pitch) }
        guard isEnabled else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    /// Normalized pitch for an ordered option set: the first option
    /// sits at the bottom of the span, the last at the top, so
    /// stepping across a value-choice segment bar walks up the scale
    /// like flicking a parameter switch. Feed the result to
    /// `selection(pitch:playsSound:)`.
    static func optionPitch(index: Int, count: Int) -> Double {
        guard count > 1 else { return 0 }
        return Double(index) / Double(count - 1) - 0.5
    }

    /// RIR selection — feedback graded by the effort the number
    /// represents. Each value 0…5 speaks its own warm note (higher
    /// notes mean more in the tank) and 0 — to failure — lands as a
    /// heavy thud under the lowest note. The haptic mirrors the
    /// weight: a medium impact at 0, a selection change elsewhere.
    static func rir(_ value: Int) {
        Sounds.playRIR(value)
        guard isEnabled else { return }
        if value == 0 {
            mediumImpact.impactOccurred()
            mediumImpact.prepare()
        } else {
            selectionGen.selectionChanged()
            selectionGen.prepare()
        }
    }

    // MARK: - Notifications

    static func success() {
        Sounds.play(.success)
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    static func warning() {
        Sounds.play(.warning)
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    static func failure() {
        Sounds.play(.failure)
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    // MARK: - Patterns (Core Haptics)

    /// The signature "set complete" feel: three distinct, escalating taps.
    /// Spacing ≥ ~90ms so each is perceived as its own event, not smeared into one.
    /// Sharpness rises alongside intensity, so each tap also feels firmer.
    static func crescendo() {
        Sounds.play(.crescendo)
        guard isEnabled else { return }
        play(events: [
            transient(intensity: 0.40, sharpness: 0.35, at: 0.00),
            transient(intensity: 0.70, sharpness: 0.60, at: 0.10),
            transient(intensity: 1.00, sharpness: 0.90, at: 0.22),
        ])
    }

    /// A gentle two-pulse — rest timer warning ("you're almost up").
    static func breath() {
        Sounds.play(.breath)
        guard isEnabled else { return }
        play(events: [
            transient(intensity: 0.5, sharpness: 0.2, at: 0.00),
            transient(intensity: 0.5, sharpness: 0.2, at: 0.18),
        ])
    }

    /// A rising rumble that ends in a slam — finishing a heavy set.
    /// 350ms continuous swell + a transient peak. Total ≈ 400ms.
    ///
    /// `hapticIntensityControl` is a scalar multiplier on the event's
    /// base intensity, so the base must be > 0 for the curve to do anything.
    static func swell() {
        Sounds.play(.swell)
        guard isEnabled else { return }
        let continuous = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.4),
            ],
            relativeTime: 0.0,
            duration: 0.35
        )
        let intensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.00, value: 0.35),
                .init(relativeTime: 0.20, value: 0.70),
                .init(relativeTime: 0.35, value: 1.00),
            ],
            relativeTime: 0.0
        )
        let sharpnessCurve = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl,
            controlPoints: [
                .init(relativeTime: 0.00, value: 0.2),
                .init(relativeTime: 0.35, value: 0.7),
            ],
            relativeTime: 0.0
        )
        let slam = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.75),
            ],
            relativeTime: 0.38
        )
        playPattern(events: [continuous, slam], curves: [intensityCurve, sharpnessCurve])
    }

    /// The workout-done fanfare — a quick rising run into a double-hit
    /// landing. Reserved for the summary card's Done button, so
    /// finishing a session feels bigger than finishing any set.
    /// Haptic events mirror the sound's run-up and "ba-DUM" timings.
    static func finale() {
        Sounds.play(.finale)
        guard isEnabled else { return }
        play(events: [
            transient(intensity: 0.30, sharpness: 0.40, at: 0.00),
            transient(intensity: 0.40, sharpness: 0.45, at: 0.06),
            transient(intensity: 0.50, sharpness: 0.50, at: 0.12),
            transient(intensity: 0.60, sharpness: 0.55, at: 0.18),
            transient(intensity: 0.75, sharpness: 0.60, at: 0.26),
            transient(intensity: 1.00, sharpness: 0.80, at: 0.34),
        ])
    }

    // MARK: - Pattern helpers

    private static func transient(intensity: Float, sharpness: Float, at time: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private static func play(events: [CHHapticEvent]) {
        playPattern(events: events, curves: [])
    }

    private static func playPattern(events: [CHHapticEvent], curves: [CHHapticParameterCurve]) {
        guard supportsHaptics else {
            mediumImpact.impactOccurred()
            return
        }
        startEngineIfNeeded()
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            mediumImpact.impactOccurred()
        }
    }
}
