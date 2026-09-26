//
//  ScrubGraduationRail.swift
//  vivobody
//
//  A shaded roller with etched graduations and a fixed index. Subdivisions
//  keep short rails legible without changing the scrubber's value detents.
//

import SwiftUI
import VivoKit

struct ScrubGraduationRail: View {
    static let width: CGFloat = 28

    let value: Double
    let step: Double
    let spacing: CGFloat
    let visible: Bool
    var engaged: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Canvas { context, size in
            drawRoller(in: &context, size: size)
            drawGraduations(in: &context, size: size)
            drawIndex(in: &context, size: size)
        }
        .frame(width: Self.width)
        .padding(.vertical, 3)
        .opacity(visible ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: visible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawRoller(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(x: 7, y: 0, width: size.width - 7, height: size.height)
        var roller = context
        roller.clip(to: Path(roundedRect: rect, cornerRadius: 5))
        roller.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Ink.primary.opacity(0.02), location: 0),
                    .init(color: Ink.primary.opacity(engaged ? 0.14 : 0.10), location: 0.48),
                    .init(color: Ink.primary.opacity(0.025), location: 1),
                ]),
                startPoint: CGPoint(x: rect.minX, y: 0),
                endPoint: CGPoint(x: rect.maxX, y: 0)
            )
        )
        // End shading makes the graduations recede around a small cylinder.
        roller.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Surface.background, location: 0),
                    .init(color: Surface.background.opacity(0), location: 0.25),
                    .init(color: Surface.background.opacity(0), location: 0.75),
                    .init(color: Surface.background, location: 1),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    private func drawGraduations(in context: inout GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        // At least ten intervals in a compact reps rail. Intermediate marks
        // carry no values; curvature only changes their visual spacing.
        let subdivisions = max(1, Int(ceil(spacing / max(3, min(6, size.height / 10)))))
        let pitch = spacing / CGFloat(subdivisions)
        let position = value / max(step, .ulpOfOne) * Double(subdivisions)
        let baseIndex = Int(position.rounded(.down))
        let fraction = CGFloat(position - Double(baseIndex))
        let reach = Int(midY / pitch) + 2

        for offset in -reach ... reach {
            let index = baseIndex + offset
            let distance = (CGFloat(offset) - fraction) * pitch
            let normalized = distance / max(midY, 1)
            guard abs(normalized) < 1 else { continue }
            let y = midY + sin(normalized * .pi / 2) * midY
            let isDetent = index.isMultiple(of: subdivisions)
            let isMajor = index.isMultiple(of: subdivisions * 5)
            let length: CGFloat = isMajor ? 17 : (isDetent ? 12 : 8)
            let edgeFade = pow(cos(normalized * .pi / 2), 0.8)
            let strength = contrast == .increased ? 1.0 : (isDetent ? 0.72 : 0.46)
            let x = size.width - length - 2
            let rect = CGRect(x: x, y: y - 0.5, width: length, height: 1)
            context.fill(
                Path(rect.offsetBy(dx: 0, dy: 1)),
                with: .color(Surface.background.opacity(edgeFade * 0.85))
            )
            context.fill(Path(rect), with: .color(Ink.primary.opacity(strength * edgeFade)))
        }
    }

    private func drawIndex(in context: inout GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        let marker = CGRect(x: 5, y: midY - 1, width: size.width - 5, height: 2)
        context.fill(
            Path(marker.insetBy(dx: -1, dy: -1)),
            with: .color(Surface.background)
        )
        context.fill(
            Path(roundedRect: marker, cornerRadius: 1),
            with: .color(Tint.primaryText)
        )
        // A stationary pointer sits outside the moving scale, like an index
        // on a physical dial. Its shape preserves the cue without color.
        var pointer = Path()
        pointer.move(to: CGPoint(x: 0, y: midY - 3))
        pointer.addLine(to: CGPoint(x: 4, y: midY))
        pointer.addLine(to: CGPoint(x: 0, y: midY + 3))
        pointer.closeSubpath()
        context.fill(pointer, with: .color(Tint.primaryText))
    }
}
