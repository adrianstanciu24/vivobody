//
//  SignatureEmblemTuning.swift
//  VivoKit
//
//  The single source of truth for the signature bloom's geometry and
//  colour, so the app's animated emblem and the static widget cannot
//  drift. Its swept, folded leaf echoes the Vivo mark while preserving
//  the data mapping: development controls reach, volume controls width,
//  and effort controls luminance.
//

import CoreGraphics
import Foundation
import SwiftUI

public enum SignatureEmblemTuning {
    /// A logo-derived leaf split into separately renderable surfaces.
    /// The broad blade catches the core light while the narrow fold
    /// turns under it; the shared crease and asymmetric edges let each
    /// renderer build depth without reconstructing geometry.
    public struct PetalShape {
        public let outline: Path
        public let blade: Path
        public let leadingEdge: Path
        public let trailingEdge: Path
        public let crease: Path
        public let specular: Path
        public let tip: CGPoint
    }

    /// Ring radius (and the satellite's orbit), as a fraction of the
    /// emblem radius.
    public static let ringFraction: CGFloat = 0.78
    /// Spokes start just outside the core and end at the ring, never
    /// piercing the label band.
    public static let spokeInnerFraction: CGFloat = 0.09
    /// Group-label radius. Each label is a two-line block (name over
    /// its volume-share numeral), so this sits slightly inside the
    /// frame edge to keep the second line unclipped at top and bottom.
    public static let labelFraction: CGFloat = 0.89

    /// The petal burn gradient: each petal is hottest where it
    /// leaves the core and cools toward the tip, so the bloom reads
    /// as light rather than cut paper. Values are multipliers of the
    /// petal's burn (`petalOpacity`), applied at `burnMidLocation`
    /// and the tip.
    public static let burnMidLocation: Double = 0.55
    public static let burnMidScale: Double = 0.72
    public static let burnTipScale: Double = 0.45

    /// A stable clockwise hue drift. It is deliberately subtle: data
    /// remains encoded by geometry and luminance, never by colour.
    public static func hueShift(index: Int, count: Int) -> Double {
        guard count > 1 else { return 0 }
        return min(1, max(0, Double(index) / Double(count - 1)))
    }

    /// The hottest orange used at the root. It stays inside the brand
    /// hue instead of approaching white or yellow.
    public static func petalHot(hueShift: Double) -> Color {
        interpolatedColor(
            from: (1.0, 0.58, 0.10),
            to: (1.0, 0.50, 0.05),
            amount: hueShift
        )
    }

    public static func petalGold(hueShift: Double) -> Color {
        interpolatedColor(
            from: (1.0, 0.52, 0.06),
            to: (1.0, 0.45, 0.0),
            amount: hueShift
        )
    }

    public static func petalEmber(hueShift: Double) -> Color {
        interpolatedColor(
            from: (0.80, 0.22, 0.02),
            to: (0.88, 0.15, 0.06),
            amount: hueShift
        )
    }

    /// The multi-stop orange burn: bright at the root, brand orange
    /// through the belly, and deep ember at the tip. All stops scaled by the petal's burn
    /// (`petalOpacity`). The widget uses it directly while the app's
    /// mesh blade is built from the same palette.
    public static func burnGradient(opacity: Double, hueShift: Double) -> Gradient {
        Gradient(stops: [
            .init(color: petalHot(hueShift: hueShift).opacity(min(1, opacity * 1.1)), location: 0),
            .init(color: petalGold(hueShift: hueShift).opacity(min(1, opacity * 1.02)), location: 0.14),
            .init(color: Tint.primary.opacity(opacity), location: 0.38),
            .init(color: Tint.primary.opacity(opacity * burnMidScale), location: burnMidLocation),
            .init(color: petalEmber(hueShift: hueShift).opacity(opacity * burnTipScale), location: 1),
        ])
    }

    /// One clockwise-swept leaf in local coordinates. The asymmetric
    /// belly and curled tip replace the old mirrored lens; two tiled
    /// interior paths reproduce the Vivo logo's folded-leaf cleft.
    public static func petalShape(length: CGFloat, halfWidth: CGFloat) -> PetalShape {
        let base = CGPoint.zero
        let tip = CGPoint(x: length, y: halfWidth * 0.14)
        let leadingControl1 = CGPoint(x: length * 0.16, y: halfWidth)
        let leadingControl2 = CGPoint(x: length * 0.58, y: halfWidth * 0.86)
        let trailingControl1 = CGPoint(x: length * 0.74, y: -halfWidth * 0.46)
        let trailingControl2 = CGPoint(x: length * 0.30, y: -halfWidth * 0.58)
        let creaseStart = CGPoint(x: length * 0.06, y: -halfWidth * 0.08)
        let creaseControl = CGPoint(x: length * 0.40, y: -halfWidth * 0.30)
        let creaseEnd = CGPoint(x: length * 0.82, y: halfWidth * 0.06)

        var outline = Path()
        outline.move(to: base)
        outline.addCurve(to: tip, control1: leadingControl1, control2: leadingControl2)
        outline.addCurve(to: base, control1: trailingControl1, control2: trailingControl2)
        outline.closeSubpath()

        var leadingEdge = Path()
        leadingEdge.move(to: base)
        leadingEdge.addCurve(to: tip, control1: leadingControl1, control2: leadingControl2)

        var trailingEdge = Path()
        trailingEdge.move(to: tip)
        trailingEdge.addCurve(to: base, control1: trailingControl1, control2: trailingControl2)

        var crease = Path()
        crease.move(to: creaseStart)
        crease.addQuadCurve(to: creaseEnd, control: creaseControl)

        var blade = Path()
        blade.move(to: creaseStart)
        blade.addQuadCurve(to: creaseEnd, control: creaseControl)
        blade.addLine(to: tip)
        blade.addCurve(to: base, control1: leadingControl2, control2: leadingControl1)
        blade.closeSubpath()

        var specular = Path()
        specular.move(to: CGPoint(x: length * 0.07, y: halfWidth * 0.06))
        specular.addQuadCurve(
            to: CGPoint(x: length * 0.42, y: halfWidth * 0.25),
            control: CGPoint(x: length * 0.21, y: halfWidth * 0.24)
        )

        return PetalShape(
            outline: outline,
            blade: blade,
            leadingEdge: leadingEdge,
            trailingEdge: trailingEdge,
            crease: crease,
            specular: specular,
            tip: tip
        )
    }

    /// Compatibility surface used by the full-growth ghost.
    public static func petalPath(length: CGFloat, halfWidth: CGFloat) -> Path {
        petalShape(length: length, halfWidth: halfWidth).outline
    }

    public static let rimOpacity: Double = 0.85
    public static let rimTipScale: Double = 0.3
    public static let rimLineWidth: CGFloat = 1.1
    public static let trailingRimOpacity: Double = 0.4
    public static let trailingRimLineWidth: CGFloat = 0.7
    public static let foldOpacity: Double = 0.9
    public static let creaseOpacity: Double = 0.5
    public static let creaseHighlightOpacity: Double = 0.3
    public static let specularOpacity: Double = 0.75
    public static let specularLineWidth: CGFloat = 2.2
    public static let castShadowOpacity: Double = 0.34
    public static let castShadowBlur: CGFloat = 2.4
    public static let castShadowOffset: CGFloat = 1.8

    // Light architecture — the shared strengths of the additive
    // passes, so the app's animated emblem and the widget's still one
    // glow with the same voice. The bloom is the halo each petal
    // throws on the dark; the spill is the core's light landing on
    // the petal roots; the hot pass relights roots and speculars.
    public static let bloomRadiusFraction: CGFloat = 0.055
    public static let bloomOpacity: Double = 0.36
    public static let hotRadiusFraction: CGFloat = 0.02
    public static let dominantHaloBoost: Double = 0.55
    public static let coreSpillFraction: CGFloat = 0.38

    /// The core's light cast onto the bloom, clipped to the petal
    /// bodies by each renderer: bright orange at the bead, brand
    /// orange through the falloff, then deep ember before fading.
    public static func coreSpillGradient(strength: Double) -> Gradient {
        Gradient(stops: [
            .init(color: Color(red: 1.0, green: 0.52, blue: 0.06).opacity(strength * 0.72), location: 0),
            .init(color: Tint.primary.opacity(strength * 0.38), location: 0.38),
            .init(color: Color(red: 0.78, green: 0.20, blue: 0.0).opacity(strength * 0.12), location: 0.72),
            .init(color: .clear, location: 1),
        ])
    }

    /// The night behind the bloom — a barely-lit pocket of warm air
    /// instead of dead flat black, so the emblem sits in an
    /// atmosphere. Deepens with training intensity.
    public static let atmosphereFraction: CGFloat = 0.86
    public static func atmosphereGradient(intensity: Double) -> Gradient {
        let a = 0.6 + 0.4 * min(1, max(0, intensity))
        return Gradient(stops: [
            .init(color: Color(red: 0.24, green: 0.08, blue: 0.0).opacity(0.22 * a), location: 0),
            .init(color: Color(red: 0.10, green: 0.025, blue: 0.0).opacity(0.10 * a), location: 0.55),
            .init(color: .clear, location: 1),
        ])
    }

    public static func foldGradient(opacity: Double, hueShift: Double) -> Gradient {
        let gold = petalGold(hueShift: hueShift)
        let ember = petalEmber(hueShift: hueShift)
        return Gradient(stops: [
            .init(color: gold.opacity(opacity * 0.36), location: 0),
            .init(color: ember.opacity(foldOpacity * opacity), location: 0.32),
            .init(color: ember.opacity(opacity * 0.34), location: 1),
        ])
    }

    public static func rimGradient(opacity: Double, hueShift: Double) -> Gradient {
        Gradient(stops: [
            .init(
                color: petalGold(hueShift: hueShift).opacity(rimOpacity * opacity),
                location: 0
            ),
            .init(
                color: Tint.primary.opacity(rimOpacity * rimTipScale * opacity),
                location: 1
            ),
        ])
    }

    /// The ambient ember behind the whole bloom — a broad, soft
    /// warmth on the black canvas that scales with training
    /// intensity, giving the emblem the presence the logo has.
    public static func ambientOpacity(intensity: Double) -> Double {
        0.03 + 0.04 * min(1, max(0, intensity))
    }

    /// The ghost bloom — a dashed white outline of every petal at
    /// full development and full width, the silhouette the live
    /// petals grow into. White on black carries further than the
    /// tint at the same opacity; kept dashed so it still reads as
    /// aspiration, not data.
    public static let ghostOpacity: Double = 0.14
    public static let ghostLineWidth: CGFloat = 0.75
    public static let ghostDash: [CGFloat] = [2.5, 3.5]

    /// Development (0…1) → petal reach as a fraction of the emblem
    /// radius. Development is normalised against the top of each
    /// muscle's productive band, so real training lives at 0.2…0.5
    /// for months; pow(·, 0.8) gently lifts that band so the bloom
    /// fills its frame, while 0 and 1 stay honest.
    public static func reachFraction(development: Double) -> CGFloat {
        let d = min(1, max(0, development))
        return 0.26 + 0.58 * CGFloat(pow(d, 0.8))
    }

    /// Volume share (normalised to the largest petal, 0…1) → petal
    /// half-width, clamped so a short petal can never grow wider than
    /// it is long: stubby regions stay petals, not blobs. Kept
    /// slender — the logo's leaves are slim, and slim petals read as
    /// a bloom rather than a starfish.
    public static func halfWidth(shareNorm: Double, length: CGFloat, radius: CGFloat) -> CGFloat {
        let s = min(1, max(0, shareNorm))
        return min(radius * (0.045 + 0.2 * s), length * 0.52)
    }

    /// Development × effort → petal burn. The floor keeps even a weak
    /// region a deliberate shape on black; the dominant region burns a
    /// touch brighter. Renderers use this for both crisp material and
    /// additive light passes.
    public static func petalOpacity(development: Double, intensity: Double, isDominant: Bool) -> Double {
        let d = min(1, max(0, development))
        let i = min(1, max(0, intensity))
        let base = (0.42 + 0.46 * d) * (0.6 + 0.4 * i)
        return min(1, base + (isDominant ? 0.2 : 0))
    }

    private static func interpolatedColor(
        from start: (red: Double, green: Double, blue: Double),
        to end: (red: Double, green: Double, blue: Double),
        amount: Double
    ) -> Color {
        let t = min(1, max(0, amount))
        return Color(
            red: start.red + (end.red - start.red) * t,
            green: start.green + (end.green - start.green) * t,
            blue: start.blue + (end.blue - start.blue) * t
        )
    }
}
