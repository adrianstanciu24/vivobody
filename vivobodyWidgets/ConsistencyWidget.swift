//
//  ConsistencyWidget.swift
//  vivobodyWidgets
//
//  The "Consistency" widget — medium family only. Just the graph:
//  the weekly-volume sparkline over the six-month training heatmap
//  with the intensity legend. No headings or stat strips.
//

import VivoKit
import SwiftUI
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

    /// Pro-gated: the app mirrors the entitlement into the App Group;
    /// free renders the locked placeholder deep-linking to the paywall.
    private var isPro: Bool { WidgetEntitlement.isPro }

    var body: some View {
        Group {
            if !isPro {
                WidgetProLock(title: "Consistency")
            } else {
                graph.padding()
            }
        }
        .widgetURL(URL(string: isPro ? "vivobody://insights/consistency" : "vivobody://pro"))
        .containerBackground(.black, for: .widget)
        .dynamicTypeSize(.large)
    }

    private var graph: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            WeeklyVolumeSparkline(values: snapshot.weeklyVolume, height: 28)
            ConsistencyHeatmapGrid(weeks: snapshot.weeks, cellSpacing: 3)
                .accessibilityLabel("Training heatmap, \(snapshot.daysTrained) days trained in the last six months")
            HeatmapLegend()
        }
    }
}
