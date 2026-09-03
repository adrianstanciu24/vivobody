//
//  MeBodyWeightSection.swift
//  vivobody
//
//  Body-weight empty and populated presentation for Me. The shell owns the
//  log sheet and detail destination and injects those actions as explicit UI.
//

import SwiftUI
import VivoKit

struct MeBodyWeightSection<PopulatedContent: View>: View {
    let presentation: MePresentation.BodyWeight
    let onLogWeight: () -> Void
    @ViewBuilder let populatedContent: (MePresentation.BodyWeightSummary) -> PopulatedContent

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(
                title: "Body weight",
                trailing: presentation.trailingLabel
            )

            switch presentation {
            case let .empty(empty):
                MeBodyWeightEmptyCard(
                    presentation: empty,
                    action: onLogWeight
                )
            case let .populated(summary):
                populatedContent(summary)
            }
        }
    }
}

private struct MeBodyWeightEmptyCard: View {
    let presentation: MePresentation.EmptyBodyWeight
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text(presentation.detail)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
            Button(action: action) {
                Text(presentation.actionLabel)
            }
            .buttonStyle(PrimaryButtonStyle(compact: true))
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }
}

struct MeBodyWeightPopulatedCard: View {
    let presentation: MePresentation.BodyWeightSummary

    var body: some View {
        HStack(alignment: .center, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .lastTextBaseline, spacing: Space.xs) {
                    Text(presentation.value)
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.primary)
                        .monospacedDigit()
                    Text(presentation.unit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
                if let delta = presentation.delta {
                    HStack(spacing: Space.xs) {
                        Image(
                            systemName: delta.isIncrease
                                ? "arrow.up.right"
                                : "arrow.down.right"
                        )
                        .font(Typography.micro)
                        .accessibilityHidden(true)
                        Text(delta.label)
                            .font(Typography.caption)
                    }
                    .foregroundStyle(Ink.secondary)
                } else if let firstEntryLabel = presentation.firstEntryLabel {
                    Text(firstEntryLabel)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
            }

            Spacer(minLength: Space.sm)

            if presentation.sparkValues.count >= 2 {
                MiniChart(
                    values: presentation.sparkValues,
                    lineColor: Tint.inProgress,
                    fillColor: Tint.inProgress,
                    accessibilityLabel: "Body weight trend"
                )
                .frame(width: 96, height: 36)
            }

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: Space.rowMin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .contentCard(bright: true)
        .contentShape(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}
