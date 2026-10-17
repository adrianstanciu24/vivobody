//
//  SettingsPreferencesSection.swift
//  vivobody
//
//  Binding-driven Settings controls with no persistence or system-service
//  access. SettingsScreen supplies values, ordered setters, and actions.
//  Choices use SegmentedPicker and switches use native Toggle inside the
//  Settings cards.
//

import SwiftUI
import VivoKit

enum SettingsRestNotificationsPresentation: Equatable {
    case available
    case denied
}

struct SettingsPreferencesSection: View {
    @Binding var appearance: AppAppearance
    @Binding var bodyDriftSpeed: BodyDriftSpeed
    @Binding var weightUnit: WeightUnit
    @Binding var defaultRestSeconds: Int
    @Binding var hapticsEnabled: Bool
    @Binding var soundsEnabled: Bool
    @Binding var restNotificationsEnabled: Bool

    let restOptions: [Int]
    let restNotificationsPresentation: SettingsRestNotificationsPresentation
    let bundledExerciseCount: Int
    let onRequestCatalogReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Preferences")

            VStack(alignment: .leading, spacing: 0) {
                appearanceRow
                rowDivider
                bodyDriftSpeedRow
                rowDivider
                weightUnitRow
            }
            .contentCard()

            restRow
                .contentCard()

            VStack(alignment: .leading, spacing: 0) {
                toggleRow(
                    title: "Haptics",
                    subtitle: "Taps and patterns throughout the app",
                    accessibilityLabel: "Haptics",
                    isOn: $hapticsEnabled
                )
                rowDivider
                toggleRow(
                    title: "Sounds",
                    subtitle: "Feedback sounds paired with haptics",
                    accessibilityLabel: "Sounds",
                    isOn: $soundsEnabled
                )
                rowDivider
                restNotificationsRow
            }
            .contentCard()

            resetCatalogRow
                .contentCard()
        }
    }

    /// The bindings' setters already play the selection haptic through
    /// SettingsInteractionPolicy, so the pickers suppress their own.
    private var appearanceRow: some View {
        choiceRow(title: "Appearance", subtitle: "Light, dark, or follow the system") {
            SegmentedPicker(
                selection: $appearance,
                options: AppAppearance.allCases,
                font: Typography.sectionLabel,
                feedback: { _ in },
                stacksAtAccessibilitySizes: true,
                label: \.label
            )
        }
    }

    private var bodyDriftSpeedRow: some View {
        choiceRow(title: "Model Rotation", subtitle: "How fast the body model turns on its own") {
            SegmentedPicker(
                selection: $bodyDriftSpeed,
                options: BodyDriftSpeed.allCases,
                font: Typography.sectionLabel,
                feedback: { _ in },
                stacksAtAccessibilitySizes: true,
                label: \.label
            )
        }
    }

    private var weightUnitRow: some View {
        choiceRow(title: "Weight Unit", subtitle: "Displayed across the app — storage stays canonical") {
            SegmentedPicker(
                selection: $weightUnit,
                options: WeightUnit.allCases,
                accessibilityLabel: \.displayName,
                feedback: { _ in },
                stacksAtAccessibilitySizes: true,
                minSegmentHeight: 52
            ) { unit, _ in
                VStack(spacing: 2) {
                    Text(unit.symbol)
                        .font(Typography.metricUnit)
                    Text(unit.displayName)
                        .font(Typography.micro)
                        .opacity(Opacity.emphasis)
                }
            }
        }
    }

    private var restRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                rowTitle("Default Rest", subtitle: "Between sets — used by the rest timer")
                Spacer()
                Text("\(defaultRestSeconds)s")
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.primary)
            }

            SegmentedPicker(
                selection: $defaultRestSeconds,
                options: restOptions,
                accessibilityLabel: { "\($0) second rest" },
                feedback: { _ in },
                stacksAtAccessibilitySizes: true
            ) { seconds, isSelected in
                SegmentedPickerText(text: "\(seconds)s", font: Typography.metricUnit, isSelected: isSelected)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private func choiceRow(
        title: String,
        subtitle: String,
        @ViewBuilder picker: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            rowTitle(title, subtitle: subtitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            picker()
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private func toggleRow(
        title: String,
        subtitle: String,
        accessibilityLabel: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            rowTitle(title, subtitle: subtitle)
        }
        .tint(Tint.inProgress)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(subtitle)
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    @ViewBuilder
    private var restNotificationsRow: some View {
        switch restNotificationsPresentation {
        case .available:
            toggleRow(
                title: "Rest Alerts",
                subtitle: "Notify you when rest ends while Vivobody is in the background",
                accessibilityLabel: "Rest alerts",
                isOn: $restNotificationsEnabled
            )
        case .denied:
            HStack {
                rowTitle("Rest Alerts", subtitle: "Notifications are turned off in iOS Settings")
                Spacer(minLength: Space.md)
                Button("Open Settings") {
                    restNotificationsEnabled = true
                }
                .font(Typography.sectionLabel)
                .foregroundStyle(Tint.primary)
                .frame(minHeight: Space.tapMin)
                .accessibilityHint("Opens iOS Settings to allow notifications")
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
        }
    }

    private func rowTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.primary)
            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resetCatalogRow: some View {
        Button(role: .destructive, action: onRequestCatalogReset) {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Reset Exercise Catalog")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Tint.danger)
                    Text("Removes custom exercises and edits; restores \(bundledExerciseCount) bundled exercises")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Image(systemName: "arrow.counterclockwise")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Tint.danger)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Wipes and reseeds the exercise catalog")
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .padding(.horizontal, Space.lg)
            .accessibilityHidden(true)
    }
}
