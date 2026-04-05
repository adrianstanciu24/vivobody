import SwiftUI

struct ExerciseDetailJointDemandView: View {
    let jointStress: [ExerciseProfileJointStress]
    let kneeVsHip: ExerciseProfileKneeVsHip

    var body: some View {
        VStack(alignment: .leading, spacing: VivoSpacing.itemGap) {
            sectionHeader
            ForEach(Array(jointStress.enumerated()), id: \.offset) { _, stress in
                JointStressBar(stress: stress)
            }
            biasSummary
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        Text("JOINT STRESS")
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
    }

    private var biasSummary: some View {
        let kneePercent = Int(kneeVsHip.kneeShare * 100)
        let hipPercent = Int(kneeVsHip.hipShare * 100)
        return Text("KNEE/HIP BIAS: \(kneeVsHip.bias.uppercased()) (\(kneePercent)% / \(hipPercent)%)")
            .font(.vivoMono(VivoFont.monoMicro))
            .tracking(VivoTracking.tight)
            .foregroundStyle(Color.vivoSecondary)
    }
}

// MARK: - Bar Row

private struct JointStressBar: View {
    let stress: ExerciseProfileJointStress

    private var levelColor: Color {
        switch stress.level {
        case "high": .vivoAccent
        case "medium": .vivoYellow
        default: .vivoSecondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(stress.label.uppercased())
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoPrimary)
                .frame(width: 52, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: VivoRadius.bar)
                        .fill(Color.vivoSurface)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: VivoRadius.bar)
                        .fill(levelColor)
                        .frame(width: geo.size.width * stress.share, height: 8)
                }
            }
            .frame(height: 8)

            Text(stress.level.uppercased())
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.tight)
                .foregroundStyle(levelColor)
                .frame(width: 36, alignment: .trailing)

            Text("\(Int(stress.share * 100))%")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 28, alignment: .trailing)
        }
        .frame(height: 20)
    }
}

#Preview {
    ExerciseDetailJointDemandView(
        jointStress: [
            ExerciseProfileJointStress(
                joint: "hip",
                label: "Hip",
                share: 0.453,
                level: "high",
                absoluteLevelScore10: 9,
                summary: ""
            ),
            ExerciseProfileJointStress(
                joint: "knee",
                label: "Knee",
                share: 0.394,
                level: "high",
                absoluteLevelScore10: 8,
                summary: ""
            ),
            ExerciseProfileJointStress(
                joint: "ankle",
                label: "Ankle",
                share: 0.152,
                level: "low",
                absoluteLevelScore10: 4,
                summary: ""
            )
        ],
        kneeVsHip: ExerciseProfileKneeVsHip(
            bias: "balanced",
            kneeShare: 0.465,
            hipShare: 0.535,
            absoluteLevelScore10: 3,
            summary: ""
        )
    )
    .background(Color.vivoBackground)
}
