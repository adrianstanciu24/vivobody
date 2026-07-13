//
//  ExerciseDominanceSection.swift
//
//  Recent training composition in one shared unit and timeframe.
//  Exercise Allocation shows which lifts received completed working
//  sets over the last four weeks; Exercise Type shows how those same
//  classified sets split between compound and isolation work.
//
//  The allocation strip gives the whole mix at a glance, the compact
//  ranked list names the top four plus Other, and a separate companion
//  panel keeps exercise type from reading as another ranking row.
//

import VivoKit
import SwiftUI

struct ExerciseDominanceSection: View {
    let board: ExerciseDominanceBoard
    let split: CompositionSplit

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Composition", trailing: "last 4 weeks")

            if !board.hasAny {
                Text("Complete working sets to see how your recent training is allocated across exercises and exercise types.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                allocationCard
                caption
                if split.hasData {
                    exerciseTypeCard
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Exercise allocation

    private var allocationCard: some View {
        VStack(spacing: Space.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise allocation")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                Text(setLabel(board.totalSets))
                    .panelLegend()
            }

            allocationStrip

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                rowView(for: row, rank: index)
            }
        }
        .padding(Space.xl)
        .contentCard()
    }

    private var allocationStrip: some View {
        GeometryReader { proxy in
            let populated = rows.filter { $0.share > 0 }
            let spacing: CGFloat = 2
            let gaps = spacing * CGFloat(max(0, populated.count - 1))
            let availableWidth = max(0, proxy.size.width - gaps)

            HStack(spacing: spacing) {
                ForEach(Array(populated.enumerated()), id: \.element.id) { index, row in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(allocationColor(rank: index))
                        .frame(width: availableWidth * row.share)
                }
            }
        }
        .frame(height: 14)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func rowView(for row: DominanceRow, rank: Int) -> some View {
        HStack(spacing: Space.sm) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(allocationColor(rank: rank))
                .frame(width: 7, height: 28)
                .accessibilityHidden(true)

            Text(row.name)
                .font(rank == 0 ? Typography.sectionHeading : Typography.caption)
                .foregroundStyle(rank == 0 ? Ink.primary : Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: Space.xs)

            Text("\(Int((row.share * 100).rounded()))%")
                .font(Typography.metricInline)
                .foregroundStyle(rank == 0 ? Tint.primary : Ink.secondary)
                .monospacedDigit()

            Text(setLabel(row.sets))
                .font(Typography.metricMicro)
                .foregroundStyle(Ink.tertiary)
                .monospacedDigit()
                .frame(minWidth: 48, alignment: .trailing)
        }
        .frame(minHeight: 34)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Exercise type

    private var exerciseTypeCard: some View {
        let compound = split.share(.compound)
        let isolation = split.share(.isolation)

        return VStack(alignment: .leading, spacing: Space.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise type")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                Text(setLabel(split.classifiedTotal))
                    .panelLegend()
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Tint.primary.opacity(0.85))
                        .frame(width: max(4, geo.size.width * compound))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Ink.quaternary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 12)
            .accessibilityHidden(true)

            HStack(spacing: 0) {
                typeStat(
                    value: Int((compound * 100).rounded()),
                    label: "Compound",
                    color: Tint.primary
                )
                Rectangle()
                    .fill(Surface.edge)
                    .frame(width: 0.5, height: 40)
                typeStat(
                    value: Int((isolation * 100).rounded()),
                    label: "Isolation",
                    color: Ink.primary
                )
            }

            if split.unclassifiedSets > 0 {
                Text("\(setLabel(split.unclassifiedSets)) from custom exercises not included")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .padding(Space.xl)
        .contentCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exerciseTypeAccessibilityLabel(
            compound: compound,
            isolation: isolation
        ))
    }

    private func typeStat(value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("\(value)%")
                .font(Typography.statValue)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .panelLegend()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Caption

    private var caption: some View {
        Text(line)
            .font(Typography.caption)
            .foregroundStyle(Ink.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var line: String {
        if board.topTwoShare > 0.5 {
            let pct = Int((board.topTwoShare * 100).rounded())
            return "Two exercises receive \(pct)% of your recent working sets."
        }
        if board.topShare > 0.4, let top = board.top {
            let pct = Int((top.share * 100).rounded())
            return "\(top.name) receives \(pct)% of your recent working sets."
        }
        let count = board.stats.count
        return "Working sets are spread across \(count) \(count == 1 ? "exercise" : "exercises")."
    }

    // MARK: - Derived rows

    /// The top 4 lifts, with the remainder (if any) collapsed into a
    /// single "Other (N lifts)" row carrying the summed share and
    /// completed set count.
    private var rows: [DominanceRow] {
        let stats = board.stats
        guard stats.count > 5 else {
            return stats.map {
                DominanceRow(
                    id: $0.historyKey,
                    name: $0.name,
                    share: $0.share,
                    sets: $0.sets
                )
            }
        }

        let top = stats.prefix(4)
        let rest = stats.dropFirst(4)
        let restShare = rest.reduce(0) { $0 + $1.share }
        let restSets = rest.reduce(0) { $0 + $1.sets }
        let restCount = rest.count

        return top.map {
            DominanceRow(
                id: $0.historyKey,
                name: $0.name,
                share: $0.share,
                sets: $0.sets
            )
        }
            + [DominanceRow(
                id: "other",
                name: "Other (\(restCount) \(restCount == 1 ? "lift" : "lifts"))",
                share: restShare,
                sets: restSets
            )]
    }

    private func allocationColor(rank: Int) -> Color {
        switch rank {
        case 0: return Tint.primary
        case 1: return Ink.primary.opacity(0.62)
        case 2: return Ink.primary.opacity(0.46)
        case 3: return Ink.primary.opacity(0.32)
        default: return Ink.quaternary
        }
    }

    private func setLabel(_ count: Int) -> String {
        "\(count) set\(count == 1 ? "" : "s")"
    }

    private func exerciseTypeAccessibilityLabel(
        compound: Double,
        isolation: Double
    ) -> String {
        var parts = [
            "Exercise type",
            setLabel(split.classifiedTotal),
            "compound \(Int((compound * 100).rounded())) percent",
            "isolation \(Int((isolation * 100).rounded())) percent",
        ]
        if split.unclassifiedSets > 0 {
            parts.append("\(setLabel(split.unclassifiedSets)) from custom exercises not included")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Row data

private struct DominanceRow: Identifiable, Hashable {
    let id: String
    let name: String
    let share: Double
    let sets: Int
}
