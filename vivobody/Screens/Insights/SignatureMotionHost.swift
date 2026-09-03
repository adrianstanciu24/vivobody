//
//  SignatureMotionHost.swift
//  vivobody
//
//  Owns the Training Signature's app-only animation lifecycle. A pure motion
//  policy maps Reduce Motion and time into deterministic renderer inputs;
//  Canvas drawing remains stateless in the focused renderer files.
//

import Foundation
import SwiftUI
import VivoKit

nonisolated enum SignatureMotionSchedule: Equatable {
    case still
    case animated(minimumInterval: TimeInterval)
}

nonisolated struct SignatureRenderFrame: Equatable {
    let time: TimeInterval
    let coreBreath: Double
    let petalBreath: Double
    let satelliteOrbit: Double
    let isAnimated: Bool
}

nonisolated enum SignatureMotionPolicy {
    /// One full satellite lap around the rim takes this long.
    static let satelliteLapSeconds: Double = 75

    /// One core breath (swell and relax) takes this long.
    static let breathSeconds: Double = 4

    /// 30fps is sufficient for the slow breath and creeping orbit.
    static let minimumInterval: TimeInterval = 1.0 / 30.0

    /// Stable ambient breath. It carries no training data.
    static let breathStrength: Double = 0.72

    /// Core radius gain at the top of a full-strength breath.
    static let coreSwell: Double = 0.3

    /// Peak opacity of the halo the core exhales.
    static let haloOpacity: Double = 0.35

    /// Glow-only dimming at the bottom of a breath. Petal geometry and
    /// material are data-bearing and remain fixed.
    static let glowBreathDepth: Double = 0.22

    static func schedule(reduceMotion: Bool) -> SignatureMotionSchedule {
        reduceMotion ? .still : .animated(minimumInterval: minimumInterval)
    }

    static func renderFrame(
        at time: TimeInterval,
        schedule: SignatureMotionSchedule
    ) -> SignatureRenderFrame {
        switch schedule {
        case .still:
            // The still petal keeps its full burn while the core halo and
            // orbit stop at the same values used by the original renderer.
            return SignatureRenderFrame(
                time: 0,
                coreBreath: 0,
                petalBreath: 1,
                satelliteOrbit: 0,
                isAnimated: false
            )
        case .animated:
            let breath = (sin(time * 2 * .pi / breathSeconds) + 1) / 2
            let orbit = (time / satelliteLapSeconds) * 2 * .pi
            return SignatureRenderFrame(
                time: time,
                coreBreath: breath,
                petalBreath: breath,
                satelliteOrbit: orbit,
                isAnimated: true
            )
        }
    }
}

/// App-only host for the quietly living signature emblem. The shape and
/// material remain fixed; only ambient light, ember dust, and the satellite
/// use the timeline. Reduce Motion selects a timeless render with no timeline.
struct SignatureMotionHost: View {
    let signature: TrainingSignature

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch SignatureMotionPolicy.schedule(reduceMotion: reduceMotion) {
            case .still:
                emblem(
                    frame: SignatureMotionPolicy.renderFrame(
                        at: 0,
                        schedule: .still
                    )
                )
            case let .animated(minimumInterval):
                TimelineView(.animation(minimumInterval: minimumInterval)) { timeline in
                    emblem(
                        frame: SignatureMotionPolicy.renderFrame(
                            at: timeline.date.timeIntervalSinceReferenceDate,
                            schedule: .animated(minimumInterval: minimumInterval)
                        )
                    )
                }
            }
        }
        .frame(height: 272)
        .accessibilityLabel(Text(SignatureAccessibilityDescription.text(for: signature)))
    }

    private func emblem(frame: SignatureRenderFrame) -> some View {
        Canvas { context, size in
            let interval = GraphicsPerformanceSignposts.begin("TrainingSignature.draw")
            defer { GraphicsPerformanceSignposts.end("TrainingSignature.draw", interval) }

            SignatureEmblemRenderer(signature: signature, frame: frame)
                .draw(in: &context, size: size)
        }
    }
}
