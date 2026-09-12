//
//  SymmetrySection.swift
//  vivobody
//
//  Training-balance instrument for opposing groups and movement patterns
//  across all history. The main Insights mode shows three fixed push/pull
//  proportional two-color capsule bars; a drill-out splits the full qualified
//  board into category cards.
//  Unfinished comparisons collapse into one building rail instead of a wall
//  of empty rows. Distribution-only pairs never imply a universal 50/50 target.
//

import SwiftUI
import VivoKit

enum SymmetryPresentation: Equatable {
    case focus
    case full

    static let focusIDs = ["horizontal-push-pull", "vertical-push-pull", "compound-push-pull"]
}

struct SymmetrySection: View {
    let board: AntagonistBoard
    let presentation: SymmetryPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Training balance",
                trailing: meaningfulPairs.isEmpty ? "building" : "all time",
                trailingIsInProgress: meaningfulPairs.isEmpty,
                accessibilityIdentifier: presentation == .focus
                    ? "insightsBalanceInstrument"
                    : "insightsBalanceAllInstrument"
            )

            if meaningfulPairs.isEmpty {
                buildingCard
            } else if presentation == .focus {
                focusCard
            } else {
                fullBoardCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var presentedPairs: [AntagonistPair] {
        presentation == .focus
            ? SymmetryPresentation.focusIDs.compactMap { board.pair($0) }
            : board.pairs
    }

    private var meaningfulPairs: [AntagonistPair] {
        presentedPairs.filter(\.hasMeaningfulWork)
    }

    private var buildingCount: Int {
        presentedPairs.count - meaningfulPairs.count
    }

    private var focusCard: some View {
        VStack(spacing: Space.section) {
            ForEach(meaningfulPairs) { pair in
                BalanceShareRow(pair: pair)
            }

            if buildingCount > 0 {
                SectionDivider()
                buildingRail
            }
        }
        .padding(Space.xl)
        .contentCard()
    }

    private var fullBoardCard: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text(group.title)
                        .panelLegend()
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("insightsBalanceGroup-\(group.id)")

                    VStack(spacing: Space.section) {
                        ForEach(group.pairs) { pair in
                            BalanceShareRow(pair: pair)
                        }
                    }
                }
                .padding(Space.xl)
                .contentCard()
            }

            if buildingCount > 0 {
                buildingRail
                    .padding(.horizontal, Space.xl)
            }
        }
    }

    private var buildingCard: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(alignment: .center, spacing: Space.sm) {
                BuildingSignalDot(size: 10)
                Text("Building comparisons")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                Text(buildingProgressLabel)
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }

            if let leadingBuildingPair {
                Text("Closest signal · \(leadingBuildingPair.leftLabel) / \(leadingBuildingPair.rightLabel)")
                    .panelLegendType()
                    .foregroundStyle(Tint.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(board.pairs) { pair in
                    let progress = buildingProgress(for: pair)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Tint.primary.opacity(0.18 + progress * 0.60),
                                    Ink.primary.opacity(0.08 + progress * 0.18),
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 18 + CGFloat(progress) * 54)
                }
            }
            .frame(height: 72, alignment: .bottom)
            .accessibilityHidden(true)

            Text("A comparison appears after six effective sets across its two sides and at least two workouts. Until then, no balance verdict is made.")
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.xl)
        .contentCard()
        .accessibilityElement(children: .combine)
    }

    private var leadingBuildingPair: AntagonistPair? {
        presentedPairs
            .filter { !$0.hasMeaningfulWork }
            .max {
                let lhs = min(
                    $0.total / AntagonistBoard.minSets,
                    Double($0.sampleSessions) / Double(AntagonistBoard.minimumSessions)
                )
                let rhs = min(
                    $1.total / AntagonistBoard.minSets,
                    Double($1.sampleSessions) / Double(AntagonistBoard.minimumSessions)
                )
                return lhs < rhs
            }
    }

    private var buildingProgressLabel: String {
        guard let pair = leadingBuildingPair else {
            return "0/\(Int(AntagonistBoard.minSets)) SETS · 0/\(AntagonistBoard.minimumSessions) WORKOUTS"
        }
        let sets = min(pair.total, AntagonistBoard.minSets)
        let sessions = min(pair.sampleSessions, AntagonistBoard.minimumSessions)
        return "\(InsightsFormat.setsLabel(sets))/\(Int(AntagonistBoard.minSets)) SETS · \(sessions)/\(AntagonistBoard.minimumSessions) WORKOUTS"
    }

    private func buildingProgress(for pair: AntagonistPair) -> Double {
        let setProgress = pair.total / AntagonistBoard.minSets
        let workoutProgress = Double(pair.sampleSessions)
            / Double(AntagonistBoard.minimumSessions)
        return min(1, max(0, min(setProgress, workoutProgress)))
    }

    private var buildingRail: some View {
        HStack(spacing: Space.md) {
            BuildingSignalDot(size: 10)
            HStack(spacing: 3) {
                ForEach(0 ..< buildingCount, id: \.self) { _ in
                    Capsule()
                        .fill(Ink.primary.opacity(0.12))
                        .frame(width: 5, height: 24)
                }
            }
            Text("\(buildingCount) more \(buildingCount == 1 ? "comparison" : "comparisons") building")
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// Stable analytics IDs assign each pair to one scan-friendly
    /// group while preserving the board's order within that group.
    private var groups: [SymmetryGroup] {
        let definitions: [(String, String, Set<String>)] = [
            (
                "upper-body-compound",
                "Upper body · compound",
                [
                    "compound-push-pull",
                    "horizontal-push-pull",
                    "vertical-push-pull",
                ]
            ),
            (
                "upper-body-isolation",
                "Upper body · isolation",
                ["isolation-push-pull"]
            ),
            (
                "upper-body-muscles",
                "Upper body · muscle groups",
                ["bi-tri"]
            ),
            (
                "lower-body",
                "Lower body",
                [
                    "quad-ham",
                    "hip-abductors-adductors",
                    "calves-shins",
                ]
            ),
            (
                "training-style",
                "Training style · descriptive",
                [
                    "squat-hinge",
                    "bilateral-unilateral",
                ]
            ),
        ]

        return definitions.compactMap { id, title, pairIDs in
            let pairs = meaningfulPairs.filter { pairIDs.contains($0.id) }
            guard !pairs.isEmpty else { return nil }
            return SymmetryGroup(id: id, title: title, pairs: pairs)
        }
    }
}

private struct SymmetryGroup: Identifiable {
    let id: String
    let title: String
    let pairs: [AntagonistPair]
}

// MARK: - Pair share row

/// Two capsule segments share the full width in proportion to the pair's work.
/// Names share one line and the large percentages sit on the bar ends beneath
/// them, so every row keeps the same height however long a name is.
private struct BalanceShareRow: View {
    let pair: AntagonistPair
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var leftPercent: Int {
        Int((pair.leftShare * 100).rounded())
    }

    private var rightPercent: Int {
        100 - leftPercent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.sm) {
                    sideLine(name: pair.leftLabel, percent: leftPercent, isLeft: true)
                    sideLine(name: pair.rightLabel, percent: rightPercent, isLeft: false)
                }
            } else {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(alignment: .top, spacing: Space.lg) {
                        nameText(pair.leftLabel, isLeft: true)
                        Spacer(minLength: 0)
                        nameText(pair.rightLabel, isLeft: false)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: Space.lg) {
                        percentText(leftPercent, isLeft: true)
                        Spacer(minLength: 0)
                        percentText(rightPercent, isLeft: false)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            GeometryReader { proxy in
                let gap: CGFloat = pair.leftShare > 0 && pair.leftShare < 1 ? 3 : 0
                let width = max(0, proxy.size.width - gap)
                HStack(spacing: gap) {
                    if pair.leftShare > 0 {
                        Capsule().fill(Tint.primary.gradient)
                            .frame(width: width * pair.leftShare)
                    }
                    if pair.leftShare < 1 {
                        Capsule().fill(Ink.secondary.opacity(0.6))
                            .frame(width: width * (1 - pair.leftShare))
                    }
                }
            }
            .frame(height: InstrumentBarHeight.standard)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("insightsBalance-\(pair.id)")
        .accessibilityLabel("\(pair.leftLabel), \(leftPercent) percent; \(pair.rightLabel), \(rightPercent) percent. Share of the pair's effective sets, all time.")
    }

    /// At accessibility sizes each side keeps its name and number on one line
    /// so the pairing stays explicit when the two sides stack.
    private func sideLine(name: String, percent: Int, isLeft: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            nameText(name, isLeft: isLeft)
            Spacer(minLength: 0)
            percentText(percent, isLeft: isLeft)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func nameText(_ name: String, isLeft: Bool) -> some View {
        Text(name)
            .font(Typography.headline)
            .foregroundStyle(isLeft ? Ink.primary : Ink.secondary)
    }

    private func percentText(_ percent: Int, isLeft: Bool) -> some View {
        Text("\(percent)%")
            .font(Typography.statValueCompact)
            .foregroundStyle(isLeft ? Tint.primary : Ink.secondary)
            .monospacedDigit()
            .lineLimit(1)
    }
}
