//
//  TrainingLoadSection.swift
//  vivobody
//
//  The recovery lens: this week's training load weighed against the
//  last four weeks' habit (acute:chronic workload ratio, in tonnage).
//  Twelve weeks of tonnage as bars — the current week lit in the
//  verdict's colour — with the 4-week baseline drawn across them as a
//  dashed rule, so "this week vs the habit" is literally visible.
//  The stat strip carries the three numbers and one caption line
//  turns the ratio into a verdict.
//

import VivoKit
import SwiftUI
import Charts

struct TrainingLoadSection: View {
    let report: TrainingLoadReport

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit
    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Training load", trailing: "7d vs 28d")

            if !report.hasEnoughHistory {
                Text(buildingCopy)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                StatStrip(
                    stats: [
                        Stat(value: WeightFormatter.volumeValue(report.acuteLoad, unit: unit), unit: unit.symbol, label: "This week"),
                        Stat(value: WeightFormatter.volumeValue(report.chronicWeekly, unit: unit), unit: unit.symbol, label: "4-wk avg"),
                        Stat(value: ratioLabel, label: "Load ratio", accent: report.verdict == .optimal),
                    ],
                    valueFont: Typography.statValue,
                    edgeAligned: true
                )
                .padding(.vertical, Space.xs)

                chart

                caption
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart

    private var chart: some View {
        let baseline = WeightFormatter.toDisplay(report.chronicWeekly, unit: unit)

        return Chart {
            ForEach(report.weeks) { week in
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Load", WeightFormatter.toDisplay(week.load, unit: unit)),
                    width: .ratio(0.65)
                )
                .foregroundStyle(barColor(for: week))
                .cornerRadius(3)
            }

            RuleMark(y: .value("Baseline", baseline))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Tint.primary.opacity(Opacity.medium))
                .annotation(position: .top, alignment: .leading) {
                    Text("4-wk avg")
                        .font(Typography.metricMicro)
                        .foregroundStyle(Tint.primary.opacity(Opacity.strong))
                }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(compactLabel(amount))
                            .font(Typography.metricMicro)
                            .foregroundStyle(Ink.tertiary)
                    }
                }
            }
        }
        .frame(height: 160)
        .padding(.top, Space.md)
        .accessibilityLabel("Weekly training load over 12 weeks against the 4-week baseline")
    }

    private func barColor(for week: LoadWeek) -> Color {
        week.isCurrent ? verdictColor : Ink.primary.opacity(0.28)
    }

    /// Compact axis figure ("48k") in display units.
    private func compactLabel(_ value: Double) -> String {
        value >= 1000
            ? String(format: "%.0fk", value / 1000)
            : String(format: "%.0f", value)
    }

    // MARK: - Caption

    private var caption: some View {
        Text(line)
            .font(Typography.caption)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Verdict word brightened against the dimmer clause.
    private var line: AttributedString {
        var head = AttributedString(headline + " ")
        head.foregroundColor = report.verdict == .overreaching ? Tint.danger : Ink.secondary
        var tail = AttributedString(explanation)
        tail.foregroundColor = Ink.tertiary
        return head + tail
    }

    private var headline: String {
        switch report.verdict {
        case .detraining:   return "Load is easing."
        case .optimal:      return "Right in the build zone."
        case .pushing:      return "Ramping hard."
        case .overreaching: return "Load is spiking."
        case .insufficient: return ""
        }
    }

    private var explanation: String {
        switch report.verdict {
        case .detraining:   return "Fine for a deload — stack full weeks to keep building."
        case .optimal:      return "This week tracks your 4-week baseline. Sweet spot 0.8–1.3."
        case .pushing:      return "Well above baseline — guard sleep and joints."
        case .overreaching: return "Far above baseline — hold steady or back off a week."
        case .insufficient: return ""
        }
    }

    private var buildingCopy: String {
        if report.daysLogged <= 0 {
            return "Once you've logged about three weeks, this reads your weekly load against your recent baseline to flag when you're ramping too fast."
        }
        let remaining = max(1, 21 - report.daysLogged)
        return "Building your load baseline — about \(remaining) more day\(remaining == 1 ? "" : "s") of history and this reads whether you're ramping too fast or coasting."
    }

    // MARK: - Derived

    private var ratioLabel: String {
        String(format: "%.2f", report.ratio)
    }

    private var verdictColor: Color {
        switch report.verdict {
        case .optimal, .pushing: return Tint.primary
        case .overreaching:      return Tint.danger
        case .detraining:        return Ink.secondary
        case .insufficient:      return Ink.tertiary
        }
    }
}
