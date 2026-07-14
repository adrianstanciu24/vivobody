#if DEBUG
//
//  MilestoneBadgeGallery.swift
//  vivobody
//
//  Every MilestoneBadge state side by side: fresh start, mid-climb,
//  near-done (accent warm-up), and fully cleared. The scrubber drives
//  one live tile through its targets so the progress track, warm-up
//  threshold, and numeral hierarchy can be tuned by eye.
//

import VivoKit
import SwiftUI

struct MilestoneBadgeGallery: View {
    @State private var value: Double = 84

    private static let thresholds = [10, 50, 100, 250, 500, 1000]

    private var liveMilestone: Milestone {
        let v = Int(value)
        if let next = Self.thresholds.first(where: { v < $0 }) {
            return Milestone(
                icon: "flame.fill", legend: "Workouts",
                valueLabel: "\(v)", targetLabel: "\(next)",
                targetProgress: Double(v) / Double(next),
                achieved: false
            )
        }
        return Milestone(
            icon: "flame.fill", legend: "Workouts",
            valueLabel: "\(v)", targetLabel: nil,
            targetProgress: 1,
            achieved: true
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("States").panelLegend()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.sm) {
                            MilestoneBadge(milestone: Milestone(
                                icon: "flame.fill", legend: "Workouts",
                                valueLabel: "3", targetLabel: "10",
                                targetProgress: 0.3, achieved: false
                            ))
                            MilestoneBadge(milestone: Milestone(
                                icon: "scalemass.fill", legend: "Volume",
                                valueLabel: "39.8k", targetLabel: "45.4k kg",
                                targetProgress: 0.88, achieved: false
                            ))
                            MilestoneBadge(milestone: Milestone(
                                icon: "calendar", legend: "Week streak",
                                valueLabel: "9", targetLabel: "12",
                                targetProgress: 0.75, achieved: false
                            ))
                            MilestoneBadge(milestone: Milestone(
                                icon: "trophy.fill", legend: "PRs",
                                valueLabel: "112", targetLabel: nil,
                                targetProgress: 1, achieved: true
                            ))
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Scrub the ladder").panelLegend()
                    MilestoneBadge(milestone: liveMilestone)
                        .fixedSize(horizontal: false, vertical: true)
                    Slider(value: $value, in: 0...1100, step: 1)
                        .tint(Tint.primary)
                    Text("\(Int(value)) workouts")
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .padding(Space.gutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Surface.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MilestoneBadgeGallery()
}
#endif
