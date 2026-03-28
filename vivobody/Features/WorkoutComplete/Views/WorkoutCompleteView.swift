import SwiftUI

struct WorkoutCompleteView: View {
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroHeader
                    vivoDivider
                    statsGrid
                    vivoDivider
                    prSection
                    vivoDivider
                    muscleVolumeSection
                    vivoDivider
                    comparisonSection
                    vivoDivider
                    exerciseLogSection
                    thickDivider
                    actionButtons
                    footerSection
                }
                .padding(.bottom, 32)
            }
        }
    }

    private var vivoDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, 24)
    }

    private var thickDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 2)
            .padding(.horizontal, 24)
    }
}

// MARK: - Hero Header

private extension WorkoutCompleteView {
    var heroHeader: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.vivoGreen)
                .frame(width: 48, height: 48)
                .overlay(
                    Text("✓")
                        .font(.vivoDisplay(20, weight: .bold))
                        .foregroundStyle(.white)
                )
                .padding(.top, 8)

            VStack(spacing: 0) {
                Text("Session")
                    .font(.vivoDisplay(30, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                Text("Complete")
                    .font(.vivoDisplay(30, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
            }
            .padding(.top, 12)

            Text("UPPER BODY PUSH A · SESSION #127")
                .font(.vivoMono(10))
                .tracking(1.5)
                .foregroundStyle(Color.vivoSecondary)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
    }
}

// MARK: - Stats Grid

private extension WorkoutCompleteView {
    var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 0
        ) {
            statCell(value: "52min", label: "DURATION", trend: "↑ 3 min faster", trendColor: .vivoGreen)
            statCell(value: "14,820lb", label: "TOTAL VOLUME", trend: "↑ +1,240 vs last", trendColor: .vivoGreen)
            statCell(value: "22", label: "TOTAL SETS", trend: "— same", trendColor: .vivoSecondary)
            statCell(value: "06", label: "EXERCISES", trend: "— same", trendColor: .vivoSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    func statCell(value: String, label: String, trend: String, trendColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.vivoDisplay(28, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(label)
                .font(.vivoMono(7))
                .tracking(1.5)
                .foregroundStyle(Color.vivoSecondary)
            Text(trend)
                .font(.vivoMono(12))
                .foregroundStyle(trendColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview {
    WorkoutCompleteView()
}
