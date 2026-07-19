//
//  MuscleColor.swift
//  vivobody
//
//  The design-system layer that turns a muscle-map channel into the
//  colour the 3D body model renders. It is deliberately a PURE mapping — no SceneKit, no
//  UIKit — so it can be reasoned about and unit-tested in isolation.
//
//  The encoding
//  ------------
//  Colour carries one continuous intensity. The owning surface gives
//  that intensity its meaning: chronic development on Today, or an
//  exercise's primary / secondary / stabilizer anatomy on Detail.
//
//    • adaptation → a TINT RAMP of the app's accent orange. A fully
//      developed muscle wears a vivid, saturated ORANGE; as
//      development drops the orange fades toward the theme's untrained
//      base. So the more saturated the orange, the more built the
//      muscle. The ramp deepens by draining green/blue (raising
//      chroma), NOT by crushing the value — crushing value is what
//      turns orange into muddy brown, so the red channel stays high.
//
//  The endpoints are themed: faded trained tissue starts at a muted,
//  desaturated clay/stone and sweeps toward vivid accent orange. A
//  separate neutral gray marks no history or no exercise role, so
//  "never trained" cannot look identical to "trained long ago."
//
//  Blends happen in OKLab, a perceptual colour space, so equal score
//  steps remain visibly closer to equal than raw RGB interpolation.
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

/// Whether a zero-intensity muscle has no history/context or has a
/// real signal that faded toward zero. Keeping this independent from
/// intensity prevents "never trained" and "trained long ago" from
/// collapsing into the same colour.
nonisolated enum MuscleMapBaseline: Equatable, Sendable {
    case noData
    case trained
}

/// Renderer input shared by the chronic development and temporary
/// exercise-anatomy maps. `intensity` is always continuous in 0...1;
/// labels and confidence are deliberately kept outside the colour.
nonisolated struct MuscleMapChannels: Equatable, Sendable {
    var intensity: Double
    var baseline: MuscleMapBaseline

    init(intensity: Double, baseline: MuscleMapBaseline = .trained) {
        self.intensity = intensity
        self.baseline = baseline
    }

    /// Compatibility spelling for development-model callers.
    init(adaptation: Double) {
        self.init(intensity: adaptation, baseline: .trained)
    }

    var adaptation: Double { intensity }

    static let noData = MuscleMapChannels(intensity: 0, baseline: .noData)
}

/// The five labels users see. Rendering remains continuous inside the
/// four trained bands; the labels avoid false percentage precision.
nonisolated enum MuscleDevelopmentBand: String, CaseIterable, Sendable {
    case noData
    case low
    case building
    case consistent
    case high

    var displayName: String {
        switch self {
        case .noData: return "No history"
        case .low: return "Low"
        case .building: return "Building"
        case .consistent: return "Consistent"
        case .high: return "High"
        }
    }

    var representativeIntensity: Double {
        switch self {
        case .noData: return 0
        case .low: return 0.125
        case .building: return 0.375
        case .consistent: return 0.625
        case .high: return 0.875
        }
    }

    static func resolve(_ channels: MuscleMapChannels) -> Self {
        guard channels.baseline == .trained else { return .noData }
        switch max(0, min(1, channels.intensity)) {
        case ..<0.25: return .low
        case ..<0.50: return .building
        case ..<0.75: return .consistent
        default: return .high
        }
    }
}

nonisolated enum MuscleColor {

    // MARK: - Tunables (gamma sRGB endpoints)

    /// Development ramp endpoints per theme. `a = 1` is a vivid,
    /// saturated orange; `a = 0` is the faded-trained base.
    ///
    /// The trained ramp must span PERCEPTUAL DISTANCE, not just hue. An
    /// earlier version kept the whole ramp inside a thin pale-peach →
    /// orange band (red pinned at 1.0, only green/blue moving): real
    /// training data clusters muscles in the middle of the range, and
    /// there the steps collapsed into one indistinguishable salmon. So
    /// the faded base is a MUTED, DESATURATED clay/stone — far
    /// from the accent in both chroma and feel — and development
    /// sweeps from that toward the vivid orange, lighting the muscle
    /// up out of the figure.
    ///
    /// Dark stage: faded `#9E8A75` dim clay, developed `#FF7A1A`
    /// vivid orange — a trained muscle literally brightens and
    /// saturates out of a quiet figure. The developed end must stay a
    /// high-value, high-chroma orange: crush its value and orange
    /// collapses into muddy brown.
    ///
    /// Light page: faded `#C2A893` warm stone, developed `#E85C00`
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

    /// Neutral, deliberately non-orange baseline for muscles with no
    /// logged development or no role in the inspected exercise.
    private static func noData(for theme: BodyModelTheme) -> (r: Double, g: Double, b: Double) {
        switch theme {
        case .dark:  (r: 0.43, g: 0.43, b: 0.46)
        case .light: (r: 0.61, g: 0.61, b: 0.64)
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
    static func rgb(for channels: MuscleMapChannels, theme: BodyModelTheme) -> RGB {
        guard channels.baseline == .trained else {
            let c = noData(for: theme)
            return RGB(red: c.r, green: c.g, blue: c.b)
        }

        let t = clamp01(channels.intensity)
        let lo = oklab(undeveloped(for: theme))
        let hi = oklab(developed(for: theme))
        return rgb(fromOKLab: (
            l: lerp(lo.l, hi.l, t),
            a: lerp(lo.a, hi.a, t),
            b: lerp(lo.b, hi.b, t)
        ))
    }

    // MARK: - OKLab + sRGB transfer

    private static func oklab(_ c: (r: Double, g: Double, b: Double)) -> (l: Double, a: Double, b: Double) {
        let rgb = linear(c)
        let l = 0.412_221_470_8 * rgb.0 + 0.536_332_536_3 * rgb.1 + 0.051_445_992_9 * rgb.2
        let m = 0.211_903_498_2 * rgb.0 + 0.680_699_545_1 * rgb.1 + 0.107_396_956_6 * rgb.2
        let s = 0.088_302_461_9 * rgb.0 + 0.281_718_837_6 * rgb.1 + 0.629_978_700_5 * rgb.2
        let lRoot = cbrt(l)
        let mRoot = cbrt(m)
        let sRoot = cbrt(s)
        return (
            l: 0.210_454_255_3 * lRoot + 0.793_617_785_0 * mRoot - 0.004_072_046_8 * sRoot,
            a: 1.977_998_495_1 * lRoot - 2.428_592_205_0 * mRoot + 0.450_593_709_9 * sRoot,
            b: 0.025_904_037_1 * lRoot + 0.782_771_766_2 * mRoot - 0.808_675_766_0 * sRoot
        )
    }

    private static func rgb(fromOKLab c: (l: Double, a: Double, b: Double)) -> RGB {
        let lRoot = c.l + 0.396_337_777_4 * c.a + 0.215_803_757_3 * c.b
        let mRoot = c.l - 0.105_561_345_8 * c.a - 0.063_854_172_8 * c.b
        let sRoot = c.l - 0.089_484_177_5 * c.a - 1.291_485_548_0 * c.b
        let l = lRoot * lRoot * lRoot
        let m = mRoot * mRoot * mRoot
        let s = sRoot * sRoot * sRoot
        return RGB(
            red: gammaEncode(4.076_741_662_1 * l - 3.307_711_591_3 * m + 0.230_969_929_2 * s),
            green: gammaEncode(-1.268_438_004_6 * l + 2.609_757_401_1 * m - 0.341_319_396_5 * s),
            blue: gammaEncode(-0.004_196_086_3 * l - 0.703_418_614_7 * m + 1.707_614_701_0 * s)
        )
    }

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
