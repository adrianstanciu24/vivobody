//
//  MuscleColor.swift
//  vivobody
//
//  The design-system layer that turns a muscle's three abstract
//  channels (see `MuscleDevelopment.Channels`) into a colour the 3D
//  body model can render. It is deliberately a PURE, perceptual
//  mapping — no SceneKit, no UIKit — so it can be reasoned about and
//  unit-tested in isolation.
//
//  Why a 2-channel + bloom encoding
//  --------------------------------
//  A single brightness ramp can't tell "big but stagnant" apart from
//  "actively growing" — yet that's exactly the nuance we want the body
//  to convey. So colour carries three independent meanings:
//
//    • adaptation → LIGHTNESS. Dark/undeveloped → bright/developed.
//    • momentum   → CHROMA (saturation). Vivid while a muscle is
//                   growing, desaturated at a plateau, washed-out and
//                   cooler when it's being lost. A developed-but-
//                   stagnant muscle therefore reads bright-but-dull;
//                   a growing one glows.
//    • fatigue    → EMISSIVE BLOOM. A transient self-lit glow returned
//                   separately so the renderer can add it as emission;
//                   it fades over days without touching the base tone.
//
//  Why OKLCH
//  ---------
//  We compose the colour in OKLCH — a perceptually-uniform space —
//  rather than lerping RGB, so equal steps in adaptation look like
//  equal steps to the eye, and changing saturation (chroma) doesn't
//  drag the hue or apparent brightness around. The hue stays in the
//  app's single warm accent family (orange), nudging slightly toward
//  yellow while growing and toward red while detraining. The final
//  step converts OKLCH → OKLab → linear sRGB → gamma sRGB with the
//  standard Björn Ottosson matrices.
//

import CoreGraphics
import Foundation

enum MuscleColor {

    // MARK: - Tunables

    /// OKLab lightness endpoints for the adaptation ramp.
    private static let lightnessUntrained = 0.32
    private static let lightnessDeveloped = 0.80

    /// Chroma (OKLCH) for a developed-but-steady muscle, and the
    /// ceiling a fully-growing one reaches.
    private static let chromaSteady = 0.055
    private static let chromaMax = 0.16
    /// How much positive momentum adds chroma; how much negative
    /// momentum strips it back toward grey.
    private static let chromaGrowthGain = 0.13
    private static let chromaDetrainCut = 0.85

    /// Accent hue (degrees) ≈ the app's electric orange, with a gentle
    /// swing: warmer (toward yellow) while growing, cooler (toward
    /// red) while losing it.
    private static let accentHue = 52.0
    private static let hueSwing = 16.0

    // MARK: - Output

    /// Linear-friendly sRGB components in `0...1` plus the emissive
    /// bloom the renderer adds on top.
    struct RGB: Equatable {
        var red: Double
        var green: Double
        var blue: Double
        /// Self-illumination strength `0...1` (acute fatigue glow).
        var emissive: Double
    }

    /// OKLCH composition for one muscle, before conversion to sRGB.
    /// Exposed so behaviour (lightness rises with development, chroma
    /// rises with momentum) can be asserted directly.
    struct OKLCH: Equatable {
        var lightness: Double
        var chroma: Double
        var hue: Double       // degrees
        var emissive: Double
    }

    // MARK: - Mapping

    /// Compose the perceptual colour for a muscle's channels.
    static func oklch(for channels: MuscleDevelopment.Channels) -> OKLCH {
        let a = clamp01(channels.adaptation)
        let m = max(-1, min(1, channels.momentum))
        let posM = max(0, m)
        let negM = max(0, -m)

        let lightness = lightnessUntrained + (lightnessDeveloped - lightnessUntrained) * a

        // Saturation reads against development (an untrained muscle
        // stays grey no matter the trend), grows with positive
        // momentum, and is stripped toward grey by negative momentum.
        let trendChroma = chromaSteady
            + chromaGrowthGain * posM
            - chromaSteady * chromaDetrainCut * negM
        let chroma = clamp(a * max(0, trendChroma), 0, chromaMax)

        let hue = accentHue + hueSwing * (posM - negM)

        return OKLCH(lightness: lightness, chroma: chroma, hue: hue, emissive: clamp01(channels.fatigue))
    }

    /// The render-ready sRGB colour (plus emissive) for a muscle.
    static func rgb(for channels: MuscleDevelopment.Channels) -> RGB {
        let c = oklch(for: channels)
        let (r, g, b) = srgb(fromOKLCH: c.lightness, chroma: c.chroma, hueDegrees: c.hue)
        return RGB(red: r, green: g, blue: b, emissive: c.emissive)
    }

    // MARK: - OKLCH → sRGB

    /// OKLCH → OKLab → linear sRGB → gamma sRGB (Ottosson). Returns
    /// gamma-encoded sRGB components clamped to `0...1`.
    static func srgb(fromOKLCH L: Double, chroma C: Double, hueDegrees: Double) -> (Double, Double, Double) {
        let h = hueDegrees * .pi / 180
        let a = C * cos(h)
        let b = C * sin(h)

        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        let lr =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return (gammaEncode(lr), gammaEncode(lg), gammaEncode(lb))
    }

    private static func gammaEncode(_ c: Double) -> Double {
        let x = max(0, c)
        let encoded = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
        return clamp01(encoded)
    }

    private static func clamp01(_ x: Double) -> Double { clamp(x, 0, 1) }
    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, x)) }
}
