//
//  UpNextWidget.swift
//  vivobodyWidgets
//
//  The "Up Next" widget. Shows today's scheduled workout or the
//  next rest-day target across system and accessory families.
//

import VivoKit
import AppIntents
import SwiftUI
import WidgetKit

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetShared.upNextKind,
            provider: SnapshotProvider(
                key: WidgetShared.upNextSnapshotKey,
                fallback: UpNextSnapshot.placeholder,
                refreshInterval: 30 * 60
            )
        ) { entry in
            UpNextWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Up Next")
        .description("Today's scheduled workout or the next rest-day target.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct UpNextWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: UpNextSnapshot

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circular
            case .accessoryRectangular:
                rectangular
            case .accessoryInline:
                Text(inlineText)
            default:
                system
            }
        }
        .widgetURL(URL(string: "vivobody://today"))
        .containerBackground(.black, for: .widget)
        .dynamicTypeSize(.large)
    }

    private var system: some View {
        Group {
            switch family {
            case .systemSmall:
                smallSystem
            case .systemMedium:
                mediumSystem
            case .systemLarge:
                largeSystem
            default:
                smallSystem
            }
        }
        .padding()
    }

    private var smallSystem: some View {
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

    private var mediumSystem: some View {
        HStack(alignment: .top, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.sm) {
                kicker
                Text(title)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if snapshot.kind == .rest {
                restSummary
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                WidgetExerciseRows(exercises: snapshot.exercises, limit: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var largeSystem: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            kicker
            Text(title)
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            if snapshot.kind == .rest {
                WidgetGlassPanel {
                    restSummary
                }
            } else {
                WidgetExerciseRows(exercises: snapshot.exercises, limit: 7)
                if let readiness = snapshot.readinessPhrase {
                    Text(readiness)
                        .font(Typography.body)
                        .foregroundStyle(snapshot.easeOff ? Tint.primary : Ink.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
            }

            Spacer(minLength: Space.xs)

            WidgetStatStrip(
                stats: [
                    WidgetStat(value: "\(snapshot.totalSets)", label: "Sets", accent: snapshot.kind == .scheduled),
                    WidgetStat(value: WidgetFormat.volumeValue(snapshot.totalVolume), unit: WidgetFormat.volumeUnit, label: "Volume"),
                    WidgetStat(value: "\(snapshot.exerciseCount)", label: "Exercises"),
                ]
            )

            if snapshot.kind == .scheduled {
                startButton
            }
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

    private var restSummary: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(snapshot.readinessPhrase ?? "Recover well.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .lineLimit(3)
            if let next = snapshot.nextTemplateName {
                Text("Next: \(next) \(dayLabel(snapshot.daysUntil))")
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(2)
            }
        }
    }

    private var startButton: some View {
        Button(intent: StartTodaysWorkoutIntent()) {
            Text("Start")
                .font(Typography.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Space.tapMin)
        }
        .buttonStyle(.glassProminent)
        .tint(Tint.primary)
        .foregroundStyle(Tint.onAccent)
    }

    private var circular: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(snapshot.kind == .scheduled ? Tint.primary : Ink.secondary)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(circularText)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today")
                .font(Typography.micro)
                .foregroundStyle(Ink.tertiary)
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
            Text(subtitle)
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.secondary)
                .lineLimit(1)
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

    private var inlineText: String { "\(title) - \(subtitle)" }
    private var circularText: String { title == "Rest" ? "Rest" : String(title.prefix(6)) }

    private func dayLabel(_ days: Int) -> String {
        switch days {
        case 1: return "tomorrow"
        case 2...6: return "in \(days)d"
        default: return "next week"
        }
    }
}
