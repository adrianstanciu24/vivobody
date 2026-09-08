//
//  ExerciseDetailAnatomySection.swift
//  vivobody
//
//  Stateless anatomy figure and authored muscle-role legend for Exercise
//  Detail. Catalog muscle involvement is supplied as an immutable value;
//  the section never queries or mutates the exercise model.
//

import SwiftUI
import VivoKit

struct ExerciseDetailAnatomySection: View {
    let exerciseName: String
    let involvement: Muscle.Involvement

    var body: some View {
        if !involvement.isEmpty {
            let hasVisualizedMuscle = involvement.contributions.contains {
                $0.muscle.isVisualized
            }
            let unvisualizedMuscles = involvement.contributions
                .map(\.muscle)
                .filter { !$0.isVisualized }

            VStack(spacing: Space.lg) {
                if hasVisualizedMuscle {
                    StagedBodyModel(
                        renderHeight: 240,
                        channels: involvement.anatomyNodeChannels,
                        warmth: 0.55
                    )
                    .frame(height: 240)
                    .accessibilityElement()
                    .accessibilityLabel("Muscles used by \(exerciseName). Primary muscles are most vivid, secondary muscles are medium, and stabilizers are faint. Anatomy colors show roles; training credit uses separate role and effort weights.")
                }

                VStack(alignment: .leading, spacing: Space.sm) {
                    anatomyRoleRow(role: .primary, muscles: involvement.primary)
                    anatomyRoleRow(role: .secondary, muscles: involvement.secondary)
                    anatomyRoleRow(role: .stabilizer, muscles: involvement.stabilizers)

                    if involvement.secondary.contains(.adductorMagnus) {
                        DisclosureGroup {
                            Text("Highlighting shows participation, not equal loading throughout adductor magnus. For example, its back portion contributes during hip extension.")
                                .font(Typography.caption)
                                .foregroundStyle(Ink.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } label: {
                            Text("About adductor magnus")
                                .foregroundStyle(Ink.primary)
                                .frame(minHeight: 44)
                        }
                        .font(Typography.caption)
                    }

                    if !unvisualizedMuscles.isEmpty {
                        Text(
                            "3D view unavailable for "
                                + unvisualizedMuscles.map(\.displayName).joined(separator: " · ")
                                + ". Authored roles and eligible training credit remain included."
                        )
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Space.md)
            .contentCard()
        }
    }

    @ViewBuilder
    private func anatomyRoleRow(
        role: MuscleRole,
        muscles: [Muscle]
    ) -> some View {
        if !muscles.isEmpty {
            ExerciseAnatomyRoleRow(role: role, muscles: muscles)
        }
    }
}

#if DEBUG
    #Preview("Exercise anatomy") {
        ExerciseDetailAnatomySection(
            exerciseName: "Barbell Bench Press",
            involvement: Muscle.Involvement(contributions: [
                .init(muscle: .pectoralisMajorSternocostal, role: .primary),
                .init(muscle: .deltoidAnterior, role: .secondary),
                .init(muscle: .triceps, role: .stabilizer),
            ])
        )
        .padding(Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
#endif
