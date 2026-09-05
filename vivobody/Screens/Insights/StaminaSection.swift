//
//  StaminaSection.swift
//  vivobody
//
//  First-to-last rep retention by movement pattern, with a common 100% rail.
//  Matched changes and individual exercise series live in the drill-out.
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
                    VStack(alignment: .leading, spacing: Space.xl) {
                        ForEach(Array(report.patterns.prefix(3))) { pattern in
                            StaminaPatternBeam(pattern: pattern, scale: scale)
                        }
                    }
                    Text("100% = first-set reps").font(Typography.caption).foregroundStyle(Ink.secondary)
                }
            }
            .padding(Space.xl).contentCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("insightsStaminaLink")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens all patterns, matched trends, and individual set series")
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
                            Text("\(change >= 0 ? "+" : "")\(Int((change * 100).rounded())) pts · first → latest matched")
                                .font(Typography.caption).foregroundStyle(Ink.secondary)
                        }
                        Text("\(pattern.series.count) series · all time")
                            .font(Typography.caption).foregroundStyle(Ink.secondary)
                    }
                    .padding(Space.xl).contentCard()
                }
                Text("Exercise series · all time").font(Typography.title).accessibilityAddTraits(.isHeader)
                ForEach(exercises, id: \.0) { key, exercise in
                    NavigationLink {
                        InsightsDrilloutScreen(title: exercise.latest?.name ?? "Exercise series") {
                            ExerciseStaminaInstrument(report: exercise)
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                            Text(exercise.latest?.name ?? "Exercise").font(Typography.headline)
                                .foregroundStyle(Ink.primary)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Ink.tertiary)
                        }
                        .frame(minHeight: 44).padding(Space.lg).contentCard()
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("staminaExercise-\(key)")
                }
                if exercises.isEmpty {
                    Text("Complete at least three sets at identical weight within an exercise.")
                        .font(Typography.body).foregroundStyle(Ink.secondary)
                }
                DisclosureGroup("What counts") {
                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("Only completed rep-based strength runs with three or more consecutive sets at identical logged weight count. The read is last-set reps divided by first-set reps; values above 100% mean reps increased.")
                        Text("A later set with higher logged RIR is marked held back and its series stays out of the pattern average. Unlogged RIR remains unknown. This describes reps, not measured fatigue or recovery.")
                        Text("Trends compare the first and latest matching series across your history. They match exercise, load, series length, first-set reps and effort logging. Different loads do not create an improvement signal.")
                        Text("All time: \(report.heldBackCount) held-back series excluded; \(report.unratedCount) included series with unrated effort; \(report.unclassifiedCount) without a compound pattern.")
                    }
                    .font(Typography.body).foregroundStyle(Ink.secondary).padding(.top, Space.sm)
                }
                .font(Typography.body).frame(minHeight: 44)
            }
        }
    }

    private var exercises: [(String, ExerciseStamina)] {
        report.byExercise.sorted { ($0.value.latest?.name ?? "") < ($1.value.latest?.name ?? "") }
            .map { ($0.key, $0.value) }
    }
}
