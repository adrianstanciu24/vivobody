//
//  PrimaryActionButton.swift
//  vivobody
//
//  The "do the thing" button. Used as the START WORKOUT call-to-action
//  on the Today screen and (eventually) for other one-shot primary
//  actions throughout the app.
//
//  Distinct from SetCompleteButton: that one is stateful (toggle to
//  complete/undo) and reads a value pair. This one is fire-and-forget
//  — title, optional subtitle, optional arrow, single action closure.
//
//  Behavior:
//    • Crescendo haptic fires on tap (same beat as SetCompleteButton's
//      "this is a deliberate action" feedback).
//    • A tinted Liquid Glass surface (.glassEffect) provides the lensing
//      and accent wash with a controlled 18pt corner and height — the
//      .glassProminent button style is avoided because it doubles the
//      padding and forces a full capsule.
//    • Default accent is the app's electric-orange primary so the
//      button reads as "the thing you want to do right now."
//

import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = "arrow.right"
    var accent: Color = Tint.primary
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.crescendo()
            action()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(Tint.onAccent.opacity(0.55))
                    }
                    Text(title)
                        .font(Typography.title)
                        .tracking(0.4)
                        .foregroundStyle(Tint.onAccent)
                }

                Spacer()

                if let icon {
                    Image(systemName: icon)
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Tint.onAccent.opacity(0.85))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .modifier(PrimaryGlassSurface(accent: accent, cornerRadius: 22))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "Activates primary action")
        .accessibilityAddTraits(.isButton)
    }
}

/// Tinted Liquid Glass surface for the primary CTA. Keeps the corner
/// radius and shadows under our control (the system .glassProminent
/// style forces a capsule and adds its own padding).
private struct PrimaryGlassSurface: ViewModifier {
    let accent: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .glassEffect(.regular.tint(accent).interactive(), in: shape)
            .shadow(color: accent.opacity(0.18), radius: 18, y: 8)
            .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
            .contentShape(shape)
    }
}

/// Subtle press feedback — the glass dips slightly under the finger.
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryActionButton(
            title: "Start Workout",
            subtitle: "Push Day · 4 exercises"
        ) {}

        PrimaryActionButton(
            title: "Save Session",
            icon: "checkmark"
        ) {}

        PrimaryActionButton(
            title: "Custom Accent",
            subtitle: "blue variant",
            accent: Color(red: 0.46, green: 0.74, blue: 0.96)
        ) {}
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
