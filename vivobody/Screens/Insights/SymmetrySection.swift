//
//  SymmetrySection.swift
//  vivobody
//
//  Opposing groups and movement patterns weighed against each other
//  over the last 4 weeks. Nine comparisons are gathered into upper
//  body, lower body, and training style groups for quick scanning.
//  Each pair draws a butterfly bar, with two wings growing outward
//  from a shared centre axis. Every wing uses one common scale, so
//  both the lean of a pair and the relative size of all pairs read
//  straight off the picture. Trained wings use the app's orange
//  accent, while zero-data pairs remain neutral.
//

import VivoKit
import SwiftUI

struct SymmetrySection: View {
    let board: AntagonistBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Symmetry", trailing: "last 4 weeks")

            VStack(alignment: .leading, spacing: 0) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text(group.title)
                            .panelLegend()
                            .accessibilityAddTraits(.isHeader)

                        VStack(spacing: Space.xl) {
                            ForEach(group.pairs) { pair in
                                ButterflyRow(pair: pair, maxSide: maxSide)
                            }
                        }
                    }

                    if group.id != groups.last?.id {
                        SectionDivider()
                            .padding(.vertical, Space.xl)
                    }
                }
            }
            .padding(Space.xl)
            .contentCard()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The largest single side across all pairs — the common scale
    /// every wing is drawn against, so Push's 150 sets and Biceps'
    /// 30 read at their true relative size.
    private var maxSide: Double {
        board.pairs.map { max($0.leftSets, $0.rightSets) }.max() ?? 1
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
                "Training style",
                [
                    "squat-hinge",
                    "bilateral-unilateral",
                ]
            ),
        ]

        return definitions.compactMap { id, title, pairIDs in
            let pairs = board.pairs.filter { pairIDs.contains($0.id) }
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

/// One antagonist pair as a mirrored bar: wings grow outward from the
/// centre axis, reach proportional to each side's sets on the shared
/// scale. Labels sit above their wing, set counts at the outer edges
/// of the track.
private struct ButterflyRow: View {
    let pair: AntagonistPair
    let maxSide: Double

    private let barHeight: CGFloat = 22
    private let centerGap: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(pair.leftLabel)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(leftLabelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verdictText)
                    .font(Typography.metricMicro)
                    .foregroundStyle(verdictColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(pair.rightLabel)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(rightLabelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            butterfly
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var butterfly: some View {
        GeometryReader { geo in
            let halfWidth = (geo.size.width - centerGap) / 2
            let leftWidth = wingWidth(for: pair.leftSets, halfWidth: halfWidth)
            let rightWidth = wingWidth(for: pair.rightSets, halfWidth: halfWidth)

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
                    .fill(Surface.edgeBright)
                    .frame(width: 1.5)
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

    private func wingWidth(for sets: Double, halfWidth: CGFloat) -> CGFloat {
        guard maxSide > 0, sets > 0 else { return 0 }
        return max(4, halfWidth * sets / maxSide)
    }

    /// Trained wings use the app accent; the lighter side stays dim so
    /// the imbalance remains readable without introducing another hue.
    private func wingColor(isHeavier: Bool) -> Color {
        guard pair.hasMeaningfulWork else {
            return Ink.primary.opacity(0.12)
        }
        if pair.isBalanced { return Tint.primary.opacity(0.8) }
        return isHeavier ? Tint.primary : Ink.primary.opacity(0.25)
    }

    private var leftIsHeavier: Bool { pair.leftShare >= 0.5 }

    private var leftLabelColor: Color {
        guard pair.hasMeaningfulWork else { return Ink.secondary }
        return leftIsHeavier ? Ink.primary : Ink.secondary
    }

    private var rightLabelColor: Color {
        guard pair.hasMeaningfulWork else { return Ink.secondary }
        return leftIsHeavier ? Ink.secondary : Ink.primary
    }

    private var verdictColor: Color {
        guard pair.hasMeaningfulWork else { return Ink.tertiary }
        return Tint.primary
    }

    /// The heavier side's share of the pair, for the lean chip.
    private var leanPercent: Int {
        Int((max(pair.leftShare, 1 - pair.leftShare) * 100).rounded())
    }

    private var verdictText: String {
        guard pair.hasMeaningfulWork else { return "no data" }
        return pair.isBalanced
            ? "balanced"
            : "\(leanPercent)% \(pair.heavierLabel.lowercased())"
    }

    private var accessibilityText: String {
        guard pair.hasMeaningfulWork else {
            return "\(pair.leftLabel), \(effectiveSetsText(pair.leftSets)), versus \(pair.rightLabel), \(effectiveSetsText(pair.rightSets)). No data yet."
        }
        return "\(pair.leftLabel), \(effectiveSetsText(pair.leftSets)), versus \(pair.rightLabel), \(effectiveSetsText(pair.rightSets)). Verdict: \(verdictText)."
    }

    private func effectiveSetsText(_ sets: Double) -> String {
        let unit = abs(sets - 1) < 0.001 ? "effective set" : "effective sets"
        return "\(InsightsFormat.setsLabel(sets)) \(unit)"
    }
}
