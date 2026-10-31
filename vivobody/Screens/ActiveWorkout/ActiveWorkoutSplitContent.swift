//
//  ActiveWorkoutSplitContent.swift
//  vivobody
//
//  The active workout on a wide window. Each page splits at the fold into
//  two lanes: identity and setup lead, the set itself trails. The lanes are
//  built in page coordinates, because SwipePager makes each page narrower
//  than the window and insets it by the neighbor peek.
//

import SwiftUI
import VivoKit

/// The two lanes of one workout page.
nonisolated struct ActiveWorkoutLanes: Equatable {
    /// The lanes in the page's coordinates.
    let page: DashboardLanes
    /// How far each page starts from the viewport's leading edge.
    let pageInset: CGFloat

    init(viewportWidth: CGFloat, divisions: [CGRect], pageInset: CGFloat) {
        self.pageInset = pageInset
        page = DashboardLanes(
            width: max(0, viewportWidth - 2 * pageInset),
            divisions: divisions.map { $0.offsetBy(dx: -pageInset, dy: 0) }
        )
    }

    /// The trailing lane in the viewport's coordinates, for content drawn
    /// outside the pager.
    var viewportTrailing: ClosedRange<CGFloat> {
        page.trailing.lowerBound + pageInset ... page.trailing.upperBound + pageInset
    }
}

extension ActiveWorkoutScreen {
    /// A sliver of neighbor peek plus the page dots is enough "there's more"
    /// cue: the width goes to the numerals.
    static let pagerPeekWidth: CGFloat = 10
    static let pagerSpacing: CGFloat = 8

    /// Lanes only in a window that splits dashboards. The fold is read
    /// outside the pager, so it stays put while the pages move.
    func lanes(in viewport: GeometryProxy) -> ActiveWorkoutLanes? {
        guard displayLayout.showsDashboardColumns, #available(iOS 27.1, *) else { return nil }
        return ActiveWorkoutLanes(
            viewportWidth: viewport.size.width,
            divisions: viewport.reservedRegions(kind: .division).map(\.frame),
            pageInset: Self.pagerPeekWidth + Self.pagerSpacing
        )
    }

    /// The top edge is far from the thumbs on a wide display, so the cover
    /// gets an explicit way back to the tabs besides its swipe-down.
    var minimizeButton: some View {
        Button {
            Haptics.soft()
            onMinimize?()
        } label: {
            Image(systemName: "chevron.down")
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .frame(width: 26, height: 26)
                .coloredGlassControl(cornerRadius: Radius.pill)
                .frame(width: Space.tapMin, height: Space.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Minimize workout")
        .accessibilityInputLabels([Text("Minimize workout"), Text("Minimize")])
        .accessibilityIdentifier("minimizeWorkoutButton")
    }
}

/// Clips the pager at its leading and trailing edges only. A window can keep
/// a horizontal safe area, such as the status bar column on the folded iPhone
/// Duo display, and the neighbor pages must not show through it. Shadows
/// still spill above and below.
nonisolated struct PagerSideClip: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: 0, dy: -rect.height))
    }
}

/// Two lane contents placed side by side in a page's lanes. With `scrolls`,
/// each lane scrolls alone, and its scroll view reaches into the gutters so
/// control shadows are not clipped at the lane edge. `fillsScrollHeight`
/// lets scrolling content push its last item to the bottom of the page.
struct WorkoutLaneSplit<Leading: View, Trailing: View>: View {
    let lanes: DashboardLanes
    let scrolls: Bool
    var fillsScrollHeight = false
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        let margin = max(0, min(Space.gutter, lanes.separation / 2, lanes.leading.lowerBound))
        GeometryReader { page in
            HStack(alignment: .top, spacing: lanes.separation - 2 * margin) {
                lane(leading, width: lanes.width(of: .leading), margin: margin, height: page.size.height)
                lane(trailing, width: lanes.width(of: .trailing), margin: margin, height: page.size.height)
            }
            .padding(.leading, lanes.leading.lowerBound - margin)
        }
    }

    @ViewBuilder
    private func lane(
        _ content: some View,
        width: CGFloat,
        margin: CGFloat,
        height: CGFloat
    ) -> some View {
        if scrolls {
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(width: width, alignment: .leading)
                    .frame(minHeight: fillsScrollHeight ? height : nil, alignment: .top)
            }
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .frame(width: width + 2 * margin, height: height)
        } else {
            content
                .frame(width: width, height: height, alignment: .top)
                .padding(.horizontal, margin)
        }
    }
}

#if DEBUG
    #Preview("Workout lanes") {
        let lanes = DashboardLanes(
            width: 831,
            divisions: [CGRect(x: 437, y: 0, width: 40, height: 600)]
        )
        WorkoutLaneSplit(lanes: lanes, scrolls: false) {
            Color.orange.opacity(0.3)
        } trailing: {
            Color.blue.opacity(0.3)
        }
        .frame(width: 831, height: 600)
        .background(Color.black)
    }
#endif
