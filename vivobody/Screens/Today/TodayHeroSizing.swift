//
//  TodayHeroSizing.swift
//  vivobody
//
//  The height of Today's trained-body figure. It latches the scroll container
//  that holds the figure, so transient layout passes do not re-scale the
//  model, and caps the height so the turntable fits a narrow pane.
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

    /// Zero until the container reports a size. Normal text sizes leave room
    /// for the pinned start bar and the development legend; accessibility
    /// sizes keep the figure to half the container so the text arrives sooner.
    func heroHeight(accessibility: Bool) -> CGFloat {
        guard containerHeight > 0 else { return 0 }
        let height = if accessibility {
            min(containerHeight * 0.5, 420)
        } else {
            max(
                containerHeight * Self.minimumHeroFraction,
                containerHeight * Self.heroFraction
                    - Self.pinnedStartBarClearance
                    - Self.developmentLegendClearance
            )
        }
        return min(height, containerWidth / StagedBodyModel.stageWidthRatio)
    }

    private static let heroFraction: CGFloat = 0.98
    private static let minimumHeroFraction: CGFloat = 0.68
    private static let developmentLegendClearance: CGFloat = 88
    private static let pinnedStartBarClearance: CGFloat = 104
}
