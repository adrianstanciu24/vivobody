//
//  ExerciseDetailRecentSessionsSection.swift
//  vivobody
//
//  Focused Exercise Detail history ledger. It renders bounded immutable rows
//  prepared by ExerciseDetailReadModel and owns no archive query or record
//  selection logic.
//

import SwiftUI
import VivoKit

struct ExerciseDetailRecentSessionsSection: View {
    let rows: [ExerciseDetailReadModel.RecentSession]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Recent sessions")
                .sectionLabelStyle(Opacity.medium)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(Surface.edge)
                            .frame(height: 0.5)
                            .accessibilityHidden(true)
                    }
                    recentRow(row)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.xs)
            .contentCard()
        }
    }

    private func recentRow(
        _ row: ExerciseDetailReadModel.RecentSession
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.dateText)
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.secondary)
                    .minimumScaleFactor(0.7)
                Text(row.relativeDateText)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 110, alignment: .leading)

            Text(row.metric.display)
                .font(Typography.metricUnit)
                .foregroundStyle(row.isPersonalRecord ? Tint.complete : Ink.primary)
                .monospacedDigit()

            Spacer()

            Text(row.setCountText)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)

            if row.isPersonalRecord {
                Text("PR")
                    .font(Typography.metricMicro)
                    .foregroundStyle(Tint.onAccent)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Tint.complete))
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
