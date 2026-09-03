//
//  ExerciseWeeklyVolumeSection.swift
//  vivobody
//
//  Focused Exercise Detail "This week" presentation. Immutable read-model
//  rows carry the exercise contribution, weekly total, landmark, and spoken
//  meaning; this leaf owns only the visual instrument and Pro cover.
//

import SwiftUI
import VivoKit

struct ExerciseDetailWeeklyVolumeSection: View {
    let volume: ExerciseDetailReadModel.WeeklyVolume?
    let isUnlocked: Bool
    let onUnlock: () -> Void

    var body: some View {
        if let volume {
            if isUnlocked {
                content(volume)
            } else {
                LockedProCover(title: "This week", action: onUnlock) {
                    content(volume)
                }
            }
        }
    }

    private func content(
        _ volume: ExerciseDetailReadModel.WeeklyVolume
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("This week")
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

/// One muscle's row: name + role, the exercise's orange contribution
/// numeral, and a slim bar of the muscle's full weekly effective sets
/// against its landmark band with this exercise's share as the
/// trailing accent segment.
private struct WeeklyVolumeRow: View {
    let row: ExerciseDetailReadModel.WeeklyVolumeRow

    private var landmark: VolumeLandmark {
        row.landmark
    }

    /// The muscle's full weekly total. Without a published stat the
    /// contribution itself is the honest lower bound.
    private var total: Double {
        row.totalSets
    }

    /// Bar scale: the band top with headroom, extended when a muscle
    /// over-trains past it so the fill never pins at 100%.
    private var scale: Double {
        max(landmark.optimalHigh + 2, total)
    }

    /// The base fill dims while a muscle sits under its minimum
    /// effective volume; inside or above the band it reads full.
    private var fillTint: Color {
        switch row.zone {
        case .under, .untrained: Ink.primary.opacity(0.42)
        case .optimal, .high, nil: Ink.primary.opacity(Opacity.strong)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(row.muscle.displayName)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.secondary)
                if let role = row.role {
                    Text("· \(role.displayName.lowercased())")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }
                Spacer(minLength: Space.sm)
                Text(row.contributionText)
                    .font(Typography.metricInline)
                    .foregroundStyle(Tint.primary)
                    .monospacedDigit()
            }

            HStack(alignment: .center, spacing: Space.md) {
                GeometryReader { geo in
                    let width = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(fillTint)
                            .frame(width: width * min(total / scale, 1))
                        Capsule()
                            .fill(Tint.primary)
                            .frame(width: width * min(row.contributionSets / scale, 1))
                            .offset(
                                x: width * max(
                                    min((total - row.contributionSets) / scale, 1),
                                    0
                                )
                            )
                            .shadow(color: Tint.primary.opacity(0.35), radius: 3)
                        bandTick(at: landmark.mev, width: width)
                        bandTick(at: landmark.optimalHigh, width: width)
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)

                Text(row.totalText)
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private func bandTick(at value: Double, width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.25))
            .frame(width: 1, height: 10)
            .offset(x: width * min(value / scale, 1))
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("This week") {
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
                    volume: volume,
                    isUnlocked: true,
                    onUnlock: {}
                )
                ExerciseDetailWeeklyVolumeSection(
                    volume: volume,
                    isUnlocked: false,
                    onUnlock: {}
                )
            }
            .padding(Space.gutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
#endif
