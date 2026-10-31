//
//  ActiveExerciseCardDensity.swift
//  vivobody
//
//  How tightly the phone column packs an exercise page. A short page, such
//  as the folded iPhone Duo display, cannot hold the standard column, so the
//  name takes one line, the gaps close, and the working value shrinks. The
//  page then fits without a scroll, and no content goes under the bars.
//

import SwiftUI
import VivoKit

nonisolated enum ActiveExerciseCardDensity: Equatable {
    case regular
    case compact

    /// The standard column needs about 590pt: a two-line name, the set
    /// timeline, the configuration, the working values, effort, and the
    /// completion action.
    static let compactBelowPageHeight: CGFloat = 600

    /// A zero height is a page before its first layout; it stays regular.
    init(pageHeight: CGFloat) {
        let isShort = pageHeight > 0 && pageHeight < Self.compactBelowPageHeight
        self = isShort ? .compact : .regular
    }

    var nameLineLimit: Int {
        self == .compact ? 1 : 2
    }

    var nameMinimumScaleFactor: CGFloat {
        self == .compact ? 0.6 : 0.82
    }

    /// The space above and below the configuration, values, and effort.
    var instrumentPadding: CGFloat {
        self == .compact ? Space.xs : Space.md
    }

    /// The space around the divider above effort.
    var effortDividerPadding: CGFloat {
        self == .compact ? Space.sm : Space.md
    }

    /// The working-value size for a regular-density size.
    func heroFontSize(_ regular: CGFloat) -> CGFloat {
        self == .compact ? (regular * 0.8).rounded() : regular
    }
}

extension EnvironmentValues {
    /// Set by ActiveExerciseCard for its instruments.
    @Entry var activeExerciseCardDensity: ActiveExerciseCardDensity = .regular
}
