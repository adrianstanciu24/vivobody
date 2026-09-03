//
//  SignaturePetalRenderer.swift
//  vivobody
//
//  Stateless material passes for the Training Signature's data-bearing
//  petals: layout, ambient bloom, folded bodies, core spill, hot highlights,
//  and ember dust. All silhouette geometry and palette tuning stay in VivoKit.
//

import SwiftUI
import VivoKit

struct SignaturePetalRenderer {
    let signature: TrainingSignature
    let frame: SignatureRenderFrame

    /// One petal's placement and material inputs for a frame.
    private struct PetalLayout {
        let angle: Double
        let opacity: Double
        let hueShift: Double
        let isDominant: Bool
        let shape: SignatureEmblemTuning.PetalShape
        let hotBase: Path
        let hotTip: CGPoint
    }

    func draw(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let layouts = petalLayouts(radius: radius)
        let glowBreath = 1 - SignatureMotionPolicy.glowBreathDepth
            * SignatureMotionPolicy.breathStrength * (1 - frame.petalBreath)

        drawAmbientEmber(in: &context, center: center, radius: radius)
        drawBloom(
            in: &context,
            layouts: layouts,
            center: center,
            radius: radius,
            glowBreath: glowBreath
        )
        drawEmberDust(in: &context, center: center, radius: radius)
        drawBodies(in: &context, layouts: layouts, center: center)
        drawCoreSpill(
            in: &context,
            layouts: layouts,
            center: center,
            radius: radius,
            glowBreath: glowBreath
        )
        drawHotPass(
            in: &context,
            layouts: layouts,
            center: center,
            radius: radius,
            glowBreath: glowBreath
        )
    }

    private func petalLayouts(radius: CGFloat) -> [PetalLayout] {
        let petals = signature.petals
        let count = petals.count
        return petals.enumerated().map { index, petal in
            let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
            let length = radius * SignatureEmblemTuning.reachFraction(
                volumeShare: petal.volumeShare
            )
            let halfWidth = SignatureEmblemTuning.halfWidth(
                volumeShare: petal.volumeShare,
                length: length,
                radius: radius
            )
            let shape = SignatureEmblemTuning.petalShape(
                length: length,
                halfWidth: halfWidth
            )
            let hotScale = CGAffineTransform(scaleX: 0.42, y: 0.5)
            let isDominant = petal.group == signature.dominantGroup
            let opacity = SignatureEmblemTuning.petalOpacity(
                volumeShare: petal.volumeShare,
                isDominant: isDominant
            )
            return PetalLayout(
                angle: angle,
                opacity: Swift.min(1, opacity),
                hueShift: SignatureEmblemTuning.hueShift(
                    index: index,
                    count: count
                ),
                isDominant: isDominant,
                shape: shape,
                hotBase: shape.outline.applying(hotScale),
                hotTip: shape.tip.applying(hotScale)
            )
        }
    }

    /// Stable warmth gives the emblem presence before any petal light.
    private func drawAmbientEmber(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let emberRadius = radius * 1.04
        let emberRect = CGRect(
            x: center.x - emberRadius,
            y: center.y - emberRadius,
            width: emberRadius * 2,
            height: emberRadius * 2
        )
        context.fill(
            Path(ellipseIn: emberRect),
            with: .radialGradient(
                Gradient(colors: [
                    Tint.primary.opacity(SignatureEmblemTuning.ambientOpacity),
                    .clear,
                ]),
                center: center,
                startRadius: 0,
                endRadius: emberRadius
            )
        )
    }

    /// Each petal throws a soft halo; the dominant petal contributes a second
    /// pass so the light reinforces the same lead carried by geometry.
    private func drawBloom(
        in context: inout GraphicsContext,
        layouts: [PetalLayout],
        center: CGPoint,
        radius: CGFloat,
        glowBreath: Double
    ) {
        context.drawLayer { bloom in
            bloom.addFilter(
                .blur(
                    radius: radius
                        * SignatureEmblemTuning.bloomRadiusFraction
                )
            )
            for petal in layouts {
                var petalContext = bloom
                petalContext.translateBy(x: center.x, y: center.y)
                petalContext.rotate(by: .radians(petal.angle))
                let strength = petal.opacity
                    * SignatureEmblemTuning.bloomOpacity * glowBreath
                petalContext.fill(
                    petal.shape.outline,
                    with: .color(
                        SignatureEmblemTuning.petalGold(
                            hueShift: petal.hueShift
                        )
                        .opacity(strength)
                    )
                )
                if petal.isDominant {
                    petalContext.fill(
                        petal.shape.outline,
                        with: .color(
                            Tint.primary.opacity(
                                strength
                                    * SignatureEmblemTuning.dominantHaloBoost
                            )
                        )
                    )
                }
            }
        }
    }

    /// Folded undersides, mesh blades, creases, and asymmetric rims are
    /// interleaved petal by petal so the bloom retains its clockwise depth.
    private func drawBodies(
        in context: inout GraphicsContext,
        layouts: [PetalLayout],
        center: CGPoint
    ) {
        for petal in layouts {
            var petalContext = context
            petalContext.translateBy(x: center.x, y: center.y)
            petalContext.rotate(by: .radians(petal.angle))
            let shape = petal.shape
            let gold = SignatureEmblemTuning.petalGold(hueShift: petal.hueShift)
            let ember = SignatureEmblemTuning.petalEmber(hueShift: petal.hueShift)

            var foldedBase = petalContext
            foldedBase.addFilter(
                .shadow(
                    color: .black.opacity(
                        SignatureEmblemTuning.castShadowOpacity
                            * petal.opacity
                    ),
                    radius: SignatureEmblemTuning.castShadowBlur,
                    x: 0.4,
                    y: SignatureEmblemTuning.castShadowOffset
                )
            )
            foldedBase.fill(
                shape.outline,
                with: .linearGradient(
                    SignatureEmblemTuning.foldGradient(
                        opacity: petal.opacity,
                        hueShift: petal.hueShift
                    ),
                    startPoint: .zero,
                    endPoint: shape.tip
                )
            )

            petalContext.fill(
                shape.blade,
                with: .meshGradient(
                    bladeMesh(
                        opacity: petal.opacity,
                        hueShift: petal.hueShift
                    )
                )
            )

            petalContext.stroke(
                shape.crease,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(
                            color: Color.black.opacity(
                                SignatureEmblemTuning.creaseOpacity
                                    * petal.opacity
                            ),
                            location: 0
                        ),
                        .init(
                            color: Color.black.opacity(
                                SignatureEmblemTuning.creaseOpacity
                                    * petal.opacity * 0.25
                            ),
                            location: 1
                        ),
                    ]),
                    startPoint: .zero,
                    endPoint: shape.tip
                ),
                lineWidth: 1.0
            )
            var creaseLight = petalContext
            creaseLight.translateBy(x: 0, y: 0.85)
            creaseLight.stroke(
                shape.crease,
                with: .color(
                    gold.opacity(
                        SignatureEmblemTuning.creaseHighlightOpacity
                            * petal.opacity
                    )
                ),
                lineWidth: 0.6
            )

            petalContext.stroke(
                shape.leadingEdge,
                with: .linearGradient(
                    SignatureEmblemTuning.rimGradient(
                        opacity: petal.opacity,
                        hueShift: petal.hueShift
                    ),
                    startPoint: .zero,
                    endPoint: shape.tip
                ),
                lineWidth: SignatureEmblemTuning.rimLineWidth
            )
            petalContext.stroke(
                shape.trailingEdge,
                with: .color(
                    ember.opacity(
                        SignatureEmblemTuning.trailingRimOpacity
                            * petal.opacity
                    )
                ),
                lineWidth: SignatureEmblemTuning.trailingRimLineWidth
            )
        }
    }

    /// The core's orange light is clipped to petal bodies so roots stay warm
    /// without additive color shifts where all six leaves meet.
    private func drawCoreSpill(
        in context: inout GraphicsContext,
        layouts: [PetalLayout],
        center: CGPoint,
        radius: CGFloat,
        glowBreath: Double
    ) {
        var spill = context
        var bodies = Path()
        for petal in layouts {
            var transform = CGAffineTransform(
                translationX: center.x,
                y: center.y
            )
            transform = transform.rotated(by: petal.angle)
            bodies.addPath(petal.shape.outline.applying(transform))
        }
        spill.clip(to: bodies)
        let spillRadius = radius * SignatureEmblemTuning.coreSpillFraction
        let strength = 0.55 * glowBreath
        spill.fill(
            Path(ellipseIn: CGRect(
                x: center.x - spillRadius,
                y: center.y - spillRadius,
                width: spillRadius * 2,
                height: spillRadius * 2
            )),
            with: .radialGradient(
                SignatureEmblemTuning.coreSpillGradient(strength: strength),
                center: center,
                startRadius: 0,
                endRadius: spillRadius
            )
        )
    }

    /// One orange pass relights roots and curved specular streaks without
    /// shifting their material palette.
    private func drawHotPass(
        in context: inout GraphicsContext,
        layouts: [PetalLayout],
        center: CGPoint,
        radius: CGFloat,
        glowBreath: Double
    ) {
        var hot = context
        hot.addFilter(
            .blur(radius: radius * SignatureEmblemTuning.hotRadiusFraction)
        )
        for petal in layouts {
            var petalContext = hot
            petalContext.translateBy(x: center.x, y: center.y)
            petalContext.rotate(by: .radians(petal.angle))
            let gold = SignatureEmblemTuning.petalGold(hueShift: petal.hueShift)
            petalContext.fill(
                petal.hotBase,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(
                            color: gold.opacity(
                                petal.opacity * 0.6 * glowBreath
                            ),
                            location: 0
                        ),
                        .init(
                            color: Tint.primary.opacity(
                                petal.opacity * 0.2 * glowBreath
                            ),
                            location: 0.5
                        ),
                        .init(color: .clear, location: 1),
                    ]),
                    startPoint: .zero,
                    endPoint: petal.hotTip
                )
            )
            petalContext.stroke(
                petal.shape.specular,
                with: .color(
                    gold.opacity(
                        SignatureEmblemTuning.specularOpacity * petal.opacity
                    )
                ),
                style: StrokeStyle(
                    lineWidth: SignatureEmblemTuning.specularLineWidth,
                    lineCap: .round
                )
            )
        }
    }

    /// The mesh is hottest at the root, full brand orange through the belly,
    /// and deep ember at the tip.
    private func bladeMesh(opacity: Double, hueShift: Double) -> MeshGradient {
        let hot = SignatureEmblemTuning.petalHot(hueShift: hueShift)
        let gold = SignatureEmblemTuning.petalGold(hueShift: hueShift)
        let ember = SignatureEmblemTuning.petalEmber(hueShift: hueShift)
        return MeshGradient(
            width: 3,
            height: 3,
            points: Self.bladeMeshPoints,
            colors: [
                gold.opacity(opacity * 0.8),
                Tint.primary.opacity(opacity * 0.8),
                ember.opacity(opacity * 0.42),
                hot.opacity(min(1, opacity * 1.1)),
                gold.opacity(min(1, opacity * 1.05)),
                ember.opacity(opacity * 0.6),
                gold.opacity(opacity * 0.72),
                Tint.primary.opacity(opacity * 0.72),
                ember.opacity(opacity * 0.4),
            ],
            smoothsColors: true,
            colorSpace: .perceptual
        )
    }

    private static let bladeMeshPoints: [SIMD2<Float>] = [
        SIMD2<Float>(0, 0), SIMD2<Float>(0.5, 0), SIMD2<Float>(1, 0),
        SIMD2<Float>(0, 0.5), SIMD2<Float>(0.38, 0.45), SIMD2<Float>(1, 0.5),
        SIMD2<Float>(0, 1), SIMD2<Float>(0.55, 1), SIMD2<Float>(1, 1),
    ]

    /// Sparks rise within the bloom's warmth and twinkle on the same ambient
    /// timeline; the still frame fixes both drift and twinkle.
    private func drawEmberDust(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        var sparks = context
        sparks.blendMode = .plusLighter
        let burn = 0.28
        for index in 0 ..< 6 {
            let seed = Double(index)
            let drift = frame.isAnimated
                ? frame.time * (0.010 + seed * 0.002)
                : 0
            let angle = seed * 2.399963 + 0.35 + drift
            let distance = radius * (0.2 + 0.07 * Double((index * 3) % 5))
            let twinkle = frame.isAnimated
                ? 0.55 + 0.45
                * sin(frame.time * (0.45 + seed * 0.04) + seed * 1.7)
                : 0.65
            let size = 1.8 + CGFloat(index % 3) * 0.7
            let point = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )
            let rect = CGRect(
                x: point.x - size,
                y: point.y - size,
                width: size * 2,
                height: size * 2
            )
            sparks.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        SignatureEmblemTuning.petalHot(
                            hueShift: SignatureEmblemTuning.hueShift(
                                index: index,
                                count: 6
                            )
                        )
                        .opacity(burn * twinkle),
                        .clear,
                    ]),
                    center: point,
                    startRadius: 0,
                    endRadius: size
                )
            )
        }
    }
}
