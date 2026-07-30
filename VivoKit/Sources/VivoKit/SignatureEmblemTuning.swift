//
//  SignatureEmblemTuning.swift
//  VivoKit
//
//  The single source of truth for the signature bloom's geometry, so
//  the app's animated emblem (the Insights hero) and the widget's
//  static one (SignatureWidget) can never drift. Pure value mapping
//  only: development / volume share / intensity in, radius fractions
//  and opacities out. Each renderer still draws its own Canvas (the
//  app adds the breath and the orbiting satellite; the widget stays
//  still), but every load-bearing number comes from here.
//

import CoreGraphics
import Foundation
import SwiftUI

public enum SignatureEmblemTuning {
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

    /// The petal's hottest colour — the near-white gold the burn
    /// starts from at the core, the same light the logo's petal is
    /// lit with. Only ever seen multiplied down by a petal's burn.
    public static let burnGold = Color(red: 1.0, green: 0.74, blue: 0.38)

    /// The multi-stop burn: incandescent gold where the petal leaves
    /// the core, settling to the tint through the belly, cooling to
    /// deep ember at the tip. All stops scaled by the petal's burn
    /// (`petalOpacity`). Shared verbatim by app and widget so the
    /// bloom is the same object in both places.
    public static func burnGradient(opacity: Double) -> Gradient {
        Gradient(stops: [
            .init(color: burnGold.opacity(min(1, opacity * 1.05)), location: 0),
            .init(color: Tint.primary.opacity(opacity), location: 0.2),
            .init(color: Tint.primary.opacity(opacity * burnMidScale), location: burnMidLocation),
            .init(color: Tint.primaryShadow.opacity(opacity * burnTipScale), location: 1),
        ])
    }

    /// One petal in local coordinates — base at the origin, tip at
    /// (length, 0) — so a base-to-tip gradient can be applied before
    /// the petal is rotated onto its axis. An organic leaf, not a
    /// lens: the belly sits forward of the midpoint, the tip tapers
    /// to a soft point — the silhouette the logo's petal is cut from.
    public static func petalPath(length: CGFloat, halfWidth: CGFloat) -> Path {
        let tip = CGPoint(x: length, y: 0)
        var leaf = Path()
        leaf.move(to: .zero)
        leaf.addCurve(
            to: tip,
            control1: CGPoint(x: length * 0.24, y: halfWidth * 1.04),
            control2: CGPoint(x: length * 0.72, y: halfWidth * 0.58)
        )
        leaf.addCurve(
            to: .zero,
            control1: CGPoint(x: length * 0.72, y: -halfWidth * 0.58),
            control2: CGPoint(x: length * 0.24, y: -halfWidth * 1.04)
        )
        return leaf
    }

    /// Rim light — a fine bright stroke along each petal's outline,
    /// strongest where it leaves the core and fading toward the tip,
    /// so petals read as lit forms with a definite silhouette rather
    /// than soft blobs. Scaled by the petal's burn at draw time.
    public static let rimOpacity: Double = 0.38
    public static let rimTipScale: Double = 0.3
    public static let rimLineWidth: CGFloat = 1

    /// The vein — a whisper of shadow along each petal's spine, the
    /// cleft the logo's petal carries. Nearly invisible; it just
    /// keeps wide petals from reading as flat fill.
    public static let veinOpacity: Double = 0.4

    /// Cross-section shading — each petal is a folded leaf, not a
    /// flat fill: light runs down the spine and falls off toward the
    /// edges. Applied as a single across-the-width gradient (shade →
    /// spine light → shade), scaled by the petal's burn.
    public static let edgeShadeOpacity: Double = 0.5
    public static let spineLightOpacity: Double = 0.16

    /// The ambient ember behind the whole bloom — a broad, soft
    /// warmth on the black canvas that scales with training
    /// intensity, giving the emblem the presence the logo has.
    public static func ambientOpacity(intensity: Double) -> Double {
        0.08 + 0.09 * min(1, max(0, intensity))
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
    /// touch brighter. Renderers draw petals additively (plus-lighter),
    /// so overlaps glow toward a hot core instead of muddying.
    public static func petalOpacity(development: Double, intensity: Double, isDominant: Bool) -> Double {
        let d = min(1, max(0, development))
        let i = min(1, max(0, intensity))
        let base = (0.42 + 0.46 * d) * (0.6 + 0.4 * i)
        return min(1, base + (isDominant ? 0.2 : 0))
    }
}
