//
//  SoundEngine.swift
//  vivobody
//
//  Actor-owned AVAudioEngine for Vivobody's interaction sounds. The actor
//  serializes the non-Sendable audio graph while keeping file loading, graph
//  construction, audio-session activation, and playback off MainActor.
//

import AVFoundation

actor SoundEngine {
    typealias Effect = Sounds.Effect

    private struct Voice {
        let player: AVAudioPlayerNode
        let varispeed: AVAudioUnitVarispeed
    }

    private struct PreparedBuffers: @unchecked Sendable {
        var buffers: [Effect: AVAudioPCMBuffer] = [:]
        var recordedBuffers: [Effect: AVAudioPCMBuffer] = [:]
        var standardScrubBuffers: [AVAudioPCMBuffer] = []
        var deepScrubBuffers: [AVAudioPCMBuffer] = []
    }

    private var engine: AVAudioEngine?
    private var isStartingEngine = false
    private var voices: [Voice] = []
    private var nextVoice = 0
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var recordedBuffers: [Effect: AVAudioPCMBuffer] = [:]
    private var recordedPlayers: [Effect: AVAudioPlayerNode] = [:]
    private var standardScrubBuffers: [AVAudioPCMBuffer] = []
    private var deepScrubBuffers: [AVAudioPCMBuffer] = []
    private var bufferPreparation: Task<PreparedBuffers, Never>?
    private var nextStandardScrubVariant = 0
    private var nextDeepScrubVariant = 0
    private var lastEmission: [Effect: TimeInterval] = [:]
    private var duckCheckedAt: TimeInterval = 0
    private var duckedVolume: Float = 1.0

    /// Enough voices that a fast scrub never steals the preceding tail.
    private static let voiceCount = 8
    /// Synth effects above roughly 28 emissions per second become one buzz.
    private static let minInterval: TimeInterval = 0.035

    func prepare() async {
        if buffers.isEmpty || standardScrubBuffers.isEmpty || deepScrubBuffers.isEmpty {
            let task: Task<PreparedBuffers, Never>
            if let bufferPreparation {
                task = bufferPreparation
            } else {
                task = Task.detached(priority: .utility) {
                    Self.loadPreparedBuffers()
                }
                bufferPreparation = task
            }

            let prepared = await task.value
            if buffers.isEmpty {
                buffers = prepared.buffers
                recordedBuffers = prepared.recordedBuffers
                standardScrubBuffers = prepared.standardScrubBuffers
                deepScrubBuffers = prepared.deepScrubBuffers
            }
            bufferPreparation = nil
        }

        await startEngineIfNeeded()
    }

    /// Feedback is intentionally best-effort. If startup or recovery is still
    /// in progress, discard this sound and prepare for the next interaction.
    func playIfReady(_ effect: Effect, pitch: Double, humanize: Bool) {
        guard engine?.isRunning == true else {
            requestPreparation()
            return
        }
        if effect.isRecorded {
            playRecorded(effect)
        } else {
            playSynthesized(effect, pitch: pitch, humanize: humanize)
        }
    }

    func playScrubDetentIfReady(deep: Bool) {
        guard let engine, engine.isRunning else {
            requestPreparation()
            return
        }
        let variants = deep ? deepScrubBuffers : standardScrubBuffers
        guard !variants.isEmpty, !voices.isEmpty else { return }

        let now = ProcessInfo.processInfo.systemUptime
        engine.mainMixerNode.outputVolume = duckLevel(now: now)

        let variantIndex: Int
        if deep {
            variantIndex = nextDeepScrubVariant
            nextDeepScrubVariant = (nextDeepScrubVariant + 1) % variants.count
        } else {
            variantIndex = nextStandardScrubVariant
            nextStandardScrubVariant = (nextStandardScrubVariant + 1) % variants.count
        }

        let voice = nextAvailableVoice()
        voice.varispeed.rate = 1
        voice.player.volume = 1
        voice.player.scheduleBuffer(variants[variantIndex], at: nil, options: .interrupts)
        if !voice.player.isPlaying { voice.player.play() }
    }

    private func requestPreparation() {
        guard bufferPreparation == nil, !isStartingEngine else { return }
        Task(priority: .utility) {
            await prepare()
        }
    }

    private func startEngineIfNeeded() async {
        guard !buffers.isEmpty else { return }
        if engine == nil, !configureEngine() { return }
        guard let engine, !engine.isRunning, !isStartingEngine else { return }

        isStartingEngine = true
        defer { isStartingEngine = false }
        do {
            try await Self.activateSession()
            engine.prepare()
            try engine.start()
            for voice in voices where !voice.player.isPlaying {
                voice.player.play()
            }
            for player in recordedPlayers.values where !player.isPlaying {
                player.play()
            }
        } catch {
            for voice in voices {
                voice.player.stop()
            }
            for player in recordedPlayers.values {
                player.stop()
            }
            AppDiagnostics.audioFailed(event: "start", error: error)
        }
    }

    private func configureEngine() -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                options: [.mixWithOthers]
            )
        } catch {
            AppDiagnostics.audioFailed(event: "configure", error: error)
            return false
        }

        let engine = AVAudioEngine()
        let format = buffers.values.first?.format
        voices = (0 ..< Self.voiceCount).map { _ in
            Voice(player: AVAudioPlayerNode(), varispeed: AVAudioUnitVarispeed())
        }
        for voice in voices {
            engine.attach(voice.player)
            engine.attach(voice.varispeed)
            engine.connect(voice.player, to: voice.varispeed, format: format)
            engine.connect(voice.varispeed, to: engine.mainMixerNode, format: format)
        }

        recordedPlayers = recordedBuffers.mapValues { _ in AVAudioPlayerNode() }
        for (effect, player) in recordedPlayers {
            engine.attach(player)
            engine.connect(
                player,
                to: engine.mainMixerNode,
                format: recordedBuffers[effect]?.format
            )
        }
        self.engine = engine
        return true
    }

    private func playSynthesized(_ effect: Effect, pitch: Double, humanize: Bool) {
        guard let engine, let buffer = buffers[effect], !voices.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastEmission[effect], now - last < Self.minInterval { return }
        lastEmission[effect] = now
        engine.mainMixerNode.outputVolume = duckLevel(now: now)

        let voice = nextAvailableVoice()
        let cents = Float(max(-1, min(1, pitch))) * 600
            + (humanize ? Float.random(in: -20 ... 20) : 0)
        voice.varispeed.rate = powf(2, cents / 1200)
        voice.player.volume = humanize ? powf(10, Float.random(in: -1 ... 1) / 20) : 1
        voice.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !voice.player.isPlaying { voice.player.play() }
    }

    private func playRecorded(_ effect: Effect) {
        guard
            let engine,
            let buffer = recordedBuffers[effect],
            let player = recordedPlayers[effect]
        else { return }

        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastEmission[effect], now - last < Self.minInterval { return }
        lastEmission[effect] = now
        engine.mainMixerNode.outputVolume = duckLevel(now: now)
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    private func nextAvailableVoice() -> Voice {
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        return voice
    }

    /// Use a brief cache so rapid scrub ticks don't query the session each time.
    private func duckLevel(now: TimeInterval) -> Float {
        if now - duckCheckedAt > 2.0 {
            duckCheckedAt = now
            duckedVolume = AVAudioSession.sharedInstance().isOtherAudioPlaying ? 0.55 : 1.0
        }
        return duckedVolume
    }

    private nonisolated static func loadPreparedBuffers() -> PreparedBuffers {
        var prepared = PreparedBuffers()
        for effect in Effect.allCases {
            guard
                let buffer = loadBuffer(
                    named: effect.resourceName,
                    extension: effect.isRecorded ? "wav" : "caf"
                )
            else { continue }
            if effect.isRecorded {
                prepared.recordedBuffers[effect] = buffer
            } else {
                prepared.buffers[effect] = buffer
            }
        }
        prepared.standardScrubBuffers = loadScrubBuffers(prefix: "sfx-scrub-reps")
        prepared.deepScrubBuffers = loadScrubBuffers(prefix: "sfx-scrub-load")
        return prepared
    }

    private nonisolated static func loadScrubBuffers(prefix: String) -> [AVAudioPCMBuffer] {
        (1 ... 6).compactMap { variant in
            loadBuffer(named: "\(prefix)-\(variant)", extension: "caf")
        }
    }

    private nonisolated static func loadBuffer(
        named name: String,
        extension ext: String
    ) -> AVAudioPCMBuffer? {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: ext),
            let file = try? AVAudioFile(forReading: url),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ),
            (try? file.read(into: buffer)) != nil
        else { return nil }
        return buffer
    }

    private nonisolated static func activateSession() async throws {
        if #available(iOS 27.0, *) {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                AVAudioSession.sharedInstance().activate(options: []) { activated, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if activated {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "Vivobody.AudioSession",
                            code: 1
                        ))
                    }
                }
            }
        } else {
            try await Task.detached {
                try AVAudioSession.sharedInstance().setActive(true)
            }.value
        }
    }
}
