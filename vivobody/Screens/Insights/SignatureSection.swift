//
//  SignatureSection.swift
//  vivobody
//
//  The Insights hero — the screen opens on a portrait, not a table.
//  A single generative emblem fuses the whole picture into a mark
//  you'd recognise as *yours*: six petals (one per muscle group)
//  whose reach is how developed the region is and whose width is how
//  much of your volume it carries, burning brighter the harder you
//  train, ringed by beads that count your weekly cadence.
//
//  It deliberately carries the group-balance read the old tab spread
//  across a separate roster — so this one mark answers "what's the
//  shape of my training?" — anchored by three plain numbers (cadence,
//  streak, balance) and one sentence so the art always has a legend.
//
//  No anatomical body here on purpose: the rotatable 3D figure is
//  Today's hero. Insights is the analytical counterpart, and the
//  emblem is its signature.
//

import SwiftUI

struct SignatureSection: View {
    let signature: TrainingSignature
    let report: ConsistencyReport

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Your signature", trailing: "the shape of your training")

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
                    valueFont: InsightsFormat.monoStat,
                    edgeAligned: true
                )
                .padding(.vertical, Space.xs)

                verdict

                Text("Each petal is a muscle group — its reach is how developed it is, its width how much of your volume it takes. The brighter the bloom, the harder the training; the beads count your sessions a week.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One read of the whole signature: its focus and trajectory, then
    /// the effort and cadence it was built at.
    private var verdict: some View {
        Text(line(signature))
            .font(Typography.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func line(_ signature: TrainingSignature) -> AttributedString {
        var focus: AttributedString
        if let group = signature.dominantGroup {
            focus = AttributedString("\(group.displayName)-led")
        } else {
            focus = AttributedString("Balanced across every region")
        }
        focus.foregroundColor = Ink.primary

        var trend = AttributedString(" \(trendPhrase(signature.trend)). ")
        trend.foregroundColor = Ink.secondary

        var effort = AttributedString(effortPhrase(signature.intensity) + ", ")
        effort.foregroundColor = Ink.secondary
        var cadence = AttributedString(InsightsFormat.perWeekLabel(signature.cadence) + "×")
        cadence.foregroundColor = Ink.primary
        var rest = AttributedString(" a week.")
        rest.foregroundColor = Ink.secondary

        return focus + trend + effort + cadence + rest
    }

    private func trendPhrase(_ trend: MomentumTrend) -> String {
        switch trend {
        case .growing: return "and climbing"
        case .holding: return "and holding steady"
        case .fading:  return "and easing off"
        }
    }

    private func effortPhrase(_ intensity: Double) -> String {
        if intensity >= 0.6 { return "Trained close to failure" }
        if intensity >= 0.4 { return "Pushed at a steady clip" }
        return "Plenty left in the tank"
    }
}

// MARK: - Training signature emblem

/// The signature bloom. Six petals radiate from a core — one per
/// muscle group, fixed at the wheel position its order assigns — each
/// reaching out by how developed the region is and fattened by how
/// much of your volume it carries. A faint ring frames it, beads
/// around the rim count weekly cadence, and the whole emblem burns
/// brighter the harder the training. Drawn in a single Canvas so the
/// petals overlap as translucent, organic strokes.
private struct TrainingSignatureView: View {
    let signature: TrainingSignature

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = Swift.min(size.width, size.height) / 2

            drawRing(in: &context, center: center, radius: radius)
            drawSpokes(in: &context, center: center, radius: radius)
            drawCadenceBeads(in: &context, center: center, radius: radius)
            drawPetals(in: &context, center: center, radius: radius)
            drawLabels(in: &context, center: center, radius: radius)
            drawCore(in: &context, center: center, radius: radius)
        }
        .frame(height: 272)
        .accessibilityLabel(Text(accessibilityText))
    }

    private func drawRing(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let r = radius * 0.78
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(Surface.cardTint), lineWidth: 1)
    }

    /// A faint guide line from the core out to each axis label. This
    /// is the legibility fix: petals are short when a region is
    /// underdeveloped, so without a spoke the eye can't tell which
    /// label a stubby petal belongs to. The spoke anchors every petal
    /// to its named axis, and the dominant region's spoke is lit so
    /// "back-led" reads straight off the emblem, not just the caption.
    private func drawSpokes(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let petals = signature.petals
        let count = petals.count
        guard count > 0 else { return }
        let inner = radius * 0.09
        let outer = radius * 0.84
        for (i, petal) in petals.enumerated() {
            let angle = (Double(i) / Double(count)) * 2 * .pi - .pi / 2
            let isDominant = petal.group == signature.dominantGroup
            var path = Path()
            path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
            context.stroke(
                path,
                with: .color(isDominant ? Tint.primary.opacity(0.45) : .white.opacity(0.05)),
                lineWidth: 1
            )
        }
    }

    private func drawCadenceBeads(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let beads = Swift.min(7, Swift.max(0, Int(signature.cadence.rounded())))
        guard beads > 0 else { return }
        let r = radius * 0.78
        for i in 0..<beads {
            let angle = (Double(i) / Double(beads)) * 2 * .pi - .pi / 2
            let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            let dot = CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)
            context.fill(Path(ellipseIn: dot), with: .color(Tint.primary.opacity(0.55)))
        }
    }

    private func drawPetals(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let petals = signature.petals
        let count = petals.count
        let maxShare = petals.map(\.volumeShare).max() ?? 0

        for (i, petal) in petals.enumerated() {
            let angle = (Double(i) / Double(count)) * 2 * .pi - .pi / 2
            // Reach to near the label ring at full development so a
            // strong region visibly touches its axis.
            let length = radius * (0.22 + 0.62 * petal.development)
            let shareNorm = maxShare > 0 ? petal.volumeShare / maxShare : 0
            let halfWidth = radius * (0.05 + 0.30 * shareNorm)
            let isDominant = petal.group == signature.dominantGroup
            let base = (0.28 + 0.55 * petal.development) * (0.55 + 0.45 * signature.intensity)
            // The lead region burns a touch brighter so the bloom
            // itself communicates the focus the caption spells out.
            let opacity = isDominant ? Swift.min(1, base + 0.22) : base

            var leaf = Path()
            let tip = CGPoint(x: length, y: 0)
            leaf.move(to: .zero)
            leaf.addQuadCurve(to: tip, control: CGPoint(x: length * 0.5, y: halfWidth))
            leaf.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: -halfWidth))

            var transform = CGAffineTransform(translationX: center.x, y: center.y)
            transform = transform.rotated(by: angle)
            context.fill(leaf.applying(transform), with: .color(Tint.primary.opacity(Swift.min(1, opacity))))

            // A bright bead at the dominant petal's tip pins the eye to
            // the leading region.
            if isDominant {
                let tipPoint = CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
                let dot = CGRect(x: tipPoint.x - 3, y: tipPoint.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dot), with: .color(Tint.primary))
            }
        }
    }

    private func drawLabels(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let petals = signature.petals
        let count = petals.count
        let r = radius * 0.92
        for (i, petal) in petals.enumerated() {
            let angle = (Double(i) / Double(count)) * 2 * .pi - .pi / 2
            let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            let isDominant = petal.group == signature.dominantGroup
            let text = Text(petal.group.displayName.uppercased())
                .font(.system(size: 9, weight: isDominant ? .bold : .semibold))
                .foregroundStyle(isDominant ? Ink.primary : Ink.tertiary)
            context.draw(text, at: p, anchor: .center)
        }
    }

    private func drawCore(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let r = radius * 0.05
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect), with: .color(Tint.primary))
    }

    private var accessibilityText: String {
        let focus = signature.dominantGroup.map { "\($0.displayName)-led" } ?? "balanced"
        let trend: String
        switch signature.trend {
        case .growing: trend = "climbing"
        case .holding: trend = "holding"
        case .fading:  trend = "easing off"
        }
        let cadence = String(format: "%.1f", signature.cadence)
        return "Training signature: \(focus), \(trend), \(cadence) sessions per week"
    }
}
