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

    /// Per-muscle training intensity in `0...1`, keyed by BodyModel
    /// mesh node name (see `MuscleHeatmap`). Drives the untrained →
    /// Volt colour ramp. Empty renders every muscle untrained.
    var activations: [String: CGFloat] = [:]

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = false

        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false
        scnView.scene = BodyModelScene.make(activations: activations)
        context.coordinator.appliedActivations = activations
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

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.heightConstraint?.constant = renderHeight

        // Re-tint in place when the heatmap changes (e.g. a workout
        // was just archived) rather than rebuilding the heavy scene.
        if context.coordinator.appliedActivations != activations,
           let scnView = uiView.viewWithTag(Self.viewTag) as? SCNView,
           let scene = scnView.scene {
            BodyModelScene.applyActivations(activations, to: scene)
            context.coordinator.appliedActivations = activations
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        var heightConstraint: NSLayoutConstraint?
        var appliedActivations: [String: CGFloat] = [:]
        private var lastX: CGFloat = 0

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
            case .changed:
                let delta = Float(translation.x - lastX)
                pivot.eulerAngles.y += delta * RotatableBodyModel.sensitivity
                lastX = translation.x
            case .ended, .cancelled, .failed:
                lastX = 0
            default:
                break
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RotatableBodyModel(renderHeight: 420)
            .frame(height: 420)
    }
}
