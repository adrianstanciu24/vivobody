//
//  PrimaryActionButton.swift
//  workapp
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
//    • Default accent is the universal completion green so the button
//      reads as "the thing you want to do right now."
//

import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = "arrow.right"
    var accent: Color = Color(.sRGB, red: 0.36, green: 0.92, blue: 0.62, opacity: 1.0)
    let action: () -> Void

    @State private var pressScale: CGFloat = 1.0

    var body: some View {
        Button {
            Haptics.crescendo()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) {
                pressScale = 0.97
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.6)) {
                    pressScale = 1.0
                }
            }
            action()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    if let subtitle {
                        Text(subtitle.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(2)
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
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(accent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: accent.opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressScale)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "Activates primary action")
        .accessibilityAddTraits(.isButton)
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
