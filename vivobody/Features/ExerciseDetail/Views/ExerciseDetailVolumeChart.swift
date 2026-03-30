import SwiftUI

struct ExerciseDetailVolumeChart: View {
    private static let barData: [(value: CGFloat, isPR: Bool)] = [
        (0.40, false), (0.55, false), (0.48, false),
        (0.62, true), (0.50, false), (0.70, false),
        (0.45, false), (0.80, true), (0.58, false),
        (0.65, false), (0.90, true), (1.0, true)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: VivoSpacing.itemGap) {
            sectionHeader
            chartArea
            legend
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        HStack {
            Text("VOLUME · LAST 12 SESSIONS")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Text("↑ 12%")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoGreen)
        }
    }

    private var chartArea: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(Self.barData.enumerated()), id: \.offset) { _, bar in
                VolumeBar(heightFraction: bar.value, isPR: bar.isPR)
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Color.vivoMuted, label: "VOLUME")
            legendItem(color: Color.vivoAccent, label: "PR SESSION")
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: VivoRadius.dot)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)
        }
    }
}

// MARK: - Volume Bar

struct VolumeBar: View {
    let heightFraction: CGFloat
    let isPR: Bool

    var body: some View {
        GeometryReader { geo in
            let barHeight = geo.size.height * heightFraction
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: VivoRadius.bar)
                    .fill(isPR ? Color.vivoAccent : Color.vivoSurface)
                    .frame(height: barHeight)
            }
        }
    }
}

#Preview {
    ExerciseDetailVolumeChart()
        .background(Color.vivoBackground)
}
