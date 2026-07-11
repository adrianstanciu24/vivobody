//
//  UpNextWidget.swift
//  vivobodyWidgets
//
//  The "Up Next" widget — small family only. Shows today's scheduled
//  workout or the next rest-day target.
//

import VivoKit
import SwiftUI
import WidgetKit

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetShared.upNextKind,
            provider: SnapshotProvider(
                key: WidgetShared.upNextSnapshotKey,
                galleryPlaceholder: UpNextSnapshot.placeholder,
                empty: UpNextSnapshot.empty,
                refreshInterval: 30 * 60
            )
        ) { entry in
            UpNextWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Up Next")
        .description("Today's scheduled workout or the next rest-day target.")
        .supportedFamilies([.systemSmall])
    }
}

struct UpNextWidgetView: View {
    let snapshot: UpNextSnapshot

    var body: some View {
        small
            .padding()
            .widgetURL(URL(string: "vivobody://today"))
            .containerBackground(.black, for: .widget)
            .dynamicTypeSize(.large)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            kicker
            Spacer(minLength: Space.xs)
            Text(title)
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
            Text(subtitle)
                .font(Typography.metricInline)
                .foregroundStyle(Ink.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }

    private var kicker: some View {
        HStack(spacing: Space.sm) {
            Text("Today")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
            if snapshot.kind == .scheduled {
                Circle()
                    .fill(Tint.primary)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
            if snapshot.easeOff {
                Text("Ease off")
                    .font(Typography.caption)
                    .foregroundStyle(Tint.primary)
                    .lineLimit(1)
            }
        }
    }

    private var title: String {
        switch snapshot.kind {
        case .scheduled:
            return snapshot.templateName ?? "Workout"
        case .rest:
            return "Rest"
        case .unscheduled:
            return "Start fresh"
        }
    }

    private var subtitle: String {
        switch snapshot.kind {
        case .scheduled:
            return "\(snapshot.totalSets) \(snapshot.totalSets == 1 ? "set" : "sets")"
        case .rest:
            let next = snapshot.nextTemplateName ?? "workout"
            return "Next: \(next) \(dayLabel(snapshot.daysUntil))"
        case .unscheduled:
            return "No schedule"
        }
    }

    private func dayLabel(_ days: Int) -> String {
        switch days {
        case 1: return "tomorrow"
        case 2...6: return "in \(days)d"
        default: return "next week"
        }
    }
}
