//
//  SettingsPreferencesSection.swift
//  vivobody
//
//  Binding-driven Settings controls with no persistence or system-service
//  access. SettingsScreen supplies values, ordered setters, and actions.
//

import SwiftUI
import VivoKit

struct SettingsPreferencesSection: View {
    @Binding var appearance: AppAppearance
    @Binding var bodyDriftSpeed: BodyDriftSpeed
    @Binding var weightUnit: WeightUnit
    @Binding var defaultRestSeconds: Int
    @Binding var hapticsEnabled: Bool
    @Binding var soundsEnabled: Bool
    @Binding var healthKitEnabled: Bool

    let restOptions: [Int]
    let healthKitPresentation: SettingsHealthKitPresentation
    let bundledExerciseCount: Int
    let onRequestUnlock: () -> Void
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
                rowDivider
                restRow
                rowDivider
                hapticsRow
                rowDivider
                soundsRow
                if healthKitPresentation != .unavailable {
                    rowDivider
                    healthKitRow
                }
                rowDivider
                resetCatalogRow
            }
            .contentCard()
        }
    }

    private var appearanceRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Appearance")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Light, dark, or follow the system")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(AppAppearance.allCases) { option in
                        appearanceChip(option)
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private func appearanceChip(_ option: AppAppearance) -> some View {
        let isSelected = option == appearance
        return Button {
            appearance = option
        } label: {
            Text(option.label)
                .font(Typography.sectionLabel)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .coloredGlassControl(cornerRadius: Radius.chip, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var bodyDriftSpeedRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Model Rotation")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("How fast the body model turns on its own")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(BodyDriftSpeed.allCases) { option in
                        bodyDriftSpeedChip(option)
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private func bodyDriftSpeedChip(_ option: BodyDriftSpeed) -> some View {
        let isSelected = option == bodyDriftSpeed
        return Button {
            bodyDriftSpeed = option
        } label: {
            Text(option.label)
                .font(Typography.sectionLabel)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .coloredGlassControl(cornerRadius: Radius.chip, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var weightUnitRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Weight Unit")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Displayed across the app — storage stays canonical")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GlassEffectContainer(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(WeightUnit.allCases) { unit in
                        weightUnitChip(unit)
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private func weightUnitChip(_ unit: WeightUnit) -> some View {
        let isSelected = unit == weightUnit
        return Button {
            weightUnit = unit
        } label: {
            VStack(spacing: 2) {
                Text(unit.symbol)
                    .font(Typography.metricUnit)
                Text(unit.displayName)
                    .font(Typography.micro)
                    .opacity(Opacity.emphasis)
            }
            .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .coloredGlassControl(cornerRadius: Radius.chip, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unit.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var restRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Default Rest")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Text("Between sets — used by the rest timer")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Text("\(defaultRestSeconds)s")
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.primary)
            }
            .padding(.horizontal, Space.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: Space.sm) {
                    HStack(spacing: Space.sm) {
                        ForEach(restOptions, id: \.self) { seconds in
                            restChip(seconds: seconds)
                        }
                    }
                }
                .padding(.vertical, Space.md)
            }
            .padding(.vertical, -Space.md)
            .contentMargins(.horizontal, Space.lg, for: .scrollContent)
        }
        .padding(.vertical, Space.md)
    }

    private func restChip(seconds: Int) -> some View {
        let isSelected = defaultRestSeconds == seconds
        return Button {
            defaultRestSeconds = seconds
        } label: {
            Text("\(seconds)s")
                .font(Typography.metricUnit)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(minWidth: 56, minHeight: 44)
                .padding(.horizontal, Space.md + 2)
                .coloredGlassControl(cornerRadius: Radius.pill, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(seconds) second rest")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var hapticsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Haptics")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Taps and patterns throughout the app")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            Spacer()
            Toggle("", isOn: $hapticsEnabled)
                .labelsHidden()
                .tint(Tint.inProgress)
                .accessibilityLabel("Haptics")
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private var soundsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Sounds")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Feedback sounds paired with haptics")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
            Spacer()
            Toggle("", isOn: $soundsEnabled)
                .labelsHidden()
                .tint(Tint.inProgress)
                .accessibilityLabel("Sounds")
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    @ViewBuilder
    private var healthKitRow: some View {
        switch healthKitPresentation {
        case .unavailable:
            EmptyView()

        case .locked:
            Button(action: onRequestUnlock) {
                HStack {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Apple Health")
                            .font(Typography.sectionHeading)
                            .foregroundStyle(Ink.primary)
                        Text("Save finished workouts to the Health app · Pro")
                            .font(Typography.caption)
                            .foregroundStyle(Ink.tertiary)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
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
            .accessibilityLabel("Apple Health, part of Vivobody Pro")
            .accessibilityHint("Opens the Vivobody Pro purchase sheet")

        case .unlocked:
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Apple Health")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Text("Save finished workouts to the Health app")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Toggle("", isOn: $healthKitEnabled)
                    .labelsHidden()
                    .tint(Tint.inProgress)
                    .accessibilityLabel("Apple Health")
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
        }
    }

    private var resetCatalogRow: some View {
        Button(action: onRequestCatalogReset) {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Reset Exercise Catalog")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Text("Restore \(bundledExerciseCount) bundled exercises")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Image(systemName: "arrow.counterclockwise")
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
