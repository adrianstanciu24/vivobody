import SwiftUI

struct ExerciseDetailStretchProfileView: View {
    let stretch: ExerciseProfileStretch

    var body: some View {
        VStack(alignment: .leading, spacing: VivoSpacing.itemGap) {
            sectionHeader
            peakPosition
            ForEach(Array(stretch.topGroups.enumerated()), id: \.offset) { _, group in
                StretchGroupBar(group: group, maxShare: stretch.topGroups.first?.share ?? 1.0)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        HStack {
            Text("STRETCH PROFILE")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Text(stretch.level.uppercased())
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(levelColor)
        }
    }

    private var peakPosition: some View {
        Text("PEAK LOAD AT: \(stretch.peakRepPosition.replacingOccurrences(of: "_", with: " ").uppercased())")
            .font(.vivoMono(VivoFont.monoXS))
            .tracking(VivoTracking.tight)
            .foregroundStyle(Color.vivoSecondary)
    }

    private var levelColor: Color {
        switch stretch.level {
        case "high": .vivoAccent
        case "medium": .vivoYellow
        default: .vivoSecondary
        }
    }
}

// MARK: - Bar Row

private struct StretchGroupBar: View {
    let group: ExerciseProfileStretchGroup
    let maxShare: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(group.label.uppercased())
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoPrimary)
                .frame(width: 88, alignment: .leading)

            Text("\(Int(group.share * 100))%")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 32, alignment: .trailing)

            GeometryReader { geo in
                let normalizedWidth = maxShare > 0 ? group.share / maxShare : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: VivoRadius.bar)
                        .fill(Color.vivoSurface)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: VivoRadius.bar)
                        .fill(Color.vivoYellow)
                        .frame(width: geo.size.width * normalizedWidth, height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(height: 20)
    }
}

#Preview {
    ExerciseDetailStretchProfileView(
        stretch: ExerciseProfileStretch(
            level: "medium",
            peakRepPosition: "deep_position",
            topGroups: [
                ExerciseProfileStretchGroup(id: "hamstrings", label: "Hamstrings", share: 0.282),
                ExerciseProfileStretchGroup(id: "quads", label: "Quads", share: 0.282),
                ExerciseProfileStretchGroup(id: "glutes", label: "Glutes", share: 0.161)
            ],
            absoluteLevelScore10: 6,
            summary: ""
        )
    )
    .background(Color.vivoBackground)
}
