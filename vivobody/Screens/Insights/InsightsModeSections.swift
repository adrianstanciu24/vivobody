//
//  InsightsModeSections.swift
//  vivobody
//
//  Focused section compositions for the Insights screen. Shape keeps the
//  lifetime bloom dominant, with compact name/share previews linking to recent
//  exercise and rep distributions. Balance keeps only the priority tug-of-war
//  beams in the main scroll and moves the qualified roster one level deeper.
//

import SwiftUI
import VivoKit

struct ShapeInsightsSection: View {
    let signature: TrainingSignature
    let dominance: ExerciseDominanceBoard
    let composition: CompositionSplit
    let intensity: IntensityMix
    let intensityWeeks: [IntensityWeek]
    let migration: RepRangeMigrationReport
    let coverage: MovementCoverage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SignatureSection(signature: signature)

            GroupSeparator(verticalPadding: Space.section)

            VStack(spacing: Space.lg) {
                VStack(spacing: Space.sm) {
                    ExerciseMixLink(board: dominance, split: composition)
                    RepMixLink(
                        mix: intensity,
                        weeks: intensityWeeks,
                        migration: migration
                    )
                }
                MovementCoverageSection(report: coverage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BalanceInsightsSection: View {
    let board: AntagonistBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SymmetrySection(board: board, presentation: .focus)

            if board.pairs.contains(where: {
                $0.hasMeaningfulWork && !SymmetryPresentation.focusIDs.contains($0.id)
            }) {
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationLink {
            InsightsDrilloutScreen(title: "Exercise mix") {
                ExerciseDominanceSection(board: board, split: split)
            }
        } label: {
            VStack(alignment: .leading, spacing: Space.sm) {
                drilloutHeader(
                    title: "Exercise mix",
                    scope: "last 4 weeks",
                    stacked: dynamicTypeSize.isAccessibilitySize
                )

                if let top = board.top {
                    mixSummary(
                        name: top.name,
                        share: top.share,
                        stacked: dynamicTypeSize.isAccessibilitySize
                    )
                    mixShareBar(leadingShare: top.share)
                } else {
                    Text("No recent strength sets")
                        .font(Typography.body)
                        .foregroundStyle(Ink.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .padding(Space.lg)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationLink {
            InsightsDrilloutScreen(title: "Rep mix") {
                IntensityMixSection(mix: mix, weeks: weeks, migration: migration)
            }
        } label: {
            VStack(alignment: .leading, spacing: Space.sm) {
                drilloutHeader(
                    title: "Rep mix",
                    scope: "last 4 weeks",
                    stacked: dynamicTypeSize.isAccessibilitySize
                )

                if let dominant = mix.dominant {
                    mixSummary(
                        name: dominant.label,
                        share: mix.share(dominant),
                        stacked: dynamicTypeSize.isAccessibilitySize
                    )
                    mixShareBar(leadingShare: mix.share(dominant))
                } else {
                    Text("No recent rep-tracked sets")
                        .font(Typography.body)
                        .foregroundStyle(Ink.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .padding(Space.lg)
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
                .foregroundStyle(Tint.primary)
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

private func drilloutHeader(title: String, scope: String, stacked: Bool) -> some View {
    let layout = stacked
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.md))

    return layout {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Text(title)
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.secondary)
            if stacked {
                Spacer(minLength: Space.sm)
                drilloutChevron
            }
        }
        if !stacked { Spacer(minLength: Space.sm) }
        Text(scope).panelLegend()
        if !stacked { drilloutChevron }
    }
}

private var drilloutChevron: some View {
    Image(systemName: "chevron.right")
        .font(Typography.caption)
        .foregroundStyle(Ink.tertiary)
        .accessibilityHidden(true)
}

private func mixSummary(name: String, share: Double, stacked: Bool) -> some View {
    let layout = stacked
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.md))

    return layout {
        Text(name)
            .font(Typography.title)
            .foregroundStyle(Ink.primary)
            .fixedSize(horizontal: false, vertical: true)
        if !stacked { Spacer(minLength: Space.sm) }
        Text(percent(share))
            .font(Typography.statValue)
            .foregroundStyle(Tint.primary)
            .monospacedDigit()
            .fixedSize()
    }
}

private func mixShareBar(leadingShare: Double) -> some View {
    let leadingShare = min(1, max(0, leadingShare))
    let hasRemainder = leadingShare < 1
    let gap = hasRemainder ? Space.xs : 0
    return GeometryReader { proxy in
        let availableWidth = max(0, proxy.size.width - gap)
        HStack(spacing: gap) {
            Capsule()
                .fill(Tint.primary)
                .frame(width: availableWidth * leadingShare)

            if hasRemainder {
                Capsule()
                    .fill(Ink.quaternary)
                    .frame(width: availableWidth * (1 - leadingShare))
            }
        }
    }
    .frame(height: InstrumentBarHeight.standard)
    .accessibilityHidden(true)
}

private func percent(_ share: Double) -> String {
    "\(Int((share * 100).rounded()))%"
}
