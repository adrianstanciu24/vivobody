//
//  RotatableBodyModel.swift
//  vivobody
//
//  SwiftUI wrapper around the anatomical body model. Hosts a single
//  `SCNView` (transparent background, so the black screen shows
//  through) and adds a horizontal drag-to-rotate gesture that spins
//  only the "bodyPivot" node about its vertical axis.
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
        coordinator.stopCoast()
    }

    @MainActor
    final class Coordinator: NSObject {
        var heightConstraint: NSLayoutConstraint?
        var appliedChannels: [String: MuscleMapChannels] = [:]
        var appliedTheme: BodyModelTheme = .dark
        var onRotation: ((Double) -> Void)?
        private var lastX: CGFloat = 0

        // Flywheel coast: a released spin keeps turning and bleeds off
        // exponentially, the same physics the scrubbers speak.
        private var coastLink: CADisplayLink?
        private var coastVelocity: Float = 0
        private weak var coastPivot: SCNNode?

        /// Which quarter turn the stage last sat in — a detent tick
        /// fires on every crossing so rotation is felt, not just seen.
        private var lastQuadrant: Int?

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let container = gesture.view,
                  let scnView = container.viewWithTag(RotatableBodyModel.viewTag) as? SCNView,
                  let pivot = scnView.scene?.rootNode.childNode(
                      withName: "bodyPivot",
                      recursively: true
                  )
            else { return }

            let translation = gesture.translation(in: container)
            switch gesture.state {
            case .began:
                stopCoast()
            case .changed:
                let delta = Float(translation.x - lastX)
                pivot.eulerAngles.y += delta * RotatableBodyModel.sensitivity
                lastX = translation.x
                report(pivot)
            case .ended:
                lastX = 0
                beginCoast(
                    pivot: pivot,
                    velocity: Float(gesture.velocity(in: container).x) * RotatableBodyModel.sensitivity
                )
            case .cancelled, .failed:
                lastX = 0
            default:
                break
            }
        }

        // MARK: Coast

        private func beginCoast(pivot: SCNNode, velocity: Float) {
            guard !UIAccessibility.isReduceMotionEnabled,
                  abs(velocity) > 0.35 else { return }
            coastPivot = pivot
            coastVelocity = min(max(velocity, -6), 6)
            coastLink?.invalidate()
            let link = CADisplayLink(target: self, selector: #selector(coastTick(_:)))
            link.add(to: .main, forMode: .common)
            coastLink = link
        }

        @objc private func coastTick(_ link: CADisplayLink) {
            guard let pivot = coastPivot else {
                stopCoast()
                return
            }
            let dt = Float(link.targetTimestamp - link.timestamp)
            pivot.eulerAngles.y += coastVelocity * dt
            coastVelocity *= exp(-2.6 * dt)
            report(pivot)
            if abs(coastVelocity) < 0.12 { stopCoast() }
        }

        func stopCoast() {
            coastLink?.invalidate()
            coastLink = nil
        }

        // MARK: Reporting

        private func report(_ pivot: SCNNode) {
            let angle = Double(pivot.eulerAngles.y)
            onRotation?(angle)
            let quadrant = Int((angle / (.pi / 2)).rounded(.down))
            if let last = lastQuadrant, quadrant != last {
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
