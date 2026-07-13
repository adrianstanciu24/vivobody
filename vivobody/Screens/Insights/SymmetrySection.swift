//
//  SymmetrySection.swift
//  vivobody
//
//  Opposing groups weighed against each other over the last 4 weeks:
//  push vs pull, quads vs hamstrings, and so on. Each pair draws a
//  butterfly bar — two wings growing outward from a shared centre
//  axis, each wing's reach proportional to that side's effective
//  sets on one common scale, so both the lean of a pair and the
//  relative size of the pairs read straight off the picture. The
//  heavier wing of a lopsided pair wears the danger tint; balanced
//  pairs stay in the accent. One caption line below calls out the
//  most lopsided pair.
//

import VivoKit
import SwiftUI

struct SymmetrySection: View {
    let board: AntagonistBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Symmetry", trailing: "last 4 weeks")

            if !board.hasAny {
                Text("Symmetry weighs opposing groups against each other — log some pushing and pulling work and the balance shows here.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: Space.xl) {
                    ForEach(board.pairs) { pair in
                        ButterflyRow(pair: pair, maxSide: maxSide)
                    }
                }
                .padding(Space.xl)
                .contentCard()

                caption
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The largest single side across all pairs — the common scale
    /// every wing is drawn against, so Push's 150 sets and Biceps'
    /// 30 read at their true relative size.
    private var maxSide: Double {
        board.pairs.map { max($0.leftSets, $0.rightSets) }.max() ?? 1
    }

    // MARK: - Caption

    @ViewBuilder
    private var caption: some View {
        if let worst = board.worst {
            Text("\(worst.heavierLabel) is outpacing \(worst.lighterLabel) — bring up your \(worst.lighterLabel).")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("All pairs evenly matched — symmetrical work.")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
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
                    .foregroundStyle(leftIsHeavier ? Ink.primary : Ink.secondary)
                Spacer(minLength: Space.sm)
                Text(pair.isBalanced ? "balanced" : "\(leanPercent)% \(pair.heavierLabel.lowercased())")
                    .font(Typography.metricMicro)
                    .foregroundStyle(pair.isBalanced ? Tint.primary : Tint.danger)
                    .monospacedDigit()
                Spacer(minLength: Space.sm)
                Text(pair.rightLabel)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(leftIsHeavier ? Ink.secondary : Ink.primary)
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

    /// Wing colour: the heavier side of a lopsided pair burns danger,
    /// its lighter side sits dim; a balanced pair keeps both wings in
    /// the accent.
    private func wingColor(isHeavier: Bool) -> Color {
        if pair.isBalanced { return Tint.primary.opacity(0.8) }
        return isHeavier ? Tint.danger : Ink.primary.opacity(0.25)
    }

    private var leftIsHeavier: Bool { pair.leftShare >= 0.5 }

    /// The heavier side's share of the pair, for the lean chip.
    private var leanPercent: Int {
        Int((max(pair.leftShare, 1 - pair.leftShare) * 100).rounded())
    }

    private var accessibilityText: String {
        let l = Int((pair.leftShare * 100).rounded())
        return "\(pair.leftLabel) \(l) percent versus \(pair.rightLabel) \(100 - l) percent, \(pair.isBalanced ? "balanced" : "imbalanced")"
    }
}
