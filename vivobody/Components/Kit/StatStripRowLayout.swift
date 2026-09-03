//
//  StatStripRowLayout.swift
//  vivobody
//
//  Allocates optional proportional columns for ScreenKit stat strips while
//  preserving their intrinsic height and centered metric presentation.
//

import SwiftUI

struct StatStripRowLayout: Layout {
    let weights: [CGFloat]

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let width = proposal.width ?? subviews.reduce(0) {
            $0 + $1.sizeThatFits(.unspecified).width
        }
        let total = weights.reduce(0, +)
        let height = subviews.enumerated().reduce(CGFloat.zero) { currentHeight, item in
            let cellWidth = width * weights[item.offset] / total
            let size = item.element.sizeThatFits(.init(width: cellWidth, height: proposal.height))
            return max(currentHeight, size.height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let total = weights.reduce(0, +)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = bounds.width * weights[index] / total
            subview.place(
                at: CGPoint(x: x + width / 2, y: bounds.midY),
                anchor: .center,
                proposal: .init(width: width, height: bounds.height)
            )
            x += width
        }
    }
}
