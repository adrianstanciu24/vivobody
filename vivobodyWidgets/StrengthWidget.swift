//
//  StrengthWidget.swift
//  vivobodyWidgets
//
//  The "Strength" widget — large family only. The Insights strength
//  instrument distilled: climbing/stalled/slipping counts, the lead
//  lift's estimated-1RM curve with the all-time best drawn as a
//  record line and PR sessions dotted, and the current/best/trend
//  stat strip. The app precomputes the series and trend label into
//  a StrengthSnapshot; weights arrive in canonical lb and convert
//  to the mirrored display unit here.
//

import VivoKit
import Charts
import SwiftUI
import WidgetKit

struct StrengthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetShared.strengthKind,
            provider: SnapshotProvider(
                key: WidgetShared.strengthSnapshotKey,
                galleryPlaceholder: StrengthSnapshot.placeholder,
                empty: StrengthSnapshot.empty,
                refreshInterval: 24 * 60 * 60
            )
        ) { entry in
            StrengthWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Strength")
        .description("Your lead lift's estimated 1RM curve.")
        .supportedFamilies([.systemLarge])
    }
}

struct StrengthWidgetView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let snapshot: StrengthSnapshot

    /// Pro-gated: the app mirrors the entitlement into the App Group;
    /// free renders the locked placeholder deep-linking to the paywall.
    private var isPro: Bool { WidgetEntitlement.isPro }

    var body: some View {
        Group {
            if !isPro {
                WidgetProLock(title: "Strength")
            } else {
                large.padding()
            }
        }
        .widgetURL(URL(string: isPro ? "vivobody://insights" : "vivobody://pro"))
        .containerBackground(.black, for: .widget)
        .dynamicTypeSize(.large)
    }

    @ViewBuilder
    private var large: some View {
        if snapshot.hasData {
            VStack(alignment: .leading, spacing: Space.md) {
                header
                WidgetStatStrip(
                    stats: [
                        WidgetStat(value: "\(snapshot.climbingCount)", label: "Climbing", accent: snapshot.climbingCount > 0),
                        WidgetStat(value: "\(snapshot.stalledCount)", label: "Stalled"),
                        WidgetStat(value: "\(snapshot.slippingCount)", label: "Slipping"),
                    ]
                )
                Text(snapshot.exercise)
                    .font(Typography.headline)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                chart
                    .frame(maxHeight: .infinity)
                WidgetStatStrip(
                    stats: [
                        WidgetStat(value: displayValue(snapshot.currentE1RM), unit: WidgetFormat.volumeUnit, label: "Current e1RM"),
                        WidgetStat(value: displayValue(snapshot.bestE1RM), unit: WidgetFormat.volumeUnit, label: "Best"),
                        WidgetStat(value: snapshot.trendLabel, label: "Trend", accent: snapshot.trendLabel == "PR"),
                    ]
                )
            }
        } else {
            VStack(alignment: .leading, spacing: Space.md) {
                header
                Spacer(minLength: 0)
                Text("Strength trends appear once you've logged a weighted lift across a few sessions.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Strength")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
            Spacer()
            Text("estimated 1RM")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        let points = snapshot.points.map { point in
            E1RMChartPoint(date: point.date, value: displayNumber(point.e1RM), isPR: point.isPR)
        }
        let best = displayNumber(snapshot.bestE1RM)

        return Chart {
            RuleMark(y: .value("Best", best))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(lineColor.opacity(Opacity.medium))
                .annotation(position: .top, alignment: .trailing) {
                    Text("best")
                        .font(Typography.metricMicro)
                        .foregroundStyle(lineColor.opacity(Opacity.strong))
                }

            ForEach(points) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("e1RM", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(lineColor)

                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("e1RM", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.22), lineColor.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                if p.isPR {
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("e1RM", p.value)
                    )
                    .symbolSize(50)
                    .foregroundStyle(lineColor)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .accessibilityLabel("\(snapshot.exercise) estimated one-rep max over time")
    }

    private var lineColor: Color {
        renderingMode == .vibrant ? .white : Tint.primary
    }

    // MARK: - Unit conversion

    private func displayNumber(_ lb: Double) -> Double {
        SharedWeightFormatter.toDisplay(lb, unit: WidgetFormat.weightUnit)
    }

    private func displayValue(_ lb: Double) -> String {
        SharedWeightFormatter.string(lb, unit: WidgetFormat.weightUnit, includeUnit: false)
    }
}

private struct E1RMChartPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
    let isPR: Bool
}
