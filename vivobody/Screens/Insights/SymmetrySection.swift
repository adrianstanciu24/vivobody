//
//  SymmetrySection.swift
//  vivobody
//
//  Training-balance instrument for opposing groups and movement patterns
//  over the last four weeks. The main Insights mode shows three priority
//  pair-relative butterfly beams; a drill-out keeps the full qualified board.
//  Unfinished comparisons collapse into one building rail instead of a wall
//  of empty rows. Distribution-only pairs never imply a universal 50/50 target.
//

import SwiftUI
import VivoKit

enum SymmetryPresentation: Equatable {
    case focus
    case full

    static let focusLimit = 3
}

struct SymmetrySection: View {
    let board: AntagonistBoard
    let presentation: SymmetryPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Training balance",
                trailing: meaningfulPairs.isEmpty ? "building" : "last 4 weeks",
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

    private var meaningfulPairs: [AntagonistPair] {
        board.pairs.filter(\.hasMeaningfulWork)
    }

    private var buildingCount: Int {
        board.pairs.count - meaningfulPairs.count
    }

    private var focusCard: some View {
        VStack(spacing: Space.xl) {
            ForEach(focusedPairs) { pair in
                ButterflyRow(pair: pair)
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
        VStack(alignment: .leading, spacing: 0) {
            Text("Each beam uses its own effective-set scale")
                .panelLegend()
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

    /// Put actionable unevenness first, then even reads, then descriptive
    /// distributions. Within each class the strongest visual difference leads.
    private var focusedPairs: [AntagonistPair] {
        Array(
            meaningfulPairs.sorted { lhs, rhs in
                let lhsRank = focusRank(lhs)
                let rhsRank = focusRank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                if lhs.skew != rhs.skew { return lhs.skew > rhs.skew }
                return lhs.id < rhs.id
            }
            .prefix(SymmetryPresentation.focusLimit)
        )
    }

    private func focusRank(_ pair: AntagonistPair) -> Int {
        if pair.isDescriptive { return 2 }
        return pair.isBalanced ? 1 : 0
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
                    .foregroundStyle(Tint.primaryText)
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

// MARK: - Butterfly row

/// One pair as a mirrored beam. The larger side fills its half and the
/// smaller side scales against it, so unlike the old mixed-unit global
/// scale every row communicates only its own ratio.
private struct ButterflyRow: View {
    let pair: AntagonistPair

    private let barHeight: CGFloat = 22
    private let centerGap: CGFloat = 3
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            pairHeader

            butterfly
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("insightsBalance-\(pair.id)")
        .accessibilityLabel(Text(accessibilityText))
    }

    @ViewBuilder
    private var pairHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stackedPairHeader
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    pairLabel(pair.leftLabel, color: leftLabelColor, alignment: .leading)
                    verdictLabel(allowsWrapping: false)
                    pairLabel(pair.rightLabel, color: rightLabelColor, alignment: .trailing)
                }

                stackedPairHeader
            }
        }
    }

    private var stackedPairHeader: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("\(pair.leftLabel) / \(pair.rightLabel)")
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            verdictLabel(allowsWrapping: true)
        }
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
                        countLabel(
                            pair.leftSets,
                            alignment: .leading,
                            onFilledWing: leftIsHeavier || pair.isBalanced
                        )
                    }
                    ZStack(alignment: .leading) {
                        track
                        wing(width: rightWidth, color: wingColor(isHeavier: !leftIsHeavier))
                        countLabel(
                            pair.rightSets,
                            alignment: .trailing,
                            onFilledWing: !leftIsHeavier || pair.isBalanced
                        )
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

    private func countLabel(
        _ sets: Double,
        alignment: Alignment,
        onFilledWing: Bool
    ) -> some View {
        Text(InsightsFormat.setsLabel(sets))
            .font(Typography.metricMicro)
            .foregroundStyle(onFilledWing ? Tint.onAccent : Ink.secondary)
            .monospacedDigit()
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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

    private var leftIsHeavier: Bool {
        pair.leftShare > 0.5
    }

    private var leftLabelColor: Color {
        if pair.isBalanced { return Ink.primary }
        return leftIsHeavier ? Ink.primary : Ink.secondary
    }

    private var rightLabelColor: Color {
        if pair.isBalanced { return Ink.primary }
        return leftIsHeavier ? Ink.secondary : Ink.primary
    }

    private var verdictColor: Color {
        pair.isDescriptive ? Ink.secondary : Tint.primaryText
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

    private func verdictLabel(allowsWrapping: Bool) -> some View {
        Text(verdictText)
            .font(Typography.metricMicro)
            .foregroundStyle(verdictColor)
            .monospacedDigit()
            .lineLimit(allowsWrapping ? nil : 1)
            .fixedSize(horizontal: !allowsWrapping, vertical: allowsWrapping)
            .frame(maxWidth: .infinity, alignment: allowsWrapping ? .leading : .center)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
