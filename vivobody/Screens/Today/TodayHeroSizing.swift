//
//  TodayHeroSizing.swift
//  vivobody
//
//  The height of Today's trained-body figure. It latches the scroll container
//  that holds the figure, so transient layout passes do not re-scale the
//  model, and caps the height so the turntable fits a narrow pane. In the
//  wide body pane the figure takes the height left above the measured bar.
//

import CoreGraphics

struct TodayHeroSizing {
    /// One reading of the scroll container that holds the figure.
    nonisolated struct Container: Equatable {
        var size: CGSize
        /// The container's top safe-area inset. Zero means the reading
        /// ignores the title above the container.
        var topInset: CGFloat = 0
    }

    /// The width the latched height belongs to.
    private(set) var containerWidth: CGFloat = 0
    /// The largest container height plus top inset seen at `containerWidth`.
    private var largestReach: CGFloat = 0
    /// The largest top inset seen at `containerWidth`.
    private var largestTopInset: CGFloat = 0
    /// The last size of the pinned bar inside the container. Only the wide
    /// body pane reports it.
    private var pinnedBar: CGSize = .zero

    /// The latched container height the figure is sized from.
    var containerHeight: CGFloat {
        largestReach - largestTopInset
    }

    /// Keeps the largest container seen at one width. Native bottom chrome can
    /// report a transient, collapsed height during launch; tracking the
    /// maximum ignores it. A new width is a new container (a rotation, a fold,
    /// or the other Today layout), so its first reading replaces the old one
    /// instead of carrying a taller display's figure into it.
    ///
    /// A collapsing large title moves its height from the top inset into the
    /// container. A reading that includes the inset therefore keeps the figure
    /// at its expanded-title size; one without it lets the figure grow with
    /// the container.
    mutating func accept(_ container: Container) {
        let size = container.size
        let topInset = container.topInset
        guard size.width.isFinite, size.height.isFinite, topInset.isFinite,
              size.width > 0, size.height > 0, topInset >= 0
        else { return }
        let reach = size.height + topInset
        if size.width != containerWidth {
            containerWidth = size.width
            largestReach = reach
            largestTopInset = topInset
        } else {
            largestReach = max(largestReach, reach)
            largestTopInset = max(largestTopInset, topInset)
        }
    }

    /// Keeps the last bar reading, not the largest: the Resume bar's status
    /// line makes it taller than the Start bar, and the figure must clear the
    /// bar on screen. The bar spans its container, so a container of another
    /// width, such as the single column after a fold, ignores the reading.
    mutating func acceptPinnedBar(_ size: CGSize) {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0
        else { return }
        pinnedBar = size
    }

    /// Zero until the container reports a size. With a measured bar, normal
    /// text sizes fill the height left above the bar and the legend. Without
    /// one, they leave a fixed room for both. Accessibility sizes keep the
    /// figure to half the container so the text arrives sooner, and never
    /// past the height left above a measured bar.
    func heroHeight(accessibility: Bool) -> CGFloat {
        guard containerHeight > 0 else { return 0 }
        let height = switch (accessibility, heightAbovePinnedBar) {
        case let (true, aboveBar?):
            min(containerHeight * 0.5, 420, aboveBar)
        case (true, nil):
            min(containerHeight * 0.5, 420)
        case let (false, aboveBar?):
            aboveBar
        case (false, nil):
            max(
                containerHeight * Self.minimumHeroFraction,
                containerHeight * Self.heroFraction
                    - Self.pinnedStartBarClearance
                    - Self.developmentLegendClearance
            )
        }
        return max(0, min(height, containerWidth / StagedBodyModel.stageWidthRatio))
    }

    private var heightAbovePinnedBar: CGFloat? {
        guard pinnedBar.width == containerWidth else { return nil }
        return containerHeight - pinnedBar.height - Self.paneLegendClearance
    }

    private static let heroFraction: CGFloat = 0.98
    private static let minimumHeroFraction: CGFloat = 0.68
    private static let developmentLegendClearance: CGFloat = 88
    private static let pinnedStartBarClearance: CGFloat = 104
    /// The body pane's 4pt top padding, the 32pt section spacing, and the
    /// legend at its tallest, 96pt, where its Dynamic Type limit stops it.
    private static let paneLegendClearance: CGFloat = 132
}
