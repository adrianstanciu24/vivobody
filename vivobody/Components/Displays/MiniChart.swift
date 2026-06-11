//
//  MiniChart.swift
//  vivobody
//
//  Tiny line chart for at-a-glance progress on Me-tab rows. Path-
//  based rather than SwiftUI Charts so it stays sparkline-tight: no
//  axes, no labels, no gridlines, no padding chrome. Just the curve,
//  a soft gradient fill below it, and optional PR pips.
//

import SwiftUI

struct MiniChart: View {
    let values: [Double]
    /// Indices in `values` to highlight as PRs. Rendered as small
    /// solid dots above the line. Out-of-bounds indices are ignored.
    var prIndices: Set<Int> = []
    var lineColor: Color = Ink.primary
    var fillColor: Color = Ink.primary

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let normalized = Self.normalize(values, height: h)

            ZStack {
                // Filled area under the curve — fades to clear so it
                // reads as a soft underglow rather than a solid block.
                Path { path in
                    guard let first = normalized.first else { return }
                    let stepX = stepX(width: w, count: normalized.count)
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: 0, y: first))
                    for (i, y) in normalized.enumerated().dropFirst() {
                        path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: y))
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [fillColor.opacity(0.30), fillColor.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // The line itself.
                Path { path in
                    guard let first = normalized.first else { return }
                    let stepX = stepX(width: w, count: normalized.count)
                    path.move(to: CGPoint(x: 0, y: first))
                    for (i, y) in normalized.enumerated().dropFirst() {
                        path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: y))
                    }
                }
                .stroke(lineColor.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

                // PR pips — small solid dots on flagged points.
                if !prIndices.isEmpty {
                    ForEach(Array(prIndices), id: \.self) { i in
                        if i >= 0 && i < normalized.count {
                            let stepX = stepX(width: w, count: normalized.count)
                            Circle()
                                .fill(prColor)
                                .frame(width: 5, height: 5)
                                .position(x: CGFloat(i) * stepX, y: normalized[i])
                        }
                    }
                }
            }
        }
    }

    private var prColor: Color {
        Color(.sRGB, red: 1.0, green: 0.78, blue: 0.30, opacity: 1.0)
    }

    private func stepX(width: CGFloat, count: Int) -> CGFloat {
        guard count > 1 else { return 0 }
        return width / CGFloat(count - 1)
    }

    /// Map values to Y coordinates in the chart's frame. Higher
    /// values produce smaller Y (closer to the top edge). When all
    /// values are equal, we plant the line at the vertical center
    /// so it doesn't collapse onto the top or bottom edge.
    private static func normalize(_ values: [Double], height: CGFloat) -> [CGFloat] {
        guard let minV = values.min(), let maxV = values.max() else { return [] }
        let range = maxV - minV
        // Reserve 4pt of headroom top and bottom so dots and line
        // ends don't kiss the chart frame.
        let usable = max(1, height - 8)
        let topPad: CGFloat = 4

        if range == 0 {
            return values.map { _ in height / 2 }
        }
        return values.map { v in
            let t = (v - minV) / range // 0…1, higher = bigger value
            return topPad + (1 - CGFloat(t)) * usable
        }
    }
}

#Preview("MiniChart") {
    VStack(alignment: .leading, spacing: 24) {
        MiniChart(
            values: [100, 105, 110, 110, 115, 120, 125, 130],
            prIndices: [0, 1, 2, 4, 5, 6, 7]
        )
        .frame(width: 120, height: 40)

        MiniChart(values: [80, 80, 80, 80])
            .frame(width: 120, height: 40)

        MiniChart(values: [200, 195, 190, 195, 200, 205, 210], prIndices: [0, 5, 6])
            .frame(width: 120, height: 40)
    }
    .padding(24)
    .background(Color.black)
}
