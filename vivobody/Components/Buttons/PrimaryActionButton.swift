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
//      "this is a deliberate action" feedback). `sound` swaps the voice
//      that rides along — Today's START WORKOUT uses its own.
//    • The tinted Liquid Glass surface, padding, shadows, and press-scale
//      feedback all come from `PrimaryButtonStyle` — this view just supplies
//      the label content and the accent color.
//    • Default accent is the app's electric-orange primary so the
//      button reads as "the thing you want to do right now."
//

import SwiftUI
import VivoKit

struct PrimaryActionButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = "arrow.right"
    var accent: Color = Tint.primary
    /// Voice Control synonyms — short, speakable labels ordered by
    /// importance (first = primary). Lets a user say "Start" instead
    /// of the full "Start Workout" to activate this button.
    var inputLabels: [String]? = nil
    var sound: Sounds.Effect = .crescendo
    let action: () -> Void

    private static let labelSpacing: CGFloat = 3

    /// Height the subtitle line adds to the label stack, measured at the
    /// current text size. Half of it is trimmed from the style's vertical
    /// padding on each edge so a subtitled CTA stands exactly as tall as a
    /// title-only one — Today swaps between the two in the same slot.
    @State private var subtitleHeight: CGFloat = 0

    var body: some View {
        Button {
            Haptics.crescendo(sound: sound)
            action()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: Self.labelSpacing) {
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(Tint.onAccent.opacity(Opacity.medium))
                            // Subtitles carry live clocks (elapsed
                            // time, rest countdowns), which must not
                            // reflow the button as digits change.
                            .monospacedDigit()
                            .lineLimit(1)
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { height in
                                subtitleHeight = height
                            }
                    }
                    Text(title)
                        .font(Typography.title)
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
            .padding(.vertical, -subtitleInset)
        }
        .buttonStyle(PrimaryButtonStyle(accent: accent))
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "Activates primary action")
        .accessibilityAddTraits(.isButton)
        .accessibilityInputLabels((inputLabels ?? [title]).map { Text($0) })
    }

    private var subtitleInset: CGFloat {
        guard subtitle != nil, subtitleHeight > 0 else { return 0 }
        return (subtitleHeight + Self.labelSpacing) / 2
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
