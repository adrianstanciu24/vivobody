//
//  SignatureWidget.swift
//  vivobodyWidgets
//
//  The "Your Signature" widget. Renders the training-signal
//  petal emblem across system and accessory families.
//

import SwiftUI
import WidgetKit

struct SignatureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetShared.signatureKind,
            provider: SnapshotProvider(
                key: WidgetShared.signatureSnapshotKey,
                fallback: SignatureSnapshot.placeholder,
                refreshInterval: 24 * 60 * 60
            )
        ) { entry in
            SignatureWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Your Signature")
        .description("The shape of your training in one mark.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct SignatureWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: SignatureSnapshot

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                SignatureEmblem(snapshot: snapshot, showsLabels: false)
                    .padding(4)
            case .accessoryRectangular:
                HStack(spacing: Space.sm) {
                    SignatureEmblem(snapshot: snapshot, showsLabels: false)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.dominantGroup.map { "\($0)-led" } ?? "Balanced")
                            .font(Typography.headline)
                        Text(String(format: "%.1fx a week", snapshot.cadence))
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.secondary)
                    }
                }
            case .accessoryInline:
                Text(snapshot.verdictLine)
            default:
                system
            }
        }
        .widgetURL(URL(string: "vivobody://insights"))
        .containerBackground(.black, for: .widget)
        .dynamicTypeSize(.large)
    }

    @ViewBuilder
    private var system: some View {
        switch family {
        case .systemSmall:
            smallSystem.padding()
        case .systemMedium:
            mediumSystem.padding()
        case .systemLarge:
            largeSystem.padding()
        default:
            smallSystem.padding()
        }
    }

    private var smallSystem: some View {
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

    private var mediumSystem: some View {
        HStack(alignment: .center, spacing: Space.lg) {
            SignatureEmblem(snapshot: snapshot, showsLabels: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Your signature")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                Text(snapshot.verdictLine)
                    .font(Typography.body)
                    .foregroundStyle(snapshot.hasSignature ? Ink.primary : Ink.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                WidgetStatStrip(stats: signatureStats, compact: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var largeSystem: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your signature")
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                Spacer()
                Text("the shape of your training")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
            }

            if snapshot.hasSignature {
                SignatureEmblem(snapshot: snapshot, showsLabels: true)
                    .frame(maxWidth: .infinity, minHeight: 170, maxHeight: 190)
                WidgetStatStrip(stats: signatureStats)
                Text(snapshot.verdictLine)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(2)
                Text("Each petal is a muscle group - its reach is how developed it is, its width how much of your volume it takes.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(3)
            } else {
                Spacer(minLength: 0)
                Text(snapshot.verdictLine)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
        }
    }

    private var signatureStats: [WidgetStat] {
        [
            WidgetStat(value: snapshot.cadence.widgetOneDecimal, label: "Per week", accent: snapshot.cadence >= 2),
            WidgetStat(value: "\(snapshot.weekStreak)", label: "Streak"),
            WidgetStat(value: "\(Int((snapshot.balance * 100).rounded()))", unit: "%", label: "Balance"),
        ]
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
