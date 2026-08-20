//
//  InsightChartKit.swift
//  vivobody
//
//  The shared chart vocabulary for the Insights tab. Every section draws
//  its Swift Charts instrument from these pieces so all of them read as
//  one family — same gridlines, same label type, same swatches — and the
//  dormant placeholders in DormantChart can mirror the live geometry
//  exactly. The chart carries the story; text stays at header, axis, and
//  legend level.
//
//  Rules encoded here:
//    • Two canvas heights only: hero for a section's main instrument,
//      compact for sparkline-scale reads.
//    • One axis chrome: hairline Surface.edge gridlines, metricMicro
//      Ink.tertiary labels, at most 4 X ticks and 3 Y ticks, no titles.
//    • One micro-legend row: swatch + label items, Tint.primary reserved
//      for the primary series or dominant element.
//

import Charts
import SwiftUI
import VivoKit

// MARK: - Canvas

/// The only two heights an Insights chart canvas may take. Fixed heights
/// keep the LazyVStack rhythm predictable and let a dormant placeholder
/// occupy exactly the space its live chart will fill.
enum InsightChartCanvas {
    /// A section's main instrument.
    static let hero: CGFloat = 180
    /// Sparkline-scale companion reads.
    static let compact: CGFloat = 56
}

// MARK: - Axis chrome

enum InsightChartAxis {
    /// Date tick density for x axes: month + day for short windows,
    /// month-only once a series spans many weeks.
    enum DateDensity {
        case monthDay
        case monthOnly
    }

    /// X axis for date series: hairline gridlines and micro date labels.
    static func dates(
        desiredCount: Int = 4,
        density: DateDensity = .monthDay
    ) -> some AxisContent {
        AxisMarks(values: .automatic(desiredCount: desiredCount)) { value in
            AxisGridLine().foregroundStyle(Surface.edge)
            AxisValueLabel {
                if let date = value.as(Date.self) {
                    Text(
                        date,
                        format: density == .monthDay
                            ? .dateTime.month(.abbreviated).day()
                            : .dateTime.month(.abbreviated)
                    )
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
                }
            }
        }
    }

    /// Y axis with caller-formatted values (sets, reps, load points).
    static func values(
        desiredCount: Int = 3,
        format: @escaping (Double) -> String
    ) -> some AxisContent {
        AxisMarks(values: .automatic(desiredCount: desiredCount)) { value in
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

    /// Y axis for whole-number counts — the common case on Insights.
    static func counts(desiredCount: Int = 3) -> some AxisContent {
        values(desiredCount: desiredCount) { "\(Int($0.rounded()))" }
    }
}

// MARK: - Micro-legend

/// The one legend row an Insights chart may carry: small swatches with
/// micro labels, plus an optional trailing note ("LAST 28 DAYS"). Anything
/// longer belongs in the section header, not under the chart.
struct InsightChartLegend: View {
    struct Item: Identifiable {
        /// `line` matches trend marks, `fill` matches bar and area marks.
        enum Swatch {
            case line
            case fill
        }

        let label: String
        let color: Color
        var swatch: Swatch = .line

        var id: String {
            label
        }
    }

    let items: [Item]
    var trailing: String? = nil

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.lg) {
                itemRow
                if let trailing {
                    Spacer(minLength: Space.sm)
                    Text(trailing)
                        .panelLegend()
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: Space.sm) {
                itemRow
                if let trailing {
                    Text(trailing)
                        .panelLegend()
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var itemRow: some View {
        ForEach(items) { item in
            HStack(spacing: Space.xs) {
                swatchView(for: item)
                Text(item.label)
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func swatchView(for item: Item) -> some View {
        switch item.swatch {
        case .line:
            Capsule()
                .fill(item.color)
                .frame(width: 18, height: 4)
        case .fill:
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(item.color)
                .frame(width: 10, height: 10)
        }
    }
}
