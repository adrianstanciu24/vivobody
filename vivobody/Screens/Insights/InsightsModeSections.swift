//
//  InsightsModeSections.swift
//  vivobody
//
//  Focused mode compositions for the Insights screen. Shape keeps the
//  lifetime bloom dominant and previews recent exercise/rep distributions as
//  compact visual drill-outs; Balance keeps only the priority tug-of-war
//  beams in the main panel and moves the qualified roster one level deeper.
//

import SwiftUI
import VivoKit

struct ShapeInsightsMode: View {
    let signature: TrainingSignature
    let dominance: ExerciseDominanceBoard
    let composition: CompositionSplit
    let intensity: IntensityMix
    let intensityWeeks: [IntensityWeek]
    let migration: RepRangeMigrationReport

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SignatureSection(signature: signature)

            GroupSeparator(verticalPadding: Space.section)

            VStack(spacing: Space.lg) {
                ExerciseMixLink(board: dominance, split: composition)
                RepMixLink(
                    mix: intensity,
                    weeks: intensityWeeks,
                    migration: migration
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BalanceInsightsMode: View {
    let board: AntagonistBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SymmetrySection(board: board, presentation: .focus)

            if qualifiedCount > SymmetryPresentation.focusLimit {
                NavigationLink {
                    InsightsDrilloutScreen(title: "All comparisons") {
                        SymmetrySection(board: board, presentation: .full)
                    }
                } label: {
                    InsightsDrilloutRow(
                        title: "All comparisons",
                        value: "\(qualifiedCount)",
                        accessibilityIdentifier: "insightsBalanceAllLink"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var qualifiedCount: Int {
        board.pairs.count(where: \.hasMeaningfulWork)
    }
}

// MARK: - Shape drill-outs

private struct ExerciseMixLink: View {
    let board: ExerciseDominanceBoard
    let split: CompositionSplit

    var body: some View {
        NavigationLink {
            InsightsDrilloutScreen(title: "Exercise mix") {
                ExerciseDominanceSection(board: board, split: split)
            }
        } label: {
            VStack(alignment: .leading, spacing: Space.lg) {
                drilloutHeader(title: "Exercise mix", scope: "last 4 weeks")

                if let top = board.top {
                    HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                        Text(top.name)
                            .font(Typography.title)
                            .foregroundStyle(Ink.primary)
                            .lineLimit(2)
                        Spacer(minLength: Space.sm)
                        Text(percent(top.share))
                            .font(Typography.statValue)
                            .foregroundStyle(Tint.primaryText)
                            .monospacedDigit()
                    }

                    mixShareBar(
                        leadingShare: top.share,
                        leadingLabel: "Top exercise",
                        remainderLabel: "Other exercises"
                    )
                } else {
                    dormantRail(label: "No recent strength sets")
                }
            }
            .padding(Space.xl)
            .contentCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("insightsExerciseMixLink")
        .accessibilityLabel(exerciseAccessibilityLabel)
        .accessibilityHint("Opens the full recent exercise and exercise-type mix")
    }

    private var exerciseAccessibilityLabel: String {
        guard let top = board.top else {
            return "Exercise mix, no strength sets in the last four weeks"
        }
        return "Exercise mix, last four weeks. Top exercise, \(top.name), \(percent(top.share)). Other exercises, \(percent(1 - top.share)). \(board.totalSets) working sets total."
    }
}

private struct RepMixLink: View {
    let mix: IntensityMix
    let weeks: [IntensityWeek]
    let migration: RepRangeMigrationReport

    var body: some View {
        NavigationLink {
            InsightsDrilloutScreen(title: "Rep mix") {
                IntensityMixSection(mix: mix, weeks: weeks, migration: migration)
            }
        } label: {
            VStack(alignment: .leading, spacing: Space.lg) {
                drilloutHeader(title: "Rep mix", scope: "last 4 weeks")

                if let dominant = mix.dominant {
                    HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                        Text(dominant.label)
                            .font(Typography.title)
                            .foregroundStyle(Ink.primary)
                        Spacer(minLength: Space.sm)
                        Text(percent(mix.share(dominant)))
                            .font(Typography.statValue)
                            .foregroundStyle(Tint.primaryText)
                            .monospacedDigit()
                    }

                    mixShareBar(
                        leadingShare: mix.share(dominant),
                        leadingLabel: "Top rep range",
                        remainderLabel: "Other rep ranges"
                    )
                } else {
                    dormantRail(label: "No recent rep-tracked sets")
                }
            }
            .padding(Space.xl)
            .contentCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("insightsRepMixLink")
        .accessibilityLabel(repAccessibilityLabel)
        .accessibilityHint("Opens the twelve-week rep-range history")
    }

    private var repAccessibilityLabel: String {
        guard let dominant = mix.dominant else {
            return "Rep mix, no rep-tracked sets in the last four weeks"
        }
        let leadingShare = mix.share(dominant)
        return "Rep mix, last four weeks. Top rep range, \(dominant.label), \(percent(leadingShare)). Other rep ranges, \(percent(1 - leadingShare)). Low reps, \(percent(mix.share(.strength))); moderate reps, \(percent(mix.share(.hypertrophy))); high reps, \(percent(mix.share(.endurance)))."
    }
}

private struct InsightsDrilloutRow: View {
    let title: String
    let value: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(spacing: Space.lg) {
            Text(title)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
            Spacer(minLength: Space.sm)
            Text(value)
                .font(Typography.statValueCompact)
                .foregroundStyle(Tint.primaryText)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.tertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: Space.rowMin)
        .padding(.horizontal, Space.xl)
        .contentCard()
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityHint("Opens the full comparison board")
    }
}

private func drilloutHeader(title: String, scope: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Space.md) {
        Text(title)
            .font(Typography.sectionHeading)
            .foregroundStyle(Ink.secondary)
        Spacer(minLength: Space.sm)
        Text(scope)
            .panelLegend()
        Image(systemName: "chevron.right")
            .font(Typography.caption)
            .foregroundStyle(Ink.tertiary)
            .accessibilityHidden(true)
    }
}

private func dormantRail(label: String) -> some View {
    VStack(alignment: .leading, spacing: Space.sm) {
        Capsule()
            .fill(Surface.cardTintBright)
            .frame(height: 28)
        Text(label)
            .font(Typography.caption)
            .foregroundStyle(Ink.secondary)
    }
}

private func mixShareBar(
    leadingShare: Double,
    leadingLabel: String,
    remainderLabel: String
) -> some View {
    let leadingShare = min(1, max(0, leadingShare))
    let hasRemainder = leadingShare < 1
    let gap = hasRemainder ? Space.xs : 0
    var legendItems = [
        InsightChartLegend.Item(
            label: leadingLabel,
            color: Tint.primary,
            swatch: .fill
        ),
    ]
    if hasRemainder {
        legendItems.append(
            InsightChartLegend.Item(
                label: remainderLabel,
                color: Ink.quaternary,
                swatch: .fill
            )
        )
    }

    return VStack(alignment: .leading, spacing: Space.sm) {
        GeometryReader { proxy in
            let availableWidth = max(0, proxy.size.width - gap)
            HStack(spacing: gap) {
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(Tint.primary)
                    .frame(width: availableWidth * leadingShare)

                if hasRemainder {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(Ink.quaternary)
                        .frame(width: availableWidth * (1 - leadingShare))
                }
            }
        }
        .frame(height: 36)

        InsightChartLegend(items: legendItems)
    }
    .accessibilityHidden(true)
}

private func percent(_ share: Double) -> String {
    "\(Int((share * 100).rounded()))%"
}
