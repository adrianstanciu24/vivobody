//
//  TodayUpNextSection.swift
//  vivobody
//
//  Today's navigable scheduled or repeat-workout preview in the Insights
//  instrument language: a readout heading, hairline-separated exercise rows
//  with monospaced set structure, and a stat strip for the last matching
//  workout. The root supplies the navigation destination.
//

import SwiftUI
import VivoKit

struct TodayUpNextSection<Destination: View>: View {
    let presentation: TodayUpNextPresentation
    let usesAccessibilityLayout: Bool
    private let destination: Destination

    init(
        presentation: TodayUpNextPresentation,
        usesAccessibilityLayout: Bool,
        @ViewBuilder destination: () -> Destination
    ) {
        self.presentation = presentation
        self.usesAccessibilityLayout = usesAccessibilityLayout
        self.destination = destination()
    }

    var body: some View {
        let preview = presentation.preview(accessibilityLayout: usesAccessibilityLayout)
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Up next", trailing: presentation.scheduleText)
            VStack(alignment: .leading, spacing: Space.lg) {
                NavigationLink { destination } label: { heading }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this workout template")
                    .accessibilityIdentifier("todayUpNextPreview")

                VStack(spacing: 0) {
                    ForEach(Array(preview.rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { hairline }
                        TodayUpNextExerciseRow(row: row, usesAccessibilityLayout: usesAccessibilityLayout)
                            .padding(.vertical, Space.lg)
                    }
                    if preview.remainingCount > 0 {
                        hairline
                        moreRow(count: preview.remainingCount)
                    }
                }

                hairline
                lastTime
            }
            .padding(Space.xl)
            .contentCard()
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                Text(presentation.templateName)
                    .font(usesAccessibilityLayout ? Typography.title : Typography.display)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Space.sm)
                Image(systemName: "chevron.right")
                    .font(Typography.headline)
                    .foregroundStyle(Ink.tertiary)
                    .accessibilityHidden(true)
            }
            Text(presentation.metadata)
                .panelLegend()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .leading)
    }

    private func moreRow(count: Int) -> some View {
        NavigationLink { destination } label: {
            HStack(spacing: Space.md) {
                Text("+\(count) more")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                Spacer(minLength: Space.sm)
                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .leading)
            .padding(.vertical, Space.xs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) more exercises")
        .accessibilityHint("Opens this workout template")
    }

    private var lastTime: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(presentation.lastTime.title)
                .panelLegend()
                .fixedSize(horizontal: false, vertical: true)
            if !presentation.lastTime.columns.isEmpty {
                StatStrip(
                    stats: presentation.lastTime.columns.map { column in
                        Stat(
                            value: column.value,
                            unit: column.unit,
                            label: column.label,
                            accessibilityLabel: column.accessibilityLabel
                        )
                    },
                    valueFont: Typography.statValueCompact,
                    columnWeights: presentation.lastTime.columns.count == 3 ? [3, 3, 4] : nil
                )
                .padding(.top, Space.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.lastTime.accessibilityLabel)
        .accessibilityIdentifier("todayUpNextLastTime")
    }
}

private struct TodayUpNextExerciseRow: View {
    let row: TodayUpNextPresentation.ExerciseRow
    let usesAccessibilityLayout: Bool

    var body: some View {
        Group {
            if usesAccessibilityLayout {
                VStack(alignment: .leading, spacing: Space.xs) {
                    group
                    name
                    scheme
                }
            } else {
                // The scheme column is sized first at its single-line width;
                // the greedy title frame then takes exactly the remaining
                // width, so the row can never report a size wider than the
                // card and a long name wraps only when it truly has to.
                VStack(alignment: .leading, spacing: Space.xs) {
                    group
                    HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                        name
                            .frame(maxWidth: .infinity, alignment: .leading)
                        scheme
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private var name: some View {
        Text(row.name)
            .font(Typography.headline)
            .foregroundStyle(Ink.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var group: some View {
        Text(row.groupName)
            .font(Typography.caption)
            .foregroundStyle(Ink.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// `3 × 12` reads as two figures joined by a quiet operator rather than
    /// three equally heavy monospaced glyphs.
    private var scheme: some View {
        let parts = row.scheme.components(separatedBy: " × ")
        return HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            if parts.count == 2 {
                figure(parts[0])
                Text("×")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
                figure(parts[1])
            } else {
                figure(row.scheme)
            }
        }
    }

    private func figure(_ text: String) -> some View {
        Text(text)
            .font(Typography.statValueCompact)
            .foregroundStyle(Ink.primary)
            .monospacedDigit()
    }
}
