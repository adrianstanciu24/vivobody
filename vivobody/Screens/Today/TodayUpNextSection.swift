//
//  TodayUpNextSection.swift
//  vivobody
//
//  Today's navigable scheduled-workout preview. It renders an immutable
//  TodayUpNextPresentation while the root supplies the navigation destination.
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
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Up next", trailing: presentation.scheduleText)

            NavigationLink {
                destination
            } label: {
                VStack(alignment: .leading, spacing: Space.lg) {
                    heading
                    exercisePreview(preview)
                    if let prProximityText = presentation.prProximityText {
                        prProximity(prProximityText)
                    }
                    if let guidance = presentation.loadGuidance {
                        loadGuidance(guidance)
                    }
                }
                .padding(Space.lg)
                .contentCard(bright: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this workout template")
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                Text(presentation.templateName)
                    .font(usesAccessibilityLayout ? Typography.title : Typography.display)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(usesAccessibilityLayout ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: Space.sm)

                Image(systemName: "chevron.right")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
            }

            Text(presentation.metadata)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.muscleSummary)
                .panelLegend()
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(
                    Surface.cardTintBright,
                    in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                )
        }
    }

    private func exercisePreview(_ preview: TodayUpNextPresentation.Preview) -> some View {
        VStack(spacing: Space.md) {
            ForEach(Array(preview.rows.enumerated()), id: \.element.id) { index, row in
                TodayUpNextExerciseRow(
                    row: row,
                    index: index + 1,
                    usesAccessibilityLayout: usesAccessibilityLayout
                )
            }
            if preview.remainingCount > 0 {
                Text("+\(preview.remainingCount) more")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, usesAccessibilityLayout ? 0 : 36)
            }
        }
    }

    private func prProximity(_ text: String) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "trophy.fill")
                .font(Typography.caption)
                .foregroundStyle(Tint.primary)
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(Tint.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityLabel(text)
    }

    private func loadGuidance(_ guidance: TodayUpNextPresentation.LoadGuidance) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(Typography.caption)
                .foregroundStyle(Tint.primary)
                .accessibilityHidden(true)
            Text(guidance.text)
                .font(Typography.caption)
                .foregroundStyle(Tint.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityLabel(guidance.accessibilityLabel)
    }
}

private struct TodayUpNextExerciseRow: View {
    let row: TodayUpNextPresentation.ExerciseRow
    let index: Int
    let usesAccessibilityLayout: Bool

    var body: some View {
        let layout = usesAccessibilityLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Space.sm))
        layout {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text("\(index)")
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.secondary)
                    .frame(width: 24, height: 24)
                    .background(Surface.cardTintBright, in: Circle())

                Text(row.name)
                    .font(Typography.headline)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !usesAccessibilityLayout {
                Spacer(minLength: Space.sm)
            }

            schemeReadout
                .padding(.leading, usesAccessibilityLayout ? 36 : 0)
        }
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private var schemeReadout: some View {
        let layout = usesAccessibilityLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.sm))
        return layout {
            Text(row.scheme.count)
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            if let load = row.scheme.load {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(load)
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    if let loadUnit = row.scheme.loadUnit {
                        Text(loadUnit)
                            .font(Typography.metricMicro)
                            .foregroundStyle(Ink.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
