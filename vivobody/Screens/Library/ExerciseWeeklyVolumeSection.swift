//
//  ExerciseWeeklyVolumeSection.swift
//  vivobody
//
//  "This week" section for ExerciseDetailScreen: the hard sets this
//  exercise delivered to each involved muscle over the trailing 7 days,
//  joined against the cached weekly muscle totals so every row shows
//  both the contribution and where the muscle's full week sits against
//  its productive band. Pro-gated with the shared LockedProCover frozen
//  treatment — the landmark model is the Insights tab's value layer.
//  Self-gates to nothing when the window holds no volume-bearing work
//  (idle week, non-volume modality, anatomy-less custom exercise).
//

import SwiftUI
import VivoKit

extension ExerciseDetailScreen {
    /// This exercise's windowed hard-set contribution. Nil hides the
    /// section entirely.
    var volumeContribution: ExerciseVolumeContribution? {
        ExerciseVolumeContribution.compute(sessions: completedSessions, item: item)
    }

    @ViewBuilder
    var weeklyVolumeSection: some View {
        if let contribution = volumeContribution {
            if pro?.isUnlocked == true {
                weeklyVolumeContent(contribution)
            } else {
                LockedProCover(title: "This week") {
                    Haptics.soft()
                    isPaywallPresented = true
                } content: {
                    weeklyVolumeContent(contribution)
                }
            }
        }
    }

    func weeklyVolumeContent(_ contribution: ExerciseVolumeContribution) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("This week")
                .sectionLabelStyle(Opacity.medium)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(
                    Array(contribution.shares.prefix(WeeklyVolumeRow.maxRows).enumerated()),
                    id: \.element.id
                ) { index, share in
                    if index > 0 { weeklyVolumeDivider }
                    WeeklyVolumeRow(
                        share: share,
                        stat: volumeStat(for: share.muscle)
                    )
                }

                Text(
                    "Hard sets from this exercise in the last 7 days. Bars show each muscle's full week against its \(bandLabel) productive band."
                )
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

    /// The muscle's cached weekly volume stat (totals, zone, landmark).
    /// Nil while the analytics feed has not published yet; the row then
    /// shows the contribution on its own.
    func volumeStat(for muscle: Muscle) -> MuscleVolumeStat? {
        sessionAnalytics?.volume.first { $0.muscle == muscle }
    }

    /// The shared band edges for the caption, from the first available
    /// stat (all muscles share the default landmark).
    private var bandLabel: String {
        let landmark = volumeContribution?.shares
            .compactMap { volumeStat(for: $0.muscle) }
            .first?.landmark ?? .default
        return "\(Int(landmark.mev))–\(Int(landmark.optimalHigh))"
    }
}

// MARK: - Row

/// One muscle's row: name + role, the exercise's orange contribution
/// numeral, and a slim bar of the muscle's full weekly effective sets
/// against its landmark band with this exercise's share as the
/// trailing accent segment.
private struct WeeklyVolumeRow: View {
    let share: ExerciseVolumeContribution.MuscleShare
    let stat: MuscleVolumeStat?

    /// Rows are capped so a many-muscle compound cannot push the rest
    /// of the screen below the fold.
    static let maxRows = 4

    private var landmark: VolumeLandmark {
        stat?.landmark ?? .default
    }

    /// The muscle's full weekly total. Without a published stat the
    /// contribution itself is the honest lower bound.
    private var total: Double {
        max(stat?.effectiveSets ?? share.sets, share.sets)
    }

    /// Bar scale: the band top with headroom, extended when a muscle
    /// over-trains past it so the fill never pins at 100%.
    private var scale: Double {
        max(landmark.optimalHigh + 2, total)
    }

    /// The base fill dims while a muscle sits under its minimum
    /// effective volume; inside or above the band it reads full.
    private var fillTint: Color {
        switch stat?.zone {
        case .under, .untrained: Ink.primary.opacity(0.42)
        case .optimal, .high, nil: Ink.primary.opacity(Opacity.strong)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(share.muscle.displayName)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.secondary)
                if let role = share.role {
                    Text("· \(role.displayName.lowercased())")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }
                Spacer(minLength: Space.sm)
                Text("+\(InsightsFormat.setsLabel(share.sets))")
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
                            .frame(width: width * min(share.sets / scale, 1))
                            .offset(x: width * max(min((total - share.sets) / scale, 1), 0))
                            .shadow(color: Tint.primary.opacity(0.35), radius: 3)
                        bandTick(at: landmark.mev, width: width)
                        bandTick(at: landmark.optimalHigh, width: width)
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)

                Text(InsightsFormat.setsLabel(total))
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func bandTick(at value: Double, width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.25))
            .frame(width: 1, height: 10)
            .offset(x: width * min(value / scale, 1))
    }

    private var accessibilitySummary: String {
        let role = share.role.map { ", \($0.displayName.lowercased())" } ?? ""
        let contribution =
            "\(InsightsFormat.setsLabel(share.sets)) hard sets from this exercise this week"
        guard let stat else {
            return "\(share.muscle.displayName)\(role). \(contribution)."
        }
        let band = "\(Int(landmark.mev)) to \(Int(landmark.optimalHigh))"
        let zonePhrase = switch stat.zone {
        case .untrained: "with no other work this week"
        case .under: "below the \(band) productive band"
        case .optimal: "inside the \(band) productive band"
        case .high: "above the \(band) productive band"
        }
        return "\(share.muscle.displayName)\(role). \(contribution). "
            + "\(InsightsFormat.setsLabel(stat.effectiveSets)) total this week, \(zonePhrase)."
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
        func stat(_ sets: Double) -> MuscleVolumeStat {
            MuscleVolumeStat(
                muscle: .pectoralisMajorSternocostal,
                effectiveSets: sets,
                allTimeEffectiveSets: sets * 10,
                daysSinceLastTrained: 1,
                landmark: .default
            )
        }
        return ScrollView {
            VStack(spacing: Space.xxl) {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("This week")
                        .sectionLabelStyle(Opacity.medium)
                    VStack(alignment: .leading, spacing: 0) {
                        WeeklyVolumeRow(share: contribution.shares[0], stat: stat(12.5))
                        WeeklyVolumeRow(share: contribution.shares[1], stat: stat(9.5))
                        WeeklyVolumeRow(share: contribution.shares[2], stat: stat(6.5))
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.xs)
                    .contentCard()
                }
                LockedProCover(title: "This week", action: {}) {
                    VStack(alignment: .leading, spacing: 0) {
                        WeeklyVolumeRow(share: contribution.shares[0], stat: stat(12.5))
                        WeeklyVolumeRow(share: contribution.shares[1], stat: stat(9.5))
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.xs)
                    .contentCard()
                }
            }
            .padding(Space.gutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
#endif
