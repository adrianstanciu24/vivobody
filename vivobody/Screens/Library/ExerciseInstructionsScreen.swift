//
//  ExerciseInstructionsScreen.swift
//  vivobody
//
//  Presents an exercise's authored execution instructions as labeled,
//  glanceable sections reached from the exercise detail screen.
//

import SwiftUI
import VivoKit

struct ExerciseInstructionsScreen: View {
    let exerciseName: String
    let execution: ExecutionInstructions?

    init(item: ExerciseCatalogItem) {
        exerciseName = item.name
        execution = item.execution
    }

    init(exerciseName: String, execution: ExecutionInstructions) {
        self.exerciseName = exerciseName
        self.execution = execution
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: Space.section) {
                Text(exerciseName)
                    .font(Typography.display)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let execution {
                    instructionSection(
                        title: "Starting position",
                        body: execution.startingPosition,
                        identifier: "exercise-execution-starting-position"
                    )
                    instructionSection(
                        title: "Movement",
                        body: execution.movement,
                        identifier: "exercise-execution-movement"
                    )
                    instructionSection(
                        title: "Endpoint",
                        body: execution.endpoint,
                        identifier: "exercise-execution-endpoint"
                    )
                    if let returnPhase = execution.returnPhase {
                        instructionSection(
                            title: "Return",
                            body: returnPhase,
                            identifier: "exercise-execution-return"
                        )
                    }
                    instructionSection(
                        title: "Keep controlled",
                        body: execution.controlledJoints,
                        identifier: "exercise-execution-controlled-joints"
                    )
                    instructionSection(
                        title: "Support and posture",
                        body: execution.supportAndPosture,
                        identifier: "exercise-execution-support-posture"
                    )
                    compensationsSection(execution.disqualifyingCompensations)
                    if let sideOrDirection = execution.sideOrDirection {
                        instructionSection(
                            title: "Sides and direction",
                            body: sideOrDirection,
                            identifier: "exercise-execution-side-direction"
                        )
                    }
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

    private func instructionSection(
        title: String,
        body: String,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title)
                .font(Typography.title)
                .foregroundStyle(Tint.primary)
                .accessibilityAddTraits(.isHeader)

            Text(body)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func compensationsSection(_ compensations: [String]) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                PulsingWarningIcon()

                Text("Compensations")
            }
            .font(Typography.title)
            .foregroundStyle(Tint.primary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Warning: Compensations")
            .accessibilityAddTraits(.isHeader)

            ForEach(compensations, id: \.self) { compensation in
                Text(compensation)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exercise-execution-compensations")
    }
}

private struct PulsingWarningIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .scaleEffect(reduceMotion ? 1 : (isExpanded ? 1.12 : 0.78))
            .accessibilityHidden(true)
            .onAppear(perform: startPulsing)
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
                isExpanded = false
            }
            .onChange(of: reduceMotion) { _, _ in startPulsing() }
    }

    private func startPulsing() {
        animationTask?.cancel()
        isExpanded = false
        guard !reduceMotion else { return }

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                isExpanded = true
            }
        }
    }
}

/// Compact labeled copy used when bundled exercise identity is shown inside
/// the editor rather than on the dedicated instruction screen.
struct ExerciseInstructionSummary: View {
    let execution: ExecutionInstructions

    var body: some View {
        summaryEntry(title: "Starting position", text: execution.startingPosition)
        summaryEntry(title: "Movement", text: execution.movement)
        summaryEntry(title: "Endpoint", text: execution.endpoint)
        if let returnPhase = execution.returnPhase {
            summaryEntry(title: "Return", text: returnPhase)
        }
        summaryEntry(title: "Keep controlled", text: execution.controlledJoints)
        summaryEntry(title: "Support and posture", text: execution.supportAndPosture)
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Compensations")
                .font(Typography.sectionHeading)
                .foregroundStyle(Tint.primary)
            ForEach(execution.disqualifyingCompensations, id: \.self) { compensation in
                Text(compensation)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if let sideOrDirection = execution.sideOrDirection {
            summaryEntry(title: "Sides and direction", text: sideOrDirection)
        }
    }

    private func summaryEntry(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(Typography.sectionHeading)
                .foregroundStyle(Tint.primary)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension ExerciseDetailScreen {
    @ViewBuilder
    var instructionsLink: some View {
        if item.execution != nil {
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
            .accessibilityHint("Opens how-to-perform instructions")
            .accessibilityIdentifier("exercise-how-to-perform")
        }
    }
}

#Preview("Exercise instructions") {
    NavigationStack {
        ExerciseInstructionsScreen(
            exerciseName: "One-Arm Dumbbell Row",
            execution: ExecutionInstructions(
                startingPosition: "Place one hand and the same-side knee on a bench with the dumbbell hanging straight down.",
                movement: "Pull the dumbbell toward the lower ribs without rotating the torso.",
                endpoint: "Finish the pull with the dumbbell beside the ribs.",
                returnPhase: "Lower the dumbbell under control until the arm is straight.",
                controlledJoints: "Keep the torso still and the supporting arm locked throughout.",
                supportAndPosture: "Keep the back flat and the head aligned with the spine.",
                disqualifyingCompensations: [
                    "Twisting the torso turns the row into a rotational pull.",
                    "Jerking the dumbbell with the hips turns the row into a cheat pull.",
                ],
                sideOrDirection: "Repeat on the other side."
            )
        )
    }
}
