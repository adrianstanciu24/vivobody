//
//  SignatureSection.swift
//  vivobody
//
//  The Insights hero — the screen opens on a portrait, not a table.
//  A single generative emblem compresses lifetime allocation into a
//  mark you'd recognise as *yours*: six petals (one per muscle group)
//  whose complete silhouette is driven by how much of your lifetime
//  volume that region carries. A numeral at each axis states the split
//  outright, an equal-share ghost gives it context, and a single
//  satellite orbits the ring for life.
//
//  It deliberately carries the group-balance read the old tab spread
//  across a separate roster — so this one mark answers "what's the
//  shape of my training?" — anchored only by evenness and coverage.
//  Cadence belongs to Rhythm. Every data-bearing channel is all-time;
//  light and motion are material, not hidden metrics.
//
//  No anatomical body here on purpose: the rotatable 3D figure is
//  Today's hero. Insights is the analytical counterpart, and the
//  emblem is its signature.
//

import SwiftUI
import VivoKit

struct SignatureSection: View {
    let signature: TrainingSignature

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Training shape",
                trailing: signature.hasSignature ? "all time" : "first signal",
                trailingIsInProgress: !signature.hasSignature,
                accessibilityIdentifier: "insightsShapeInstrument"
            )

            if dynamicTypeSize.isAccessibilitySize {
                SignatureAccessibilitySpectrum(signature: signature)
            } else {
                TrainingSignatureView(signature: signature)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.sm)
            }

            if !signature.hasSignature {
                Text("waiting for the first muscle-mapped set")
                    .panelLegend()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Space.sm)
            } else {
                Text(focusLabel)
                    .font(Typography.display)
                    .foregroundStyle(Tint.primaryText)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                StatStrip(
                    stats: [
                        Stat(
                            value: signature.hasVolume
                                ? "\(Int((signature.balance * 100).rounded()))"
                                : "—",
                            unit: signature.hasVolume ? "%" : nil,
                            label: "Evenness"
                        ),
                        Stat(
                            value: "\(signature.trainedGroupCount)/6",
                            label: "Regions trained"
                        ),
                    ],
                    valueFont: Typography.statValue
                )
                .padding(.vertical, Space.xs)

                HStack(spacing: Space.sm) {
                    Capsule(style: .continuous)
                        .stroke(
                            Ink.primary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                        .frame(width: 28, height: 8)
                        .accessibilityHidden(true)
                    Text("dashed = even six-way share")
                        .panelLegend()
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Dashed petals show an even six-way share")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var focusLabel: String {
        guard signature.hasSignature else { return "Awaiting history" }
        if let group = signature.dominantGroup {
            return "\(group.displayName)-led"
        }
        if signature.trainedGroupCount == MuscleGroup.allCases.count,
           signature.balance >= TrainingSignature.evenBalanceThreshold
        {
            return "Evenly spread"
        }
        return "No single lead"
    }
}

// MARK: - Training signature emblem

/// The signature bloom. Six petals radiate from a core — one per
/// muscle group, fixed at the wheel position its order assigns — each
/// growing in both reach and width from its all-time volume share,
/// with the split stated outright by a numeral at each axis. A faint
/// ring frames it, a dashed ghost shows an even six-way split, a lone
/// satellite orbits the rim, and the whole emblem keeps a stable burn.
/// Every load-bearing number comes from VivoKit's `SignatureEmblemTuning`
/// so the widget draws the identical shape. Drawn in a single Canvas:
/// a restrained bloom pass glows beneath crisp orange-gradient petals,
/// brightest at the core and cooling toward the tips.
///
/// The mark is quietly alive: the core breathes, the bloom's glow dims
/// and swells with it, and the satellite laps the rim like a watch
/// movement. Petal geometry and material never move; the shape is the
/// data, while the light is ambient. Holds perfectly still under
/// Reduce Motion.
private struct TrainingSignatureView: View {
    let signature: TrainingSignature

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Ambient-motion tuning — the numbers to play with when judging
    /// how alive the emblem should feel.
    private enum Motion {
        /// One full satellite lap around the rim takes this long.
        static let satelliteLapSeconds: Double = 75

        /// One core breath (swell and relax) takes this long.
        static let breathSeconds: Double = 4

        /// Stable ambient breath. It carries no training data.
        static let breathStrength: Double = 0.72

        /// Core radius gain at the top of a full-strength breath.
        static let coreSwell: Double = 0.3

        /// Peak opacity of the halo the core exhales.
        static let haloOpacity: Double = 0.35

        /// How deeply the bloom's additive light dims at the bottom
        /// of a breath. Glow only — petal geometry and material are
        /// the data and never move.
        static let glowBreathDepth: Double = 0.22
    }

    var body: some View {
        Group {
            if reduceMotion {
                emblem(time: 0, animated: false)
            } else {
                // 30fps is plenty for a slow breath and a creeping orbit.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    emblem(time: timeline.date.timeIntervalSinceReferenceDate, animated: true)
                }
            }
        }
        .frame(height: 272)
        .accessibilityLabel(Text(accessibilityText))
    }

    private func emblem(time: TimeInterval, animated: Bool) -> some View {
        Canvas { context, size in
            let interval = GraphicsPerformanceSignposts.begin("TrainingSignature.draw")
            defer { GraphicsPerformanceSignposts.end("TrainingSignature.draw", interval) }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = Swift.min(size.width, size.height) / 2
            let breath = animated ? (sin(time * 2 * .pi / Motion.breathSeconds) + 1) / 2 : 0
            let orbit = animated ? (time / Motion.satelliteLapSeconds) * 2 * .pi : 0

            drawAtmosphere(in: &context, center: center, radius: radius)
            drawRing(in: &context, center: center, radius: radius)
            drawSpokes(in: &context, center: center, radius: radius)
            drawSatellite(in: &context, center: center, radius: radius, orbit: orbit, animated: animated)
            drawGhostBloom(in: &context, center: center, radius: radius)
            // At rest the petal sits at full burn (breath 1); the core's
            // halo instead vanishes at rest (breath 0) — hence two values.
            drawPetals(
                in: &context,
                center: center,
                radius: radius,
                breath: animated ? breath : 1,
                time: time,
                animated: animated
            )
            drawLabels(in: &context, center: center, radius: radius)
            drawCore(in: &context, center: center, radius: radius, breath: breath)
        }
    }

    /// The night the bloom sits in — a barely-lit pocket of warm air
    /// instead of dead flat black, so the emblem has depth before a
    /// single petal is drawn.
    private func drawAtmosphere(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let r = radius * SignatureEmblemTuning.atmosphereFraction
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                SignatureEmblemTuning.atmosphereGradient(),
                center: center,
                startRadius: 0,
                endRadius: r
            )
        )
    }

    private func drawRing(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let r = radius * SignatureEmblemTuning.ringFraction
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(Surface.cardTint), lineWidth: 1)
    }

    /// A faint guide line from the core out to the ring, anchoring
    /// each petal to its named axis — without it the eye can't tell
    /// which label a stubby petal belongs to. Spokes end at the ring
    /// so they never pierce the label band and read as pins. The
    /// dominant region's spoke is lit so "legs-led" reads straight
    /// off the emblem, reinforced by its tinted label and numeral.
    private func drawSpokes(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let petals = signature.petals
        let count = petals.count
        guard count > 0 else { return }
        let inner = radius * SignatureEmblemTuning.spokeInnerFraction
        let outer = radius * SignatureEmblemTuning.ringFraction
        for (i, petal) in petals.enumerated() {
            let angle = (Double(i) / Double(count)) * 2 * .pi - .pi / 2
            let isDominant = petal.group == signature.dominantGroup
            var path = Path()
            path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
            context.stroke(
                path,
                with: .color(isDominant ? Tint.primary.opacity(0.45) : Ink.primary.opacity(0.05)),
                lineWidth: 1
            )
        }
    }

    /// A single dim bead lapping the ring — pure ambient life, like a
    /// watch movement. It deliberately carries no data: the old ring
    /// of cadence beads sat on the label ring and read as markers
    /// flagging whichever axis they passed, so cadence now lives in
    /// the stat strip as a plain numeral and the bloom keeps only the
    /// motion. At rest the bead parks off-axis so the still emblem
    /// never reads it as flagging a muscle group.
    private func drawSatellite(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, orbit: Double, animated: Bool) {
        let r = radius * SignatureEmblemTuning.ringFraction
        let angle = orbit - .pi / 2 + (animated ? 0 : 0.9)
        let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
        let dot = CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)
        context.fill(Path(ellipseIn: dot), with: .color(Tint.primary.opacity(0.3)))
    }

    /// The equal-share bloom: six identical dashed leaves showing the
    /// silhouette of a perfectly even 1/6 allocation. Live petals
    /// outside or inside it make the lifetime bias visible at a glance.
    private func drawGhostBloom(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let count = signature.petals.count
        guard count > 0 else { return }
        let share = SignatureEmblemTuning.equalShare
        let length = radius * SignatureEmblemTuning.reachFraction(volumeShare: share)
        let halfWidth = SignatureEmblemTuning.halfWidth(
            volumeShare: share,
            length: length,
            radius: radius
        )
        let leaf = SignatureEmblemTuning.petalPath(length: length, halfWidth: halfWidth)

        for i in 0 ..< count {
            let angle = (Double(i) / Double(count)) * 2 * .pi - .pi / 2
            var transform = CGAffineTransform(translationX: center.x, y: center.y)
            transform = transform.rotated(by: angle)
            context.stroke(
                leaf.applying(transform),
                with: .color(Ink.primary.opacity(SignatureEmblemTuning.ghostOpacity)),
                style: StrokeStyle(lineWidth: SignatureEmblemTuning.ghostLineWidth, dash: SignatureEmblemTuning.ghostDash)
            )
        }
    }

    /// One petal's placement and burn for a frame.
    private struct PetalLayout {
        let angle: Double
        let opacity: Double
        let hueShift: Double
        let isDominant: Bool
        let shape: SignatureEmblemTuning.PetalShape
        let hotBase: Path
        let hotTip: CGPoint
    }

    private func petalLayouts(radius: CGFloat) -> [PetalLayout] {
        let petals = signature.petals
        let count = petals.count
        return petals.enumerated().map { i, petal in
            let angle = (Double(i) / Double(count)) * 2 * .pi - .pi / 2
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
                hueShift: SignatureEmblemTuning.hueShift(index: i, count: count),
                isDominant: isDominant,
                shape: shape,
                hotBase: shape.outline.applying(hotScale),
                hotTip: shape.tip.applying(hotScale)
            )
        }
    }

    /// Each leaf is a small material study: its folded underside casts
    /// onto the leaf below, a mesh-gradient blade carries light in two
    /// axes, the logo cleft separates both planes, and a soft specular
    /// streak catches near the bright orange core.
    private func drawPetals(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        breath: Double,
        time: TimeInterval,
        animated: Bool
    ) {
        let layout = petalLayouts(radius: radius)

        // Only the light breathes: every additive pass below dims and
        // swells with the core's beat while the petal material — the
        // data — holds perfectly still.
        let glowBreath = 1 - Motion.glowBreathDepth
            * Motion.breathStrength * (1 - breath)

        // Ambient ember — the emblem's presence on the black canvas,
        // providing stable material warmth.
        let emberR = radius * 1.04
        let emberRect = CGRect(x: center.x - emberR, y: center.y - emberR, width: emberR * 2, height: emberR * 2)
        context.fill(
            Path(ellipseIn: emberRect),
            with: .radialGradient(
                Gradient(colors: [
                    Tint.primary.opacity(SignatureEmblemTuning.ambientOpacity),
                    .clear,
                ]),
                center: center,
                startRadius: 0,
                endRadius: emberR
            )
        )

        // The halo each petal throws on the dark. The dominant petal
        // is drawn into the bloom twice — the data's lead is also the
        // light's lead.
        context.drawLayer { bloom in
            bloom.addFilter(.blur(radius: radius * SignatureEmblemTuning.bloomRadiusFraction))
            for petal in layout {
                var c = bloom
                c.translateBy(x: center.x, y: center.y)
                c.rotate(by: .radians(petal.angle))
                let strength = petal.opacity * SignatureEmblemTuning.bloomOpacity * glowBreath
                c.fill(
                    petal.shape.outline,
                    with: .color(
                        SignatureEmblemTuning.petalGold(hueShift: petal.hueShift)
                            .opacity(strength)
                    )
                )
                if petal.isDominant {
                    c.fill(
                        petal.shape.outline,
                        with: .color(
                            Tint.primary.opacity(strength * SignatureEmblemTuning.dominantHaloBoost)
                        )
                    )
                }
            }
        }

        drawEmberDust(
            in: &context,
            center: center,
            radius: radius,
            time: time,
            animated: animated
        )

        // Bodies are deliberately interleaved with their shadows.
        // Later leaves overlap earlier ones, making the clockwise sweep
        // read as a stacked bloom instead of six coplanar lenses.
        for petal in layout {
            var c = context
            c.translateBy(x: center.x, y: center.y)
            c.rotate(by: .radians(petal.angle))
            let shape = petal.shape
            let gold = SignatureEmblemTuning.petalGold(hueShift: petal.hueShift)
            let ember = SignatureEmblemTuning.petalEmber(hueShift: petal.hueShift)

            var foldedBase = c
            foldedBase.addFilter(
                .shadow(
                    color: .black.opacity(SignatureEmblemTuning.castShadowOpacity * petal.opacity),
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

            c.fill(
                shape.blade,
                with: .meshGradient(
                    bladeMesh(opacity: petal.opacity, hueShift: petal.hueShift)
                )
            )

            // The crease fades as it leaves the root so it reads as a
            // fold in the leaf, not a crack across the light.
            c.stroke(
                shape.crease,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(
                            color: Color.black.opacity(SignatureEmblemTuning.creaseOpacity * petal.opacity),
                            location: 0
                        ),
                        .init(
                            color: Color.black.opacity(SignatureEmblemTuning.creaseOpacity * petal.opacity * 0.25),
                            location: 1
                        ),
                    ]),
                    startPoint: .zero,
                    endPoint: shape.tip
                ),
                lineWidth: 1.0
            )
            var creaseLight = c
            creaseLight.translateBy(x: 0, y: 0.85)
            creaseLight.stroke(
                shape.crease,
                with: .color(
                    gold.opacity(SignatureEmblemTuning.creaseHighlightOpacity * petal.opacity)
                ),
                lineWidth: 0.6
            )

            c.stroke(
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
            c.stroke(
                shape.trailingEdge,
                with: .color(
                    ember.opacity(SignatureEmblemTuning.trailingRimOpacity * petal.opacity)
                ),
                lineWidth: SignatureEmblemTuning.trailingRimLineWidth
            )
        }

        // The core's orange light landing on the bloom, clipped to
        // the petal bodies so the roots stay warm without additive
        // colour shifts where all six leaves converge.
        do {
            var spill = context
            var bodies = Path()
            for petal in layout {
                var transform = CGAffineTransform(translationX: center.x, y: center.y)
                transform = transform.rotated(by: petal.angle)
                bodies.addPath(petal.shape.outline.applying(transform))
            }
            spill.clip(to: bodies)
            let spillR = radius * SignatureEmblemTuning.coreSpillFraction
            let strength = 0.55 * glowBreath
            spill.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - spillR,
                    y: center.y - spillR,
                    width: spillR * 2,
                    height: spillR * 2
                )),
                with: .radialGradient(
                    SignatureEmblemTuning.coreSpillGradient(strength: strength),
                    center: center,
                    startRadius: 0,
                    endRadius: spillR
                )
            )
        }

        // One orange pass relights both the root and the curved
        // specular streak without additive colour shifts.
        do {
            var hot = context
            hot.addFilter(.blur(radius: radius * SignatureEmblemTuning.hotRadiusFraction))
            for petal in layout {
                var c = hot
                c.translateBy(x: center.x, y: center.y)
                c.rotate(by: .radians(petal.angle))
                let gold = SignatureEmblemTuning.petalGold(hueShift: petal.hueShift)
                c.fill(
                    petal.hotBase,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: gold.opacity(petal.opacity * 0.6 * glowBreath), location: 0),
                            .init(color: Tint.primary.opacity(petal.opacity * 0.2 * glowBreath), location: 0.5),
                            .init(color: .clear, location: 1),
                        ]),
                        startPoint: .zero,
                        endPoint: petal.hotTip
                    )
                )
                c.stroke(
                    petal.shape.specular,
                    with: .color(
                        gold.opacity(SignatureEmblemTuning.specularOpacity * petal.opacity)
                    ),
                    style: StrokeStyle(
                        lineWidth: SignatureEmblemTuning.specularLineWidth,
                        lineCap: .round
                    )
                )
            }
        }
    }

    /// The blade's material: bright orange at the root column, full
    /// brand orange through the belly, and deep ember at the tip.
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

    /// Sparks rising off the burn — additive so they read as motes of
    /// the core's light, never as stray grey dots. They stay inside
    /// the bloom's warmth and twinkle on the fire's timetable.
    private func drawEmberDust(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        time: TimeInterval,
        animated: Bool
    ) {
        var sparks = context
        sparks.blendMode = .plusLighter
        let burn = 0.28
        for index in 0 ..< 6 {
            let seed = Double(index)
            let drift = animated ? time * (0.010 + seed * 0.002) : 0
            let angle = seed * 2.399963 + 0.35 + drift
            let distance = radius * (0.2 + 0.07 * Double((index * 3) % 5))
            let twinkle = animated
                ? 0.55 + 0.45 * sin(time * (0.45 + seed * 0.04) + seed * 1.7)
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
                            hueShift: SignatureEmblemTuning.hueShift(index: index, count: 6)
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

    /// Axis labels, each with the group's share of volume stated
    /// outright: petal width is the weakest channel to judge, so the
    /// numeral carries the split. Name and numeral stack vertically in
    /// screen space — two radial offsets would overlap at diagonal
    /// axes. The dominant axis is tinted to match its lit spoke; an
    /// untrained group shows a name only.
    private func drawLabels(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let petals = signature.petals
        let count = petals.count
        for (i, petal) in petals.enumerated() {
            let angle = (Double(i) / Double(count)) * 2 * .pi - .pi / 2
            let isDominant = petal.group == signature.dominantGroup
            let labelPoint = CGPoint(
                x: center.x + cos(angle) * radius * SignatureEmblemTuning.labelFraction,
                y: center.y + sin(angle) * radius * SignatureEmblemTuning.labelFraction
            )
            let name = Text(petal.group.displayName.uppercased())
                .font(Typography.micro)
                .fontWeight(isDominant ? .bold : .medium)
                .foregroundStyle(isDominant ? Tint.primaryText : Ink.tertiary)
            context.draw(name, at: CGPoint(x: labelPoint.x, y: labelPoint.y - 7), anchor: .center)

            guard petal.volumeShare > 0 else { continue }
            let numeral = Text(signatureShareLabel(petal.volumeShare))
                .font(Typography.micro.monospacedDigit())
                .foregroundStyle(isDominant ? Tint.primaryText : Ink.secondary)
            context.draw(numeral, at: CGPoint(x: labelPoint.x, y: labelPoint.y + 7), anchor: .center)
        }
    }

    private func drawCore(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, breath: Double) {
        let strength = Motion.breathStrength * breath
        let r = radius * 0.05 * (1 + CGFloat(Motion.coreSwell * strength))

        // Contact shadow tucks every petal root beneath the bead. The
        // bright halo is drawn afterward, preserving the core's light
        // while leaving a narrow depth seam at its edge.
        let contactR = r * 2.05
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - contactR,
                y: center.y - contactR,
                width: contactR * 2,
                height: contactR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [Color.black.opacity(0.52), .clear]),
                center: center,
                startRadius: r * 0.78,
                endRadius: contactR
            )
        )

        // The exhale: a soft halo that swells and fades with the beat.
        // At rest (breath == 0) it vanishes and the core sits at its
        // base size — exactly the still emblem Reduce Motion renders.
        if strength > 0 {
            let haloR = r * 2.9
            let haloRect = CGRect(x: center.x - haloR, y: center.y - haloR, width: haloR * 2, height: haloR * 2)
            context.fill(
                Path(ellipseIn: haloRect),
                with: .radialGradient(
                    Gradient(colors: [Tint.primary.opacity(Motion.haloOpacity * strength), .clear]),
                    center: center,
                    startRadius: 0,
                    endRadius: haloR
                )
            )
        }

        // The lens streak — a hairline horizontal flare through the
        // bead, the cue that makes it read as a photographed light
        // source rather than a dot. It rides the breath: a touch
        // longer and brighter at the top of each swell.
        do {
            let flare = context
            let streakR = radius * 0.3 * (0.85 + 0.3 * CGFloat(strength))
            let glow = 0.7 + 0.3 * strength
            let soft = CGRect(x: center.x - streakR, y: center.y - 1.6, width: streakR * 2, height: 3.2)
            flare.fill(
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
            let hair = CGRect(x: center.x - streakR * 0.72, y: center.y - 0.6, width: streakR * 1.44, height: 1.2)
            flare.fill(
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

        // The core stays inside one orange ramp, avoiding a pale
        // additive center where all six petal roots meet.
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
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
                endRadius: r
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

    private var accessibilityText: String {
        let split = signature.petals
            .filter { $0.volumeShare > 0 }
            .map { "\($0.group.displayName) \(signatureShareSpokenLabel($0.volumeShare))" }
            .joined(separator: ", ")
        let volume = if !signature.hasSignature {
            "No signature data yet. Complete a strength set on an exercise with muscle targets to begin."
        } else if signature.hasVolume {
            "All-time volume split: \(split). Balance \(Int((signature.balance * 100).rounded())) percent, with \(signature.trainedGroupCount) of 6 regions represented."
        } else {
            "No completed muscle-targeted strength work yet."
        }
        return "Training signature. \(volume) \(signature.identityLine). Dashed outlines show an even six-way split."
    }
}
