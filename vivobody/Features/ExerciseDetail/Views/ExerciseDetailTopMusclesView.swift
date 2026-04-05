import SwiftUI

struct ExerciseDetailTopMusclesView: View {
    let muscles: [ExerciseProfileTopMuscle]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            ForEach(Array(muscles.enumerated()), id: \.offset) { index, muscle in
                TopMuscleRow(rank: index + 1, muscle: muscle)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        HStack {
            Text("TOP MUSCLES")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Text("RELATIVE LOAD")
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoSecondary)
        }
        .padding(.bottom, VivoSpacing.itemGap)
    }
}

// MARK: - Row

private struct TopMuscleRow: View {
    let rank: Int
    let muscle: ExerciseProfileTopMuscle

    private var bucketColor: Color {
        switch muscle.loadBucket {
        case "high": .vivoAccent
        case "medium": .vivoYellow
        default: .vivoSecondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(String(format: "%02d", rank))
                .font(.vivoMono(VivoFont.monoXS))
                .foregroundStyle(Color.vivoAccent)
                .frame(width: 24, alignment: .leading)

            Text(muscle.muscle.uppercased())
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoPrimary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            Text(muscle.groupLabel.uppercased())
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)
                .frame(width: 72, alignment: .leading)
                .lineLimit(1)

            Spacer()

            loadBar
                .frame(width: 60, height: 6)

            Text(muscle.loadBucket.uppercased())
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.tight)
                .foregroundStyle(bucketColor)
                .frame(width: 36, alignment: .trailing)
        }
        .frame(height: 28)
    }

    private var loadBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: VivoRadius.dot)
                    .fill(Color.vivoSurface)
                RoundedRectangle(cornerRadius: VivoRadius.dot)
                    .fill(bucketColor)
                    .frame(width: geo.size.width * muscle.estimatedRelativeLoad)
            }
        }
    }
}

#Preview {
    ExerciseDetailTopMusclesView(muscles: [
        ExerciseProfileTopMuscle(
            muscle: "glmax3",
            group: "glutes",
            groupLabel: "Glutes",
            estimatedRelativeLoad: 1.0,
            loadBucket: "high",
            phaseBias: "ascent",
            displayScore10: 10,
            relativeRankScore10: 10
        ),
        ExerciseProfileTopMuscle(
            muscle: "glmax2",
            group: "glutes",
            groupLabel: "Glutes",
            estimatedRelativeLoad: 0.874,
            loadBucket: "high",
            phaseBias: "ascent",
            displayScore10: 9,
            relativeRankScore10: 9
        ),
        ExerciseProfileTopMuscle(
            muscle: "vaslat",
            group: "quads",
            groupLabel: "Quads",
            estimatedRelativeLoad: 0.681,
            loadBucket: "medium",
            phaseBias: "ascent",
            displayScore10: 7,
            relativeRankScore10: 7
        ),
        ExerciseProfileTopMuscle(
            muscle: "glmax1",
            group: "glutes",
            groupLabel: "Glutes",
            estimatedRelativeLoad: 0.675,
            loadBucket: "medium",
            phaseBias: "ascent",
            displayScore10: 7,
            relativeRankScore10: 7
        ),
        ExerciseProfileTopMuscle(
            muscle: "addmagDist",
            group: "adductors",
            groupLabel: "Adductors",
            estimatedRelativeLoad: 0.592,
            loadBucket: "medium",
            phaseBias: "ascent",
            displayScore10: 6,
            relativeRankScore10: 6
        ),
        ExerciseProfileTopMuscle(
            muscle: "semiten",
            group: "hamstrings",
            groupLabel: "Hamstrings",
            estimatedRelativeLoad: 0.575,
            loadBucket: "medium",
            phaseBias: "ascent",
            displayScore10: 6,
            relativeRankScore10: 6
        )
    ])
    .background(Color.vivoBackground)
}
