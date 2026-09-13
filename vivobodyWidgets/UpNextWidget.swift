//
//  UpNextWidget.swift
//  vivobodyWidgets
//
//  The "Up Next" widget — small family only. Shows today's scheduled
//  workout as a compact card, with a separate start/resume action,
//  or the next rest-day target. The surrounding tile opens Today.
//

import AppIntents
import SwiftUI
import VivoKit
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let snapshot: UpNextSnapshot

    var body: some View {
        // Extra Large already needs the compact hierarchy in a small widget.
        card(showDetails: dynamicTypeSize <= .large)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetURL(URL(string: "vivobody://today"))
            .widgetAppearanceBackground(warmAccent: true)
    }

    private func card(showDetails: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if showDetails {
                Text("Today")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
            }
            Spacer(minLength: Space.xs)
            Text(title)
                .font(showDetails ? .system(.title2, weight: .bold) : Typography.headline)
                .fontWeight(.bold)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: Space.xs)
            if snapshot.kind == .scheduled {
                scheduledFooter(showDetails: showDetails)
            } else {
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func scheduledFooter(showDetails: Bool) -> some View {
        HStack(alignment: .bottom, spacing: Space.sm) {
            Group {
                if showDetails {
                    HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                        Text(snapshot.totalSets, format: .number)
                            .font(Typography.statValue)
                            .fontWeight(.bold)
                            .foregroundStyle(Tint.primaryText)
                            .monospacedDigit()
                            .widgetAccentable()
                        Text(snapshot.totalSets == 1 ? "set" : "sets")
                            .font(Typography.caption)
                            .foregroundStyle(Ink.secondary)
                    }
                } else {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Tint.primaryText)
                        .widgetAccentable()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(snapshot.totalSets) planned \(snapshot.totalSets == 1 ? "set" : "sets")")
            Spacer(minLength: 0)
            Button(intent: StartTodaysWorkoutIntent()) {
                Image(systemName: "arrow.up.right")
                    .font(Typography.headline)
                    .foregroundStyle(Tint.onAccent)
                    .frame(width: Space.tapMin, height: Space.tapMin)
                    .background(Tint.primary, in: Circle())
            }
            .buttonStyle(.plain)
            .widgetAccentable()
            .accessibilityLabel("Start \(title)")
            .accessibilityHint("Opens your workout in Vivobody. Resumes a workout if one is already active.")
            .accessibilityIdentifier("upNextWidgetStartButton")
        }
    }

    private var title: String {
        switch snapshot.kind {
        case .scheduled:
            snapshot.templateName ?? "Workout"
        case .rest:
            "Rest"
        case .unscheduled:
            "Start fresh"
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
        case 1: "tomorrow"
        case 2 ... 6: "in \(days)d"
        default: "next week"
        }
    }
}
