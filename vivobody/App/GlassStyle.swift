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
