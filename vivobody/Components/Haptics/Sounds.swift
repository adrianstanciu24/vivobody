//
//  Sounds.swift
//  vivobody
//
//  The audio twin of Haptics. Every haptic atom and pattern has a
//  matching Teenage-Engineering-style synth sound (short sine/square
//  blips, pitch-drop thuds), baked as .caf files in Resources/Sounds
//  by Scripts/generate_sounds.py.
//
//  Playback goes through one AVAudioEngine with a small round-robin
//  pool of voices (player -> varispeed -> mixer), so rapid scrubber
//  ticks overlap instead of cutting each other off. Buffers are
//  decoded once at prepare() and scheduled with near-zero latency,
//  keeping sound and haptic fused into a single perceived event.
//
//  Character details:
//    • Callers can pass a pitch (-1…1, ≈ ±600 cents) — scrubbers map
//      their step delta onto it so ticks rise as the value climbs,
//      like an OP-1 encoder. Varispeed (not time-pitch) does the
//      shifting: sampler-style, zero added latency.
//    • Every emission gets ±20 cents / ±1 dB of jitter so rapid
//      repeats never sound bit-identical (the "machine gun" tell).
//    • Emissions rate-limit at ~28/s per effect; past that, audio
//      smears into noise while haptics stay clean.
//    • When other audio is playing (gym playlist), the mix ducks to
//      ~55% so blips sit under the music instead of competing.
//
//  The session category is .ambient: sounds mix under the user's
//  music without ducking it, and the ring/silent switch mutes them
//  system-wide. A separate Me-tab toggle (SettingsKey.soundsEnabled)
//  gates emission independently of haptics.
//

import AVFoundation

@MainActor
enum Sounds {

    enum Effect: String, CaseIterable {
        case tick, thunk, slam, rigid, soft, selection
        case tickDeep = "tick-deep"
        case success, warning, failure
        case crescendo, breath, swell

        var resourceName: String { "sfx-\(rawValue)" }
    }

    // MARK: - State

    private struct Voice {
        let player: AVAudioPlayerNode
        let varispeed: AVAudioUnitVarispeed
    }

    private static var engine: AVAudioEngine?
    private static var voices: [Voice] = []
    private static var nextVoice = 0
    private static var buffers: [Effect: AVAudioPCMBuffer] = [:]

    /// Enough voices that a fast scrub never steals the tail of the
    /// previous tick; more would just waste mixer channels.
    private static let voiceCount = 4

    /// Minimum spacing between two emissions of the same effect.
    /// Scrub storms above ~28/s read as one continuous buzz anyway.
    private static let minInterval: TimeInterval = 0.035
    private static var lastEmission: [Effect: TimeInterval] = [:]

    /// isOtherAudioPlaying is an audio-session query — cheap, but not
    /// worth re-asking 28 times a second mid-scrub. Cached briefly.
    private static var duckCheckedAt: TimeInterval = 0
    private static var duckedVolume: Float = 1.0

    /// Master mute. Reflects the Me-tab Sounds toggle; read fresh on
    /// every emission (same pattern as Haptics.isEnabled).
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.soundsEnabled) as? Bool
            ?? SettingsDefaults.soundsEnabled
    }

    // MARK: - Lifecycle

    /// Call at app launch and on every foreground transition
    /// (Haptics.prepare() forwards here). Safe to call repeatedly.
    static func prepare() {
        if buffers.isEmpty { loadBuffers() }
        startEngineIfNeeded()
    }

    private static func loadBuffers() {
        for effect in Effect.allCases {
            guard
                let url = Bundle.main.url(
                    forResource: effect.resourceName, withExtension: "caf"
                ),
                let file = try? AVAudioFile(forReading: url),
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                ),
                (try? file.read(into: buffer)) != nil
            else { continue }
            buffers[effect] = buffer
        }
    }

    private static func startEngineIfNeeded() {
        guard !buffers.isEmpty else { return }

        if engine == nil {
            try? AVAudioSession.sharedInstance().setCategory(
                .ambient, options: [.mixWithOthers]
            )

            let e = AVAudioEngine()
            let format = buffers.values.first?.format
            voices = (0..<voiceCount).map { _ in
                Voice(player: AVAudioPlayerNode(), varispeed: AVAudioUnitVarispeed())
            }
            for voice in voices {
                e.attach(voice.player)
                e.attach(voice.varispeed)
                e.connect(voice.player, to: voice.varispeed, format: format)
                e.connect(voice.varispeed, to: e.mainMixerNode, format: format)
            }
            engine = e
        }

        guard let engine, !engine.isRunning else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.prepare()
        try? engine.start()
        for voice in voices where !voice.player.isPlaying {
            voice.player.play()
        }
    }

    // MARK: - Emission

    /// Play an effect. `pitch` is normalized -1…1 and maps to about
    /// ∓600 cents; scrubbers feed their step delta through it so a
    /// climbing value climbs in pitch too.
    static func play(_ effect: Effect, pitch: Double = 0) {
        guard isEnabled, let buffer = buffers[effect] else { return }

        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastEmission[effect], now - last < minInterval { return }
        lastEmission[effect] = now

        // Engine stops on backgrounding / route changes; recover inline
        // so the first sound after foregrounding still lands.
        if engine?.isRunning != true {
            startEngineIfNeeded()
            guard let engine, engine.isRunning else { return }
            engine.mainMixerNode.outputVolume = duckLevel(now: now)
        } else {
            engine?.mainMixerNode.outputVolume = duckLevel(now: now)
        }

        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count

        let cents = Float(max(-1, min(1, pitch))) * 600 + Float.random(in: -20...20)
        voice.varispeed.rate = powf(2, cents / 1200)
        voice.player.volume = powf(10, Float.random(in: -1...1) / 20)

        voice.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !voice.player.isPlaying { voice.player.play() }
    }

    /// 55% under someone else's audio, full level otherwise.
    private static func duckLevel(now: TimeInterval) -> Float {
        if now - duckCheckedAt > 2.0 {
            duckCheckedAt = now
            duckedVolume = AVAudioSession.sharedInstance().isOtherAudioPlaying ? 0.55 : 1.0
        }
        return duckedVolume
    }
}
