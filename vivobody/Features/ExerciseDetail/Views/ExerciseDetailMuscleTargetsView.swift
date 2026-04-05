import SwiftUI

struct ExerciseDetailMuscleTargetsView: View {
    let targets: [ExerciseProfileTarget]

    var body: some View {
        VStack(alignment: .leading, spacing: VivoSpacing.itemGap) {
            sectionHeader
            ForEach(Array(targets.enumerated()), id: \.offset) { _, target in
                MuscleTargetBar(target: target)
            }
            legend
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        HStack {
            Text("MUSCLE TARGETS")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Text("\(targets.count) GROUPS")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Color.vivoAccent, label: "PRIMARY")
            legendItem(color: Color.vivoSecondary, label: "SECONDARY")
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

// MARK: - Bar Row

private struct MuscleTargetBar: View {
    let target: ExerciseProfileTarget

    private var barColor: Color {
        target.role == "primary" ? .vivoAccent : .vivoSecondary
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(target.label.uppercased())
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoPrimary)
                .frame(width: 88, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: VivoRadius.bar)
                        .fill(Color.vivoSurface)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: VivoRadius.bar)
                        .fill(barColor)
                        .frame(width: geo.size.width * target.share, height: 8)
                }
            }
            .frame(height: 8)

            Text("\(Int(target.share * 100))%")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 32, alignment: .trailing)
        }
        .frame(height: 20)
    }
}

#Preview {
    ExerciseDetailMuscleTargetsView(targets: [
        ExerciseProfileTarget(id: "quads", label: "Quads", share: 0.394, role: "primary", relativeRankScore10: 10),
        ExerciseProfileTarget(id: "glutes", label: "Glutes", share: 0.205, role: "primary", relativeRankScore10: 5),
        ExerciseProfileTarget(id: "calves", label: "Calves", share: 0.152, role: "secondary", relativeRankScore10: 4),
        ExerciseProfileTarget(
            id: "adductors",
            label: "Adductors",
            share: 0.151,
            role: "secondary",
            relativeRankScore10: 4
        ),
        ExerciseProfileTarget(
            id: "hamstrings",
            label: "Hamstrings",
            share: 0.097,
            role: "secondary",
            relativeRankScore10: 2
        )
    ])
    .background(Color.vivoBackground)
}
