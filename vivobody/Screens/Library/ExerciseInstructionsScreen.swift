//
//  ExerciseInstructionsScreen.swift
//  vivobody
//
//  Presents an exercise's authored movement steps as a numbered,
//  glanceable sequence reached from the exercise detail screen.
//

import SwiftUI
import VivoKit

struct ExerciseInstructionsScreen: View {
    let exerciseName: String
    let steps: [String]

    init(item: ExerciseCatalogItem) {
        exerciseName = item.name
        steps = item.movementSteps
    }

    init(exerciseName: String, steps: [String]) {
        self.exerciseName = exerciseName
        self.steps = steps
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: Space.section) {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(exerciseName)
                        .font(Typography.display)
                        .foregroundStyle(Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(steps.count) steps")
                        .font(Typography.sectionLabel)
                        .foregroundStyle(Ink.tertiary)
                }

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    instructionCard(number: index + 1, description: step)
                }
            }
            .padding(.top, Space.sm)
            .padding(.bottom, Space.section)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .navigationTitle("How to perform")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func instructionCard(number: Int, description: String) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Step \(number)")
                .font(Typography.title)
                .foregroundStyle(Tint.primary)
                .accessibilityAddTraits(.isHeader)

            Text(description)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
        .accessibilityElement(children: .combine)
    }
}

/// Compact numbered copy used when bundled exercise identity is shown inside
/// the editor rather than on the dedicated instruction screen.
struct ExerciseInstructionSummary: View {
    let steps: [String]

    var body: some View {
        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Step \(index + 1)")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Tint.primary)
                Text(step)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension ExerciseDetailScreen {
    @ViewBuilder
    var instructionsLink: some View {
        let steps = item.movementSteps

        if !steps.isEmpty {
            NavigationLink {
                ExerciseInstructionsScreen(item: item)
            } label: {
                KitRow(
                    title: "How to perform",
                    leading: Image(systemName: "figure.strengthtraining.traditional")
                ) {
                    Image(systemName: "chevron.right")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens step-by-step instructions")
            .accessibilityIdentifier("exercise-how-to-perform")
        }
    }
}

#Preview("Exercise instructions") {
    NavigationStack {
        ExerciseInstructionsScreen(
            exerciseName: "Barbell Row",
            steps: [
                "Stand holding a barbell and establish a strict hip hinge.",
                "Pull the bar toward the lower ribs without changing the torso angle.",
                "Lower the bar under control.",
            ]
        )
    }
}
