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
        .dynamicTypeSize(.large)
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
            let ring = Path(ellipseIn: CGRect(
                x: center.x - radius * 0.78,
                y: center.y - radius * 0.78,
                width: radius * 1.56,
                height: radius * 1.56
            ))
            context.stroke(ring, with: .color(Surface.cardTint), lineWidth: 1)

            for (index, petal) in snapshot.petals.enumerated() {
                let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
                let dominant = petal.group == snapshot.dominantGroup
                var spoke = Path()
                spoke.move(to: CGPoint(x: center.x + cos(angle) * radius * 0.08, y: center.y + sin(angle) * radius * 0.08))
                spoke.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 0.82, y: center.y + sin(angle) * radius * 0.82))
                context.stroke(spoke, with: .color(spokeColor(isDominant: dominant)), lineWidth: 1)
            }

            for (index, petal) in snapshot.petals.enumerated() {
                let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
                let length = radius * (0.20 + 0.62 * petal.development)
                let share = maxShare > 0 ? petal.volumeShare / maxShare : 0
                let halfWidth = radius * (0.05 + 0.28 * share)
                let dominant = petal.group == snapshot.dominantGroup
                let opacity = min(1, (0.28 + 0.55 * petal.development) * (0.55 + 0.45 * snapshot.intensity) + (dominant ? 0.18 : 0))

                var leaf = Path()
                let tip = CGPoint(x: length, y: 0)
                leaf.move(to: .zero)
                leaf.addQuadCurve(to: tip, control: CGPoint(x: length * 0.5, y: halfWidth))
                leaf.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: -halfWidth))

                var transform = CGAffineTransform(translationX: center.x, y: center.y)
                transform = transform.rotated(by: angle)
                context.fill(leaf.applying(transform), with: .color(petalColor(opacity: opacity)))

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
