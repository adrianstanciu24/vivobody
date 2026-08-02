//
//  ExerciseDominanceSection.swift
//
//  Recent strength composition in one shared unit and timeframe.
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let clearSampleSets = 6

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Strength composition",
                trailing: compositionIsBuilding
                    ? "\(compositionSetCount)/\(clearSampleSets) sets"
                    : "last 4 weeks",
                trailingIsInProgress: compositionIsBuilding
            )

            if !board.hasAny && split.totalSets == 0 {
                InsightBuildingCard(
                    title: "Composition starts with your lifts",
                    detail: "Complete strength sets to reveal which lifts shape this four-week block and how the classified work is distributed.",
                    progress: 0,
                    progressLabel: "0/\(clearSampleSets) STRENGTH SETS",
                    accessibilityProgress: "0 of \(clearSampleSets) strength sets"
                )
            } else {
                if board.hasAny {
                    allocationCard
                }
                if split.totalSets > 0 {
                    exerciseTypeCard
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compositionSetCount: Int {
        max(board.totalSets, split.totalSets)
    }

    private var compositionIsBuilding: Bool {
        compositionSetCount < clearSampleSets
    }

    // MARK: - Exercise allocation

    private var allocationCard: some View {
        VStack(spacing: Space.lg) {
            allocationHeading

            allocationStrip

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                rowView(for: row, rank: index)
            }
        }
        .padding(Space.xl)
        .contentCard()
    }

    @ViewBuilder
    private var allocationHeading: some View {
        let sample = board.totalSets < clearSampleSets
            ? "EARLY READ · \(setLabel(board.totalSets))"
            : setLabel(board.totalSets)

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Exercise allocation")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Text(sample)
                    .font(Typography.metricMicro)
                    .foregroundStyle(board.totalSets < clearSampleSets ? Ink.secondary : Ink.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise allocation")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                Text(sample)
                    .font(Typography.metricMicro)
                    .foregroundStyle(board.totalSets < clearSampleSets ? Ink.secondary : Ink.tertiary)
            }
        }
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
        HStack(alignment: .top, spacing: Space.sm) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(allocationColor(rank: rank))
                .frame(width: 7, height: 28)
                .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.xs) {
                    rowName(row, rank: rank)
                    HStack(spacing: Space.sm) {
                        rowShare(row, rank: rank)
                        rowSetCount(row)
                    }
                }
            } else {
                rowName(row, rank: rank)
                Spacer(minLength: Space.xs)
                rowShare(row, rank: rank)
                rowSetCount(row)
            }
        }
        .frame(minHeight: 34)
        .accessibilityElement(children: .combine)
    }

    private func rowName(_ row: DominanceRow, rank: Int) -> some View {
        Text(row.name)
            .font(rank == 0 ? Typography.sectionHeading : Typography.caption)
            .foregroundStyle(rank == 0 ? Ink.primary : Ink.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func rowShare(_ row: DominanceRow, rank: Int) -> some View {
        Text("\(Int((row.share * 100).rounded()))%")
            .font(Typography.metricInline)
            .foregroundStyle(rank == 0 ? Tint.primary : Ink.secondary)
            .monospacedDigit()
    }

    private func rowSetCount(_ row: DominanceRow) -> some View {
        Text(setLabel(row.sets))
            .font(Typography.metricMicro)
            .foregroundStyle(Ink.tertiary)
            .monospacedDigit()
            .frame(minWidth: 48, alignment: .trailing)
    }

    // MARK: - Exercise type

    private var exerciseTypeCard: some View {
        let compound = allSetShare(split.compoundSets)
        let isolation = allSetShare(split.isolationSets)
        let unclassified = allSetShare(split.unclassifiedSets)

        return VStack(alignment: .leading, spacing: Space.lg) {
            exerciseTypeHeading

            GeometryReader { geo in
                let populated = typeSegments.filter { $0.share > 0 }
                let spacing: CGFloat = 2
                let gaps = spacing * CGFloat(max(0, populated.count - 1))
                let available = max(0, geo.size.width - gaps)

                HStack(spacing: spacing) {
                    ForEach(populated) { segment in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(segment.fill)
                            .frame(width: available * segment.share)
                            .shadow(
                                color: segment.id == "compound"
                                    ? Tint.primary.opacity(0.26)
                                    : .clear,
                                radius: 8
                            )
                    }
                }
            }
            .frame(height: 16)
            .clipShape(Capsule())
            .accessibilityHidden(true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.md) {
                    typeStat(value: compound, label: "Compound", color: Tint.primary)
                    typeStat(value: isolation, label: "Isolation", color: Ink.primary)
                    if split.unclassifiedSets > 0 {
                        typeStat(value: unclassified, label: "Unclassified", color: Ink.tertiary)
                    }
                }

                VStack(spacing: Space.sm) {
                    typeStat(value: compound, label: "Compound", color: Tint.primary)
                    typeStat(value: isolation, label: "Isolation", color: Ink.primary)
                    if split.unclassifiedSets > 0 {
                        typeStat(value: unclassified, label: "Unclassified", color: Ink.tertiary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                coverageHeading

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Surface.cardTint)
                        Capsule()
                            .fill(Tint.primary.opacity(0.72))
                            .frame(width: proxy.size.width * split.classificationCoverage)
                    }
                }
                .frame(height: 5)
                .accessibilityHidden(true)
            }

            if !split.hasData {
                Text("These sets came from custom exercises without type metadata, so no compound/isolation verdict is shown.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if split.unclassifiedSets > 0 {
                Text("Percentages include every eligible strength set; unclassified custom work stays visible instead of silently dropping out.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
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

    @ViewBuilder
    private var exerciseTypeHeading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Exercise type")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                confidenceChip
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise type")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                confidenceChip
            }
        }
    }

    @ViewBuilder
    private var coverageHeading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Classification coverage")
                Text("\(split.classifiedTotal) of \(split.totalSets) sets")
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(Typography.caption)
            .foregroundStyle(Ink.secondary)
        } else {
            HStack {
                Text("Classification coverage")
                Spacer(minLength: Space.sm)
                Text("\(split.classifiedTotal) of \(split.totalSets) sets")
                    .monospacedDigit()
            }
            .font(Typography.caption)
            .foregroundStyle(Ink.secondary)
        }
    }

    private func typeStat(value: Double, label: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Text("\(Int((value * 100).rounded()))%")
                .font(Typography.statValue)
                .foregroundStyle(color)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
            Text(label)
                .panelLegend()
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .leading)
    }

    @ViewBuilder
    private var confidenceChip: some View {
        Text(confidenceLabel)
            .font(Typography.metricMicro)
            .foregroundStyle(split.isEarlyRead ? Ink.primary : Tint.primary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs)
            .background(
                Capsule()
                    .fill(
                        split.isEarlyRead
                            ? Ink.primary.opacity(0.10)
                            : Tint.primary.opacity(0.14)
                    )
            )
    }

    private var confidenceLabel: String {
        if split.isEarlyRead { return "EARLY READ · \(setLabel(split.totalSets))" }
        if split.classificationCoverage < 0.6 {
            return "LIMITED · \(Int((split.classificationCoverage * 100).rounded()))%"
        }
        return "\(Int((split.classificationCoverage * 100).rounded()))% CLASSIFIED"
    }

    private func allSetShare(_ count: Int) -> Double {
        split.totalSets > 0 ? Double(count) / Double(split.totalSets) : 0
    }

    private var typeSegments: [TypeSegment] {
        [
            TypeSegment(id: "compound", share: allSetShare(split.compoundSets), fill: Tint.primary.opacity(0.9)),
            TypeSegment(id: "isolation", share: allSetShare(split.isolationSets), fill: Ink.primary.opacity(0.48)),
            TypeSegment(id: "unclassified", share: allSetShare(split.unclassifiedSets), fill: Ink.primary.opacity(0.14)),
        ]
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
            confidenceAccessibilityLabel,
            "\(split.classifiedTotal) of \(split.totalSets) sets classified",
            "compound \(Int((compound * 100).rounded())) percent",
            "isolation \(Int((isolation * 100).rounded())) percent",
        ]
        if split.unclassifiedSets > 0 {
            parts.append("unclassified \(Int((allSetShare(split.unclassifiedSets) * 100).rounded())) percent")
        }
        return parts.joined(separator: ", ")
    }

    private var confidenceAccessibilityLabel: String {
        if split.isEarlyRead {
            return "Early read based on \(setLabel(split.totalSets))"
        }
        if split.classificationCoverage < 0.6 {
            return "Limited confidence because classification coverage is below 60 percent"
        }
        return "Established classification coverage"
    }
}

// MARK: - Row data

private struct DominanceRow: Identifiable, Hashable {
    let id: String
    let name: String
    let share: Double
    let sets: Int
}

private struct TypeSegment: Identifiable {
    let id: String
    let share: Double
    let fill: Color
}
