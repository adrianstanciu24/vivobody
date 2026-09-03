//
//  MeJourneySection.swift
//  vivobody
//
//  Me dashboard journey hero and empty state, rendered entirely from the
//  immutable presentation snapshot.
//

import SwiftUI
import VivoKit

struct MeJourneySection: View {
    let presentation: MePresentation.Journey

    var body: some View {
        switch presentation {
        case let .empty(empty):
            VStack(alignment: .leading, spacing: Space.lg) {
                SectionHeader(title: "Your journey")
                ContentUnavailableView(
                    empty.title,
                    systemImage: empty.systemImage,
                    description: Text(empty.detail)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case let .populated(hero):
            journeyHero(hero)
        }
    }

    private func journeyHero(
        _ hero: MePresentation.JourneyHero
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your journey")
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary.opacity(Opacity.strong))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Space.sm)
                Text("All time")
                    .panelLegend()
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                CarvedVolumeText(
                    value: hero.volume.value,
                    unit: hero.volume.unit ?? "",
                    size: 56
                )
                Text(hero.volume.label)
                    .panelLegend()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(hero.volume.accessibilityLabel)

            Text(lifetimeSummary(hero.lifetimeMetrics))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityLabel(hero.lifetimeAccessibilityLabel)

            if let ageText = hero.trainingAgeText {
                MeJourneyTimeline(caption: ageText)
            }
        }
        .padding(Space.lg)
        .contentCard()
    }

    private func lifetimeSummary(
        _ metrics: [MePresentation.Metric]
    ) -> AttributedString {
        var result = AttributedString()
        for (index, metric) in metrics.enumerated() {
            if index > 0 {
                var separator = AttributedString("   ·   ")
                separator.foregroundColor = Ink.quaternary
                result += separator
            }
            var value = AttributedString(metric.value)
            value.font = Typography.sectionHeading
            value.foregroundColor = metric.accent ? Tint.primary : Ink.primary
            result += value

            var label = AttributedString(" " + metric.label)
            label.font = Typography.body
            label.foregroundColor = Ink.tertiary
            result += label
        }
        return result
    }
}

/// A qualitative start-to-now rail. It gives the lifetime caption a physical
/// origin and live endpoint without pretending training age is goal progress.
private struct MeJourneyTimeline: View {
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: 0) {
                Circle()
                    .fill(Ink.quaternary)
                    .frame(width: 6, height: 6)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Ink.quaternary, Tint.primary.opacity(0.86)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                Circle()
                    .fill(Tint.primary)
                    .frame(width: 7, height: 7)
                    .shadow(color: Tint.primary.opacity(0.42), radius: 4)
            }

            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: Space.sm)
                Text("Today")
                    .panelLegend()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
    }
}
