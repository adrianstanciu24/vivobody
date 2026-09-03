//
//  ExerciseBestHeroCard.swift
//  vivobody
//
//  Stateless standing-record card for Exercise Detail: a prominent
//  best-set value and an optional sessions / per-week / last-performed
//  footer. All archive-derived copy arrives preformatted from
//  ExerciseDetailReadModel.
//

import SwiftUI
import VivoKit

struct ExerciseBestHeroCard: View {
    let bestSet: ExerciseDetailReadModel.BestSet
    let frequency: ExerciseDetailReadModel.Frequency?

    /// The standing record gets a hero card with the huge monospaced
    /// numeral — the screen's one editorial moment.
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Best set")
                .sectionLabelStyle(Opacity.soft)

            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(bestSet.value)
                    .font(Typography.metricHero)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                if let unit = bestSet.unit {
                    Text(unit)
                        .font(Typography.statValueCompact)
                        .foregroundStyle(Ink.tertiary)
                }
                if let fragment = bestSet.detail {
                    Text(fragment)
                        .font(Typography.statValueCompact)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }

            Text(bestSet.dateText ?? " ")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)

            if let frequency {
                frequencyFooter(frequency)
            }
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard(bright: true)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Frequency footer

    /// Sessions · per week · last performed, split by hairlines. All
    /// three facts come from the cached history index and progress
    /// series; the footer hides entirely until the exercise has been
    /// logged once.
    private func frequencyFooter(
        _ frequency: ExerciseDetailReadModel.Frequency
    ) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Surface.edge)
                .frame(height: 0.5)
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                frequencyCell(
                    label: "SESSIONS",
                    value: frequency.sessionCountText,
                    accessibility: frequency.sessionsAccessibilityLabel
                )
                frequencyDivider
                frequencyCell(
                    label: "PER WEEK",
                    value: frequency.perWeekText,
                    accessibility: frequency.perWeekAccessibilityLabel
                )
                frequencyDivider
                frequencyCell(
                    label: "LAST",
                    value: frequency.lastDateText,
                    accessibility: frequency.lastDateAccessibilityLabel
                )
            }
            .padding(.top, Space.md)
        }
        .padding(.top, Space.xs)
    }

    private func frequencyCell(
        label: String,
        value: String,
        accessibility: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Typography.metricMicro)
                .foregroundStyle(Ink.quaternary)
            Text(value)
                .font(Typography.metricInline)
                .foregroundStyle(Ink.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }

    private var frequencyDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(width: 0.5, height: 26)
            .padding(.horizontal, Space.md)
            .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview("Exercise best set") {
        ExerciseBestHeroCard(
            bestSet: ExerciseDetailReadModel.BestSet(
                value: "225",
                unit: "lb",
                detail: "× 5",
                date: Date(timeIntervalSince1970: 0),
                dateText: "Today",
                accessibilityLabel: "Best set, 5 reps at 225 pounds, today"
            ),
            frequency: ExerciseDetailReadModel.Frequency(
                sessionCount: 12,
                sessionCountText: "12",
                sessionsAccessibilityLabel: "12 sessions",
                perWeek: 1.5,
                perWeekText: "1.5×",
                perWeekAccessibilityLabel: "1.5 per week",
                lastDate: Date(timeIntervalSince1970: 0),
                lastDateText: "Today",
                lastDateAccessibilityLabel: "Last today",
                accessibilityLabel: "12 sessions, 1.5 per week, last today"
            )
        )
        .padding(Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
#endif
