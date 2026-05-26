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
        tint: Color? = nil
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }

    /// Chip / small surface — same idea, tighter radius.
    func glassChip(
        cornerRadius: CGFloat = Radius.chip,
        tint: Color? = nil
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }

    /// Pill / capsule glass — used for floating buttons and chips
    /// where the shape is fully rounded.
    func glassPill(tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(cornerRadius: Radius.pill, tint: tint))
    }

    /// Primary-action glow. Pairs an orange-tinted shadow with a
    /// subtle inner specular gradient so the button reads as the
    /// hot spot of the screen.
    func primaryGlow(_ accent: Color = Tint.primary, radius: CGFloat = 22, y: CGFloat = 6) -> some View {
        self.shadow(color: accent.opacity(0.45), radius: radius, y: y)
            .shadow(color: accent.opacity(0.18), radius: 4, y: 1)
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

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                ZStack {
                    if let tint {
                        shape.fill(tint.opacity(0.14))
                    } else {
                        shape.fill(Surface.cardTint)
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
                        lineWidth: 0.5
                    )
            }
    }
}
