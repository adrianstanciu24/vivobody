//
//  MuscleColor.swift
//  vivobody
//
//  The design-system layer that turns a muscle's training channels
//  (see `MuscleDevelopment.Channels`) into the colour the 3D body
//  model renders. It is deliberately a PURE mapping — no SceneKit, no
//  UIKit — so it can be reasoned about and unit-tested in isolation.
//
//  The encoding
//  ------------
//  Colour carries development only.
//
//    • adaptation → a TINT RAMP of the app's accent orange. A fully
//      developed muscle wears a vivid, saturated ORANGE; as
//      development drops the orange fades toward the theme's untrained
//      base. So the more saturated the orange, the more built the
//      muscle. The ramp deepens by draining green/blue (raising
//      chroma), NOT by crushing the value — crushing value is what
//      turns orange into muddy brown, so the red channel stays high.
//
//  The endpoints are themed: the untrained base is always a muted,
//  desaturated clay/stone (dim against black, warm stone against the
//  light page), and development sweeps a WIDE arc from it to the
//  vivid accent orange — luminance and chroma both move, so mid-range
//  differences between muscles stay visible. One ramp logic, two
//  endpoint pairs.
//
//  Blends happen in linear-light sRGB (gamma-decoded endpoints, lerp,
//  re-encode) so midtones don't go muddy and the ramp reads evenly.
//

import CoreGraphics
import Foundation

/// The resolved colour scheme the body model renders for. Distinct
/// from `AppAppearance` (the user's *preference*, which may be
/// "system") — this is the scheme actually in effect, mapped from
/// SwiftUI's environment at the render boundary. Pure value type so
/// `MuscleColor` stays free of UIKit/SwiftUI.
enum BodyModelTheme {
    case light
    case dark
}

enum MuscleColor {

    // MARK: - Tunables (gamma sRGB endpoints)

    /// Development ramp endpoints per theme. `a = 1` is a vivid,
    /// saturated orange; `a = 0` is the untrained base.
    ///
    /// The ramp must span PERCEPTUAL DISTANCE, not just hue. An
    /// earlier version kept the whole ramp inside a thin pale-peach →
    /// orange band (red pinned at 1.0, only green/blue moving): real
    /// training data clusters muscles in the middle of the range, and
    /// there the steps collapsed into one indistinguishable salmon. So
    /// the untrained base is a MUTED, DESATURATED clay/stone — far
    /// from the accent in both chroma and feel — and development
    /// sweeps from that toward the vivid orange, lighting the muscle
    /// up out of the figure.
    ///
    /// Dark stage: untrained `#9E8A75` dim clay, developed `#FF7A1A`
    /// vivid orange — a trained muscle literally brightens and
    /// saturates out of a quiet figure. The developed end must stay a
    /// high-value, high-chroma orange: crush its value and orange
    /// collapses into muddy brown.
    ///
    /// Light page: untrained `#C2A893` warm stone, developed `#E85C00`
    /// deep saturated orange — development DARKENS and saturates, so
    /// the figure separates by sitting below the near-white page.
    private static func developed(for theme: BodyModelTheme) -> (r: Double, g: Double, b: Double) {
        switch theme {
        case .dark:  (r: 1.00, g: 0.48, b: 0.10)
        case .light: (r: 0.91, g: 0.36, b: 0.00)
        }
    }

    private static func undeveloped(for theme: BodyModelTheme) -> (r: Double, g: Double, b: Double) {
        switch theme {
        case .dark:  (r: 0.62, g: 0.54, b: 0.46)
        case .light: (r: 0.76, g: 0.66, b: 0.58)
        }
    }

    // MARK: - Output

    /// Render-ready gamma sRGB components in `0...1`.
    struct RGB: Equatable {
        var red: Double
        var green: Double
        var blue: Double
    }

    // MARK: - Mapping

    /// The render-ready colour for a muscle's channels, on the given
    /// theme's ramp.
    static func rgb(for channels: MuscleDevelopment.Channels, theme: BodyModelTheme) -> RGB {
        let a = clamp01(channels.adaptation)

        let lo = linear(undeveloped(for: theme))
        let hi = linear(developed(for: theme))

        // Development → tint ramp (pale → vivid orange), in linear
        // light.
        let rl = lerp(lo.0, hi.0, a)
        let gl = lerp(lo.1, hi.1, a)
        let bl = lerp(lo.2, hi.2, a)

        return RGB(
            red: gammaEncode(rl),
            green: gammaEncode(gl),
            blue: gammaEncode(bl)
        )
    }

    // MARK: - sRGB transfer

    private static func linear(_ c: (r: Double, g: Double, b: Double)) -> (Double, Double, Double) {
        (gammaDecode(c.r), gammaDecode(c.g), gammaDecode(c.b))
    }

    private static func gammaDecode(_ c: Double) -> Double {
        let x = clamp01(c)
        return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
    }

    private static func gammaEncode(_ c: Double) -> Double {
        let x = max(0, c)
        let encoded = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
        return clamp01(encoded)
    }

    private static func lerp(_ x: Double, _ y: Double, _ t: Double) -> Double { x + (y - x) * t }
    private static func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
}
