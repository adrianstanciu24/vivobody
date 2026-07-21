//
//  RotatableBodyModel.swift
//  vivobody
//
//  SwiftUI wrapper around the anatomical body model. Hosts a single
//  `SCNView` (transparent background, so the black screen shows
//  through) and adds a horizontal drag-to-rotate gesture that spins
//  only the "bodyPivot" node about its vertical axis.
//
//  At rest the figure idles on its turntable — a very slow constant
//  drift so the hero never reads as a screenshot. The finger always
//  wins: touching stops the drift dead, a flick coasts and bleeds off
//  into the drift speed, and parking the model holds still for a
//  grace period before the drift eases back in. All tuning lives in
//  the `Drift` enum. Honors Reduce Motion by never self-moving.
//
//  The pan recogniser is deliberately direction-locked to horizontal:
//  a mostly-vertical drag fails the gesture so the enclosing
//  ScrollView keeps ownership of vertical scrolling. The model is the
//  hero atop the Today screen, which scrolls — the two must coexist.
//

import SceneKit
import SwiftUI

// MARK: - Direction-locked horizontal pan

/// Fails itself the moment a drag reads as mostly-vertical, handing
/// the touch back to the surrounding ScrollView.
final class HorizontalPanGesture: UIPanGestureRecognizer {
    private var directionLocked = false

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard !directionLocked, state == .began || state == .changed else { return }
        let velocity = velocity(in: view)
        directionLocked = true
        if abs(velocity.y) > abs(velocity.x) {
            state = .failed
        }
    }

    override func reset() {
        super.reset()
        directionLocked = false
    }
}

// MARK: - Representable

struct RotatableBodyModel: UIViewRepresentable {
    static let sensitivity: Float = 0.008
    private static let viewTag = 999

    /// Self-motion tuning — every number that shapes how the figure
    /// moves on its own. `secondsPerRevolution` is the one to play
    /// with when judging how alive the turntable should feel.
    enum Drift {
        /// One full idle revolution takes this long.
        static let secondsPerRevolution: Double = 90

        /// Idle angular speed (radians/second), derived from the above.
        static var speed: Float { Float(2 * Double.pi / secondsPerRevolution) }

        /// How long the model holds still after the user parks it
        /// before the drift eases back in — releasing must never feel
        /// like the model snatches control back.
        static let resumeDelay: TimeInterval = 3.5

        /// Exponential rate at which angular velocity approaches its
        /// target. Governs both the flick bleed-off and the ease back
        /// up to idle speed; higher = snappier.
        static let approachRate: Float = 2.6

        /// A release slower than this is a park, not a flick.
        static let flickThreshold: Float = 0.35

        /// Flick velocity clamp so a hard fling can't spin the model wild.
        static let maxFlickVelocity: Float = 6

        /// Quadrant detent haptics fire only above this speed — the
        /// felt part of a user's spin, never the ambient drift.
        static let hapticFloor: Float = 0.12
    }

    /// Height, in points, the SCNView is pinned to via an explicit
    /// constraint. The figure's scale is bound to this drawable
    /// height, so it MUST stay constant for the model to hold a fixed
    /// size. We deliberately do NOT let the SCNView track its
    /// SwiftUI container: inside a ScrollView the container's height
    /// flexes (safe-area / large-title collapse), and a SwiftUI
    /// `.frame(height:)` on a representable doesn't reliably pin the
    /// underlying view — both let the figure "zoom" mid-scroll.
    var renderHeight: CGFloat

    /// Per-muscle render channels keyed by BodyModel mesh node name.
    /// The owning surface decides whether intensity means chronic
    /// development or temporary exercise anatomy.
    var channels: [String: MuscleMapChannels] = [:]

    /// Reports the pivot's live Y rotation (radians) on every change —
    /// drag and coast alike. The specimen stage's degree ticks ride
    /// this so figure and turntable rotate as one piece. Called at
    /// frame rate while the model is in motion; keep the observer
    /// small.
    var onRotation: ((Double) -> Void)? = nil

    /// The resolved scheme the scene renders for — materials and light
    /// rig are all themed (see `BodyModelScene`).
    private static func theme(for context: Context) -> BodyModelTheme {
        context.environment.colorScheme == .dark ? .dark : .light
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = false

        let theme = Self.theme(for: context)
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false
        scnView.scene = BodyModelScene.make(channels: channels, theme: theme)
        scnView.preferredFramesPerSecond = 30
        context.coordinator.appliedChannels = channels
        context.coordinator.appliedTheme = theme
        scnView.pointOfView = scnView.scene?.rootNode.childNodes.first { $0.camera != nil }
        scnView.translatesAutoresizingMaskIntoConstraints = false
        scnView.tag = Self.viewTag
        container.addSubview(scnView)

        let heightConstraint = scnView.heightAnchor.constraint(equalToConstant: renderHeight)
        context.coordinator.heightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            scnView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            scnView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            heightConstraint
        ])

        let pan = HorizontalPanGesture(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        container.addGestureRecognizer(pan)
        context.coordinator.onRotation = onRotation
        context.coordinator.scnView = scnView
        context.coordinator.pivot = scnView.scene?.rootNode.childNode(
            withName: "bodyPivot",
            recursively: true
        )
        context.coordinator.beginIdleDrift()

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.heightConstraint?.constant = renderHeight
        context.coordinator.onRotation = onRotation

        // Re-tint in place when the development map changes (e.g. a
        // workout was just archived) or the resolved colour scheme
        // flips, rather than rebuilding the heavy scene.
        let theme = Self.theme(for: context)
        if let scnView = uiView.viewWithTag(Self.viewTag) as? SCNView {
            if context.coordinator.appliedChannels != channels
                || context.coordinator.appliedTheme != theme,
               let scene = scnView.scene {
                BodyModelScene.apply(channels: channels, theme: theme, to: scene)
                context.coordinator.appliedChannels = channels
                context.coordinator.appliedTheme = theme
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stopMotion()
    }

    @MainActor
    final class Coordinator: NSObject {
        var heightConstraint: NSLayoutConstraint?
        var appliedChannels: [String: MuscleMapChannels] = [:]
        var appliedTheme: BodyModelTheme = .dark
        var onRotation: ((Double) -> Void)?
        weak var scnView: SCNView?
        weak var pivot: SCNNode?
        private var lastX: CGFloat = 0

        // Self-motion: one display link drives both the flywheel coast
        // and the idle drift. Every frame the angular velocity
        // approaches `targetVelocity` exponentially — a flick starts
        // fast and bleeds off into the drift speed; a resume starts at
        // zero and eases up to it. Same equation, both feels.
        private var motionLink: CADisplayLink?
        private var velocity: Float = 0
        private var targetVelocity: Float = 0
        private var resumeTask: Task<Void, Never>?

        /// Which way the turntable idles — follows the user's last
        /// flick so the drift always continues their gesture.
        private var driftDirection: Float = 1

        /// Which quarter turn the stage last sat in — a detent tick
        /// fires on every crossing so rotation is felt, not just seen.
        private var lastQuadrant: Int?

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let container = gesture.view, let pivot else { return }

            let translation = gesture.translation(in: container)
            switch gesture.state {
            case .began:
                stopMotion()
            case .changed:
                let delta = Float(translation.x - lastX)
                pivot.eulerAngles.y += delta * RotatableBodyModel.sensitivity
                lastX = translation.x
                report(pivot, withHaptics: true)
            case .ended:
                lastX = 0
                release(
                    flick: Float(gesture.velocity(in: container).x) * RotatableBodyModel.sensitivity
                )
            case .cancelled, .failed:
                lastX = 0
                scheduleDriftResume()
            default:
                break
            }
        }

        // MARK: Self-motion

        /// Start (or seamlessly retarget to) the idle drift from the
        /// current velocity. Safe to call any time the model should be
        /// moving on its own.
        func beginIdleDrift() {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            targetVelocity = Drift.speed * driftDirection
            startMotionLink()
        }

        /// The user let go: a flick coasts into the drift, a park
        /// schedules the drift to ease back in after the grace period.
        private func release(flick: Float) {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            if abs(flick) > Drift.flickThreshold {
                driftDirection = flick > 0 ? 1 : -1
                velocity = min(max(flick, -Drift.maxFlickVelocity), Drift.maxFlickVelocity)
                beginIdleDrift()
            } else {
                scheduleDriftResume()
            }
        }

        private func scheduleDriftResume() {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            resumeTask?.cancel()
            resumeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Drift.resumeDelay))
                guard !Task.isCancelled else { return }
                self?.beginIdleDrift()
            }
        }

        private func startMotionLink() {
            guard motionLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(motionTick(_:)))
            // The scene renders at 30fps; driving the pivot faster is
            // wasted work for a link that runs whenever the model idles.
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            motionLink = link
        }

        @objc private func motionTick(_ link: CADisplayLink) {
            guard let pivot else {
                stopMotion()
                return
            }
            // Hold position while off-window (e.g. another tab is up):
            // no motion the user can't see, no SceneKit re-renders.
            guard scnView?.window != nil else { return }
            let dt = Float(link.targetTimestamp - link.timestamp)
            velocity = targetVelocity + (velocity - targetVelocity) * exp(-Drift.approachRate * dt)
            pivot.eulerAngles.y += velocity * dt
            report(pivot, withHaptics: abs(velocity) > Drift.hapticFloor)
        }

        func stopMotion() {
            resumeTask?.cancel()
            resumeTask = nil
            motionLink?.invalidate()
            motionLink = nil
            velocity = 0
        }

        // MARK: Reporting

        private func report(_ pivot: SCNNode, withHaptics: Bool) {
            let angle = Double(pivot.eulerAngles.y)
            onRotation?(angle)
            let quadrant = Int((angle / (.pi / 2)).rounded(.down))
            if withHaptics, let last = lastQuadrant, quadrant != last {
                Haptics.tick()
            }
            lastQuadrant = quadrant
        }
    }
}

#Preview("Dark") {
    ZStack {
        Color.black.ignoresSafeArea()
        RotatableBodyModel(renderHeight: 420)
            .frame(height: 420)
    }
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    ZStack {
        Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea()
        RotatableBodyModel(renderHeight: 420)
            .frame(height: 420)
    }
    .preferredColorScheme(.light)
}
