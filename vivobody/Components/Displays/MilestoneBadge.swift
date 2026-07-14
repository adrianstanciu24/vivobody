//
//  MilestoneBadge.swift
//  vivobody
//
//  One lifetime-progress tile for the Me tab's Milestones row. Leads
//  with the standing value as a big monospaced numeral against the
//  next threshold ("84 / 100"), under a silkscreened category legend,
//  over a thin track matching that exact ratio. The category
//  glyph sits inside the top-trailing header margin. A cleared category
//  wears the accent and a glowing seal; a near-done tile's numeral
//  warms up. Same resting-surface vocabulary as every other content
//  chip — the glass stays on the floating controls layer.
//

import VivoKit
import SwiftUI

struct MilestoneBadge: View {
    let milestone: Milestone

    /// Accent warm-up threshold — close enough that "almost there"
    /// should read from across the room.
    private var nearDone: Bool {
        !milestone.achieved && milestone.targetProgress >= 0.85
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Text(milestone.legend)
                    .panelLegendType()
                    .foregroundStyle(milestone.achieved ? Tint.primary : Ink.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: Space.sm)
                Image(systemName: milestone.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(milestone.achieved ? Tint.primary : Ink.tertiary)
                if milestone.achieved {
                    Image(systemName: "checkmark.seal.fill")
                        .font(Typography.caption)
                        .foregroundStyle(Tint.primary)
                        .shadow(color: Tint.primary.opacity(0.55), radius: 5)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text(milestone.valueLabel)
                    .font(Typography.statValue)
                    .foregroundStyle(nearDone ? Tint.primary : Ink.primary)
                if let target = milestone.targetLabel {
                    Text("/ \(target)")
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            MilestoneProgressTrack(
                progress: milestone.targetProgress,
                warm: nearDone || milestone.achieved
            )
        }
        .padding(Space.md)
        // Fixed width: the progress track fills the tile edge-to-edge, so
        // every tile in the rail shares one rhythm regardless of how
        // large its next threshold is.
        .frame(width: 170, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .contentChip(cornerRadius: Radius.chip, tint: milestone.achieved ? Tint.primary : nil)
        .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if milestone.achieved {
            return "\(milestone.legend), all milestones reached, \(milestone.valueLabel)"
        }
        if let target = milestone.targetLabel {
            return "\(milestone.legend), \(milestone.valueLabel) of \(target)"
        }
        return "\(milestone.legend), \(milestone.valueLabel)"
    }
}

// MARK: - Progress track

/// One continuous gauge matching the visible current/target ratio.
/// There are no hidden lifetime tiers or category-specific segments.
struct MilestoneProgressTrack: View {
    let progress: Double
    var warm: Bool = false

    private let trackHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Ink.quaternary.opacity(0.5))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Tint.primary)
                    .frame(
                        width: geo.size.width * min(1, max(0, progress)),
                        height: trackHeight
                    )
                    .shadow(color: warm ? Tint.primary.opacity(0.35) : .clear, radius: 3)
            }
        }
        .frame(height: trackHeight)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Space.sm) {
        MilestoneBadge(milestone: Milestone(
            icon: "flame.fill", legend: "Workouts",
            valueLabel: "84", targetLabel: "100",
            targetProgress: 0.84, achieved: false
        ))
        MilestoneBadge(milestone: Milestone(
            icon: "trophy.fill", legend: "PRs",
            valueLabel: "112", targetLabel: nil,
            targetProgress: 1, achieved: true
        ))
    }
    .fixedSize(horizontal: true, vertical: true)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Surface.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
