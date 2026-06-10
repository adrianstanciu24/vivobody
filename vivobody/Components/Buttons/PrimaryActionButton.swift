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
//    • Tactile press scale (1.0 → 0.97 → 1.0).
//    • Default accent is the app's electric-orange primary so the
//      button reads as "the thing you want to do right now." Liquid
//      Glass adds the interactive surface response without changing
//      that chosen color.
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
                            .foregroundStyle(.black.opacity(0.55))
                    }
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                }

                Spacer()

                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .modifier(PrimaryGlassSurface(accent: accent, cornerRadius: 18))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "Activates primary action")
        .accessibilityAddTraits(.isButton)
    }
}

/// Prominent, full-width Liquid Glass surface for primary actions. The
/// accent remains an opaque design-token fill; glass only adds the
/// interactive optical response and rim detail on top.
private struct PrimaryGlassSurface: ViewModifier {
    let accent: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                shape.fill(accent)
            }
            .glassEffect(.regular.interactive(), in: shape)
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.46),
                            Color.black.opacity(0.12),
                            Color.white.opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.9
                )
            }
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.52)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .shadow(color: accent.opacity(0.18), radius: 18, y: 8)
            .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
            .contentShape(shape)
    }
}

/// A physical "push" press: the button scales down while held and
/// springs back on release. Deliberately scale-only, leaving the glass
/// material to handle its own interactive optical response.
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
