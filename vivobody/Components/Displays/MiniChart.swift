//
//  MiniChart.swift
//  vivobody
//
//  Tiny Swift Charts sparkline for at-a-glance progress on Me-tab rows.
//  All chart chrome is hidden so it stays sparkline-tight: no axes, no
//  labels, no gridlines, no legend, no plot padding. Just the curve, a
//  soft gradient fill below it, and optional PR pips. The chart reads as
//  one VoiceOver element carrying the caller's summary label.
//

import Charts
import SwiftUI
import VivoKit

struct MiniChart: View {
    let values: [Double]
    /// Indices in `values` to highlight as PRs. Rendered as small
    /// solid dots above the line. Out-of-bounds indices are ignored.
    var prIndices: Set<Int> = []
    var lineColor: Color = Ink.primary
    var fillColor: Color = Ink.primary
    /// VoiceOver description of the chart's data. Callers should
    /// pass a concise summary (e.g. "Body weight trend, 178 to 185 lb").
    var accessibilityLabel: String? = nil

    /// Reserve 4pt of headroom top and bottom so dots and line ends
    /// don't kiss the chart frame.
    private static let verticalInset: CGFloat = 4

    var body: some View {
        let domain = Self.yDomain(for: values)
        Chart {
            ForEach(values.indices, id: \.self) { index in
                // Filled area under the curve — fades to clear so it
                // reads as a soft underglow rather than a solid block.
                AreaMark(
                    x: .value("Index", index),
                    yStart: .value("Floor", domain.lowerBound),
                    yEnd: .value("Value", values[index])
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [fillColor.opacity(0.30), fillColor.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", values[index])
                )
                .foregroundStyle(lineColor.opacity(0.85))
                .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            }

            ForEach(prIndices.filter(values.indices.contains).sorted(), id: \.self) { index in
                PointMark(
                    x: .value("Index", index),
                    y: .value("Value", values[index])
                )
                .symbolSize(CGSize(width: 5, height: 5))
                .foregroundStyle(prColor)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(
            domain: 0 ... max(values.count - 1, 1),
            range: .plotDimension(padding: 0)
        )
        .chartYScale(
            domain: domain,
            range: .plotDimension(startPadding: Self.verticalInset, endPadding: Self.verticalInset)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "Trend chart")
    }

    private var prColor: Color {
        Color(.sRGB, red: 1.0, green: 0.78, blue: 0.30, opacity: 1.0)
    }

    /// The value range the plot spans. When all values are equal, the
    /// range widens symmetrically so the line sits at the vertical
    /// center instead of collapsing onto the top or bottom edge.
    private static func yDomain(for values: [Double]) -> ClosedRange<Double> {
        guard let minV = values.min(), let maxV = values.max() else { return 0 ... 1 }
        guard maxV > minV else { return (minV - 1) ... (minV + 1) }
        return minV ... maxV
    }
}

#Preview("MiniChart") {
    VStack(alignment: .leading, spacing: Space.xxl) {
        MiniChart(
            values: [100, 105, 110, 110, 115, 120, 125, 130],
            prIndices: [0, 1, 2, 4, 5, 6, 7]
        )
        .frame(width: 120, height: 40)

        MiniChart(values: [80, 80, 80, 80])
            .frame(width: 120, height: 40)

        MiniChart(values: [200, 195, 190, 195, 200, 205, 210], prIndices: [0, 5, 6])
            .frame(width: 120, height: 40)

        MiniChart(
            values: [178, 179.4, 178.8, 177.9, 177.6],
            lineColor: Tint.inProgress,
            fillColor: Tint.inProgress
        )
        .frame(width: 96, height: 36)
    }
    .padding(Space.xxl)
    .background(Color.black)
}
