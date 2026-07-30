//
//  SignatureSection.swift
//  vivobody
//
//  The Insights hero — the screen opens on a portrait, not a table.
//  A single generative emblem fuses the whole picture into a mark
//  you'd recognise as *yours*: six petals (one per muscle group)
//  whose reach is how developed the region is and whose width is how
//  much of your volume it carries, burning brighter the harder you
//  train. A numeral at each axis states the volume split outright,
//  and a single satellite orbits the ring for life.
//
//  It deliberately carries the group-balance read the old tab spread
//  across a separate roster — so this one mark answers "what's the
//  shape of my training?" — anchored by three plain numbers (cadence,
//  streak, balance) and a concise visual legend.
//
//  No anatomical body here on purpose: the rotatable 3D figure is
//  Today's hero. Insights is the analytical counterpart, and the
//  emblem is its signature.
//

import VivoKit
import SwiftUI

struct SignatureSection: View {
    let signature: TrainingSignature
    let report: ConsistencyReport

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                SectionHeader(title: "Your signature")
                Text("the shape of your training")
                    .panelLegend()
            }

            if !signature.hasSignature {
                Text("Your signature takes shape once you've logged some training — a living portrait of how you train, all of it in one mark.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                TrainingSignatureView(signature: signature)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.sm)

                StatStrip(
                    stats: [
                        Stat(value: InsightsFormat.perWeekLabel(signature.cadence), label: "Per week", accent: signature.cadence >= 2),
                        Stat(value: "\(report.weekStreak)", label: "Week streak"),
                        Stat(value: "\(Int((signature.balance * 100).rounded()))", unit: "%", label: "Balance"),
                    ],
                    valueFont: Typography.statValue,
                    edgeAligned: true
                )
                .padding(.vertical, Space.xs)

                Text("Each petal is a muscle group — its reach is how developed it is, its width and the numeral at its axis how much of your volume it takes. The dashed ghost is the bloom fully grown; the brighter the burn, the harder the training.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

// MARK: - Training signature emblem

/// The signature bloom. Six petals radiate from a core — one per
/// muscle group, fixed at the wheel position its order assigns — each
/// reaching out by how developed the region is and fattened by how
/// much of your volume it carries, with the split stated outright by
/// a numeral at each axis. A faint ring frames it, a dashed ghost
/// outlines the bloom fully grown, a lone satellite orbits the rim,
/// and the whole emblem burns brighter the harder the training. Every
/// load-bearing number comes from VivoKit's `SignatureEmblemTuning`
/// so the widget draws the identical shape. Drawn in a single Canvas:
/// a blurred bloom pass glows beneath crisp flame-gradient petals,
/// all blended additively so the emblem reads as light — incandescent
/// at the core, cooling toward the tips.
///
/// The mark is quietly alive: the core breathes — swelling harder the
/// more intense the training — the dominant petal's burn dims and
/// swells in step with it, and the satellite laps the rim like a
/// watch movement. Petal geometry never moves; the shape is the data,
/// only its light breathes. Holds perfectly still under Reduce Motion.
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

        /// How much the breath registers at all — scaled by training
        /// intensity so a hard block beats visibly and a light week
        /// barely stirs, but the heart never fully stops.
        static func breathStrength(for intensity: Double) -> Double {
            0.2 + 0.8 * intensity
        }

        /// Core radius gain at the top of a full-strength breath.
        static let coreSwell: Double = 0.3

        /// Peak opacity of the halo the core exhales.
        static let haloOpacity: Double = 0.35

        /// How deeply the dominant petal's burn dims at the bottom of
        /// a breath, as a fraction of its resting opacity. Luminance
        /// only — petal geometry is the data and never moves.
        static let petalBreathDepth: Double = 0.25
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

            drawRing(in: &context, center: center, radius: radius)
            drawSpokes(in: &context, center: center, radius: radius)
            drawSatellite(in: &context, center: center, radius: radius, orbit: orbit, animated: animated)
            drawGhostBloom(in: &context, center: center, radius: radius)
            // At rest the petal sits at full burn (breath 1); the core's
            // halo instead vanishes at rest (breath 0) — hence two values.
            drawPetals(in: &context, center: center, radius: radius, breath: animated ? breath : 1)
            drawLabels(in: &context, center: center, radius: radius)
            drawCore(in: &context, center: center, radius: radius, breath: breath)
        }
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

    /// The ghost bloom: every petal outlined at full development and
    /// full width, the silhouette the live petals grow into. Six
    /// identical dashed leaves, faint enough to read as aspiration
    /// rather than data — the gap between ghost and fill is the
    /// "how much further can this grow" answer at a glance.
    private func drawGhostBloom(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let count = signature.petals.count
        guard count > 0 else { return }
        let length = radius * SignatureEmblemTuning.reachFraction(development: 1)
        let halfWidth = SignatureEmblemTuning.halfWidth(shareNorm: 1, length: length, radius: radius)
        let leaf = SignatureEmblemTuning.petalPath(length: length, halfWidth: halfWidth)

        for i in 0..<count {
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
        let length: CGFloat
        let halfWidth: CGFloat
        let opacity: Double
    }

    /// The leaf in local coordinates (base at the origin, tip at
    /// (length, 0)) comes from VivoKit's `SignatureEmblemTuning` so
    /// the widget's bloom is the identical silhouette.

    private func petalLayouts(radius: CGFloat, breath: Double) -> [PetalLayout] {
        let petals = signature.petals
        let count = petals.count
        let maxShare = petals.map(\.volumeShare).max() ?? 0
        return petals.enumerated().map { i, petal in
            let angle = (Double(i) / Double(count)) * 2 * .pi - .pi / 2
            // Reach to near the label ring at full development so a
            // strong region visibly touches its axis.
            let length = radius * SignatureEmblemTuning.reachFraction(development: petal.development)
            let shareNorm = maxShare > 0 ? petal.volumeShare / maxShare : 0
            let halfWidth = SignatureEmblemTuning.halfWidth(shareNorm: shareNorm, length: length, radius: radius)
            let isDominant = petal.group == signature.dominantGroup
            var opacity = SignatureEmblemTuning.petalOpacity(
                development: petal.development,
                intensity: signature.intensity,
                isDominant: isDominant
            )
            if isDominant {
                // The lead petal's burn breathes in step with the core —
                // dimming from its resting brightness and swelling back,
                // scaled by intensity like the core's beat.
                let depth = Motion.petalBreathDepth * Motion.breathStrength(for: signature.intensity)
                opacity *= 1 - depth * (1 - breath)
            }
            return PetalLayout(angle: angle, length: length, halfWidth: halfWidth, opacity: Swift.min(1, opacity))
        }
    }

    /// Petals are lit forms, not cut paper — the same light the logo
    /// is drawn with. Five passes build the depth: a broad ambient
    /// ember warms the black canvas beneath the whole bloom; a
    /// blurred additive bloom pass glows; a crisp body pass carries
    /// the multi-stop burn (incandescent gold at the core cooling to
    /// deep ember at the tip); a short additive hot-base pass relights
    /// each petal's root so the heart sums toward white; and a fine
    /// rim light plus a whisper of vein give each petal a definite,
    /// crafted silhouette.
    private func drawPetals(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, breath: Double) {
        let layout = petalLayouts(radius: radius, breath: breath)

        // Ambient ember — the emblem's presence on the black canvas,
        // warming with training intensity.
        let emberR = radius * 1.04
        let emberRect = CGRect(x: center.x - emberR, y: center.y - emberR, width: emberR * 2, height: emberR * 2)
        context.fill(
            Path(ellipseIn: emberRect),
            with: .radialGradient(
                Gradient(colors: [
                    Tint.primary.opacity(SignatureEmblemTuning.ambientOpacity(intensity: signature.intensity)),
                    .clear,
                ]),
                center: center,
                startRadius: 0,
                endRadius: emberR
            )
        )

        context.drawLayer { bloom in
            bloom.addFilter(.blur(radius: radius * 0.05))
            bloom.blendMode = .plusLighter
            for petal in layout {
                var c = bloom
                c.translateBy(x: center.x, y: center.y)
                c.rotate(by: .radians(petal.angle))
                c.fill(
                    SignatureEmblemTuning.petalPath(length: petal.length, halfWidth: petal.halfWidth),
                    with: .color(Tint.primary.opacity(petal.opacity * 0.5))
                )
            }
        }

        // Body — the definite form, in normal blend so the multi-stop
        // burn reads true.
        for petal in layout {
            var c = context
            c.translateBy(x: center.x, y: center.y)
            c.rotate(by: .radians(petal.angle))
            c.fill(
                SignatureEmblemTuning.petalPath(length: petal.length, halfWidth: petal.halfWidth),
                with: .linearGradient(
                    SignatureEmblemTuning.burnGradient(opacity: petal.opacity),
                    startPoint: .zero,
                    endPoint: CGPoint(x: petal.length, y: 0)
                )
            )
        }

        // Hot base — a soft additive relight of each petal's root, so
        // the heart of the bloom sums toward incandescent. Blurred so
        // no edge can read as a separate shape.
        do {
            var hot = context
            hot.blendMode = .plusLighter
            hot.addFilter(.blur(radius: radius * 0.02))
            for petal in layout {
                var c = hot
                c.translateBy(x: center.x, y: center.y)
                c.rotate(by: .radians(petal.angle))
                let l = petal.length * 0.42
                c.fill(
                    SignatureEmblemTuning.petalPath(length: l, halfWidth: petal.halfWidth * 0.5),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: SignatureEmblemTuning.burnGold.opacity(petal.opacity * 0.45), location: 0),
                            .init(color: Tint.primary.opacity(petal.opacity * 0.15), location: 0.5),
                            .init(color: .clear, location: 1),
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: l, y: 0)
                    )
                )
            }
        }

        // Cross-section shading, rim light and vein — the folded-leaf
        // volume, the crafted edge and the cleft, all scaled by the
        // petal's burn so faint regions stay faint.
        for petal in layout {
            var c = context
            c.translateBy(x: center.x, y: center.y)
            c.rotate(by: .radians(petal.angle))
            let path = SignatureEmblemTuning.petalPath(length: petal.length, halfWidth: petal.halfWidth)

            let shade = Tint.primaryShadow.opacity(SignatureEmblemTuning.edgeShadeOpacity * petal.opacity)
            let spine = SignatureEmblemTuning.burnGold.opacity(SignatureEmblemTuning.spineLightOpacity * petal.opacity)
            c.fill(
                path,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: shade, location: 0),
                        .init(color: spine, location: 0.5),
                        .init(color: shade, location: 1),
                    ]),
                    startPoint: CGPoint(x: 0, y: -petal.halfWidth),
                    endPoint: CGPoint(x: 0, y: petal.halfWidth)
                )
            )

            let rim = Gradient(stops: [
                .init(color: SignatureEmblemTuning.burnGold.opacity(SignatureEmblemTuning.rimOpacity * petal.opacity), location: 0),
                .init(color: Tint.primary.opacity(SignatureEmblemTuning.rimOpacity * SignatureEmblemTuning.rimTipScale * petal.opacity), location: 1),
            ])
            c.stroke(
                path,
                with: .linearGradient(rim, startPoint: .zero, endPoint: CGPoint(x: petal.length, y: 0)),
                lineWidth: SignatureEmblemTuning.rimLineWidth
            )
            var vein = Path()
            vein.move(to: CGPoint(x: petal.length * 0.12, y: 0))
            vein.addQuadCurve(
                to: CGPoint(x: petal.length * 0.86, y: 0),
                control: CGPoint(x: petal.length * 0.5, y: petal.halfWidth * 0.05)
            )
            c.stroke(
                vein,
                with: .color(Tint.primaryShadow.opacity(SignatureEmblemTuning.veinOpacity * petal.opacity)),
                lineWidth: 1
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
                .foregroundStyle(isDominant ? Tint.primary : Ink.tertiary)
            context.draw(name, at: CGPoint(x: labelPoint.x, y: labelPoint.y - 7), anchor: .center)

            guard petal.volumeShare > 0 else { continue }
            let numeral = Text("\(Int((petal.volumeShare * 100).rounded()))%")
                .font(Typography.micro.monospacedDigit())
                .foregroundStyle(isDominant ? Tint.primary.opacity(0.75) : Ink.secondary)
            context.draw(numeral, at: CGPoint(x: labelPoint.x, y: labelPoint.y + 7), anchor: .center)
        }
    }

    private func drawCore(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, breath: Double) {
        let strength = Motion.breathStrength(for: signature.intensity) * breath
        let r = radius * 0.05 * (1 + CGFloat(Motion.coreSwell * strength))

        // The exhale: a soft halo that swells and fades with the beat.
        // At rest (breath == 0) it vanishes and the core sits at its
        // base size — exactly the still emblem Reduce Motion renders.
        if strength > 0 {
            let haloR = r * 2.6
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

        // The core is incandescent: a white-hot centre cooling to the
        // tint at its edge, so the whole bloom reads as lit from within.
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        let bead = Path(ellipseIn: rect)
        context.fill(
            bead,
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.9), Tint.primary]),
                center: center,
                startRadius: 0,
                endRadius: r
            )
        )
        // A hairline rim so the bead reads as a polished point of
        // light rather than a soft blot.
        context.stroke(bead, with: .color(Color.white.opacity(0.4)), lineWidth: 0.5)
    }

    private var accessibilityText: String {
        let cadence = String(format: "%.1f", signature.cadence)
        let lead = signature.dominantGroup.map { "\($0.displayName)-led. " } ?? ""
        let split = signature.petals
            .filter { $0.volumeShare > 0 }
            .map { "\($0.group.displayName) \(Int(($0.volumeShare * 100).rounded())) percent" }
            .joined(separator: ", ")
        return "Training signature. \(lead)Volume split: \(split). \(cadence) sessions per week. Dashed outlines show each region fully developed."
    }
}
