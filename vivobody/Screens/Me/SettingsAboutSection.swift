//
//  SettingsAboutSection.swift
//  vivobody
//
//  Stateless Settings contact rows. URL and mail presentation remain
//  in SettingsScreen and arrive as explicit actions.
//

import SwiftUI
import VivoKit

struct SettingsAboutSection: View {
    let onOpenPrivacyPolicy: () -> Void
    let onComposeSupportMail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "About")

            VStack(alignment: .leading, spacing: 0) {
                aboutRow(
                    title: "Privacy Policy",
                    subtitle: "Everything stays on your device",
                    icon: "arrow.up.right",
                    hint: "Opens in this app",
                    action: onOpenPrivacyPolicy
                )
                rowDivider
                aboutRow(
                    title: "Contact & Support",
                    subtitle: "Questions, bugs, feature requests",
                    icon: "envelope",
                    hint: "Opens a new email",
                    action: onComposeSupportMail
                )
            }
            .contentCard()
        }
    }

    private func aboutRow(
        title: String,
        subtitle: String,
        icon: String,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title)
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Image(systemName: icon)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .padding(.horizontal, Space.lg)
            .accessibilityHidden(true)
    }
}
