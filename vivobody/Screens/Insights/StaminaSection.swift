//
//  StaminaSection.swift
//  vivobody
//
//  First-to-last rep retention by movement pattern, with a common 100% rail.
//  The drill-out compares movement patterns; exercise history lives in Exercise Detail.
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
                Text("Reps held · all time").panelLegend()
                if report.patterns.isEmpty {
                    Text(report.heldBackCount > 0 ? "Held-back series only" : "Building your first series")
                        .font(Typography.headline).foregroundStyle(Ink.primary)
                    Text("Three completed sets at the same weight reveal how reps hold up.")
                        .font(Typography.body).foregroundStyle(Ink.secondary)
                } else {
                    Text("Reps retained compared with your first set.")
                        .font(Typography.caption).foregroundStyle(Ink.secondary)
                    VStack(alignment: .leading, spacing: Space.xl) {
                        ForEach(Array(report.patterns.prefix(3))) { pattern in
                            StaminaPatternBeam(pattern: pattern, scale: scale)
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
        .accessibilityHint("Opens all movement patterns and comparable changes")
    }

    private var scale: Double {
        max(1, report.patterns.map(\.retention).max() ?? 1)
    }

    private var accessibilityLabel: String {
        let reads = report.patterns.prefix(3).map {
            "\($0.pattern.displayName), \(Int(($0.retention * 100).rounded())) percent of first-set reps across \($0.series.count) series"
        }.joined(separator: ". ")
        return "Set-series stamina. All time. \(reads.isEmpty ? "Building: three completed sets at the same weight needed." : reads). \(report.heldBackCount) held-back series excluded."
    }
}

private struct StaminaPatternBeam: View {
    let pattern: SetSeriesStamina.Pattern
    let scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(pattern.pattern.displayName).font(Typography.headline).foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                Text("\(Int((pattern.retention * 100).rounded()))%")
                    .font(Typography.statValueCompact).foregroundStyle(Tint.primaryText).monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Surface.cardTintBright)
                    Capsule().fill(Tint.primary.gradient)
                        .frame(width: proxy.size.width * pattern.retention / scale)
                    Rectangle().fill(Ink.secondary)
                        .frame(width: 2, height: 24)
                        .offset(x: max(0, proxy.size.width / scale - 2))
                }
            }
            .frame(height: 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pattern.pattern.displayName), holds \(Int((pattern.retention * 100).rounded())) percent of first-set reps, \(pattern.series.count) series, all time")
    }
}

private struct StaminaDetail: View {
    let report: SetSeriesStamina

    var body: some View {
        InsightsDrilloutScreen(title: "Set-series stamina") {
            LazyVStack(alignment: .leading, spacing: Space.xxl) {
                Text("How your reps hold up").font(Typography.title)
                    .accessibilityIdentifier("staminaPatterns").accessibilityAddTraits(.isHeader)
                Text("First → last · same logged weight").font(Typography.caption).foregroundStyle(Ink.secondary)
                ForEach(report.patterns) { pattern in
                    VStack(alignment: .leading, spacing: Space.lg) {
                        StaminaPatternBeam(pattern: pattern, scale: max(1, report.patterns.map(\.retention).max() ?? 1))
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
                if report.patterns.isEmpty {
                    Text("Complete at least three sets at identical weight within a compound exercise.")
                        .font(Typography.body).foregroundStyle(Ink.secondary)
                }
            }
        }
    }
}
