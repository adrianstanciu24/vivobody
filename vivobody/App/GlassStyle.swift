//
//  GlassStyle.swift
//  vivobody
//
//  iOS 26 Liquid Glass surface vocabulary. Wraps `.glassEffect()`
//  with project-specific shapes and tints, and nothing else — the
//  system material owns the rim lighting, specular highlights, and
//  accessibility fallbacks (Reduce Transparency / Increase Contrast).
//  No hand-drawn strokes or sheens are layered on top: they double
//  the system's own highlights and don't adapt when the material
//  changes appearance.
//
//  Why a centralised modifier rather than per-site glass calls:
//    • One file to tweak when iOS reshapes the `.glassEffect` API.
//    • Lets the rest of the codebase stop reasoning about materials
//      and just say `.glassCard()` / `.glassChip()`.
//

import VivoKit
import SwiftUI

extension View {
    /// Plain content surface — the translucent neutral fill of a card
    /// or row with NO `.glassEffect`. Liquid Glass belongs to the
    /// floating controls/navigation layer; the scrolling content
    /// beneath it (stat cards, list rows, tables) is a resting
    /// surface, so the glass that genuinely floats (search pill, CTA,
    /// MiniBar, chips) keeps its meaning and lists stay cheap to
    /// render. Same shape/tint vocabulary as `glassCard`, so swapping
    /// one for the other is a drop-in.
    func contentCard(
        cornerRadius: CGFloat = Radius.card,
        tint: Color? = nil,
        bright: Bool = false
    ) -> some View {
        modifier(ContentSurfaceModifier(cornerRadius: cornerRadius, tint: tint, bright: bright))
    }

    /// Chip-radius content surface — see `contentCard`.
    func contentChip(
        cornerRadius: CGFloat = Radius.chip,
        tint: Color? = nil,
        bright: Bool = false
    ) -> some View {
        modifier(ContentSurfaceModifier(cornerRadius: cornerRadius, tint: tint, bright: bright))
    }

    /// Standard card-shaped Liquid Glass surface. Reserve for the
    /// controls/navigation layer that floats above content; resting
    /// content cards and rows should use `contentCard` instead. The
    /// system material supplies the edge lighting and specular
    /// response; only the translucent fill tint is ours.
    func glassCard(
        cornerRadius: CGFloat = Radius.card,
        tint: Color? = nil,
        bright: Bool = false,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint, bright: bright, interactive: interactive))
    }

    /// Chip / small surface — same idea, tighter radius.
    func glassChip(
        cornerRadius: CGFloat = Radius.chip,
        tint: Color? = nil,
        bright: Bool = false,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint, bright: bright, interactive: interactive))
    }

    /// Pill / capsule glass — used for floating buttons and chips
    /// where the shape is fully rounded.
    func glassPill(tint: Color? = nil, bright: Bool = false, interactive: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: Radius.pill, tint: tint, bright: bright, interactive: interactive))
    }

    /// Button/control glass carrying a caller-owned accent. The color
    /// rides as the glass material's own tint — never as an opaque
    /// fill underneath, which would leave the lensing nothing to
    /// refract and flatten the control into a painted slab.
    func coloredGlassControl(
        cornerRadius: CGFloat = Radius.chip,
        fill: Color? = nil,
        interactive: Bool = true
    ) -> some View {
        modifier(ColoredGlassControlModifier(cornerRadius: cornerRadius, fill: fill, interactive: interactive))
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

    /// The single point through which `.glassEffect` reaches the
    /// codebase. Every other modifier in this file (`glassCard`,
    /// `glassChip`, `glassPill`, `coloredGlassControl`) and every
    /// external caller routes here, so when iOS reshapes the
    /// `.glassEffect` API there is exactly one site to update.
    func glassTinted(
        _ tint: Color? = nil,
        interactive: Bool = false,
        in shape: some Shape
    ) -> some View {
        let glass: Glass = interactive ? .regular.interactive() : .regular
        return glassEffect(tint.map { glass.tint($0) } ?? glass, in: shape)
    }
}

private struct ColoredGlassControlModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fill: Color?
    var interactive: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                // Neutral (untinted) controls keep the faint surface
                // wash so tracks and idle chips read as a resting
                // surface; translucent, so the lensing stays live.
                if fill == nil {
                    shape.fill(Surface.cardTint)
                }
            }
            .glassTinted(fill, interactive: interactive, in: shape)
            .containerShape(shape)
            .contentShape(shape)
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

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            // When Reduce Transparency is active, render as a solid
            // tinted disc — the Fresnel gradients and specular
            // highlights rely on transparency and don't adapt.
            Circle()
                .fill(tint)
                .frame(width: size, height: size)
        } else {
            fullSphere
        }
    }

    private var fullSphere: some View {
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
        .accessibilityHidden(true)
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

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 0) {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(reduceTransparency ? min(shadowOpacity * 1.5, 1.0) : shadowOpacity),
                            tint.opacity(reduceTransparency ? min(shadowOpacity * 0.8, 1.0) : shadowOpacity * 0.4),
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
        .accessibilityHidden(true)
    }
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    var bright: Bool = false
    var interactive: Bool = false

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
            .glassTinted(interactive: interactive, in: shape)
            .containerShape(shape)
            .contentShape(shape)
    }
}

/// Resting content surface: the same translucent fill as
/// `GlassCardModifier` but without `.glassEffect`, so content cards
/// and rows don't compete with the floating glass controls above them.
private struct ContentSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    var bright: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                if let tint {
                    shape.fill(tint.opacity(reduceTransparency ? 0.40 : 0.14))
                } else {
                    shape.fill(bright ? Surface.cardTintBright : Surface.cardTint)
                }
            }
    }
}
