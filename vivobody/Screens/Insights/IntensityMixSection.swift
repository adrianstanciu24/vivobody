//
//  IntensityMixSection.swift
//
//  How training is distributed across rep ranges over time. A
//  dominant-zone hero and four-week mix lead, followed by 12 weeks of
//  completed sets stacked into strength (1–5), hypertrophy (6–12),
//  and endurance (13+) zones. The current partial week is deliberately
//  subdued, and the closing instrument condenses average-rep drift.
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
                Text("As you log weighted sets, this stacks each week's work across strength, hypertrophy, and endurance rep ranges so you can see what your training emphasizes and where it is drifting.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                currentMixHero
                chartBlock
                zoneLegend
                trendSummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Current mix

    @ViewBuilder
    private var currentMixHero: some View {
        if let dominant = mix.dominant {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(alignment: .lastTextBaseline, spacing: Space.md) {
                    Text("\(percentage(for: dominant))%")
                        .font(Typography.metricHero)
                        .foregroundStyle(dominant == .hypertrophy ? Tint.primary : Ink.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(dominant.label)
                            .font(Typography.title)
                            .foregroundStyle(Ink.primary)
                            .lineLimit(1)
                        Text("\(dominant.repRange) reps")
                            .panelLegend()
                    }
                    .padding(.bottom, Space.xs)

                    Spacer(minLength: 0)
                }

                currentMixBar

                Text("of completed working sets in the last 4 weeks")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(dominant.label), \(percentage(for: dominant)) percent of completed working sets in the last 4 weeks, \(dominant.repRange) reps")
        } else {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("No recent sets")
                    .font(Typography.display)
                    .foregroundStyle(Ink.primary)
                Text("Your earlier rep-range history is still shown below.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
            }
        }
    }

    private var currentMixBar: some View {
        GeometryReader { proxy in
            let populated = IntensityZone.allCases.filter { mix.count($0) > 0 }
            let spacing: CGFloat = 2
            let gaps = spacing * CGFloat(max(0, populated.count - 1))
            let availableWidth = max(0, proxy.size.width - gaps)

            HStack(spacing: spacing) {
                ForEach(populated, id: \.self) { zone in
                    Rectangle()
                        .fill(color(zone))
                        .frame(width: availableWidth * mix.share(zone))
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    // MARK: - Weekly chart

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly sets by rep range")
                    .panelLegend()
                Spacer(minLength: 0)
            }

            Chart {
                ForEach(weeks) { week in
                    ForEach(IntensityZone.allCases.reversed(), id: \.self) { zone in
                        if week.count(zone) > 0 {
                            BarMark(
                                x: .value("Week", week.weekStart, unit: .weekOfYear),
                                y: .value("Sets", week.count(zone)),
                                width: .ratio(0.68)
                            )
                            .foregroundStyle(by: .value("Zone", zone.label))
                            .cornerRadius(3)
                            .opacity(week.isCurrentWeek ? 0.42 : 1)
                        }
                    }
                }

                if let latestCompleteWeek {
                    PointMark(
                        x: .value("Latest full week", latestCompleteWeek.weekStart, unit: .weekOfYear),
                        y: .value("Latest full week sets", latestCompleteWeek.total)
                    )
                    .foregroundStyle(Color.clear)
                    .annotation(position: .top, spacing: Space.xs) {
                        Text("\(latestCompleteWeek.total)")
                            .font(Typography.metricMicro)
                            .foregroundStyle(Ink.secondary)
                            .monospacedDigit()
                    }
                }

                if let currentWeek {
                    PointMark(
                        x: .value("Current week", currentWeek.weekStart, unit: .weekOfYear),
                        y: .value("Current week sets", currentWeek.total)
                    )
                    .foregroundStyle(Color.clear)
                    .annotation(position: .top, spacing: Space.xs) {
                        Text("Now")
                            .panelLegend()
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
            .frame(height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chartAccessibilityLabel)
        }
    }

    private var latestCompleteWeek: IntensityWeek? {
        weeks.last { !$0.isCurrentWeek }
    }

    private var currentWeek: IntensityWeek? {
        weeks.last { $0.isCurrentWeek }
    }

    private var chartAccessibilityLabel: String {
        var label = "Weekly completed sets by rep range over 12 weeks."
        if let latestCompleteWeek {
            label += " The latest full week had \(setLabel(latestCompleteWeek.total))."
        }
        if let currentWeek {
            label += " The current partial week has \(setLabel(currentWeek.total))."
        }
        return label
    }

    // MARK: - Zone legend

    private var zoneLegend: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            ForEach(IntensityZone.allCases, id: \.self) { zone in
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.xs) {
                        Circle()
                            .fill(color(zone))
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(zone.label)
                            .font(Typography.caption)
                            .foregroundStyle(zone == mix.dominant ? Ink.primary : Ink.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                    Text(legendDetail(for: zone))
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.tertiary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func legendDetail(for zone: IntensityZone) -> String {
        guard mix.hasData else { return "\(zone.repRange) reps" }
        return "\(zone.repRange) · \(percentage(for: zone))%"
    }

    // MARK: - Rep trend

    @ViewBuilder
    private var trendSummary: some View {
        if migration.hasData {
            HStack(alignment: .center, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Average reps / set")
                        .panelLegend()

                    HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                        if migration.hasTrend {
                            Text(format(migration.earlierAverage))
                                .font(Typography.metricLg)
                                .foregroundStyle(Ink.secondary)
                            Text("→")
                                .font(Typography.metricInline)
                                .foregroundStyle(Ink.tertiary)
                        }
                        Text(format(migration.currentAverage))
                            .font(Typography.metricLg)
                            .foregroundStyle(Ink.primary)
                    }
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                Text(trendLabel)
                    .panelLegendType()
                    .foregroundStyle(trendColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs + 2)
                    .contentChip(tint: trendColor.opacity(0.10))
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .contentChip()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(trendAccessibilityLabel)
        }
    }

    private var trendLabel: String {
        guard migration.hasTrend else { return "Building trend" }
        switch migration.verdict {
        case .towardStrength:  return "Lower-rep shift"
        case .towardEndurance: return "Higher-rep shift"
        case .stable:          return "Stable range"
        }
    }

    private var trendAccessibilityLabel: String {
        guard migration.hasTrend else {
            return "Average reps per set, \(format(migration.currentAverage)). Building a trend."
        }
        return "Average reps per set changed from \(format(migration.earlierAverage)) to \(format(migration.currentAverage)). \(trendLabel)."
    }

    private var trendColor: Color {
        migration.hasTrend && migration.verdict != .stable ? Tint.primary : Ink.secondary
    }

    // MARK: - Formatting

    private func percentage(for zone: IntensityZone) -> Int {
        Int((mix.share(zone) * 100).rounded())
    }

    private func setLabel(_ count: Int) -> String {
        "\(count) set\(count == 1 ? "" : "s")"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
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
