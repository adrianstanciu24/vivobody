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

    /// One petal's precomputed placement, shared by the bloom, body,
    /// and core-spill passes so the widget draws the same light
    /// architecture as the app without recomputing geometry.
    private struct PlacedPetal {
        let petal: SignaturePetalSnapshot
        let angle: Double
        let opacity: Double
        let hueShift: Double
        let isDominant: Bool
        let shape: SignatureEmblemTuning.PetalShape
        let placedOutline: Path
    }

    var body: some View {
        Canvas { context, size in
            guard !snapshot.petals.isEmpty else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let count = snapshot.petals.count
            let maxShare = snapshot.petals.map(\.volumeShare).max() ?? 0

            // The warm air behind the bloom — skipped in vibrant
            // rendering, where the system material owns the canvas.
            if renderingMode != .vibrant {
                let atmoR = radius * SignatureEmblemTuning.atmosphereFraction
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - atmoR, y: center.y - atmoR, width: atmoR * 2, height: atmoR * 2)),
                    with: .radialGradient(
                        SignatureEmblemTuning.atmosphereGradient(intensity: snapshot.intensity),
                        center: center,
                        startRadius: 0,
                        endRadius: atmoR
                    )
                )
            }

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

            // Full-colour widgets keep the app's warm atmosphere;
            // vibrant rendering stays plain so the system material can
            // control contrast.
            if renderingMode != .vibrant {
                let ambient = context
                // The ambient ember — the same warmth the app's bloom
                // sits in. Skipped in vibrant rendering, where the
                // system controls the material.
                let emberR = radius * 1.04
                ambient.fill(
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

            let placed: [PlacedPetal] = snapshot.petals.enumerated().map { index, petal in
                let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
                let length = radius * SignatureEmblemTuning.reachFraction(development: petal.development)
                let share = maxShare > 0 ? petal.volumeShare / maxShare : 0
                let halfWidth = SignatureEmblemTuning.halfWidth(shareNorm: share, length: length, radius: radius)
                let dominant = petal.group == snapshot.dominantGroup
                let opacity = SignatureEmblemTuning.petalOpacity(development: petal.development, intensity: snapshot.intensity, isDominant: dominant)
                let shape = SignatureEmblemTuning.petalShape(length: length, halfWidth: halfWidth)
                var transform = CGAffineTransform(translationX: center.x, y: center.y)
                transform = transform.rotated(by: angle)
                return PlacedPetal(
                    petal: petal,
                    angle: angle,
                    opacity: opacity,
                    hueShift: SignatureEmblemTuning.hueShift(index: index, count: count),
                    isDominant: dominant,
                    shape: shape,
                    placedOutline: shape.outline.applying(transform)
                )
            }

            // The halo each petal throws on the dark, the dominant
            // petal boosted — same light lead as the app's emblem.
            if renderingMode != .vibrant {
                context.drawLayer { bloom in
                    bloom.addFilter(.blur(radius: radius * SignatureEmblemTuning.bloomRadiusFraction))
                    for item in placed {
                        let strength = item.opacity * SignatureEmblemTuning.bloomOpacity
                        bloom.fill(
                            item.placedOutline,
                            with: .color(SignatureEmblemTuning.petalGold(hueShift: item.hueShift).opacity(strength))
                        )
                        if item.isDominant {
                            bloom.fill(
                                item.placedOutline,
                                with: .color(Tint.primary.opacity(strength * SignatureEmblemTuning.dominantHaloBoost))
                            )
                        }
                    }
                }
            }

            for item in placed {
                let petal = item.petal
                let angle = item.angle
                let dominant = item.isDominant
                let opacity = item.opacity
                let hueShift = item.hueShift
                let shape = item.shape

                var c = context
                c.translateBy(x: center.x, y: center.y)
                c.rotate(by: .radians(angle))

                if renderingMode == .vibrant {
                    c.fill(
                        shape.outline,
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: petalColor(opacity: opacity), location: 0),
                                .init(
                                    color: petalColor(
                                        opacity: opacity * SignatureEmblemTuning.burnMidScale
                                    ),
                                    location: SignatureEmblemTuning.burnMidLocation
                                ),
                                .init(
                                    color: petalColor(
                                        opacity: opacity * SignatureEmblemTuning.burnTipScale
                                    ),
                                    location: 1
                                ),
                            ]),
                            startPoint: .zero,
                            endPoint: shape.tip
                        )
                    )
                } else {
                    c.fill(
                        shape.outline,
                        with: .linearGradient(
                            SignatureEmblemTuning.foldGradient(
                                opacity: opacity,
                                hueShift: hueShift
                            ),
                            startPoint: .zero,
                            endPoint: shape.tip
                        )
                    )
                    c.fill(
                        shape.blade,
                        with: .linearGradient(
                            SignatureEmblemTuning.burnGradient(
                                opacity: opacity,
                                hueShift: hueShift
                            ),
                            startPoint: .zero,
                            endPoint: shape.tip
                        )
                    )
                    c.stroke(
                        shape.crease,
                        with: .color(
                            Color.black.opacity(
                                SignatureEmblemTuning.creaseOpacity * opacity
                            )
                        ),
                        lineWidth: 0.7
                    )

                    c.stroke(
                        shape.leadingEdge,
                        with: .linearGradient(
                            SignatureEmblemTuning.rimGradient(
                                opacity: opacity,
                                hueShift: hueShift
                            ),
                            startPoint: .zero,
                            endPoint: shape.tip
                        ),
                        lineWidth: SignatureEmblemTuning.rimLineWidth
                    )
                }

                if showsLabels {
                    let p = CGPoint(x: center.x + cos(angle) * radius * 0.88, y: center.y + sin(angle) * radius * 0.88)
                    let label = Text(petal.group.prefix(3).uppercased())
                        .font(Typography.micro)
                        .foregroundStyle(dominant ? Ink.primary : Ink.tertiary)
                    context.draw(label, at: p, anchor: .center)
                }
            }

            // The core's orange light landing on the petal roots,
            // clipped to the bodies without additive colour shifts.
            if renderingMode != .vibrant {
                var spill = context
                var bodies = Path()
                for item in placed {
                    bodies.addPath(item.placedOutline)
                }
                spill.clip(to: bodies)
                let spillR = radius * SignatureEmblemTuning.coreSpillFraction
                spill.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - spillR,
                        y: center.y - spillR,
                        width: spillR * 2,
                        height: spillR * 2
                    )),
                    with: .radialGradient(
                        SignatureEmblemTuning.coreSpillGradient(
                            strength: 0.42 + 0.18 * snapshot.intensity
                        ),
                        center: center,
                        startRadius: 0,
                        endRadius: spillR
                    )
                )
            }

            let contact = CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)
            context.fill(Path(ellipseIn: contact), with: .color(.black.opacity(0.35)))
            let core = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
            context.fill(
                Path(ellipseIn: core),
                with: renderingMode == .vibrant
                    ? .color(.white)
                    : .radialGradient(
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
                        endRadius: 4
                    )
            )
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
