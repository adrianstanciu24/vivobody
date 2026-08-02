//
//  TrainingLoadSection.swift
//  vivobody
//
//  The personal workload lens. A plain-language Below / Within / Above
//  recent-range status leads, followed by the user's position against
//  the median of their previous four weeks, a Swift Charts rolling
//  seven-day trend, and the strength work that drove it. Early reads
//  keep the same bold hierarchy while stating baseline progress.
//

import VivoKit
import SwiftUI
import Charts

struct TrainingLoadSection: View {
    let report: TrainingLoadReport

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Training load",
                trailing: report.hasEnoughHistory ? "rolling 7 days" : "baseline building",
                trailingIsInProgress: !report.hasEnoughHistory
            )

            if report.points.isEmpty {
                InsightBuildingCard(
                    title: "Your load range starts here",
                    detail: "Complete working sets to begin the rolling seven-day line. The comparison settles after 28 days and 3 active baseline weeks.",
                    progress: baselineProgressFraction,
                    progressLabel: baselineProgressLabel,
                    accessibilityProgress: baselineProgressAccessibilityLabel
                )
            } else {
                VStack(alignment: .leading, spacing: Space.lg) {
                    status
                    if report.gaugeMarkerPosition != nil {
                        rangeIndicator
                    }
                    if !report.hasEnoughHistory {
                        baselineProgress
                    }
                    chart
                }
                .padding(Space.xl)
                .contentCard()

                drivers
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status

    private var status: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(statusTitle)
                .font(Typography.display)
                .foregroundStyle(statusColor)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)

            Text(statusContext)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusTitle: String {
        switch report.verdict {
        case .insufficient: return "Building your range"
        case .low:          return "Below recent range"
        case .productive:   return "Within recent range"
        case .high:         return "Above recent range"
        }
    }

    private var statusContext: String {
        if report.hasEnoughHistory {
            return "Your last 7 days compared with the median of the previous 4 weeks."
        }
        if report.activeBaselineWeeks > 0 {
            let count = report.activeBaselineWeeks
            return "Early read from \(count) prior active \(count == 1 ? "week" : "weeks"). Your range settles after 28 days and 3 active baseline weeks."
        }
        return "Your range settles after 28 days and 3 active baseline weeks."
    }

    // MARK: - Personal range

    private var rangeIndicator: some View {
        VStack(spacing: Space.sm) {
            SegmentGauge(segments: 48, height: 12, spacing: 2) { _, position in
                if abs(position - gaugePosition) < 0.025 {
                    return statusColor
                }
                if TrainingLoadReport.gaugeRecentBand.contains(position) {
                    return Tint.primary.opacity(0.28)
                }
                return Surface.edge
            }

            HStack {
                Text("Below")
                Spacer()
                Text("Within")
                Spacer()
                Text("Above")
            }
            .panelLegend()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rangeAccessibilityLabel)
    }

    private var gaugePosition: Double {
        report.gaugeMarkerPosition ?? 0
    }

    private var rangeAccessibilityLabel: String {
        let qualifier = report.hasEnoughHistory ? "recent range" : "early recent-range estimate"
        return "\(statusTitle), positioned against your \(qualifier)"
    }

    private var baselineProgress: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.sm) {
                BuildingSignalDot()
                Text("Baseline progress")
                    .panelLegendType()
                    .foregroundStyle(Tint.inProgress)
            }

            StatStrip(
                stats: [
                    Stat(
                        value: "\(report.activeBaselineWeeks)/\(TrainingLoadReport.requiredActiveBaselineWeeks)",
                        label: "Prior active weeks"
                    ),
                    Stat(
                        value: "\(report.observedBaselineDays)/\(TrainingLoadReport.baselineMinimumDays)",
                        label: "Days elapsed"
                    ),
                ],
                valueFont: Typography.statValueCompact,
                edgeAligned: true
            )

            SegmentLadder(
                fraction: baselineProgressFraction,
                segments: 24,
                tint: Tint.inProgress,
                height: 5,
                spacing: 3
            )

            Text(baselineProgressText)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.lg)
        .contentChip(tint: Tint.inProgress.opacity(0.07))
        .padding(.horizontal, -Space.lg)
    }

    private var baselineProgressFraction: Double {
        let dayProgress = Double(report.observedBaselineDays)
            / Double(TrainingLoadReport.baselineMinimumDays)
        let weekProgress = Double(report.activeBaselineWeeks)
            / Double(TrainingLoadReport.requiredActiveBaselineWeeks)
        return min(1, max(0, min(dayProgress, weekProgress)))
    }

    private var baselineProgressLabel: String {
        let days = min(report.observedBaselineDays, TrainingLoadReport.baselineMinimumDays)
        let weeks = min(report.activeBaselineWeeks, TrainingLoadReport.requiredActiveBaselineWeeks)
        return "\(days)/\(TrainingLoadReport.baselineMinimumDays) DAYS · \(weeks)/\(TrainingLoadReport.requiredActiveBaselineWeeks) ACTIVE WEEKS"
    }

    private var baselineProgressAccessibilityLabel: String {
        let days = min(report.observedBaselineDays, TrainingLoadReport.baselineMinimumDays)
        let weeks = min(report.activeBaselineWeeks, TrainingLoadReport.requiredActiveBaselineWeeks)
        return "\(days) of \(TrainingLoadReport.baselineMinimumDays) days and \(weeks) of \(TrainingLoadReport.requiredActiveBaselineWeeks) active weeks"
    }

    private var baselineProgressText: String {
        let days = report.baselineDaysRemaining
        let weeks = report.baselineWeeksRemaining
        if days > 0, weeks > 0 {
            return "Needs \(days) more \(days == 1 ? "day" : "days") and \(weeks) more active \(weeks == 1 ? "week" : "weeks") before the comparison settles."
        }
        if days > 0 {
            return "Needs \(days) more \(days == 1 ? "day" : "days") before the comparison settles."
        }
        if weeks > 0 {
            return "Needs \(weeks) more active \(weeks == 1 ? "week" : "weeks") before the comparison settles."
        }
        return "Your recent range is ready to settle."
    }

    // MARK: - Trend

    private var chart: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.lg) {
                legend(color: Tint.primary, label: "7-day load")
                if report.hasEnoughHistory {
                    legend(color: Tint.primary.opacity(0.22), label: "Recent range")
                }
            }

            Chart {
                ForEach(report.points) { point in
                    if let lower = point.rangeLower,
                       let upper = point.rangeUpper {
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
                    .foregroundStyle(statusColor)
                    .symbolSize(46)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Surface.edge)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(chartDateLabel(date))
                                .font(Typography.metricMicro)
                                .foregroundStyle(Ink.tertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Surface.edge)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(format(amount))
                                .font(Typography.metricMicro)
                                .foregroundStyle(Ink.tertiary)
                        }
                    }
                }
            }
            .frame(height: 180)
            // Keep Swift Charts' per-point accessibility representation so
            // VoiceOver users can inspect the trend instead of receiving a
            // single flattened summary.
            .accessibilityLabel("Training load trend")
            .accessibilityValue(chartAccessibilitySummary)
        }
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

    private func chartDateLabel(_ date: Date) -> String {
        if usesDetailedChartDates {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.abbreviated))
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: Space.xs) {
            Capsule()
                .fill(color)
                .frame(width: 18, height: 4)
            Text(label)
                .font(Typography.metricMicro)
                .foregroundStyle(Ink.tertiary)
        }
    }

    // MARK: - Drivers

    private var drivers: some View {
        VStack(spacing: 0) {
            driverRow("Estimated hard sets", driver: report.drivers.hardSets)
            divider
            driverRow("Strength sessions", driver: report.drivers.sessions, wholeNumber: true)
            divider
            driverRow("1–5 rep sets", driver: report.drivers.heavySets, wholeNumber: true)
        }
        .padding(.horizontal, Space.lg)
        .contentChip()
    }

    private func driverRow(
        _ label: String,
        driver: LoadDriver,
        wholeNumber: Bool = false
    ) -> some View {
        HStack(spacing: Space.md) {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
            Spacer(minLength: Space.sm)
            Text(wholeNumber ? "\(Int(driver.current.rounded()))" : format(driver.current))
                .font(Typography.metricInline)
                .foregroundStyle(Ink.primary)
                .monospacedDigit()
            if let usual = driver.usual {
                Text(comparison(current: driver.current, usual: usual))
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
                    .monospacedDigit()
                    .frame(minWidth: 64, alignment: .trailing)
            }
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
    }

    private func comparison(current: Double, usual: Double) -> String {
        let delta = current - usual
        if abs(delta) < 0.05 {
            return "matches recent"
        }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(format(abs(delta))) vs recent"
    }

    // MARK: - Formatting

    private func format(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private var statusColor: Color {
        switch report.verdict {
        case .productive:   return Tint.primary
        case .high:         return Ink.primary
        case .low:          return Ink.secondary
        case .insufficient: return Ink.primary
        }
    }
}
