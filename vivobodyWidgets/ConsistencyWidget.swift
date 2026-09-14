//
//  ConsistencyWidget.swift
//  vivobodyWidgets
//
//  The "Consistency" widget — medium family only. The weekly-volume
//  sparkline sits over the six-month training heatmap, with the matching
//  days-trained total and intensity legend.
//

import SwiftUI
import VivoKit
import WidgetKit

struct ConsistencyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetShared.consistencyKind,
            provider: SnapshotProvider(
                key: WidgetShared.consistencySnapshotKey,
                galleryPlaceholder: ConsistencySnapshot.placeholder,
                empty: ConsistencySnapshot.empty,
                refreshInterval: 24 * 60 * 60
            )
        ) { entry in
            ConsistencyWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Consistency")
        .description("Your six-month training heatmap.")
        .supportedFamilies([.systemMedium])
    }
}

struct ConsistencyWidgetView: View {
    let snapshot: ConsistencySnapshot

    var body: some View {
        graph.padding()
            .widgetURL(URL(string: "vivobody://insights/consistency"))
            .widgetAppearanceBackground()
    }

    private var graph: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            WeeklyVolumeSparkline(values: snapshot.weeklyVolume, height: 28)
            HStack(spacing: Space.md) {
                ConsistencyHeatmapGrid(weeks: snapshot.weeks, cellSpacing: 3)
                    .accessibilityLabel("Training heatmap, \(daysTrainedAccessibilityLabel) in the last six months")

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(snapshot.daysTrained, format: .number)
                        .font(Typography.metricLg)
                        .fontWeight(.black)
                        .foregroundStyle(Ink.primary)
                        .monospacedDigit()
                    Text(daysTrainedLabel)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .accessibilityHidden(true)
            }
            HeatmapLegend()
        }
    }

    private var daysTrainedLabel: String {
        snapshot.daysTrained == 1 ? "day trained" : "days trained"
    }

    private var daysTrainedAccessibilityLabel: String {
        "\(snapshot.daysTrained) \(daysTrainedLabel)"
    }
}
