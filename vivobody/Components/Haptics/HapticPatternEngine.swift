//
//  HapticPatternEngine.swift
//  vivobody
//
//  Actor-owned Core Haptics engine for Vivobody's custom patterns. Engine
//  creation, asynchronous startup, pattern construction, and playback never
//  occupy MainActor or delay the action associated with a button tap.
//

import CoreHaptics

nonisolated enum HapticPatternKind {
    case crescendo
    case breath
    case swell
    case finale
}

actor HapticPatternEngine {
    private var engine: CHHapticEngine?
    private var isStarting = false
    private var isRunning = false

    func prepare() async {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }
        if engine == nil {
            do {
                let engine = try CHHapticEngine()
                engine.stoppedHandler = { [weak self] _ in
                    Task { await self?.markStopped() }
                }
                engine.resetHandler = { [weak self] in
                    Task { await self?.restartAfterReset() }
                }
                self.engine = engine
            } catch {
                return
            }
        }

        guard !isRunning, !isStarting, let engine else { return }
        isStarting = true
        let didStart = await start(engine)
        isStarting = false
        isRunning = didStart
    }

    /// Returns immediately with `false` when the engine is not ready so the
    /// caller can use a UIKit impact fallback without delaying user intent.
    func playIfReady(_ kind: HapticPatternKind) -> Bool {
        guard isRunning, let engine else {
            if !isStarting {
                Task { await prepare() }
            }
            return false
        }

        do {
            let pattern = try pattern(for: kind)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    private func start(_ engine: CHHapticEngine) async -> Bool {
        await withCheckedContinuation { continuation in
            engine.start { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    private func markStopped() {
        isRunning = false
    }

    private func restartAfterReset() async {
        isRunning = false
        await prepare()
    }

    private func pattern(for kind: HapticPatternKind) throws -> CHHapticPattern {
        switch kind {
        case .crescendo:
            return try CHHapticPattern(
                events: [
                    transient(intensity: 0.40, sharpness: 0.35, at: 0.00),
                    transient(intensity: 0.70, sharpness: 0.60, at: 0.10),
                    transient(intensity: 1.00, sharpness: 0.90, at: 0.22),
                ],
                parameterCurves: []
            )

        case .breath:
            return try CHHapticPattern(
                events: [
                    transient(intensity: 0.5, sharpness: 0.2, at: 0.00),
                    transient(intensity: 0.5, sharpness: 0.2, at: 0.18),
                ],
                parameterCurves: []
            )

        case .swell:
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
            return try CHHapticPattern(
                events: [continuous, slam],
                parameterCurves: [intensityCurve, sharpnessCurve]
            )

        case .finale:
            return try CHHapticPattern(
                events: [
                    transient(intensity: 0.30, sharpness: 0.40, at: 0.00),
                    transient(intensity: 0.40, sharpness: 0.45, at: 0.06),
                    transient(intensity: 0.50, sharpness: 0.50, at: 0.12),
                    transient(intensity: 0.60, sharpness: 0.55, at: 0.18),
                    transient(intensity: 0.75, sharpness: 0.60, at: 0.26),
                    transient(intensity: 1.00, sharpness: 0.80, at: 0.34),
                ],
                parameterCurves: []
            )
        }
    }

    private func transient(
        intensity: Float,
        sharpness: Float,
        at time: TimeInterval
    ) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }
}
