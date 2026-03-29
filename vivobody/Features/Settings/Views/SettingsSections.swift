import SwiftUI

// MARK: - Units Section

extension SettingsView {
    var unitsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("UNITS & MEASUREMENT")
            settingRow(
                title: "Weight Unit",
                subtitle: "Used for load, volume, and body weight"
            ) {
                segmentedPicker(
                    options: ["LB", "KG"],
                    selection: $weightUnit
                )
            }
            settingRow(
                title: "Distance Unit",
                subtitle: "Cardio tracking and movement distance"
            ) {
                segmentedPicker(
                    options: ["MI", "KM"],
                    selection: $distanceUnit
                )
            }
            settingRow(
                title: "Weight Increment",
                subtitle: "Step size for load +/- buttons"
            ) {
                stepperControl(
                    value: String(format: "%.1f lb", weightIncrement),
                    onMinus: { weightIncrement = max(0.5, weightIncrement - 0.5) },
                    onPlus: { weightIncrement += 0.5 }
                )
            }
        }
    }

    var timerSection: some View {
        VStack(spacing: 0) {
            sectionHeader("TIMER & REST")
            settingRow(
                title: "Default Rest Timer",
                subtitle: "Auto-starts after logging a set"
            ) {
                stepperControl(
                    value: formatTime(restTimer),
                    onMinus: { restTimer = max(30, restTimer - 15) },
                    onPlus: { restTimer += 15 }
                )
            }
            toggleRow(
                title: "Auto-Start Timer",
                subtitle: "Begin rest countdown after each set",
                isOn: $autoStartTimer
            )
            toggleRow(
                title: "Timer Vibration",
                subtitle: "Haptic feedback when rest ends",
                isOn: $timerVibration
            )
            toggleRow(
                title: "Timer Sound",
                subtitle: "Audible alert when rest ends",
                isOn: $timerSound
            )
        }
    }

    var appearanceSection: some View {
        VStack(spacing: 0) {
            sectionHeader("APPEARANCE")
            settingRow(
                title: "Theme",
                subtitle: "Interface color scheme"
            ) {
                segmentedPicker(
                    options: ["LIGHT", "DARK", "AUTO"],
                    selection: $theme
                )
            }
            settingRow(
                title: "Accent Color",
                subtitle: "Primary highlight color"
            ) {
                accentColorPicker
            }
        }
    }
}

// MARK: - Data Section

extension SettingsView {
    var dataSection: some View {
        VStack(spacing: 0) {
            sectionHeader("DATA")
            iconRow(icon: "↑", title: "Export Data", subtitle: "Download all sessions as CSV or JSON")
            iconRow(icon: "↓", title: "Import Data", subtitle: "Import from Strong, Hevy, or CSV")
            toggleIconRow(
                icon: "☁",
                title: "iCloud Sync",
                subtitle: "Last synced: today at 09:38",
                isOn: $iCloudSync
            )
        }
    }

    var dangerSection: some View {
        VStack(spacing: 0) {
            sectionHeader("DANGER ZONE")
            iconRow(
                icon: "⚠",
                title: "Reset All Data",
                subtitle: "Permanently delete all sessions and exercises",
                titleColor: .red
            )
        }
    }
}

// MARK: - Branding & Footer

extension SettingsView {
    var brandingFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VIVOBODY")
                .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Text("VERSION 5.0.0 (127)")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)

            Text("BUILD 2026.03.18 · TEENAGE ENGINEERING INSPIRED")
                .font(.vivoMono(VivoFont.monoMin))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    var footerSection: some View {
        VivoFooter()
    }
}

// MARK: - Reusable Components

extension SettingsView {
    func settingRow(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoPrimary)
                Text(subtitle)
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .frame(height: 62)
    }

    func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoPrimary)
                Text(subtitle)
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.vivoAccent)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .frame(height: 62)
    }

    func iconRow(
        icon: String,
        title: String,
        subtitle: String,
        titleColor: Color = .vivoPrimary
    ) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.vivoDisplay(VivoFont.bodySmall))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(titleColor)
                Text(subtitle)
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            Text("›")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoMuted)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .frame(height: 62)
    }

    func toggleIconRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.vivoDisplay(VivoFont.bodySmall))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoPrimary)
                Text(subtitle)
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.vivoAccent)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .frame(height: 62)
    }

    func segmentedPicker(options: [String], selection: Binding<String>) -> some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.wrappedValue == option
                Button { selection.wrappedValue = option } label: {
                    Text(option)
                        .font(.vivoMono(VivoFont.monoXS, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(
                            isSelected ? Color.vivoBackground : Color.vivoSecondary
                        )
                        .padding(.horizontal, VivoSpacing.cardPadding)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: VivoRadius.pill)
                                .fill(isSelected ? Color.vivoPrimary : Color.clear)
                        )
                        .overlay(
                            isSelected ? nil :
                                RoundedRectangle(cornerRadius: VivoRadius.pill)
                                .stroke(Color.vivoSurface, lineWidth: 1)
                        )
                }
            }
        }
    }

    func stepperControl(
        value: String,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Button(action: onMinus) {
                Text("−")
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoSecondary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: VivoRadius.pill)
                            .stroke(Color.vivoSurface, lineWidth: 1)
                    )
            }

            Text(value)
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoPrimary)
                .frame(minWidth: 42)

            Button(action: onPlus) {
                Text("+")
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoSecondary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: VivoRadius.pill)
                            .stroke(Color.vivoSurface, lineWidth: 1)
                    )
            }
        }
    }

    var accentColorPicker: some View {
        let colors: [Color] = [.vivoAccent, .vivoGreen, .blue, .purple]
        return HStack(spacing: 6) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        index == accentIndex
                            ? Circle().stroke(Color.vivoPrimary, lineWidth: 2)
                            : nil
                    )
                    .onTapGesture { accentIndex = index }
            }
        }
    }

    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
