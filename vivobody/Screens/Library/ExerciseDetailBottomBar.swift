//
//  ExerciseDetailBottomBar.swift
//  vivobody
//
//  Exercise Detail's safe-area actions. The leaf renders immutable
//  entitlement and pick state while the root screen owns presentation,
//  navigation, haptics, and the resulting actions.
//

import SwiftUI
import VivoKit

struct ExerciseDetailBottomBar: View {
    let showsUnlock: Bool
    let price: String?
    let onUnlock: () -> Void
    let onAddToWorkout: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if showsUnlock {
                unlockControl
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.sm)
            }
            if let onAddToWorkout {
                addToWorkoutControl(action: onAddToWorkout)
            }
        }
    }

    private var unlockControl: some View {
        Button(action: onUnlock) {
            HStack(spacing: Space.md) {
                Text("Unlock Vivobody Pro")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let price {
                    Text("· \(price)")
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .font(Typography.headline)
            .foregroundStyle(Tint.onAccent)
            .frame(minHeight: Space.tapMin)
            .padding(.horizontal, Space.xl)
            .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.primary)
            .softElevation(radius: 14, y: 7, opacity: 0.42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlockLabel)
        .accessibilityHint("Opens the Vivobody Pro purchase sheet")
    }

    private var unlockLabel: String {
        price.map { "Unlock Vivobody Pro, \($0)" }
            ?? "Unlock Vivobody Pro"
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
