//
//  SettingsProSection.swift
//  vivobody
//
//  Binding-free presentation for the Vivobody Pro row at the top of
//  Settings. The root owns StoreKit state and routes unlock requests.
//

import SwiftUI
import VivoKit

struct SettingsProSection: View {
    let presentation: SettingsProPresentation
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Vivobody Pro")

            switch presentation {
            case .unlocked:
                HStack {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Vivobody Pro")
                            .font(Typography.sectionHeading)
                            .foregroundStyle(Ink.primary)
                        Text("Unlocked — thank you")
                            .font(Typography.caption)
                            .foregroundStyle(Ink.tertiary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(Typography.headline)
                        .foregroundStyle(Tint.primaryText)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
                .contentCard()
                .accessibilityElement(children: .combine)

            case .locked:
                Button(action: onUnlock) {
                    HStack {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("Unlock Vivobody Pro")
                                .font(Typography.sectionHeading)
                                .foregroundStyle(Ink.primary)
                            Text("Insights, exercise instruments, comparison, unlimited templates, widgets")
                                .font(Typography.caption)
                                .foregroundStyle(Ink.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(Typography.sectionLabel)
                            .foregroundStyle(Ink.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.md)
                    .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
                    .contentCard(bright: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settingsProUnlock")
                .accessibilityHint("Opens the Vivobody Pro purchase sheet")
            }
        }
    }
}
