//
//  ConsistencyWidget.swift
//  vivobodyWidgets
//
//  The "Consistency" widget. Shows the training streak and a
//  six-month heatmap across system and accessory families.
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
        .description("Your training streak and six-month heatmap.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct ConsistencyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: ConsistencySnapshot

    /// Pro-gated: the app mirrors the entitlement into the App Group;
    /// free renders the locked placeholder deep-linking to the paywall.
    private var isPro: Bool { WidgetEntitlement.isPro }

    var body: some View {
        Group {
            if !isPro {
                WidgetProLock(title: "Consistency")
            } else {
                switch family {
                case .accessoryCircular:
                    VStack(spacing: 0) {
                        Text("\(snapshot.weekStreak)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                        Text("wks")
                            .font(Typography.micro)
                    }
                case .accessoryRectangular:
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(snapshot.weekStreak) weeks")
                            .font(Typography.headline)
                        cadenceRow
                    }
                case .accessoryInline:
                    Text("\(snapshot.weekStreak) weeks in a row")
                default:
                    system
                }
            }
        }
        .widgetURL(URL(string: isPro ? "vivobody://insights/consistency" : "vivobody://pro"))
        .containerBackground(.black, for: .widget)
        .dynamicTypeSize(.large)
    }

    @ViewBuilder
    private var system: some View {
        switch family {
        case .systemSmall:
            smallSystem.padding()
        case .systemMedium:
            mediumSystem.padding()
        case .systemLarge:
            largeSystem.padding()
        default:
            smallSystem.padding()
        }
    }

    private var smallSystem: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Streak")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text("\(snapshot.weekStreak)")
                    .font(Typography.metricHero)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                Text("weeks")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.secondary)
            }
            Spacer(minLength: 0)
            cadenceRow
        }
    }

    private var mediumSystem: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Consistency")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
            ConsistencyHeatmapGrid(weeks: Array(snapshot.weeks.suffix(8)), cellSpacing: 3)
                .accessibilityLabel("Training heatmap")
            Spacer(minLength: 0)
            statLine
        }
    }

    private var largeSystem: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Consistency")
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                Spacer()
                Text("last 6 months")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
            }
            statLine
            ConsistencyHeatmapGrid(weeks: snapshot.weeks, cellSpacing: 3)
                .accessibilityLabel("Training heatmap, \(snapshot.daysTrained) days trained in the last six months")
            WeeklyVolumeSparkline(values: snapshot.weeklyVolume)
            HeatmapLegend()
        }
    }

    private var cadenceRow: some View {
        HStack(spacing: 4) {
            ForEach((snapshot.weeks.last ?? []).indices, id: \.self) { index in
                let day = (snapshot.weeks.last ?? [])[index]
                Circle()
                    .fill(day.level > 0 ? Tint.primary : Ink.primary.opacity(0.10))
                    .frame(width: 10, height: 10)
                    .overlay {
                        if day.isToday {
                            Circle().stroke(Ink.secondary, lineWidth: 1)
                        }
                    }
                    .widgetAccentable()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week: \(trainedDayCount) of \(totalDayCount) days trained")
    }

    private var trainedDayCount: Int {
        (snapshot.weeks.last ?? []).filter { $0.level > 0 }.count
    }

    private var totalDayCount: Int {
        (snapshot.weeks.last ?? []).count
    }

    private var statLine: some View {
        WidgetStatStrip(
            stats: [
                WidgetStat(value: snapshot.sessionsPerWeek.widgetOneDecimal, label: "Per week", accent: snapshot.sessionsPerWeek >= 2),
                WidgetStat(value: "\(snapshot.weekStreak)", label: "Week streak"),
                WidgetStat(value: snapshot.averageRIR?.widgetOneDecimal ?? "-", label: "Avg RIR"),
            ],
            compact: family == .systemMedium
        )
    }
}
