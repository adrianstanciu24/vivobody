//
//  InsightsCardLayout.swift
//  vivobody
//
//  The wide Insights composition: one vertical scroll whose cards alternate
//  between a leading and a trailing lane by reading order, with both lanes
//  kept clear of the display's fold.
//

import SwiftUI
import VivoKit

/// The horizontal extents of the two card lanes, in the viewport's
/// coordinates.
nonisolated struct InsightsLanes: Equatable {
    let leading: ClosedRange<CGFloat>
    let trailing: ClosedRange<CGFloat>

    /// Lanes inside `width` with a gutter at each outer edge. A vertical
    /// division (the fold) keeps a gutter on each side of it; without one,
    /// the lanes split the width evenly with `spacing` between them. A
    /// division that would leave a lane without width is ignored.
    init(
        width: CGFloat,
        divisions: [CGRect],
        gutter: CGFloat = Space.gutter,
        spacing: CGFloat = Space.section
    ) {
        let usable = gutter ... max(gutter, width - gutter)
        if let fold = Self.fold(in: divisions, across: usable),
           fold.lowerBound - gutter > usable.lowerBound,
           fold.upperBound + gutter < usable.upperBound
        {
            leading = usable.lowerBound ... fold.lowerBound - gutter
            trailing = fold.upperBound + gutter ... usable.upperBound
        } else {
            let laneWidth = max(0, (usable.upperBound - usable.lowerBound - spacing) / 2)
            leading = usable.lowerBound ... usable.lowerBound + laneWidth
            trailing = usable.upperBound - laneWidth ... usable.upperBound
        }
    }

    /// Even reading-order positions take the leading lane.
    func lane(for index: Int) -> ClosedRange<CGFloat> {
        index.isMultiple(of: 2) ? leading : trailing
    }

    /// The x-extent covering every vertical division that crosses the
    /// usable width. A horizontal division does not split side-by-side lanes.
    private static func fold(
        in divisions: [CGRect],
        across usable: ClosedRange<CGFloat>
    ) -> ClosedRange<CGFloat>? {
        let crossing = divisions.filter {
            $0.height > $0.width && $0.maxX > usable.lowerBound && $0.minX < usable.upperBound
        }
        guard let minX = crossing.map(\.minX).min(),
              let maxX = crossing.map(\.maxX).max()
        else { return nil }
        return minX ... maxX
    }
}

/// Where each card goes. Reading-order parity picks the lane, and each lane
/// stacks its own cards from the top, so a tall card never moves a later
/// card into the other lane.
nonisolated struct InsightsCardPlan: Equatable {
    /// One frame per card, in reading order.
    let frames: [CGRect]
    let height: CGFloat

    init(heights: [CGFloat], lanes: InsightsLanes, spacing: CGFloat) {
        var nextY: [CGFloat] = [0, 0]
        frames = heights.enumerated().map { index, height in
            let lane = lanes.lane(for: index)
            let frame = CGRect(
                x: lane.lowerBound,
                y: nextY[index % 2],
                width: lane.upperBound - lane.lowerBound,
                height: height
            )
            nextY[index % 2] += height + spacing
            return frame
        }
        height = frames.map(\.maxY).max() ?? 0
    }
}

struct InsightsAlternatingLayout: Layout {
    let lanes: InsightsLanes
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
        let heights = subviews.indices.map { index in
            let lane = lanes.lane(for: index)
            return subviews[index].sizeThatFits(
                ProposedViewSize(width: lane.upperBound - lane.lowerBound, height: nil)
            ).height
        }
        return InsightsCardPlan(heights: heights, lanes: lanes, spacing: spacing)
    }
}

/// Every card in one scroll, in two lanes on either side of the fold.
@available(iOS 27.1, *)
struct InsightsCardLanes: View {
    let reports: SessionAnalytics.InsightsReports

    var body: some View {
        // Read outside the scroll: the fold stays put while the cards move.
        GeometryReader { viewport in
            let lanes = InsightsLanes(
                width: viewport.size.width,
                divisions: viewport.reservedRegions(kind: .division).map(\.frame)
            )
            ScrollView(.vertical) {
                InsightsAlternatingLayout(lanes: lanes, spacing: Space.section) {
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
