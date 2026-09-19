//
//  RestNotificationPrimerCard.swift
//  vivobody
//
//  Contextual, non-blocking explanation shown during the first rest.
//  It keeps the timer usable and leaves the system permission prompt
//  behind an explicit Turn On action.
//

import SwiftUI
import VivoKit

struct RestNotificationPrimerCard: View {
    let onNotNow: () -> Void
    let onTurnOn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Rest alerts")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Get notified when rest ends while Vivobody is in the background or your iPhone is locked.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.sm) {
                    actions
                }
                VStack(spacing: Space.sm) {
                    actions
                }
            }
        }
        .padding(Space.lg)
        .contentCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("restNotificationPrimer")
    }

    @ViewBuilder
    private var actions: some View {
        Button("Not now", action: onNotNow)
            .font(Typography.sectionLabel)
            .foregroundStyle(Ink.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("dismissRestNotificationsButton")

        Button("Turn on", action: onTurnOn)
            .font(Typography.sectionLabel)
            .foregroundStyle(Tint.onAccent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .coloredGlassControl(cornerRadius: Radius.chip, fill: Tint.inProgress)
            .accessibilityIdentifier("enableRestNotificationsButton")
    }
}

#Preview {
    RestNotificationPrimerCard(onNotNow: {}, onTurnOn: {})
        .padding()
        .screenBackground()
        .preferredColorScheme(.dark)
}
