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
//    • The tinted Liquid Glass surface, padding, shadows, and press-scale
//      feedback all come from `PrimaryButtonStyle` — this view just supplies
//      the label content and the accent color.
//    • Default accent is the app's electric-orange primary so the
//      button reads as "the thing you want to do right now."
//

import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = "arrow.right"
    var accent: Color = Tint.primary
    /// Voice Control synonyms — short, speakable labels ordered by
    /// importance (first = primary). Lets a user say "Start" instead
    /// of the full "Start Workout" to activate this button.
    var inputLabels: [String]? = nil
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
                            .foregroundStyle(Tint.onAccent.opacity(Opacity.medium))
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
                        .foregroundStyle(Tint.onAccent.opacity(Opacity.strong))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle(accent: accent))
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "Activates primary action")
        .accessibilityAddTraits(.isButton)
        .accessibilityInputLabels((inputLabels ?? [title]).map { Text($0) })
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
    .padding(Space.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
