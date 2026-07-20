//
//  PrimaryButtonStyle.swift
//  vivobody
//
//  The unified primary-CTA surface. Every "do the thing" button in
//  the app — the START WORKOUT hero on Today, the empty-state CTAs
//  on Me / Library / ExercisePicker — wears this style so there is
//  one visual vocabulary for the single most important action on a
//  screen.
//
//  Replaces the previous split between `PrimaryActionButton`'s
//  custom glass surface and the system `.glassProminent` capsule.
//  Both served the same semantic role but looked different (rounded
//  rectangle vs capsule); now all primary CTAs are a tinted Liquid
//  Glass rounded rectangle with `Radius.card` corners, the app's
//  accent tint, and a subtle press-scale dip.
//
//  Width is intrinsic — the caller's label decides. The hero CTA
//  passes a label with `.frame(maxWidth: .infinity)` to fill the
//  width; empty-state CTAs pass a bare `Text` and auto-size.
//
//  `compact: true` keeps the same tinted-glass surface but drops to
//  headline type and tighter padding — for inline section prompts
//  where the hero scale would overwhelm surrounding content.
//

import VivoKit
import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var accent: Color = Tint.primary
    var cornerRadius: CGFloat = Radius.card
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonContent(
            configuration: configuration,
            accent: accent,
            cornerRadius: cornerRadius,
            compact: compact
        )
    }
}

/// Renders the styled primary-CTA content. Split out from
/// `PrimaryButtonStyle` so it can read `@Environment` values
/// (notably `accessibilityReduceMotion`), which `ButtonStyle`
/// itself cannot do.
private struct PrimaryButtonContent: View {
    let configuration: PrimaryButtonStyle.Configuration
    let accent: Color
    let cornerRadius: CGFloat
    let compact: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .font(compact ? Typography.headline : Typography.title)
            .tracking(0.4)
            .foregroundStyle(Tint.onAccent)
            .padding(.horizontal, compact ? Space.xl : Space.xxl)
            .padding(.vertical, compact ? Space.md : Space.xl)
            .glassTinted(accent, interactive: true, in: shape)
            .shadow(color: accent.opacity(compact ? 0.12 : 0.18), radius: compact ? 10 : 18, y: compact ? 4 : 8)
            .shadow(color: .black.opacity(compact ? 0.3 : 0.45), radius: compact ? 6 : 10, y: compact ? 3 : 5)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.62),
                value: configuration.isPressed
            )
    }
}
