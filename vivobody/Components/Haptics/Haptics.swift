//
//  Haptics.swift
//  vivobody
//
//  The haptics engine. Every component depends on this.
//
//  Two layers:
//    • UIFeedbackGenerator — sub-frame latency atoms (tick, thunk, slam).
//    • HapticPatternEngine — actor-owned custom patterns (crescendo, breath,
//      swell) that never delay the user action associated with a tap.
//
//  Every atom carries sound by default, and it is always the same
//  sound: the app's single button click (`Sounds.playButton()`).
//  Which atom a caller picks chooses the *feel* of the tap, not its
//  voice — one click means "a control responded," everywhere.
//
//  Callers pass `playsSound: false` for feedback that isn't a tap:
//  scrub detents and drag thresholds, page swipes, rotation
//  quadrants, async system callbacks. Those would machine-gun the
//  click or fire it with nothing pressed.
//
//  Signature patterns and active notifications keep their own
//  voices. Sound calls sit before the haptics guard so the two
//  Me-tab toggles remain independent.
//

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

    // MARK: - Custom patterns

    private static let patternEngine = HapticPatternEngine()

    /// Master mute. Reflects the Me-tab Haptics toggle. Read fresh on
    /// every emission so toggling takes effect immediately without
    /// requiring any view to re-publish state. UserDefaults reads are
    /// in-memory after the first hit, so this is effectively free.
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.hapticsEnabled) as? Bool
            ?? SettingsDefaults.hapticsEnabled
    }

    // MARK: - Lifecycle

    /// Queue custom haptic and sound engines for preparation. UIKit's
    /// generators are intentionally prepared only after actual feedback,
    /// when Apple says another nearby interaction can benefit.
    static func prepare() {
        let patternEngine = patternEngine
        Task(priority: .utility) {
            await patternEngine.prepare()
        }
        Sounds.prepare()
    }

    // MARK: - Atoms

    /// Which voice a scrub detent speaks in. `.standard` is the light
    /// encoder blip (reps, sets, durations); `.deep` is an octave
    /// lower with more body, reserved for load — a heavy thing
    /// moving should sound like one. The haptic is identical.
    enum TickTone {
        case standard
        case deep
    }

    /// Light tick — stepper increments, hover transitions.
    static func tick(playsSound: Bool = true) {
        if playsSound { Sounds.playButton() }
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
    static func thunk(playsSound: Bool = true) {
        if playsSound { Sounds.playButton() }
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    /// Heavy slam — PRs, final set. Use sparingly so it stays meaningful.
    /// Choreographed moments may suppress the ordinary click when a longer
    /// signature recording is already playing.
    static func slam(playsSound: Bool = true) {
        if playsSound { Sounds.playButton() }
        guard isEnabled else { return }
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }

    /// Rigid tap — hard edges (can't decrement below zero, end of list).
    static func rigid(playsSound: Bool = true) {
        if playsSound { Sounds.playButton() }
        guard isEnabled else { return }
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }

    /// Soft tap — subtle transitions, ambient confirmation. A caller can
    /// retain the soft feel while matching a stronger action's voice.
    static func soft(playsSound: Bool = true, sound: Sounds.Effect = .click) {
        if playsSound { Sounds.play(sound) }
        guard isEnabled else { return }
        softImpact.impactOccurred()
        softImpact.prepare()
    }

    /// Caution — the tap that raises a destructive prompt, like the
    /// active workout's X. Its own voice instead of the ordinary
    /// click, so "this one asks a question" is audible before the
    /// sheet even appears. The feel stays soft: the tap itself
    /// destroys nothing.
    static func caution() {
        Sounds.play(.alert)
        guard isEnabled else { return }
        softImpact.impactOccurred()
        softImpact.prepare()
    }

    /// Selection change — for pickers, segmented controls, wheel rolls.
    static func selection(playsSound: Bool = true) {
        if playsSound { Sounds.playButton() }
        guard isEnabled else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    /// RIR selection — every choice uses the shared recorded click while
    /// the haptic remains graded by effort: a medium impact at 0, to
    /// failure, and a selection change elsewhere.
    static func rir(_ value: Int) {
        Sounds.playButton()
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

    /// Success notification feel with an optional caller-selected voice.
    /// The summary uses haptics alone; the visible rest timer passes its
    /// recorded expiration sound.
    static func success(sound: Sounds.Effect? = nil) {
        if let sound { Sounds.play(sound) }
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    // MARK: - Patterns (Core Haptics)

    /// The signature "set complete" feel: three distinct, escalating taps.
    /// Spacing ≥ ~90ms so each is perceived as its own event, not smeared into one.
    /// Sharpness rises alongside intensity, so each tap also feels firmer.
    ///
    /// `sound` swaps the voice while keeping the escalating taps —
    /// set-completion buttons pass `.setCompletion`.
    static func crescendo(sound: Sounds.Effect = .crescendo) {
        Sounds.play(sound)
        guard isEnabled else { return }
        playPattern(.crescendo)
    }

    /// A gentle two-pulse — rest timer warning ("you're almost up").
    static func breath() {
        Sounds.play(.breath)
        guard isEnabled else { return }
        playPattern(.breath)
    }

    /// A rising rumble that ends in a slam — finishing a heavy set.
    /// 350ms continuous swell + a transient peak. Total ≈ 400ms.
    ///
    /// `hapticIntensityControl` is a scalar multiplier on the event's
    /// base intensity, so the base must be > 0 for the curve to do anything.
    ///
    /// `sound` swaps the voice while keeping the rumble — the last
    /// set of an exercise sounds like every other completed set, and
    /// only feels heavier.
    static func swell(sound: Sounds.Effect = .swell) {
        Sounds.play(sound)
        guard isEnabled else { return }
        playPattern(.swell)
    }

    /// The workout-done finale. Reserved for the summary card's Done
    /// button, so finishing a session feels bigger than finishing any
    /// set. The authored recording accompanies the rising haptic run.
    static func finale() {
        Sounds.play(.finale)
        guard isEnabled else { return }
        playPattern(.finale)
    }

    // MARK: - Pattern helpers

    private static func playPattern(_ pattern: HapticPatternKind) {
        let patternEngine = patternEngine
        Task {
            let didPlay = await patternEngine.playIfReady(pattern)
            guard !didPlay, isEnabled else { return }
            mediumImpact.impactOccurred()
            mediumImpact.prepare()
        }
    }
}
