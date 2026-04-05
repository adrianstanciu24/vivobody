import SwiftUI

struct ExerciseDetailMovementProfileView: View {
    let stability: ExerciseProfileStability
    let tempoSensitivity: ExerciseProfileTempoSensitivity
    let repDurationSec: Double
    let movementTags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: VivoSpacing.itemGap) {
            sectionHeader
            statsRow
            tagFlow
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        Text("MOVEMENT PROFILE")
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            VivoStatColumn(
                value: "\(stability.absoluteLevelScore10)/10",
                label: "STABILITY",
                valueFont: VivoFont.headlineSM
            )
            verticalDivider
            VivoStatColumn(
                value: "\(tempoSensitivity.absoluteLevelScore10)/10",
                label: "TEMPO SENS",
                valueFont: VivoFont.headlineSM
            )
            verticalDivider
            VivoStatColumn(
                value: String(format: "%.1fs", repDurationSec),
                label: "REP DUR",
                valueFont: VivoFont.headlineSM
            )
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(width: 1, height: 28)
    }

    private var tagFlow: some View {
        VivoFlowLayout(spacing: 6) {
            ForEach(Array(movementTags.enumerated()), id: \.offset) { _, tag in
                tagPill(tag)
            }
        }
    }

    private func tagPill(_ tag: String) -> some View {
        Text(tag.replacingOccurrences(of: "_", with: " ").uppercased())
            .font(.vivoMono(VivoFont.monoMicro))
            .tracking(VivoTracking.tight)
            .foregroundStyle(Color.vivoPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: VivoRadius.badge)
                    .stroke(Color.vivoSurface, lineWidth: 1)
            )
    }
}

#Preview {
    ExerciseDetailMovementProfileView(
        stability: ExerciseProfileStability(level: "medium", score: 0.55, absoluteLevelScore10: 7, summary: ""),
        tempoSensitivity: ExerciseProfileTempoSensitivity(
            level: "medium",
            score: 0.55,
            absoluteLevelScore10: 7,
            summary: "",
            slowerTempoBias: ["Quads", "Glutes"],
            fasterTempoBias: ["power_output"]
        ),
        repDurationSec: 2.0,
        movementTags: ["bilateral", "bilateral_squat", "quads_dominant", "deep_hip_flexion", "forward_torso_lean"]
    )
    .background(Color.vivoBackground)
}
