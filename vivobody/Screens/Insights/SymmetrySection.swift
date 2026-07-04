//
//  SymmetrySection.swift
//  vivobody
//
//  Opposing groups weighed against each other over the last 4 weeks:
//  push vs pull, quads vs hamstrings, and so on. Each pair draws a
//  tug-of-war bar — the thumb leans toward the heavier side — and one
//  plain-language line calls out the most lopsided pair so you know
//  which side to bring up.
//

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
                insight

                VStack(spacing: Space.xl) {
                    ForEach(board.pairs) { row($0) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var insight: some View {
        if let worst = board.worst {
            Text(line(heavier: worst.heavierLabel, lighter: worst.lighterLabel))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Push and pull, quads and hamstrings, arms — all evenly matched. Symmetrical work.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Two-tone symmetry line: both group names brightened against the
    /// dimmer copy (AttributedString; Text `+` is deprecated).
    private func line(heavier: String, lighter: String) -> AttributedString {
        var a = AttributedString(heavier); a.foregroundColor = Ink.primary
        var b = AttributedString(" is outpacing "); b.foregroundColor = Ink.secondary
        var c = AttributedString(lighter); c.foregroundColor = Ink.primary
        var d = AttributedString(" — bring up your "); d.foregroundColor = Ink.secondary
        var e = AttributedString(lighter); e.foregroundColor = Ink.primary
        var f = AttributedString("."); f.foregroundColor = Ink.secondary
        return a + b + c + d + e + f
    }

    private func row(_ pair: AntagonistPair) -> some View {
        let color = pair.isBalanced ? Tint.primary : Tint.danger
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(pair.leftLabel)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                Text(pair.isBalanced ? "balanced" : "imbalanced")
                    .font(Typography.caption)
                    .foregroundStyle(color)
                Spacer(minLength: Space.sm)
                Text(pair.rightLabel)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
            }

            DivergingBar(
                leftShare: pair.leftShare,
                balanced: pair.isBalanced,
                leftLabel: pair.leftLabel,
                rightLabel: pair.rightLabel
            )

            HStack(spacing: Space.sm) {
                Text("\(InsightsFormat.setsLabel(pair.leftSets)) sets")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                Spacer(minLength: Space.sm)
                Text("\(InsightsFormat.setsLabel(pair.rightSets)) sets")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Diverging balance bar

/// A tug-of-war between two opposing groups, as a segmented dial.
/// The centre segment marks a perfect 50/50 split; segments light
/// from the centre out to the current lean, with the far segment —
/// the thumb — brightest. Accent when balanced, red past tolerance.
private struct DivergingBar: View {
    let leftShare: Double
    let balanced: Bool
    let leftLabel: String
    let rightLabel: String

    private let segments = 41

    var body: some View {
        let center = segments / 2
        let thumb = thumbIndex
        let lo = min(center, thumb)
        let hi = max(center, thumb)
        let color = balanced ? Tint.primary : Tint.danger

        return SegmentGauge(segments: segments, height: 10) { index, _ in
            if index == thumb { return color }
            if index == center { return Ink.tertiary }
            if index > lo && index < hi { return color.opacity(0.45) }
            return Surface.edge
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    /// The lit end of the fill. `leftShare` of 1.0 means fully left,
    /// which sits at index 0 (the track runs left→right).
    private var thumbIndex: Int {
        let position = 1 - min(max(leftShare, 0), 1)
        return min(segments - 1, Int(position * Double(segments)))
    }

    private var accessibilityText: String {
        let l = Int((leftShare * 100).rounded())
        return "\(leftLabel) \(l) percent versus \(rightLabel) \(100 - l) percent"
    }
}
