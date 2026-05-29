//
//  GlassStyle.swift
//  vivobody
//
//  iOS 26 Liquid Glass surface vocabulary. Wraps `.glassEffect()`
//  with project-specific shapes, tints, and the specular top edge
//  that gives every glass surface a hint of light.
//
//  Why a centralised modifier rather than per-site glass calls:
//    • One file to tweak when iOS reshapes the `.glassEffect` API.
//    • Guarantees the specular highlight rim is the same on every
//      card, so the depth language is consistent.
//    • Lets the rest of the codebase stop reasoning about materials
//      and just say `.glassCard()` / `.glassChip()`.
//

import SwiftUI

extension View {
    /// Standard card-shaped Liquid Glass surface. Drop-in replacement
    /// for the legacy `RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.04))`
    /// pattern. Includes a top-edge specular highlight and a faint
    /// outer stroke so the card reads as a luminous piece of material
    /// against the pure-black backdrop.
    func glassCard(
        cornerRadius: CGFloat = Radius.card,
        tint: Color? = nil,
        bright: Bool = false
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint, bright: bright))
    }

    /// Chip / small surface — same idea, tighter radius.
    func glassChip(
        cornerRadius: CGFloat = Radius.chip,
        tint: Color? = nil,
        bright: Bool = false
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint, bright: bright))
    }

    /// Pill / capsule glass — used for floating buttons and chips
    /// where the shape is fully rounded.
    func glassPill(tint: Color? = nil, bright: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: Radius.pill, tint: tint, bright: bright))
    }

    /// Neutral elevation. Lifts a CTA or card off the pure-black
    /// backdrop with a soft black shadow — no colored bloom. The
    /// warm orange / green halos stay reserved for the genuine
    /// moments that own their own glow (PR celebration, active-card
    /// focus, set completion), so those finally read as special
    /// rather than every button faking importance.
    func softElevation(radius: CGFloat = 12, y: CGFloat = 6, opacity: Double = 0.35) -> some View {
        self.shadow(color: .black.opacity(opacity), radius: radius, y: y)
    }

    /// Carved-glass rim: a bright outer stroke plus a darker inner
    /// stroke offset one point inwards. Together they read as a
    /// bevel — light catches the top outer edge while the inner lip
    /// drops into shadow, the same way real polished glass looks
    /// against a dark backdrop.
    func glassRimBevel(
        cornerRadius: CGFloat,
        outerWidth: CGFloat = 0.6,
        innerInset: CGFloat = 1.2
    ) -> some View {
        modifier(GlassRimBevelModifier(
            cornerRadius: cornerRadius,
            outerWidth: outerWidth,
            innerInset: innerInset
        ))
    }

    /// Top-edge specular sheen — a vertical gradient overlay clipped
    /// to the shape, fading from a soft white at the top into
    /// transparency over the upper third. Sells "wet glass" on any
    /// surface without changing its fill.
    func topSpecularSheen(
        cornerRadius: CGFloat,
        intensity: Double = 0.10,
        height: Double = 0.38
    ) -> some View {
        modifier(TopSpecularSheenModifier(
            cornerRadius: cornerRadius,
            intensity: intensity,
            height: height
        ))
    }
}

private struct GlassRimBevelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let outerWidth: CGFloat
    let innerInset: CGFloat

    func body(content: Content) -> some View {
        let outer = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: max(0, cornerRadius - innerInset), style: .continuous)
        return content
            .overlay {
                outer.stroke(
                    LinearGradient(
                        colors: [
                            Surface.edgeBright,
                            Surface.edge.opacity(0.55),
                            Surface.edge.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: outerWidth
                )
            }
            .overlay {
                inner
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.45),
                                Color.black.opacity(0.10),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                    .padding(innerInset)
                    .blendMode(.plusDarker)
                    .opacity(0.6)
            }
    }
}

private struct TopSpecularSheenModifier: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: Double
    let height: Double

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(intensity),
                            Color.white.opacity(intensity * 0.35),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * CGFloat(height))
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
    }
}

/// A Fresnel-shaded translucent sphere — the same vocabulary used
/// for the rest-timer orb, packaged for reuse anywhere a circular
/// glass element should read as 3D rather than as a flat tinted
/// disc. Layers (in z-order):
///   1. Sphere body — radial gradient with bright spec mid, dark
///      rim. This is the Fresnel cue that sells "round, not flat."
///   2. Inner rim shadow — a darker stroke at the edge so the
///      sphere has a visible lip.
///   3. Bounce-light arc — warm crescent on the lower rim,
///      suggesting light reflecting up off a notional floor.
///   4. Specular cap — small white highlight upper-left, the
///      light catching on the polished surface.
///
/// Compose with an outer `.softElevation(...)` or an Image overlay
/// to get the full empty-state treatment (atmosphere + icon).
struct GlassSphere: View {
    var size: CGFloat = 132
    var tint: Color = Tint.primary

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: tint.opacity(0.58), location: 0.00),
                            .init(color: tint.opacity(0.42), location: 0.45),
                            .init(color: tint.opacity(0.20), location: 0.78),
                            .init(color: tint.opacity(0.06), location: 0.95),
                            .init(color: tint.opacity(0.00), location: 1.00),
                        ]),
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )

            Circle()
                .stroke(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.40)
                        ],
                        center: .center,
                        startRadius: size * 0.40,
                        endRadius: size * 0.50
                    ),
                    lineWidth: size * 0.06
                )
                .blendMode(.multiply)

            Circle()
                .trim(from: 0.58, to: 0.92)
                .stroke(
                    tint.opacity(0.55),
                    style: StrokeStyle(lineWidth: size * 0.015, lineCap: .round)
                )
                .blur(radius: size * 0.012)
                .padding(size * 0.012)
                .blendMode(.plusLighter)

            Circle()
                .fill(Color.white.opacity(0.28))
                .frame(width: size * 0.30, height: size * 0.30)
                .blur(radius: size * 0.09)
                .offset(x: -size * 0.18, y: -size * 0.18)
                .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
    }
}

/// Pedestal beneath a centered subject: a soft elliptical ground
/// shadow plus a faint mirrored reflection wedge below it. Drop
/// underneath a hero element (like the plate visualizer) to make
/// the element feel placed on a surface rather than floating in
/// zero-G.
struct GlassPedestal: View {
    var width: CGFloat = 220
    var shadowOpacity: Double = 0.55
    var tint: Color = .black

    var body: some View {
        VStack(spacing: 0) {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(shadowOpacity),
                            tint.opacity(shadowOpacity * 0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: width * 0.55
                    )
                )
                .frame(width: width, height: width * 0.18)
                .blur(radius: 6)
        }
        .allowsHitTesting(false)
    }
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    var bright: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                ZStack {
                    if let tint {
                        shape.fill(tint.opacity(0.14))
                    } else {
                        shape.fill(bright ? Surface.cardTintBright : Surface.cardTint)
                    }
                }
            }
            .glassEffect(.regular, in: shape)
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Surface.edgeBright,
                                Surface.edge.opacity(0.6),
                                Surface.edge.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: bright ? 0.75 : 0.5
                    )
            }
    }
}
