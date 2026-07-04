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

import VivoKit
import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var accent: Color = Tint.primary
    var cornerRadius: CGFloat = Radius.card

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonContent(
            configuration: configuration,
            accent: accent,
            cornerRadius: cornerRadius
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .font(Typography.title)
            .tracking(0.4)
            .foregroundStyle(Tint.onAccent)
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.xl)
            .glassTinted(accent, interactive: true, in: shape)
            .shadow(color: accent.opacity(0.18), radius: 18, y: 8)
            .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.62),
                value: configuration.isPressed
            )
    }
}
