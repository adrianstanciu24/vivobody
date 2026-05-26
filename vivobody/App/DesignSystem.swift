//
//  DesignSystem.swift
//  vivobody
//
//  Centralised colour and radius tokens for the Liquid Glass design
//  system. Every accent, surface tint, and corner radius routes
//  through these enums so a future palette tweak is one-file wide.
//
//  - `Tint.primary` is the warm orange/amber that drives navigation
//    tint, primary CTAs, and the focus ambient glow on the active
//    workout card.
//  - `Tint.success` is reserved for moment-of-completion cues:
//    SetCompleteButton, PR celebration, "exercise complete" flag.
//  - `Tint.danger` is reserved for destructive affordances and
//    delete confirmations.
//

import SwiftUI

enum Tint {
    /// Vivid red-orange — borrowed from the original vivobody palette
    /// (`#FF5500`). Saturated and unmistakable, reads as a bright
    /// "live now" accent rather than a soft amber tint.
    static let primary       = Color(.sRGB, red: 1.00, green: 0.333, blue: 0.00, opacity: 1.0)
    static let primaryDim    = Color(.sRGB, red: 1.00, green: 0.333, blue: 0.00, opacity: 0.35)
    /// Darker companion (`#CC4400`) — used when a deeper variant of
    /// the primary works better (shadow halos, pressed states).
    static let primaryShadow = Color(.sRGB, red: 0.80, green: 0.267, blue: 0.00, opacity: 1.0)

    /// Apple system green (`#34C759`) — vivid, grounded, not minty.
    static let success    = Color(.sRGB, red: 0.204, green: 0.780, blue: 0.349, opacity: 1.0)
    static let successDim = Color(.sRGB, red: 0.204, green: 0.780, blue: 0.349, opacity: 0.35)

    static let danger     = Color(.sRGB, red: 0.96, green: 0.42, blue: 0.42, opacity: 1.0)
}

enum Radius {
    static let card: CGFloat   = 24
    static let chip: CGFloat   = 16
    static let small: CGFloat  = 12
    static let pill: CGFloat   = 999
}

enum Surface {
    static let background = Color.black
    static let cardTint   = Color.white.opacity(0.04)
    static let edge       = Color.white.opacity(0.10)
    static let edgeBright = Color.white.opacity(0.22)
}
