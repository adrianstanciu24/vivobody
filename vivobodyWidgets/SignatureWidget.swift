//
//  SignatureWidget.swift
//  vivobodyWidgets
//
//  The "Your Signature" widget — small family only. Renders the
//  training-signal petal emblem with a one-line verdict.
//

import VivoKit
import SwiftUI
import WidgetKit

struct SignatureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetShared.signatureKind,
            provider: SnapshotProvider(
                key: WidgetShared.signatureSnapshotKey,
                galleryPlaceholder: SignatureSnapshot.placeholder,
                empty: SignatureSnapshot.empty,
                refreshInterval: 24 * 60 * 60
            )
        ) { entry in
            SignatureWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Your Signature")
        .description("The shape of your training in one mark.")
        .supportedFamilies([.systemSmall])
    }
}

struct SignatureWidgetView: View {
    let snapshot: SignatureSnapshot

    /// Pro-gated: the app mirrors the entitlement into the App Group;
    /// free renders the locked placeholder deep-linking to the paywall.
    private var isPro: Bool { WidgetEntitlement.isPro }

    var body: some View {
        Group {
            if !isPro {
                WidgetProLock(title: "Your Signature")
            } else {
                small.padding()
            }
        }
        .widgetURL(URL(string: isPro ? "vivobody://insights" : "vivobody://pro"))
        .containerBackground(.black, for: .widget)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Your signature")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
            if snapshot.hasSignature {
                SignatureEmblem(snapshot: snapshot, showsLabels: false)
                    .frame(maxWidth: .infinity, maxHeight: 92)
                Text(snapshot.verdictLine)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                Spacer(minLength: 0)
                Text(snapshot.verdictLine)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(3)
            }
        }
    }
}

struct SignatureEmblem: View {
    let snapshot: SignatureSnapshot
    var showsLabels: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Canvas { context, size in
            guard !snapshot.petals.isEmpty else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let count = snapshot.petals.count
            let maxShare = snapshot.petals.map(\.volumeShare).max() ?? 0
            let ring = radius * SignatureEmblemTuning.ringFraction
            let ringPath = Path(ellipseIn: CGRect(
                x: center.x - ring,
                y: center.y - ring,
                width: ring * 2,
                height: ring * 2
            ))
            context.stroke(ringPath, with: .color(Surface.cardTint), lineWidth: 1)

            for (index, petal) in snapshot.petals.enumerated() {
                let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
                let dominant = petal.group == snapshot.dominantGroup
                var spoke = Path()
                spoke.move(to: CGPoint(x: center.x + cos(angle) * radius * SignatureEmblemTuning.spokeInnerFraction, y: center.y + sin(angle) * radius * SignatureEmblemTuning.spokeInnerFraction))
                spoke.addLine(to: CGPoint(x: center.x + cos(angle) * ring, y: center.y + sin(angle) * ring))
                context.stroke(spoke, with: .color(spokeColor(isDominant: dominant)), lineWidth: 1)
            }

            // The ghost bloom: every petal outlined at full size, the
            // silhouette the live petals grow into.
            let ghostLength = radius * SignatureEmblemTuning.reachFraction(development: 1)
            let ghostHalfWidth = SignatureEmblemTuning.halfWidth(shareNorm: 1, length: ghostLength, radius: radius)
            let ghostLeaf = SignatureEmblemTuning.petalPath(length: ghostLength, halfWidth: ghostHalfWidth)
            for index in snapshot.petals.indices {
                let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
                var transform = CGAffineTransform(translationX: center.x, y: center.y)
                transform = transform.rotated(by: angle)
                context.stroke(
                    ghostLeaf.applying(transform),
                    with: .color(Ink.primary.opacity(SignatureEmblemTuning.ghostOpacity)),
                    style: StrokeStyle(lineWidth: SignatureEmblemTuning.ghostLineWidth, dash: SignatureEmblemTuning.ghostDash)
                )
            }

            // Additive petals glow toward a hot core in full colour;
            // vibrant (lock-screen) rendering keeps plain alpha so the
            // white-on-white sum can't blow out.
            var glow = context
            if renderingMode != .vibrant {
                glow.blendMode = .plusLighter
                // The ambient ember — the same warmth the app's bloom
                // sits in. Skipped in vibrant rendering, where the
                // system controls the material.
                let emberR = radius * 1.04
                glow.fill(
                    Path(ellipseIn: CGRect(x: center.x - emberR, y: center.y - emberR, width: emberR * 2, height: emberR * 2)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Tint.primary.opacity(SignatureEmblemTuning.ambientOpacity(intensity: snapshot.intensity)),
                            .clear,
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: emberR
                    )
                )
            }

            for (index, petal) in snapshot.petals.enumerated() {
                let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
                let length = radius * SignatureEmblemTuning.reachFraction(development: petal.development)
                let share = maxShare > 0 ? petal.volumeShare / maxShare : 0
                let halfWidth = SignatureEmblemTuning.halfWidth(shareNorm: share, length: length, radius: radius)
                let dominant = petal.group == snapshot.dominantGroup
                let opacity = SignatureEmblemTuning.petalOpacity(development: petal.development, intensity: snapshot.intensity, isDominant: dominant)

                // Same organic leaf and multi-stop burn as the app —
                // incandescent gold at the core cooling to deep ember
                // at the tip — drawn in local coordinates so the
                // gradient runs base-to-tip before rotation.
                let leaf = SignatureEmblemTuning.petalPath(length: length, halfWidth: halfWidth)
                let tip = CGPoint(x: length, y: 0)

                var c = glow
                c.translateBy(x: center.x, y: center.y)
                c.rotate(by: .radians(angle))
                let burn = renderingMode == .vibrant
                    ? Gradient(stops: [
                        .init(color: petalColor(opacity: opacity), location: 0),
                        .init(color: petalColor(opacity: opacity * SignatureEmblemTuning.burnMidScale), location: SignatureEmblemTuning.burnMidLocation),
                        .init(color: petalColor(opacity: opacity * SignatureEmblemTuning.burnTipScale), location: 1),
                    ])
                    : SignatureEmblemTuning.burnGradient(opacity: opacity)
                c.fill(leaf, with: .linearGradient(burn, startPoint: .zero, endPoint: tip))

                if renderingMode != .vibrant {
                    let rim = Gradient(stops: [
                        .init(color: SignatureEmblemTuning.burnGold.opacity(SignatureEmblemTuning.rimOpacity * opacity), location: 0),
                        .init(color: Tint.primary.opacity(SignatureEmblemTuning.rimOpacity * SignatureEmblemTuning.rimTipScale * opacity), location: 1),
                    ])
                    c.stroke(leaf, with: .linearGradient(rim, startPoint: .zero, endPoint: tip), lineWidth: SignatureEmblemTuning.rimLineWidth)
                }

                if showsLabels {
                    let p = CGPoint(x: center.x + cos(angle) * radius * 0.88, y: center.y + sin(angle) * radius * 0.88)
                    let label = Text(petal.group.prefix(3).uppercased())
                        .font(Typography.micro)
                        .foregroundStyle(dominant ? Ink.primary : Ink.tertiary)
                    context.draw(label, at: p, anchor: .center)
                }
            }

            let core = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: core), with: .color(renderingMode == .vibrant ? .white : Tint.primary))
        }
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.verdictLine.isEmpty ? "Training signature" : snapshot.verdictLine)
    }

    private func petalColor(opacity: Double) -> Color {
        renderingMode == .vibrant ? .white.opacity(opacity) : Tint.primary.opacity(opacity)
    }

    private func spokeColor(isDominant: Bool) -> Color {
        if renderingMode == .vibrant {
            return .white.opacity(isDominant ? 0.45 : 0.10)
        }
        return isDominant ? Tint.primary.opacity(0.45) : Ink.primary.opacity(0.05)
    }
}
