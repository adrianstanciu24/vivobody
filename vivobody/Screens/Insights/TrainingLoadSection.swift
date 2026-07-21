//
//  TrainingLoadSection.swift
//  vivobody
//
//  The personal workload lens. A plain-language Low / Productive /
//  High status leads, followed by the user's position against their
//  own range, a Swift Charts rolling seven-day trend, the work that
//  drove it, and one calm next action.
//

import VivoKit
import SwiftUI
import Charts

struct TrainingLoadSection: View {
    let report: TrainingLoadReport

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Training load", trailing: "Rolling 7 days")

            if report.points.isEmpty {
                Text("Complete a workout to start reading your training load.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
            } else {
                status
                if report.hasEnoughHistory {
                    rangeIndicator
                }
                chart
                drivers
                guidance
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status

    private var status: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(statusTitle)
                .font(Typography.display)
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(statusSummary)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        switch report.verdict {
        case .insufficient: return "Building your range"
        case .low:          return "Low load"
        case .productive:   return "Productive load"
        case .high:         return "High load"
        }
    }

    private var statusSummary: String {
        guard let change = report.changeFromUsual else {
            let remaining = max(1, 28 - report.daysLogged)
            return "\(format(report.currentLoad)) estimated hard sets in the last 7 days. Keep logging for about \(remaining) more day\(remaining == 1 ? "" : "s") to form your personal range."
        }

        let percent = Int((abs(change) * 100).rounded())
        if percent <= 1 {
            return "Your last 7 days match your usual training."
        }
        let direction = change > 0 ? "above" : "below"
        return "Your last 7 days are \(percent)% \(direction) your usual training."
    }

    // MARK: - Personal range

    private var rangeIndicator: some View {
        VStack(spacing: Space.sm) {
            SegmentGauge(segments: 48, height: 12, spacing: 2) { _, position in
                if abs(position - gaugePosition) < 0.025 {
                    return statusColor
                }
                if TrainingLoadReport.gaugeProductiveBand.contains(position) {
                    return Tint.primary.opacity(0.28)
                }
                return Surface.edge
            }

            HStack {
                Text("Low")
                Spacer()
                Text("Productive")
                Spacer()
                Text("High")
            }
            .panelLegend()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(statusTitle), positioned against your personal productive range")
    }

    private var gaugePosition: Double {
        TrainingLoadReport.gaugePosition(forRatio: report.ratio)
    }

    // MARK: - Trend

    private var chart: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.lg) {
                legend(color: Tint.primary, label: "7-day load")
                if report.hasEnoughHistory {
                    legend(color: Tint.primary.opacity(0.22), label: "Productive range")
                }
            }

            Chart {
                ForEach(report.points) { point in
                    if let lower = point.productiveLower,
                       let upper = point.productiveUpper {
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
                            Text(format(amount))
                                .font(Typography.metricMicro)
                                .foregroundStyle(Ink.tertiary)
                        }
                    }
                }
            }
            .frame(height: 180)
            .accessibilityElement()
            .accessibilityLabel("Rolling seven-day training load over \(report.points.count) days")
        }
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
            driverRow("Sessions", driver: report.drivers.sessions, wholeNumber: true)
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
            return "usual"
        }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(format(abs(delta))) vs usual"
    }

    // MARK: - Guidance

    private var guidance: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(guidanceText)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .contentChip()
        .accessibilityElement(children: .combine)
    }

    private var guidanceText: String {
        switch report.verdict {
        case .insufficient:
            return "Keep training normally while your personal range takes shape."
        case .low:
            return "If you feel ready, add a normal session."
        case .productive:
            return "Maintain your current training rhythm."
        case .high:
            return "Keep the next session lighter, or add a rest day."
        }
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
        case .high:         return Tint.danger
        case .low:          return Ink.secondary
        case .insufficient: return Ink.primary
        }
    }
}
