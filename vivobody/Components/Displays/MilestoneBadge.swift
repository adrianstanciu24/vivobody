//
//  MilestoneBadge.swift
//  vivobody
//
//  One lifetime-progress tile for the Me tab's Milestones row. A goal
//  you're climbing toward shows a partial fill and a "84 / 100"
//  readout; a cleared category wears the accent, a seal, and
//  "Reached". Same resting-surface vocabulary as every other content
//  chip — the glass stays on the floating controls layer.
//

import SwiftUI

struct MilestoneBadge: View {
    let milestone: Milestone

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Image(systemName: milestone.icon)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(milestone.achieved ? Tint.primary : Ink.tertiary)
                Spacer()
                if milestone.achieved {
                    Image(systemName: "checkmark.seal.fill")
                        .font(Typography.caption)
                        .foregroundStyle(Tint.primary)
                }
            }

            Text(milestone.title)
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            ShareBar(
                fraction: milestone.progress,
                tint: milestone.achieved ? Tint.primary : Ink.secondary
            )

            Text(milestone.valueText)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(Space.md)
        .frame(width: 150, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .contentChip(cornerRadius: 16, tint: milestone.achieved ? Tint.primary : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(milestone.title), \(milestone.achieved ? "reached" : milestone.valueText)")
    }
}

#Preview {
    HStack(spacing: Space.sm) {
        MilestoneBadge(milestone: Milestone(
            icon: "flame.fill", title: "100 workouts",
            valueText: "84 / 100", progress: 0.84, achieved: false
        ))
        MilestoneBadge(milestone: Milestone(
            icon: "trophy.fill", title: "10 PRs",
            valueText: "Reached", progress: 1, achieved: true
        ))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Surface.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
