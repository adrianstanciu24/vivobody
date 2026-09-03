//
//  SignatureEmblemRenderer.swift
//  vivobody
//
//  Stateless Canvas orchestration for the Training Signature's atmosphere,
//  guides, labels, satellite, and core. Petal material is delegated to its
//  focused drawing pass; shared data geometry stays in VivoKit.
//

import SwiftUI
import VivoKit

nonisolated enum SignatureEmblemRenderPass: CaseIterable, Equatable {
    case atmosphere
    case ring
    case spokes
    case satellite
    case equalShareGhost
    case petals
    case labels
    case core

    static let drawOrder: [Self] = [
        .atmosphere,
        .ring,
        .spokes,
        .satellite,
        .equalShareGhost,
        .petals,
        .labels,
        .core,
    ]
}

struct SignatureEmblemRenderer {
    let signature: TrainingSignature
    let frame: SignatureRenderFrame

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = Swift.min(size.width, size.height) / 2

        for pass in SignatureEmblemRenderPass.drawOrder {
            switch pass {
            case .atmosphere:
                drawAtmosphere(in: &context, center: center, radius: radius)
            case .ring:
                drawRing(in: &context, center: center, radius: radius)
            case .spokes:
                drawSpokes(in: &context, center: center, radius: radius)
            case .satellite:
                drawSatellite(in: &context, center: center, radius: radius)
            case .equalShareGhost:
                drawGhostBloom(in: &context, center: center, radius: radius)
            case .petals:
                SignaturePetalRenderer(signature: signature, frame: frame)
                    .draw(in: &context, center: center, radius: radius)
            case .labels:
                drawLabels(in: &context, center: center, radius: radius)
            case .core:
                drawCore(in: &context, center: center, radius: radius)
            }
        }
    }

    /// The night the bloom sits in — a barely-lit pocket of warm air
    /// instead of dead flat black, so the emblem has depth before a
    /// single petal is drawn.
    private func drawAtmosphere(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let atmosphereRadius = radius * SignatureEmblemTuning.atmosphereFraction
        let rect = CGRect(
            x: center.x - atmosphereRadius,
            y: center.y - atmosphereRadius,
            width: atmosphereRadius * 2,
            height: atmosphereRadius * 2
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                SignatureEmblemTuning.atmosphereGradient(),
                center: center,
                startRadius: 0,
                endRadius: atmosphereRadius
            )
        )
    }

    private func drawRing(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let ringRadius = radius * SignatureEmblemTuning.ringFraction
        let rect = CGRect(
            x: center.x - ringRadius,
            y: center.y - ringRadius,
            width: ringRadius * 2,
            height: ringRadius * 2
        )
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(Surface.cardTint),
            lineWidth: 1
        )
    }

    /// Faint guides anchor every petal to its named axis. The dominant
    /// region's spoke is lit, reinforced by its tinted label and numeral.
    private func drawSpokes(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let petals = signature.petals
        let count = petals.count
        guard count > 0 else { return }
        let inner = radius * SignatureEmblemTuning.spokeInnerFraction
        let outer = radius * SignatureEmblemTuning.ringFraction
        for (index, petal) in petals.enumerated() {
            let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
            let isDominant = petal.group == signature.dominantGroup
            var path = Path()
            path.move(
                to: CGPoint(
                    x: center.x + cos(angle) * inner,
                    y: center.y + sin(angle) * inner
                )
            )
            path.addLine(
                to: CGPoint(
                    x: center.x + cos(angle) * outer,
                    y: center.y + sin(angle) * outer
                )
            )
            context.stroke(
                path,
                with: .color(
                    isDominant
                        ? Tint.primary.opacity(0.45)
                        : Ink.primary.opacity(0.05)
                ),
                lineWidth: 1
            )
        }
    }

    /// A single dim bead carries ambient life without encoding data. In the
    /// still frame it parks off-axis so it cannot read as a group marker.
    private func drawSatellite(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let ringRadius = radius * SignatureEmblemTuning.ringFraction
        let angle = frame.satelliteOrbit - .pi / 2 + (frame.isAnimated ? 0 : 0.9)
        let point = CGPoint(
            x: center.x + cos(angle) * ringRadius,
            y: center.y + sin(angle) * ringRadius
        )
        let dot = CGRect(
            x: point.x - 1.5,
            y: point.y - 1.5,
            width: 3,
            height: 3
        )
        context.fill(
            Path(ellipseIn: dot),
            with: .color(Tint.primary.opacity(0.3))
        )
    }

    /// Six equal dashed leaves provide the stable one-sixth reference that
    /// makes live petals inside or outside the guide meaningful at a glance.
    private func drawGhostBloom(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let count = signature.petals.count
        guard count > 0 else { return }
        let share = SignatureEmblemTuning.equalShare
        let length = radius * SignatureEmblemTuning.reachFraction(volumeShare: share)
        let halfWidth = SignatureEmblemTuning.halfWidth(
            volumeShare: share,
            length: length,
            radius: radius
        )
        let leaf = SignatureEmblemTuning.petalPath(
            length: length,
            halfWidth: halfWidth
        )

        for index in 0 ..< count {
            let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
            var transform = CGAffineTransform(
                translationX: center.x,
                y: center.y
            )
            transform = transform.rotated(by: angle)
            context.stroke(
                leaf.applying(transform),
                with: .color(
                    Ink.primary.opacity(SignatureEmblemTuning.ghostOpacity)
                ),
                style: StrokeStyle(
                    lineWidth: SignatureEmblemTuning.ghostLineWidth,
                    dash: SignatureEmblemTuning.ghostDash
                )
            )
        }
    }

    /// Each label states its share because petal width is the weaker visual
    /// channel. The dominant group receives the same tint as its spoke.
    private func drawLabels(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let petals = signature.petals
        let count = petals.count
        for (index, petal) in petals.enumerated() {
            let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
            let isDominant = petal.group == signature.dominantGroup
            let labelPoint = CGPoint(
                x: center.x + cos(angle) * radius * SignatureEmblemTuning.labelFraction,
                y: center.y + sin(angle) * radius * SignatureEmblemTuning.labelFraction
            )
            let name = Text(petal.group.displayName.uppercased())
                .font(Typography.micro)
                .fontWeight(isDominant ? .bold : .medium)
                .foregroundStyle(isDominant ? Tint.primaryText : Ink.tertiary)
            context.draw(
                name,
                at: CGPoint(x: labelPoint.x, y: labelPoint.y - 7),
                anchor: .center
            )

            guard petal.volumeShare > 0 else { continue }
            let numeral = Text(signatureShareLabel(petal.volumeShare))
                .font(Typography.micro.monospacedDigit())
                .foregroundStyle(isDominant ? Tint.primaryText : Ink.secondary)
            context.draw(
                numeral,
                at: CGPoint(x: labelPoint.x, y: labelPoint.y + 7),
                anchor: .center
            )
        }
    }

    private func drawCore(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let strength = SignatureMotionPolicy.breathStrength * frame.coreBreath
        let coreRadius = radius * 0.05
            * (1 + CGFloat(SignatureMotionPolicy.coreSwell * strength))

        let contactRadius = coreRadius * 2.05
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - contactRadius,
                y: center.y - contactRadius,
                width: contactRadius * 2,
                height: contactRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [Color.black.opacity(0.52), .clear]),
                center: center,
                startRadius: coreRadius * 0.78,
                endRadius: contactRadius
            )
        )

        if strength > 0 {
            drawCoreHalo(
                in: &context,
                center: center,
                coreRadius: coreRadius,
                strength: strength
            )
        }
        drawCoreFlare(
            in: &context,
            center: center,
            radius: radius,
            strength: strength
        )
        drawCoreBead(
            in: &context,
            center: center,
            coreRadius: coreRadius
        )
    }

    private func drawCoreHalo(
        in context: inout GraphicsContext,
        center: CGPoint,
        coreRadius: CGFloat,
        strength: Double
    ) {
        let haloRadius = coreRadius * 2.9
        let haloRect = CGRect(
            x: center.x - haloRadius,
            y: center.y - haloRadius,
            width: haloRadius * 2,
            height: haloRadius * 2
        )
        context.fill(
            Path(ellipseIn: haloRect),
            with: .radialGradient(
                Gradient(colors: [
                    Tint.primary.opacity(SignatureMotionPolicy.haloOpacity * strength),
                    .clear,
                ]),
                center: center,
                startRadius: 0,
                endRadius: haloRadius
            )
        )
    }

    private func drawCoreFlare(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        strength: Double
    ) {
        let streakRadius = radius * 0.3 * (0.85 + 0.3 * CGFloat(strength))
        let glow = 0.7 + 0.3 * strength
        let soft = CGRect(
            x: center.x - streakRadius,
            y: center.y - 1.6,
            width: streakRadius * 2,
            height: 3.2
        )
        context.fill(
            Path(soft),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Tint.primary.opacity(0.34 * glow), location: 0.5),
                    .init(color: .clear, location: 1),
                ]),
                startPoint: CGPoint(x: soft.minX, y: center.y),
                endPoint: CGPoint(x: soft.maxX, y: center.y)
            )
        )

        let hair = CGRect(
            x: center.x - streakRadius * 0.72,
            y: center.y - 0.6,
            width: streakRadius * 1.44,
            height: 1.2
        )
        context.fill(
            Path(hair),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(
                        color: SignatureEmblemTuning.petalHot(hueShift: 0.5)
                            .opacity(0.42 * glow),
                        location: 0.5
                    ),
                    .init(color: .clear, location: 1),
                ]),
                startPoint: CGPoint(x: hair.minX, y: center.y),
                endPoint: CGPoint(x: hair.maxX, y: center.y)
            )
        )
    }

    private func drawCoreBead(
        in context: inout GraphicsContext,
        center: CGPoint,
        coreRadius: CGFloat
    ) {
        let rect = CGRect(
            x: center.x - coreRadius,
            y: center.y - coreRadius,
            width: coreRadius * 2,
            height: coreRadius * 2
        )
        let bead = Path(ellipseIn: rect)
        context.fill(
            bead,
            with: .radialGradient(
                Gradient(stops: [
                    .init(
                        color: SignatureEmblemTuning.petalHot(hueShift: 0.5),
                        location: 0
                    ),
                    .init(color: Tint.primary, location: 0.58),
                    .init(
                        color: SignatureEmblemTuning.petalEmber(hueShift: 0.5),
                        location: 1
                    ),
                ]),
                center: center,
                startRadius: 0,
                endRadius: coreRadius
            )
        )
        context.stroke(
            bead,
            with: .color(
                SignatureEmblemTuning.petalHot(hueShift: 0.5).opacity(0.5)
            ),
            lineWidth: 0.5
        )
    }
}
