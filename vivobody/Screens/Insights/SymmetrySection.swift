//
//  SymmetrySection.swift
//  vivobody
//
//  Training-balance instrument for opposing groups and movement
//  patterns over the last four weeks. Meaningful comparisons lead as
//  pair-relative butterfly beams; unfinished comparisons collapse into
//  one building rail instead of a wall of empty rows. Squat/hinge and
//  bilateral/unilateral stay descriptive — they never imply that a
//  universal 50/50 target exists.
//

import VivoKit
import SwiftUI

struct SymmetrySection: View {
    let board: AntagonistBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Training balance",
                trailing: buildingCount > 0
                    ? "\(meaningfulPairs.count)/\(board.pairs.count) online"
                    : "last 4 weeks",
                trailingIsInProgress: buildingCount > 0
            )

            Text("Opposing muscle groups and movement patterns, compared in effective sets. Each beam uses its own pair-relative scale.")
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if groups.isEmpty {
                buildingCard
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    balancePulse
                        .padding(.bottom, Space.xl)

                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: Space.lg) {
                            Text(group.title)
                                .panelLegend()
                                .accessibilityAddTraits(.isHeader)

                            VStack(spacing: Space.xl) {
                                ForEach(group.pairs) { pair in
                                    ButterflyRow(pair: pair)
                                }
                            }
                        }

                        if group.id != groups.last?.id {
                            SectionDivider()
                                .padding(.vertical, Space.xl)
                        }
                    }

                    if buildingCount > 0 {
                        SectionDivider()
                            .padding(.vertical, Space.lg)
                        buildingRail
                    }
                }
                .padding(Space.xl)
                .contentCard()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var meaningfulPairs: [AntagonistPair] {
        board.pairs.filter(\.hasMeaningfulWork)
    }

    private var buildingCount: Int {
        board.pairs.count - meaningfulPairs.count
    }

    /// A visual ignition state: available comparisons orbit one strong
    /// count instead of beginning with another dashboard stat strip.
    private var balancePulse: some View {
        HStack(alignment: .center, spacing: Space.lg) {
            ZStack {
                Circle()
                    .fill(Tint.primary.opacity(0.11))
                    .frame(width: 74, height: 74)
                    .blur(radius: 2)
                Circle()
                    .stroke(Tint.primary.opacity(0.32), lineWidth: 1)
                    .frame(width: 58, height: 58)
                Text("\(meaningfulPairs.count)")
                    .font(Typography.statValue)
                    .foregroundStyle(Tint.primary)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(meaningfulPairs.count == 1 ? "comparison online" : "comparisons online")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text("Six effective sets across two workouts unlock each read")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
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
                    .foregroundStyle(Tint.inProgress)
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
        board.pairs
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
                ForEach(0..<buildingCount, id: \.self) { _ in
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
                "upper-body",
                "Upper body",
                [
                    "push-pull",
                    "horizontal-push-pull",
                    "vertical-push-pull",
                    "bi-tri",
                ]
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

// MARK: - Butterfly row

/// One pair as a mirrored beam. The larger side fills its half and the
/// smaller side scales against it, so unlike the old mixed-unit global
/// scale every row communicates only its own ratio.
private struct ButterflyRow: View {
    let pair: AntagonistPair

    private let barHeight: CGFloat = 22
    private let centerGap: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    pairLabel(pair.leftLabel, color: leftLabelColor, alignment: .leading)
                    verdictLabel
                    pairLabel(pair.rightLabel, color: rightLabelColor, alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("\(pair.leftLabel) / \(pair.rightLabel)")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    verdictLabel
                }
            }

            butterfly
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var butterfly: some View {
        GeometryReader { geo in
            let halfWidth = (geo.size.width - centerGap) / 2
            let pairMaximum = max(pair.leftSets, pair.rightSets)
            let leftWidth = wingWidth(
                for: pair.leftSets,
                maximum: pairMaximum,
                halfWidth: halfWidth
            )
            let rightWidth = wingWidth(
                for: pair.rightSets,
                maximum: pairMaximum,
                halfWidth: halfWidth
            )

            ZStack {
                HStack(spacing: centerGap) {
                    ZStack(alignment: .trailing) {
                        track
                        wing(width: leftWidth, color: wingColor(isHeavier: leftIsHeavier))
                        countLabel(pair.leftSets, alignment: .leading)
                    }
                    ZStack(alignment: .leading) {
                        track
                        wing(width: rightWidth, color: wingColor(isHeavier: !leftIsHeavier))
                        countLabel(pair.rightSets, alignment: .trailing)
                    }
                }

                Rectangle()
                    .fill(Tint.primary.opacity(0.72))
                    .frame(width: 1.5, height: barHeight + 8)
                    .shadow(color: Tint.primary.opacity(0.45), radius: 5)
            }
        }
        .frame(height: barHeight)
    }

    private var track: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Surface.cardTint)
    }

    private func wing(width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color)
            .frame(width: width)
    }

    private func countLabel(_ sets: Double, alignment: Alignment) -> some View {
        Text(InsightsFormat.setsLabel(sets))
            .font(Typography.metricMicro)
            .foregroundStyle(Ink.secondary)
            .monospacedDigit()
            .padding(.horizontal, Space.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    private func wingWidth(
        for sets: Double,
        maximum: Double,
        halfWidth: CGFloat
    ) -> CGFloat {
        guard maximum > 0, sets > 0 else { return 0 }
        return halfWidth * sets / maximum
    }

    private func wingColor(isHeavier: Bool) -> Color {
        if pair.isBalanced { return Tint.primary.opacity(0.82) }
        return isHeavier ? Tint.primary : Ink.primary.opacity(0.25)
    }

    private var leftIsHeavier: Bool { pair.leftShare > 0.5 }

    private var leftLabelColor: Color {
        if pair.isBalanced { return Ink.primary }
        return leftIsHeavier ? Ink.primary : Ink.secondary
    }

    private var rightLabelColor: Color {
        if pair.isBalanced { return Ink.primary }
        return leftIsHeavier ? Ink.secondary : Ink.primary
    }

    private var verdictColor: Color {
        pair.isDescriptive ? Ink.secondary : Tint.primary
    }

    private var leanPercent: Int {
        Int((max(pair.leftShare, 1 - pair.leftShare) * 100).rounded())
    }

    private var verdictText: String {
        if pair.isDescriptive {
            let left = Int((pair.leftShare * 100).rounded())
            return "\(left) / \(100 - left)"
        }
        return pair.isBalanced
            ? "balanced"
            : "\(leanPercent)% \(pair.heavierLabel.lowercased())"
    }

    private var verdictLabel: some View {
        Text(verdictText)
            .font(Typography.metricMicro)
            .foregroundStyle(verdictColor)
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func pairLabel(
        _ text: String,
        color: Color,
        alignment: Alignment
    ) -> some View {
        Text(text)
            .font(Typography.sectionHeading)
            .foregroundStyle(color)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var accessibilityText: String {
        let read = pair.isDescriptive ? "Distribution" : "Balance read"
        return "\(pair.leftLabel), \(effectiveSetsText(pair.leftSets)), versus \(pair.rightLabel), \(effectiveSetsText(pair.rightSets)). \(read): \(verdictText)."
    }

    private func effectiveSetsText(_ sets: Double) -> String {
        let unit = abs(sets - 1) < 0.001 ? "effective set" : "effective sets"
        return "\(InsightsFormat.setsLabel(sets)) \(unit)"
    }
}
