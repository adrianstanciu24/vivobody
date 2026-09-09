//
//  ExerciseWeeklyVolumeSection.swift
//  vivobody
//
//  Focused Exercise Detail "Last 7 days" presentation. Immutable read-model
//  rows carry the exercise contribution, weekly total, and spoken
//  meaning; this leaf owns only the visual instrument.
//

import SwiftUI
import VivoKit

struct ExerciseDetailWeeklyVolumeSection: View {
    let volume: ExerciseDetailReadModel.WeeklyVolume?

    var body: some View {
        if let volume {
            content(volume)
        }
    }

    private func content(
        _ volume: ExerciseDetailReadModel.WeeklyVolume
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Last 7 days")
                .sectionLabelStyle(Opacity.medium)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(volume.rows.enumerated()), id: \.element.muscle) { index, row in
                    if index > 0 { weeklyVolumeDivider }
                    WeeklyVolumeRow(row: row)
                }

                Text(volume.caption)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.md)
                    .padding(.bottom, Space.xs)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.xs)
            .contentCard()
        }
    }

    /// In-card hairline between rows — the same plain, edge-inset line
    /// the recent-sessions ledger uses.
    private var weeklyVolumeDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}

// MARK: - Row

/// Each bar shows this exercise's share of the muscle's last seven days.
private struct WeeklyVolumeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let row: ExerciseDetailReadModel.WeeklyVolumeRow

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(row.muscle.displayName)
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.secondary)
            if let role = row.role {
                Text(role.displayName)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.md))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Space.md))
            layout {
                metric(row.contributionText, label: "From this exercise", tint: Tint.primary)
                metric(row.totalText, label: "All exercises", tint: Ink.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Ink.primary.opacity(0.22))
                    Capsule()
                        .fill(Tint.primary)
                        .frame(width: geo.size.width * (row.totalSets > 0
                                ? min(max(row.contributionSets / row.totalSets, 0), 1) : 0))
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private func metric(_ value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(value)
                .font(Typography.metricInline)
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Last 7 days") {
        let contribution = ExerciseVolumeContribution(
            shares: [
                .init(muscle: .pectoralisMajorSternocostal, role: .primary, sets: 6),
                .init(muscle: .triceps, role: .secondary, sets: 3),
                .init(muscle: .deltoidAnterior, role: .secondary, sets: 3),
            ],
            totalSets: 12
        )
        let stat: (Muscle, Double) -> MuscleVolumeStat = { muscle, sets in
            MuscleVolumeStat(
                muscle: muscle,
                effectiveSets: sets,
                allTimeEffectiveSets: sets * 10,
                daysSinceLastTrained: 1,
                landmark: .default
            )
        }
        let volume = ExerciseDetailReadModel.weeklyVolume(
            contribution: contribution,
            stats: [
                stat(.pectoralisMajorSternocostal, 12.5),
                stat(.triceps, 9.5),
                stat(.deltoidAnterior, 6.5),
            ]
        )
        ScrollView {
            VStack(spacing: Space.xxl) {
                ExerciseDetailWeeklyVolumeSection(
                    volume: volume
                )
            }
            .padding(Space.gutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
#endif
