//
//  PrimaryActionButton.swift
//  vivobody
//
//  The "do the thing" button. Used as the START WORKOUT call-to-action
//  on the Today screen and for other one-shot primary actions
//  throughout the app.
//
//  Distinct from SetCompleteButton: that one is stateful (toggle to
//  complete/undo) and reads a value pair. This one is fire-and-forget
//  — title, optional subtitle, optional arrow, single action closure.
//
//  Behavior:
//    • Crescendo haptic is queued on tap without delaying the action (same
//      beat as SetCompleteButton's "this is a deliberate action" feedback).
//      `sound` swaps the voice that rides along — Today's START WORKOUT uses
//      its own.
//    • The surface is the system prominent glass button through
//      `primaryButtonStyle`, shared by every primary CTA in the app. The
//      system owns the glass, press feedback, and Reduce Motion handling.
//    • Default accent is the app's electric-orange primary so the
//      button reads as "the thing you want to do right now."
//    • VoiceOver reads the title as the label and the subtitle as the
//      value, so live clocks never change the label that callers and
//      Voice Control match on.
//

import SwiftUI
import VivoKit

struct PrimaryActionButton: View {
    let title: String
    var subtitle: Text? = nil
    var icon: String? = "arrow.right"
    var accent: Color = Tint.primary
    /// Voice Control synonyms — short, speakable labels ordered by
    /// importance (first = primary). Lets a user say "Start" instead
    /// of the full "Start Workout" to activate this button.
    var inputLabels: [String]? = nil
    var sound: Sounds.Effect = .crescendo
    let action: () -> Void

    /// The label inset `.glassProminent` adds at `.small`. The label pads
    /// the rest itself, so the button matches the start tiles at the same
    /// height with or without a subtitle; the larger control sizes inset too
    /// much vertically for a subtitle to fit in `Space.actionMin`.
    private static let systemInset = EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)

    var body: some View {
        Button {
            action()
            Haptics.crescendo(sound: sound)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    if let subtitle {
                        subtitle
                            .font(Typography.caption)
                            .foregroundStyle(Tint.onAccent.opacity(Opacity.medium))
                            // Subtitles carry live clocks (elapsed
                            // time, rest countdowns), which must not
                            // reflow the button as digits change.
                            .monospacedDigit()
                            .lineLimit(1)
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
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Space.gutter - Self.systemInset.leading)
            .frame(maxWidth: .infinity, minHeight: Space.actionMin - Self.systemInset.top - Self.systemInset.bottom)
        }
        .primaryButtonStyle(accent: accent, controlSize: .small)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? Text(verbatim: ""))
        .accessibilityInputLabels((inputLabels ?? [title]).map { Text($0) })
    }
}

extension View {
    /// The app's primary call to action: the system prominent glass
    /// button in the card shape, tinted with the accent. `compact` drops
    /// to headline type for inline prompts where the hero scale would
    /// overwhelm the surrounding content. Both sizes stay above 44pt.
    /// `controlSize` overrides the size for a label that sets its own height.
    func primaryButtonStyle(
        accent: Color = Tint.primary,
        compact: Bool = false,
        controlSize: ControlSize? = nil
    ) -> some View {
        buttonStyle(.glassProminent)
            .buttonBorderShape(.roundedRectangle(radius: Radius.card))
            .controlSize(controlSize ?? (compact ? .large : .extraLarge))
            .tint(accent)
            .font(compact ? Typography.headline : Typography.title)
            .foregroundStyle(Tint.onAccent)
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryActionButton(
            title: "Start Workout",
            subtitle: Text("Push Day · 4 exercises")
        ) {}

        PrimaryActionButton(
            title: "Save Session",
            icon: "checkmark"
        ) {}

        PrimaryActionButton(
            title: "Custom Accent",
            subtitle: Text("blue variant"),
            accent: Color(red: 0.46, green: 0.74, blue: 0.96)
        ) {}

        Button("Compact prompt") {}
            .primaryButtonStyle(compact: true)
    }
    .padding(Space.xxl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
