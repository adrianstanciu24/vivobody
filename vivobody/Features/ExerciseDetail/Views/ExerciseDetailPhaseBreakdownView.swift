import SwiftUI

struct ExerciseDetailPhaseBreakdownView: View {
    let phases: [ExerciseProfilePhase]
    let phaseWindows: [ExerciseProfilePhaseWindow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                let window = phaseWindows.first { $0.phase == phase.phase }
                PhaseBlock(phase: phase, window: window)
                if index < phases.count - 1 {
                    Spacer().frame(height: VivoSpacing.itemGap)
                }
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        Text("PHASE BREAKDOWN")
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
            .padding(.bottom, VivoSpacing.itemGap)
    }
}

// MARK: - Phase Block

private struct PhaseBlock: View {
    let phase: ExerciseProfilePhase
    let window: ExerciseProfilePhaseWindow?

    private var arrow: String {
        phase.phase == "ascent" ? "\u{25B2}" : "\u{25BC}"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(arrow) \(phase.label.uppercased())")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoPrimary)
                Spacer()
                if let window {
                    Text("INTENSITY: \(String(format: "%.1f", window.intensity))")
                        .font(.vivoMono(VivoFont.monoMicro))
                        .tracking(VivoTracking.tight)
                        .foregroundStyle(Color.vivoSecondary)
                }
            }

            let targets = phase.primaryTargets.map(\.label).joined(separator: " \u{00B7} ")
            HStack(spacing: 4) {
                Text("TARGETS")
                    .font(.vivoMono(VivoFont.monoMicro))
                    .tracking(VivoTracking.medium)
                    .foregroundStyle(Color.vivoSecondary)
                    .frame(width: 56, alignment: .leading)
                Text(targets)
                    .font(.vivoMono(VivoFont.monoXS))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoAccent)
            }

            let actions = phase.mainJointActions.map(\.label).joined(separator: " \u{00B7} ")
            HStack(spacing: 4) {
                Text("ACTIONS")
                    .font(.vivoMono(VivoFont.monoMicro))
                    .tracking(VivoTracking.medium)
                    .foregroundStyle(Color.vivoSecondary)
                    .frame(width: 56, alignment: .leading)
                Text(actions)
                    .font(.vivoMono(VivoFont.monoXS))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoPrimary)
            }
        }
    }
}

#Preview {
    ExerciseDetailPhaseBreakdownView(
        phases: [
            ExerciseProfilePhase(
                phase: "ascent",
                label: "Ascent",
                primaryTargets: [
                    ExerciseProfilePhaseTarget(id: "glutes", label: "Glutes"),
                    ExerciseProfilePhaseTarget(id: "quads", label: "Quads"),
                    ExerciseProfilePhaseTarget(id: "calves", label: "Calves")
                ],
                mainJointActions: [
                    ExerciseProfilePhaseAction(
                        action: "hip_extension",
                        label: "Hip extension",
                        dominantGroup: ExerciseProfilePhaseTarget(id: "glutes", label: "Glutes")
                    ),
                    ExerciseProfilePhaseAction(
                        action: "knee_extension",
                        label: "Knee extension",
                        dominantGroup: ExerciseProfilePhaseTarget(id: "quads", label: "Quads")
                    )
                ]
            ),
            ExerciseProfilePhase(
                phase: "descent",
                label: "Descent",
                primaryTargets: [
                    ExerciseProfilePhaseTarget(id: "glutes", label: "Glutes"),
                    ExerciseProfilePhaseTarget(id: "quads", label: "Quads")
                ],
                mainJointActions: [
                    ExerciseProfilePhaseAction(
                        action: "hip_extension",
                        label: "Hip extension",
                        dominantGroup: ExerciseProfilePhaseTarget(id: "glutes", label: "Glutes")
                    )
                ]
            )
        ],
        phaseWindows: [
            ExerciseProfilePhaseWindow(phase: "ascent", start: 0.5, end: 1.0, intensity: 1.0),
            ExerciseProfilePhaseWindow(phase: "descent", start: 0.0, end: 0.5, intensity: 0.7)
        ]
    )
    .background(Color.vivoBackground)
}
