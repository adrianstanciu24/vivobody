import SwiftUI

struct SettingsView: View {
    @State var weightUnit = "LB"
    @State var distanceUnit = "MI"
    @State var weightIncrement = 2.5
    @State var restTimer = 120
    @State var autoStartTimer = true
    @State var timerVibration = true
    @State var timerSound = false
    @State var theme = "DARK"
    @State var accentIndex = 0
    @State var iCloudSync = true

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileCard
                    unitsSection
                    vivoDivider
                    timerSection
                    vivoDivider
                    appearanceSection
                    vivoDivider
                    dataSection
                    vivoDivider
                    dangerSection
                    vivoDivider
                    brandingFooter
                    footerSection
                }
                .padding(.bottom, 32)
            }
        }
    }

    var vivoDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, 24)
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.vivoMono(12))
            .tracking(2)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }
}

// MARK: - Profile Card

private extension SettingsView {
    var profileCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.vivoSurface)
                .frame(width: 48, height: 48)
                .overlay(
                    Text("AS")
                        .font(.vivoMono(14, weight: .bold))
                        .foregroundStyle(Color.vivoPrimary)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Alex S.")
                    .font(.vivoDisplay(16, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                Text("MEMBER SINCE SEP 2025 · 127 SESSIONS")
                    .font(.vivoMono(12))
                    .tracking(0.5)
                    .foregroundStyle(Color.vivoSecondary)
                Text("SN: VIVO-USR-0041-AS")
                    .font(.vivoMono(7))
                    .tracking(1)
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
