//
//  InsightsCardLayout.swift
//  vivobody
//
//  The wide Insights composition: one vertical scroll whose cards sit in a
//  leading and a trailing lane, with both lanes kept clear of the display's
//  fold.
//

import SwiftUI
import VivoKit

/// Where each card goes. Each card names its lane, and each lane stacks its
/// own cards from the top, so a tall card never moves a later card into the
/// other lane.
nonisolated struct InsightsCardPlan: Equatable {
    /// One frame per card, in reading order.
    let frames: [CGRect]
    let height: CGFloat

    init(heights: [CGFloat], assignments: [DashboardLane], lanes: DashboardLanes, spacing: CGFloat) {
        var nextY: [DashboardLane: CGFloat] = [.leading: 0, .trailing: 0]
        frames = zip(heights, assignments).map { height, assignment in
            let lane = lanes.extent(of: assignment)
            let y = nextY[assignment, default: 0]
            nextY[assignment] = y + height + spacing
            return CGRect(
                x: lane.lowerBound,
                y: y,
                width: lane.upperBound - lane.lowerBound,
                height: height
            )
        }
        height = frames.map(\.maxY).max() ?? 0
    }
}

struct InsightsLaneLayout: Layout {
    let lanes: DashboardLanes
    /// One lane per subview, in reading order.
    let assignments: [DashboardLane]
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        CGSize(
            width: proposal.width ?? lanes.trailing.upperBound,
            height: plan(for: subviews).height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        for (subview, frame) in zip(subviews, plan(for: subviews).frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func plan(for subviews: Subviews) -> InsightsCardPlan {
        let heights = zip(subviews, assignments).map { subview, assignment in
            subview.sizeThatFits(
                ProposedViewSize(width: lanes.width(of: assignment), height: nil)
            ).height
        }
        return InsightsCardPlan(heights: heights, assignments: assignments, lanes: lanes, spacing: spacing)
    }
}

/// Every card in one scroll, in two lanes on either side of the fold.
@available(iOS 27.1, *)
struct InsightsCardLanes: View {
    let reports: SessionAnalytics.InsightsReports

    var body: some View {
        // Read outside the scroll: the fold stays put while the cards move.
        GeometryReader { viewport in
            let lanes = DashboardLanes(
                width: viewport.size.width,
                divisions: viewport.reservedRegions(kind: .division).map(\.frame)
            )
            ScrollView(.vertical) {
                InsightsLaneLayout(
                    lanes: lanes,
                    assignments: InsightsCardID.allCases.map(\.wideLane),
                    spacing: Space.section
                ) {
                    ForEach(Array(InsightsCardID.allCases.enumerated()), id: \.element) { index, id in
                        InsightsCard(id: id, reports: reports)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("insightsCard-\(id.rawValue)")
                            // VoiceOver would otherwise read across the lanes
                            // by position; this keeps the reading order.
                            .accessibilitySortPriority(Double(InsightsCardID.allCases.count - index))
                    }
                }
                .padding(.top, Space.lg)
                .padding(.bottom, Space.xxl)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .accessibilityIdentifier("insightsScroll")
        }
    }
}
