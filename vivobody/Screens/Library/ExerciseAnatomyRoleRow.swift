//
//  ExerciseAnatomyRoleRow.swift
//  vivobody
//
//  Adaptive muscle-role rows for the exercise-detail anatomy card.
//  Standard text sizes retain the compact keyed legend; accessibility
//  sizes stack each key above its muscles so labels stay intact.
//

import SwiftUI
import VivoKit

extension ExerciseDetailScreen {
    /// One keyed legend row: the role's color dot (same ramp the model
    /// renders) + role label + the muscle names that carry it. Rows
    /// for roles with no muscles hide themselves. Replaces both the
    /// old dots-only legend and the separate mid-screen Muscles list.
    @ViewBuilder
    func anatomyRoleRow(role: MuscleRole, muscles: [Muscle]) -> some View {
        if !muscles.isEmpty {
            ExerciseAnatomyRoleRow(role: role, muscles: muscles)
        }
    }
}

private struct ExerciseAnatomyRoleRow: View {
    let role: MuscleRole
    let muscles: [Muscle]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let rgb = MuscleColor.rgb(
            for: role.anatomyMapChannels,
            theme: colorScheme == .dark ? .dark : .light
        )
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.xs) {
                    roleLabel(rgb: rgb)
                    muscleNames
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                    roleLabel(rgb: rgb)
                        .frame(width: 100, alignment: .leading)
                    muscleNames
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func roleLabel(rgb: MuscleColor.RGB) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
                .frame(width: 9, height: 9)
            Text(role.displayName)
                .sectionLabelStyle(Opacity.soft)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var muscleNames: some View {
        Text(muscles.map(\.displayName).joined(separator: " · "))
            .font(Typography.sectionHeading)
            .foregroundStyle(role == .primary ? Ink.secondary : Ink.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
