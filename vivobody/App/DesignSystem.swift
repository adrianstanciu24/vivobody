//
//  DesignSystem.swift
//  vivobody
//
//  The visual constitution. Every colour, opacity tier, radius, and
//  spacing step routes through these enums so the whole app obeys
//  one set of rules — consistency is enforced by tokens, not by
//  willpower screen-to-screen.
//
//  First-principles rules baked in here:
//    1. ONE accent (electric orange). It marks the single primary
//       action, the live/in-progress state, and the moment of
//       completion / PR. Everything else is grayscale. No second hue.
//    2. Text is white at four opacity tiers (`Ink`) — hierarchy
//       comes from luminance, not colour.
//    3. ONE card fill, ONE hairline, ONE family of radii. Cards do
//       not get reinvented per screen.
//
//  - `Tint.primary` (electric orange) — primary CTA, nav tint, live indicator.
//  - `Tint.success` — moment-of-completion cues. Deliberately the
//    *same* hue as primary: completion is signalled by motion +
//    haptic + fill-state, not by introducing a competing colour.
//  - `Tint.danger` — destructive affordances only.
//

import SwiftUI

enum Tint {
    /// Electric orange (`#FF7300`). The single accent. On pure black
    /// it reads as molten / high-energy and pairs cleanly with
    /// grayscale. Used sparingly so it always means something.
    static let primary       = Color(.sRGB, red: 1.0, green: 0.45, blue: 0.0, opacity: 1.0)
    static let primaryDim    = Color(.sRGB, red: 1.0, green: 0.45, blue: 0.0, opacity: 0.35)
    /// Deeper amber companion — pressed states, shadow halos.
    static let primaryShadow = Color(.sRGB, red: 0.72, green: 0.30, blue: 0.0, opacity: 1.0)

    /// Completion / PR cue. Same hue as `primary` on purpose: one
    /// accent, full stop. The *moment* (spring overshoot, haptic
    /// crescendo, fill flooding in) is what reads as "done," not a
    /// new colour.
    static let success    = primary
    static let successDim = primaryDim

    // ONE accent, full stop. Both "in progress" and "complete" are
    // the same electric orange — the difference between them is read
    // through motion (spring overshoot), haptics (crescendo), and
    // fill-state (faint rim → solid flood), never a competing hue.
    // A second warm accent sitting ~30° away only muddied lists where
    // the two appeared side by side.

    /// In-progress — the live/charged state: the active set, the
    /// primary action you're about to take.
    static let inProgress = primary

    /// Complete — the earned "done" state: a finished set, a finished
    /// exercise, a PR. Same orange as `inProgress`; the *moment*
    /// (overshoot + haptic + fill flooding in) is what reads as done.
    static let complete    = primary
    static let completeDim = primaryDim

    /// Black sits on the accent for CTAs — maximum contrast.
    static let onAccent   = Color.black

    /// Destructive affordances only (delete, discard). The lone
    /// permitted exception to the one-accent rule.
    static let danger     = Color(.sRGB, red: 0.96, green: 0.42, blue: 0.42, opacity: 1.0)
}

/// Text colour tiers. Hierarchy is luminance, never hue. Reach for
/// these instead of scattering `.white.opacity(...)` literals so the
/// steps stay identical everywhere.
enum Ink {
    /// Hero numerals, titles, the thing you read first.
    static let primary    = Color.white
    /// Body copy, secondary values.
    static let secondary  = Color.white.opacity(0.70)
    /// Labels, captions, supporting metadata.
    static let tertiary   = Color.white.opacity(0.45)
    /// Faintest — disabled, dividers-as-text, deep background detail.
    static let quaternary = Color.white.opacity(0.30)
}

enum Radius {
    static let card: CGFloat   = 22
    static let chip: CGFloat   = 14
    static let small: CGFloat  = 10
    static let pill: CGFloat   = 999
}

/// 4-pt spacing scale. Section gaps, card padding, and row heights
/// all snap to these so vertical rhythm is shared across screens.
enum Space {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 12
    static let lg: CGFloat  = 16
    static let xl: CGFloat  = 20
    static let xxl: CGFloat = 24
    /// Outer screen gutter — the left/right padding every tab uses.
    static let gutter: CGFloat = 20
    /// Gap between major sections on a screen. Generous so a new
    /// section reads as a distinct block, not a continuation of the
    /// one above it.
    static let section: CGFloat = 32
    /// Minimum tappable row height (HIG-compliant, glanceable).
    static let rowMin: CGFloat = 60
}

enum Surface {
    static let background = Color.black
    static let cardTint   = Color.white.opacity(0.05)
    /// Brighter neutral fill for hero / primary stat cards — lets
    /// them read as "raised, important" through luminance rather
    /// than a colored tint wash (which skews muddy over black).
    static let cardTintBright = Color.white.opacity(0.08)
    static let edge       = Color.white.opacity(0.10)
    static let edgeBright = Color.white.opacity(0.22)
}
