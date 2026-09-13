//
//  StrengthWidget.swift
//  vivobodyWidgets
//
//  The large Training Load widget replacing the former Strength surface.
//  Its stable WidgetKit kind preserves existing placements while the content
//  now answers whether the rolling seven-day load sits inside the user's
//  personal range. The app precomputes every value into a plain snapshot.
//

import Charts
import SwiftUI
import VivoKit
import WidgetKit

struct TrainingLoadWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetShared.trainingLoadKind,
            provider: SnapshotProvider(
                key: WidgetShared.trainingLoadSnapshotKey,
                galleryPlaceholder: TrainingLoadSnapshot.placeholder,
                empty: TrainingLoadSnapshot.empty,
                refreshInterval: 24 * 60 * 60
            )
        ) { entry in
            TrainingLoadWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Training Load")
        .description("Your rolling seven-day workload against your personal range.")
        .supportedFamilies([.systemLarge])
    }
}

struct TrainingLoadWidgetView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let snapshot: TrainingLoadSnapshot

    var body: some View {
        large
            .padding()
            .widgetURL(URL(string: "vivobody://insights"))
            .widgetAppearanceBackground()
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header

            if snapshot.points.isEmpty {
                baselineBuilding
            } else {
                currentReadout
                chart
                    .frame(maxHeight: .infinity)
                contextFooter
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Training load")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
            Spacer()
            Text(snapshot.points.isEmpty ? "waiting for sets" : "12-week view")
                .font(Typography.panelLegend)
                .foregroundStyle(Ink.tertiary)
                .tracking(Typography.panelLegendTracking)
                .textCase(.uppercase)
        }
    }

    private var currentReadout: some View {
        HStack(alignment: .bottom, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                    Text(formatMeasure(snapshot.currentLoad))
                        .font(Typography.metricLg)
                        .foregroundStyle(metricColor)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if snapshot.measure == .volumeLoad {
                        Text(WidgetFormat.volumeUnit)
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.secondary)
                    }
                }
                Text(metricLabel)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 1) {
                Text(verdictTitle)
                    .font(Typography.title)
                    .foregroundStyle(verdictColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("vs personal range")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentAccessibilityLabel)
    }

    private var chart: some View {
        Chart {
            ForEach(snapshot.points) { point in
                if let lower = point.rangeLower,
                   let upper = point.rangeUpper
                {
                    AreaMark(
                        x: .value("Date", point.date),
                        yStart: .value("Range lower", chartValue(lower)),
                        yEnd: .value("Range upper", chartValue(upper))
                    )
                    .foregroundStyle(lineColor.opacity(0.14))
                }

                LineMark(
                    x: .value("Date", point.date),
                    y: .value(chartValueLabel, chartValue(point.load))
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            if let latest = snapshot.points.last {
                PointMark(
                    x: .value("Latest date", latest.date),
                    y: .value("Latest load", chartValue(latest.load))
                )
                .foregroundStyle(verdictColor)
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
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel {
                    if let load = value.as(Double.self) {
                        Text(formatChartValue(load))
                    }
                }
                .font(Typography.metricMicro)
                .foregroundStyle(Ink.tertiary)
            }
        }
        .chartXScale(range: .plotDimension(startPadding: 4, endPadding: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Training load over 12 weeks")
        .accessibilityValue(chartAccessibilityValue)
    }

    private var rangeLegend: some View {
        HStack(spacing: Space.sm) {
            RoundedRectangle(cornerRadius: Radius.pill)
                .fill(lineColor.opacity(0.22))
                .frame(width: 28, height: 7)
            Text(rangeText)
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rangeAccessibilityLabel)
    }

    @ViewBuilder
    private var contextFooter: some View {
        if snapshot.verdict == .insufficient {
            Text("\(min(snapshot.observedBaselineDays, 28))/28 days · \(min(snapshot.activeBaselineWeeks, 3))/3 active weeks")
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .monospacedDigit()
                .accessibilityLabel(
                    "Baseline building, \(min(snapshot.observedBaselineDays, 28)) of 28 days and \(min(snapshot.activeBaselineWeeks, 3)) of 3 active weeks"
                )
        } else {
            rangeLegend
        }
    }

    private var baselineBuilding: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Spacer(minLength: 0)
            Text("Baseline building")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
            HStack(spacing: Space.sm) {
                baselineProgress(
                    value: snapshot.observedBaselineDays,
                    target: 28,
                    label: "days"
                )
                baselineProgress(
                    value: snapshot.activeBaselineWeeks,
                    target: 3,
                    label: "active weeks"
                )
            }
            Text("Complete working sets to begin your rolling seven-day load.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func baselineProgress(
        value: Int,
        target: Int,
        label: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("\(min(value, target))/\(target)")
                .font(Typography.statValueCompact)
                .foregroundStyle(Ink.primary)
                .monospacedDigit()
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(Surface.cardTint, in: RoundedRectangle(cornerRadius: Radius.small))
    }

    private var metricLabel: String {
        switch snapshot.measure {
        case .volumeLoad: "Volume load · 7 days"
        case .hardSets: "Estimated hard sets · 7 days"
        }
    }

    private var verdictTitle: String {
        switch snapshot.verdict {
        case .insufficient: "Baseline building"
        case .low: "Below range"
        case .within: "Within range"
        case .high: "Above range"
        }
    }

    private var rangeText: String {
        guard let lower = snapshot.rangeLower,
              let upper = snapshot.rangeUpper
        else { return "Personal range forming" }
        let values = "\(formatMeasure(lower))–\(formatMeasure(upper))"
        let unit = snapshot.measure == .volumeLoad ? " \(WidgetFormat.volumeUnit)" : ""
        return "Personal range \(values)\(unit)"
    }

    private var currentAccessibilityLabel: String {
        let unit = snapshot.measure == .volumeLoad ? " \(WidgetFormat.volumeUnit)" : " estimated hard sets"
        return "\(formatMeasure(snapshot.currentLoad))\(unit), \(metricLabel). \(verdictTitle) versus personal range."
    }

    private var rangeAccessibilityLabel: String {
        guard let lower = snapshot.rangeLower,
              let upper = snapshot.rangeUpper
        else { return "Personal range forming" }
        let unit = snapshot.measure == .volumeLoad ? " \(WidgetFormat.volumeUnit)" : " estimated hard sets"
        return "Personal range, \(formatMeasure(lower)) to \(formatMeasure(upper))\(unit)"
    }

    private var chartAccessibilityValue: String {
        guard let latest = snapshot.points.last else { return "No training load data" }
        let date = latest.date.formatted(date: .abbreviated, time: .omitted)
        return "\(snapshot.points.count) values. Latest, \(formatMeasure(latest.load)) on \(date)."
    }

    private var chartValueLabel: String {
        snapshot.measure == .volumeLoad ? "Volume load" : "Estimated hard sets"
    }

    private var metricColor: Color {
        renderingMode == .vibrant ? .white : Tint.primaryText
    }

    private var lineColor: Color {
        renderingMode == .vibrant ? .white : Tint.primary
    }

    private var verdictColor: Color {
        switch snapshot.verdict {
        case .within: lineColor
        case .low: Ink.secondary
        case .high, .insufficient: Ink.primary
        }
    }

    private func chartValue(_ value: Double) -> Double {
        snapshot.measure == .volumeLoad
            ? SharedWeightFormatter.toDisplay(value, unit: WidgetFormat.weightUnit)
            : value
    }

    private func formatMeasure(_ value: Double) -> String {
        switch snapshot.measure {
        case .volumeLoad: WidgetFormat.volumeValue(value)
        case .hardSets: formatSetCount(value)
        }
    }

    private func formatChartValue(_ value: Double) -> String {
        if snapshot.measure == .volumeLoad {
            if value >= 10000 {
                let thousands = value / 1000
                return thousands.rounded() == thousands
                    ? "\(Int(thousands))k"
                    : String(format: "%.1fk", thousands)
            }
            return "\(Int(value.rounded()))"
        }
        return formatSetCount(value)
    }

    private func formatSetCount(_ value: Double) -> String {
        abs(value.rounded() - value) < 0.05
            ? "\(Int(value.rounded()))"
            : String(format: "%.1f", value)
    }
}
