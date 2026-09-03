//
//  TrainingLoadSection.swift
//  vivobody
//
//  The personal workload lens as one bold instrument: the rolling
//  seven-day line in orange against the user's own recent-range band,
//  with the current seven-day value and Below / Within / Above verdict
//  promoted to a large readout above the chart. A slim driver strip sits
//  under the chart inside the same card. Before any qualifying work is
//  logged, a dormant canvas fills the same geometry — baseline weeks as
//  slots, baseline days as a span track — so the empty state is the
//  chart not yet drawn, never a text card.
//

import Charts
import SwiftUI
import VivoKit

struct TrainingLoadSection: View {
    let report: TrainingLoadReport

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Training load",
                trailing: report.points.isEmpty ? "waiting for sets" : "12-week view",
                trailingIsInProgress: report.points.isEmpty,
                accessibilityIdentifier: "insightsLoadInstrument"
            )

            if report.points.isEmpty {
                DormantSlotsCanvas(
                    slotCount: TrainingLoadReport.requiredActiveBaselineWeeks,
                    filledSlots: report.activeBaselineWeeks,
                    legend: baselineLegend,
                    spanFraction: baselineDayFraction,
                    accessibilityLabel: baselineAccessibilityLabel
                )
                .frame(height: InsightChartCanvas.hero)
                .padding(Space.xl)
                .contentCard()
            } else {
                VStack(alignment: .leading, spacing: Space.lg) {
                    loadReadout

                    InsightChartLegend(items: legendItems)

                    chart

                    Rectangle()
                        .fill(Surface.edge)
                        .frame(height: 0.5)

                    StatStrip(
                        stats: [
                            Stat(
                                value: "\(Int(report.drivers.sessions.current.rounded()))",
                                label: "Sessions"
                            ),
                            Stat(
                                value: "\(Int(report.drivers.heavySets.current.rounded()))",
                                label: "1–5 reps"
                            ),
                            Stat(
                                value: "\(Int(report.drivers.moderateSets.current.rounded()))",
                                label: "6–12 reps"
                            ),
                        ]
                    )
                }
                .padding(Space.xl)
                .contentCard()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Current read

    private var loadReadout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: Space.xl) {
                currentMetric
                Spacer(minLength: Space.sm)
                verdictReadout
            }

            VStack(alignment: .leading, spacing: Space.lg) {
                currentMetric
                verdictReadout
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var currentMetric: some View {
        MetricView(
            label: "Estimated hard sets · 7 days",
            value: format(report.currentLoad),
            valueFont: Typography.metricLg,
            accent: true,
            accentColor: Tint.primaryText
        )
    }

    private var verdictReadout: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(verdictTitle)
                .font(Typography.title)
                .foregroundStyle(verdictTextColor)
            Text(report.hasEnoughHistory ? "vs personal range" : "personal range forming")
                .panelLegend()
        }
    }

    private var verdictTitle: String {
        switch report.verdict {
        case .low: "Below range"
        case .productive: "Within range"
        case .high: "Above range"
        case .insufficient: "Baseline building"
        }
    }

    // MARK: - Baseline (dormant) state

    private var baselineDayFraction: Double {
        min(
            1,
            max(
                0,
                Double(report.observedBaselineDays)
                    / Double(TrainingLoadReport.baselineMinimumDays)
            )
        )
    }

    private var baselineLegend: String {
        let days = min(report.observedBaselineDays, TrainingLoadReport.baselineMinimumDays)
        let weeks = min(report.activeBaselineWeeks, TrainingLoadReport.requiredActiveBaselineWeeks)
        return "\(days)/\(TrainingLoadReport.baselineMinimumDays) days · \(weeks)/\(TrainingLoadReport.requiredActiveBaselineWeeks) weeks"
    }

    private var baselineAccessibilityLabel: String {
        let days = min(report.observedBaselineDays, TrainingLoadReport.baselineMinimumDays)
        let weeks = min(report.activeBaselineWeeks, TrainingLoadReport.requiredActiveBaselineWeeks)
        return "Training load signal building. \(days) of \(TrainingLoadReport.baselineMinimumDays) days and \(weeks) of \(TrainingLoadReport.requiredActiveBaselineWeeks) active weeks collected. Complete working sets to begin the rolling seven-day line."
    }

    // MARK: - Trend chart

    private var legendItems: [InsightChartLegend.Item] {
        var items = [InsightChartLegend.Item(label: "7-day load", color: Tint.primary)]
        if report.hasEnoughHistory {
            items.append(
                InsightChartLegend.Item(label: "Recent range", color: Tint.primary.opacity(0.22))
            )
        }
        return items
    }

    private var chart: some View {
        Chart {
            ForEach(report.points) { point in
                if let lower = point.rangeLower,
                   let upper = point.rangeUpper
                {
                    AreaMark(
                        x: .value("Date", point.date),
                        yStart: .value("Range lower", lower),
                        yEnd: .value("Range upper", upper)
                    )
                    .foregroundStyle(Tint.primary.opacity(0.14))
                }

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Estimated hard sets", point.load)
                )
                .foregroundStyle(Tint.primary)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            if let latest = report.points.last {
                PointMark(
                    x: .value("Latest date", latest.date),
                    y: .value("Latest load", latest.load)
                )
                .foregroundStyle(verdictColor)
                .symbolSize(46)
            }
        }
        .chartXAxis {
            InsightChartAxis.dates(
                desiredCount: usesDetailedChartDates ? 4 : 3,
                density: usesDetailedChartDates ? .monthDay : .monthOnly
            )
        }
        .chartYAxis { InsightChartAxis.values(format: format) }
        .frame(height: InsightChartCanvas.hero)
        // Keep Swift Charts' per-point accessibility representation so
        // VoiceOver users can inspect the trend instead of receiving a
        // single flattened summary.
        .accessibilityLabel("Training load trend")
        .accessibilityValue(chartAccessibilitySummary)
    }

    private var chartAccessibilitySummary: String {
        guard let latest = report.points.last else {
            return "No training load data"
        }
        let date = latest.date.formatted(date: .abbreviated, time: .omitted)
        let count = report.points.count
        return "\(count) daily \(count == 1 ? "value" : "values"). Latest, \(format(latest.load)) estimated hard sets on \(date)."
    }

    private var usesDetailedChartDates: Bool {
        guard let first = report.points.first?.date,
              let last = report.points.last?.date else { return true }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return days < 45
    }

    // MARK: - Formatting and color

    private func format(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private var verdictColor: Color {
        switch report.verdict {
        case .productive: Tint.primary
        case .high: Ink.primary
        case .low: Ink.secondary
        case .insufficient: Ink.primary
        }
    }

    private var verdictTextColor: Color {
        switch report.verdict {
        case .productive: Tint.primaryText
        case .high: Ink.primary
        case .low: Ink.secondary
        case .insufficient: Ink.primary
        }
    }
}
