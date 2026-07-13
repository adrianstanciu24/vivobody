//
//  IntensityMixSection.swift
//
//  How hard the training is, over time: every completed working set
//  of the last 12 weeks, stacked per week by rep-range zone —
//  strength (1–5), hypertrophy (6–12), endurance (13+). The chart
//  carries both reads that used to live in two sections: the current
//  mix (the recent bars' colour balance) and the drift (the balance
//  shifting week over week). The caption below states the drift
//  verdict from `repRangeMigration`.
//
//  Hypertrophy wears the accent as the productive default zone; the
//  heavy and high-rep ends sit in grayscale luminance — one accent,
//  hierarchy by brightness, like the rest of the app.
//

import VivoKit
import SwiftUI
import Charts

struct IntensityMixSection: View {
    let mix: IntensityMix
    let weeks: [IntensityWeek]
    let migration: RepRangeMigrationReport

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Intensity", trailing: "12 weeks")

            if weeks.isEmpty {
                Text("As you log weighted sets, this stacks each week's work across the strength, hypertrophy, and endurance rep ranges so you can see what your training really emphasises — and where it's drifting.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                readout
                chart
                legend
                caption
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Readout

    /// The line above the chart: the 4-week dominant zone.
    @ViewBuilder
    private var readout: some View {
        if let dominant = mix.dominant {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(dominant.label)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(dominant == .hypertrophy ? Tint.primary : Ink.primary)
                Text("\(Int((mix.share(dominant) * 100).rounded()))% of recent sets")
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(weeks) { week in
                ForEach(IntensityZone.allCases.reversed(), id: \.self) { zone in
                    if week.count(zone) > 0 {
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Sets", week.count(zone)),
                            width: .ratio(0.65)
                        )
                        .foregroundStyle(by: .value("Zone", zone.label))
                        .cornerRadius(3)
                    }
                }
            }
        }
        .chartForegroundStyleScale(
            domain: IntensityZone.allCases.map(\.label),
            range: IntensityZone.allCases.map { color($0) }
        )
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Weekly working sets by rep-range zone over 12 weeks")
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: Space.md) {
            ForEach(IntensityZone.allCases, id: \.self) { zone in
                HStack(spacing: Space.xs) {
                    Circle()
                        .fill(color(zone))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(zone.label)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.secondary)
                        .lineLimit(1)
                    Text(zone.repRange)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.quaternary)
                        .lineLimit(1)
                }
                .fixedSize()
            }
            Spacer(minLength: 0)
        }
        .minimumScaleFactor(0.8)
    }

    // MARK: - Caption

    @ViewBuilder
    private var caption: some View {
        if migration.hasTrend {
            Text(captionLine)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var captionLine: String {
        let earlier = String(format: "%.1f", migration.earlierAverage)
        let current = String(format: "%.1f", migration.currentAverage)
        switch migration.verdict {
        case .towardStrength:
            return "Average set drifted \(earlier) → \(current) reps — trending heavier."
        case .towardEndurance:
            return "Average set drifted \(earlier) → \(current) reps — trending higher-rep."
        case .stable:
            return "Average rep range holding steady around \(current) reps per set."
        }
    }

    // MARK: - Colors

    private func color(_ zone: IntensityZone) -> Color {
        switch zone {
        case .strength:    return Ink.secondary
        case .hypertrophy: return Tint.primary
        case .endurance:   return Ink.quaternary
        }
    }
}
