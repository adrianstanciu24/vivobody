//
//  DashboardLanes.swift
//  vivobody
//
//  The two side-by-side lanes a wide dashboard places its cards in, kept
//  clear of the display's fold. Insights, Me, and the active workout share
//  this one geometry.
//

import SwiftUI
import VivoKit

nonisolated enum DashboardLane: Hashable {
    case leading
    case trailing
}

/// The horizontal extents of the two card lanes, in the viewport's
/// coordinates.
nonisolated struct DashboardLanes: Equatable {
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

    func extent(of lane: DashboardLane) -> ClosedRange<CGFloat> {
        switch lane {
        case .leading: leading
        case .trailing: trailing
        }
    }

    func width(of lane: DashboardLane) -> CGFloat {
        let extent = extent(of: lane)
        return extent.upperBound - extent.lowerBound
    }

    /// The space between the two lanes, including any fold.
    var separation: CGFloat {
        trailing.lowerBound - leading.upperBound
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

extension View {
    /// Places this view across \`extent\` of the container's width. Without an
    /// extent, the view centers across the whole width. Both cases keep one
    /// view identity, so a lane change does not rebuild the view.
    func horizontallyPlaced(in extent: ClosedRange<CGFloat>?) -> some View {
        frame(width: extent.map { $0.upperBound - $0.lowerBound })
            .padding(.leading, extent?.lowerBound ?? 0)
            .frame(maxWidth: .infinity, alignment: extent == nil ? .center : .leading)
    }
}
