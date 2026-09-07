//
//  ExerciseDetailBottomBar.swift
//  vivobody
//
//  Exercise Detail's safe-area actions. The leaf renders immutable
//  pick state while the root screen owns presentation,
//  navigation, haptics, and the resulting actions.
//

import SwiftUI
import VivoKit

struct ExerciseDetailBottomBar: View {
    let onAddToWorkout: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if let onAddToWorkout {
                addToWorkoutControl(action: onAddToWorkout)
            }
        }
    }

    private func addToWorkoutControl(
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text("Add to Workout")
                    .font(Typography.title)
                    .tracking(0.4)
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
                    .font(Typography.sectionHeading)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Tint.onAccent)
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.xl)
            .frame(maxWidth: .infinity)
            .coloredGlassControl(
                cornerRadius: Radius.card,
                fill: Tint.inProgress,
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, 8)
        .padding(.top, 12)
    }
}
