//
//  Sounds.swift
//  vivobody
//
//  Non-blocking entry point for Vivobody's interaction sounds. Every public
//  call only queues work on SoundEngine; audio loading, graph construction,
//  session activation, and playback never occupy MainActor or gate a control.
//

import Foundation

nonisolated enum Sounds {
    nonisolated enum Effect: String, CaseIterable {
        case click, commit, alert
        case setCompletion = "set-completion"
        case personalRecord = "personal-record"
        case timerExpired = "timer-expired"
        case crescendo, breath, swell, finale

        var resourceName: String {
            "sfx-\(rawValue)"
        }

        /// Recordings play verbatim through dedicated players; the rest use
        /// the synthesized round-robin voice pool.
        var isRecorded: Bool {
            switch self {
            case .click, .commit, .alert, .setCompletion, .personalRecord,
                 .timerExpired, .finale:
                true
            default:
                false
            }
        }
    }

    private static let engine = SoundEngine()

    /// Reflects the independent Me-tab Sounds toggle. Reading UserDefaults is
    /// cheap and avoids scheduling work when the user has disabled feedback.
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.soundsEnabled) as? Bool
            ?? SettingsDefaults.soundsEnabled
    }

    /// Starts preparation without making the caller wait. Safe to repeat on
    /// launch, foreground transitions, and feedback-heavy screen entry.
    static func prepare() {
        guard isEnabled else { return }
        let engine = engine
        Task(priority: .utility) {
            await engine.prepare()
        }
    }

    /// The app's one ordinary button voice.
    static func playButton() {
        play(.click)
    }

    /// Queues an effect if the engine is ready. A cold or recovering engine
    /// drops the sound and prepares for the next interaction instead of ever
    /// delaying the current one.
    static func play(_ effect: Effect, pitch: Double = 0, humanize: Bool = true) {
        guard isEnabled else { return }
        let engine = engine
        Task(priority: .userInitiated) {
            await engine.playIfReady(effect, pitch: pitch, humanize: humanize)
        }
    }

    /// Queues one scroll detent for one crossed value boundary.
    static func playScrubDetent(deep: Bool) {
        guard isEnabled else { return }
        let engine = engine
        Task(priority: .userInitiated) {
            await engine.playScrubDetentIfReady(deep: deep)
        }
    }
}
