//
//  StaminaSection.swift
//  vivobody
//
//  Set-to-set rep changes by movement pattern: fewer, same, or more reps.
//  The drill-out adds the typical rep profile for each movement pattern;
//  exercise history lives in Exercise Detail. A window that splits dashboards
//  lays the drill-out's pattern cards in two lanes beside the fold.
//

import SwiftUI
import VivoKit

struct StaminaSection: View {
    let report: SetSeriesStamina

    var body: some View {
        NavigationLink {
            StaminaDetail(report: report)
        } label: {
            VStack(alignment: .leading, spacing: Space.lg) {
                HStack {
                    Text("Set-series stamina").font(Typography.title)
                    Spacer(minLength: Space.sm)
                    Image(systemName: "chevron.right").font(Typography.caption)
                }
                .foregroundStyle(Ink.primary)
                Text("Set to set · all time").panelLegend()
                if report.patterns.isEmpty {
                    Text(report.heldBackCount > 0 ? "Held-back series only" : "Building your first series")
                        .font(Typography.headline).foregroundStyle(Ink.primary)
                    Text("Three completed sets at the same weight reveal how reps hold up.")
                        .font(Typography.body).foregroundStyle(Ink.secondary)
                } else {
                    Text("How your reps change from one set to the next.")
                        .font(Typography.caption).foregroundStyle(Ink.secondary)
                    VStack(alignment: .leading, spacing: Space.xl) {
                        ForEach(Array(report.patterns.prefix(3))) { pattern in
                            StaminaStepsRow(pattern: pattern, showsSeriesCount: true)
                        }
                    }
                }
            }
            .padding(Space.xl).contentCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("insightsStaminaLink")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens all movement patterns and typical reps per set")
    }

    private var accessibilityLabel: String {
        let reads = report.patterns.prefix(3).map(StaminaStepsRow.accessibilityRead).joined(separator: ". ")
        return "Set-series stamina. All time. \(reads.isEmpty ? "Building: three completed sets at the same weight needed." : reads). \(report.heldBackCount) held-back series excluded."
    }
}

private struct StaminaDetail: View {
    let report: SetSeriesStamina

    var body: some View {
        InsightsDrilloutScreen(title: "Set-series stamina") { lanes in
            if let lanes {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    header
                        .horizontallyPlaced(in: lanes.leading)
                    InsightsLaneLayout(
                        lanes: lanes,
                        assignments: report.patterns.indices.map { $0.isMultiple(of: 2) ? .leading : .trailing },
                        spacing: Space.xxl
                    ) {
                        ForEach(Array(report.patterns.enumerated()), id: \.element.id) { index, pattern in
                            patternCard(pattern)
                                .accessibilityElement(children: .contain)
                                // VoiceOver would otherwise read across the lanes
                                // by position; this keeps the reading order.
                                .accessibilitySortPriority(Double(report.patterns.count - index))
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            } else {
                LazyVStack(alignment: .leading, spacing: Space.xxl) {
                    header
                    ForEach(report.patterns) { pattern in
                        patternCard(pattern)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            Text("How your reps hold up").font(Typography.title)
                .accessibilityIdentifier("staminaPatterns").accessibilityAddTraits(.isHeader)
            Text("Set to set · same logged weight").font(Typography.caption).foregroundStyle(Ink.secondary)
            if report.patterns.isEmpty {
                Text("Complete at least three sets at identical weight within a compound exercise.")
                    .font(Typography.body).foregroundStyle(Ink.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func patternCard(_ pattern: SetSeriesStamina.Pattern) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            StaminaStepsRow(pattern: pattern, showsSeriesCount: false)
            TypicalSetsBlock(
                title: pattern.pattern.displayName, sets: pattern.typicalSets,
                identifier: "staminaTypicalSets-\(pattern.pattern.rawValue)"
            )
            .padding(.top, Space.sm)
            Text("Last set averages \(Int((pattern.retention * 100).rounded()))% of first-set reps")
                .font(Typography.caption).foregroundStyle(Ink.secondary)
            if let change = pattern.change {
                let points = Int((change * 100).rounded())
                Text(points == 0
                    ? "No change across comparable series"
                    : "\(abs(points)) percentage \(abs(points) == 1 ? "point" : "points") \(points > 0 ? "increase" : "decrease") across comparable series")
                    .font(Typography.caption).foregroundStyle(Ink.secondary)
            }
            Text("Based on \(pattern.series.count) set series · all time")
                .font(Typography.caption).foregroundStyle(Ink.secondary)
        }
        .padding(Space.xl).contentCard()
    }
}
