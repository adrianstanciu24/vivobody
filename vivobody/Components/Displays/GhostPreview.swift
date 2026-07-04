//
//  GhostPreview.swift
//  vivobody
//
//  Empty-state "ghost" vocabulary. Instead of a decorative orb +
//  SF Symbol, every empty state shows a dim, dashed-rim phantom of
//  the real content it will eventually hold — a template card, a
//  session row, a stats tile. The phantom reuses the same Liquid
//  Glass material as the populated surface, so the empty state
//  reads as part of the system rather than a sticker on top of it,
//  and it teaches the shape of what the user is about to make.
//
//  Two primitives:
//    • GhostBar  — a single rounded placeholder line. Compose
//      several to sketch a row's text hierarchy.
//    • GhostCard — a dashed-rim glass container. Its contents
//      breathe (slow opacity pulse) so the placeholder feels alive
//      and "to be filled," not like a stalled loading skeleton —
//      the dashed rim is the cue that this is empty, not loading.
//

import VivoKit
import SwiftUI

/// A single placeholder line. `width == nil` stretches to fill the
/// available width (useful for a sparkline-area placeholder); a
/// fixed width sketches a specific text run.
struct GhostBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    var cornerRadius: CGFloat = 5
    var opacity: Double = 0.12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Ink.quaternary.opacity(opacity / 0.12))
        Group {
            if let width {
                shape.frame(width: width, height: height)
            } else {
                shape.frame(maxWidth: .infinity).frame(height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Dashed-rim glass container for empty-state phantoms. Reuses the
/// project's card material (`Surface.cardTint` + `.glassEffect`) so
/// the phantom is literally the same glass as the real card, then
/// overlays a dashed rim and breathes the contents to signal
/// "placeholder."
struct GhostCard<Content: View>: View {
    var cornerRadius: CGFloat = Radius.card
    var padding: CGFloat = 20
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content()
            .opacity(breathing ? 1.0 : 0.66)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                value: breathing
            )
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { shape.fill(Surface.cardTint) }
            .glassTinted(in: shape)
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Surface.edgeBright,
                            Surface.edge.opacity(0.5),
                            Surface.edge.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { breathing = true }
    }
}

#Preview("Ghosts") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            GhostCard(cornerRadius: Radius.card) {
                VStack(alignment: .leading, spacing: Space.lg) {
                    HStack {
                        GhostBar(width: 120, height: 18, cornerRadius: 6, opacity: 0.16)
                        Spacer()
                        GhostBar(width: 44, height: 10)
                    }
                    GhostBar(width: 168, height: 12)
                    HStack(spacing: Space.sm) {
                        GhostBar(width: 62, height: 24, cornerRadius: Radius.chip)
                        GhostBar(width: 52, height: 24, cornerRadius: Radius.chip)
                    }
                }
            }
            .frame(maxWidth: 300)
        }
        .padding(Space.xxl)
    }
    .preferredColorScheme(.dark)
}
