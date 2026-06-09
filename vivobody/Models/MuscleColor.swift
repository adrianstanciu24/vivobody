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
//  Colour carries development only; tightness is passed through for
//  the renderer to drive a brightness pulse on top.
//
//    • adaptation → a TINT RAMP of the app's accent orange. A fully
//      developed muscle wears a vivid, saturated ORANGE (#FF7A1A); as
//      development drops the orange pales toward a light, washed-out
//      tint. So the more saturated the orange, the more built the
//      muscle. The ramp deepens by draining green/blue (raising
//      chroma), NOT by crushing the value — crushing value is what
//      turns orange into muddy brown, so the red channel stays high.
//    • tightness  → not in the diffuse at all; returned as a level the
//      renderer turns into a brighten-only throb (base↔brighter, same
//      hue), so a tight muscle pulses brighter in its own colour
//      without restaining it. Pulsation IS the tightness signal.
//
//  Blends happen in linear-light sRGB (gamma-decoded endpoints, lerp,
//  re-encode) so midtones don't go muddy and the ramp reads evenly.
//

import CoreGraphics
import Foundation

enum MuscleColor {

    // MARK: - Tunables (gamma sRGB endpoints)

    /// Development ramp. `a = 1` is a vivid, saturated orange
    /// (`#FF7A1A`); `a = 0` is a pale, light tint of that same orange.
    /// The trick: a fully developed muscle must stay a high-VALUE,
    /// high-chroma orange — crush the value (e.g. `#8C4000`, or even a
    /// burnt `#E06605` once the renderer dims it) and orange collapses
    /// into muddy brown. So we keep the red channel pinned high and
    /// deepen the ramp purely by draining green + blue (raising chroma).
    private static let developed   = (r: 1.00, g: 0.48, b: 0.10)
    private static let undeveloped = (r: 1.00, g: 0.83, b: 0.69)

    // MARK: - Output

    /// Render-ready gamma sRGB components in `0...1`, plus the tightness
    /// level the renderer turns into a brightness pulse.
    struct RGB: Equatable {
        var red: Double
        var green: Double
        var blue: Double
        /// Tightness level `0...1`, passed through for the renderer
        /// (see `BodyModelScene`) — never baked into the base colour;
        /// it only drives the throb that marks a stiff muscle.
        var tightness: Double
    }

    // MARK: - Mapping

    /// The render-ready colour for a muscle's channels.
    static func rgb(for channels: MuscleDevelopment.Channels) -> RGB {
        let a = clamp01(channels.adaptation)

        let lo = linear(undeveloped)
        let hi = linear(developed)

        // Development → tint ramp (pale → vivid orange), in linear
        // light. Tightness is left out of the colour entirely.
        let rl = lerp(lo.0, hi.0, a)
        let gl = lerp(lo.1, hi.1, a)
        let bl = lerp(lo.2, hi.2, a)

        return RGB(
            red: gammaEncode(rl),
            green: gammaEncode(gl),
            blue: gammaEncode(bl),
            tightness: clamp01(channels.tightness)
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
