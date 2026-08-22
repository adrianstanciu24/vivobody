//
//  ExerciseDominanceSection.swift
//
//  Recent strength composition as two bold segmented rails in one shared
//  unit and timeframe. Exercise Allocation divides the last four weeks
//  of completed working sets per lift — the top lift wears the accent,
//  the rest step down through gray — with a clear legend naming each
//  segment. Exercise Type divides those sets between compound, isolation,
//  and unclassified work. Classification coverage is a header token, and
//  before any strength work exists a dormant canvas holds the same geometry
//  while the six-set sample collects.
//

import SwiftUI
import VivoKit

struct ExerciseDominanceSection: View {
    let board: ExerciseDominanceBoard
    let split: CompositionSplit

    private let clearSampleSets = 6

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Strength composition",
                trailing: compositionIsBuilding
                    ? "\(compositionSetCount)/\(clearSampleSets) sets"
                    : "last 4 weeks",
                trailingIsInProgress: compositionIsBuilding,
                accessibilityIdentifier: "insightsExerciseMixInstrument"
            )

            if !board.hasAny, split.totalSets == 0 {
                DormantSlotsCanvas(
                    slotCount: clearSampleSets,
                    filledSlots: 0,
                    legend: "0/\(clearSampleSets) strength sets",
                    accessibilityLabel: "Strength composition signal building. 0 of \(clearSampleSets) strength sets completed. Complete strength sets to reveal your exercise allocation and type mix."
                )
                .frame(height: InsightChartCanvas.hero)
                .padding(Space.xl)
                .contentCard()
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
        VStack(alignment: .leading, spacing: Space.lg) {
            cardHeading("Exercise allocation", trailing: setLabel(board.totalSets))

            segmentedShareBar(
                Array(rows.enumerated()).map { index, row in
                    ShareBarSegment(
                        id: row.id,
                        weight: row.sets,
                        fill: allocationColor(rank: index)
                    )
                }
            )

            allocationLegend
        }
        .padding(Space.xl)
        .contentCard()
    }

    private var allocationLegend: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: Space.sm) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(allocationColor(rank: index))
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)

                    Text(row.name)
                        .font(index == 0 ? Typography.sectionHeading : Typography.caption)
                        .foregroundStyle(index == 0 ? Ink.primary : Ink.secondary)
                        .lineLimit(1)

                    Spacer(minLength: Space.sm)

                    Text("\(Int((row.share * 100).rounded()))%")
                        .font(Typography.metricInline)
                        .foregroundStyle(index == 0 ? Tint.primaryText : Ink.secondary)
                        .monospacedDigit()
                }
                .frame(minHeight: 34)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Exercise type

    private var exerciseTypeCard: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            cardHeading("Exercise type", trailing: classificationToken)

            segmentedShareBar(
                typeSegments.map { segment in
                    ShareBarSegment(
                        id: segment.id,
                        weight: segment.sets,
                        fill: segment.fill
                    )
                }
            )

            typeLegend
        }
        .padding(Space.xl)
        .contentCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exerciseTypeAccessibilityLabel)
    }

    private var classificationToken: String {
        if split.isEarlyRead { return "early read" }
        return "\(Int((split.classificationCoverage * 100).rounded()))% classified"
    }

    private var typeSegments: [TypeSegment] {
        [
            TypeSegment(id: "compound", sets: split.compoundSets, fill: Tint.primary.opacity(0.9)),
            TypeSegment(id: "isolation", sets: split.isolationSets, fill: Ink.primary.opacity(0.48)),
            TypeSegment(id: "unclassified", sets: split.unclassifiedSets, fill: Ink.primary.opacity(0.14)),
        ]
        .filter { $0.sets > 0 }
    }

    private var typeLegend: some View {
        VStack(spacing: 0) {
            ForEach(typeSegments) { segment in
                HStack(spacing: Space.sm) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(segment.fill)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)

                    Text(segment.id.capitalized)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.secondary)

                    Spacer(minLength: Space.sm)

                    Text("\(Int((share(of: segment.sets) * 100).rounded()))%")
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                }
                .frame(minHeight: 34)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func share(of count: Int) -> Double {
        split.totalSets > 0 ? Double(count) / Double(split.totalSets) : 0
    }

    // MARK: - Shared pieces

    private func cardHeading(_ title: String, trailing: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                headingTitle(title)
                Spacer(minLength: Space.sm)
                headingTrailing(trailing)
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                headingTitle(title)
                headingTrailing(trailing)
            }
        }
    }

    private func headingTitle(_ title: String) -> some View {
        Text(title)
            .font(Typography.sectionHeading)
            .foregroundStyle(Ink.primary)
    }

    private func headingTrailing(_ trailing: String) -> some View {
        Text(trailing)
            .panelLegend()
            .lineLimit(1)
    }

    private func segmentedShareBar(_ segments: [ShareBarSegment]) -> some View {
        let totalWeight = segments.reduce(0) { $0 + $1.weight }
        let gapCount = max(0, segments.count - 1)

        return GeometryReader { proxy in
            let totalGap = Space.xs * CGFloat(gapCount)
            let availableWidth = max(0, proxy.size.width - totalGap)

            HStack(spacing: Space.xs) {
                ForEach(segments) { segment in
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(segment.fill)
                        .frame(
                            width: totalWeight > 0
                                ? availableWidth * CGFloat(segment.weight) / CGFloat(totalWeight)
                                : 0
                        )
                }
            }
        }
        .frame(height: 36)
        .accessibilityHidden(true)
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
        case 0: Tint.primary
        case 1: Ink.primary.opacity(0.62)
        case 2: Ink.primary.opacity(0.46)
        case 3: Ink.primary.opacity(0.32)
        default: Ink.quaternary
        }
    }

    private func setLabel(_ count: Int) -> String {
        "\(count) set\(count == 1 ? "" : "s")"
    }

    private var exerciseTypeAccessibilityLabel: String {
        let compound = Int((share(of: split.compoundSets) * 100).rounded())
        let isolation = Int((share(of: split.isolationSets) * 100).rounded())
        var parts = [
            "Exercise type",
            confidenceAccessibilityLabel,
            "\(split.classifiedTotal) of \(split.totalSets) sets classified",
            "compound \(compound) percent",
            "isolation \(isolation) percent",
        ]
        if split.unclassifiedSets > 0 {
            parts.append("unclassified \(Int((share(of: split.unclassifiedSets) * 100).rounded())) percent")
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
    let sets: Int
    let fill: Color
}

private struct ShareBarSegment: Identifiable {
    let id: String
    let weight: Int
    let fill: Color
}
