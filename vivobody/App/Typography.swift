//
//  Typography.swift
//  vivobody
//
//  Centralised text roles. Replaces the dozens of ad-hoc
//  `.font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(2)`
//  sites scattered across the app.
//
//  Principle: monospaced is reserved for *digits* and unit suffixes
//  (where it helps numeric alignment). Labels use the system text
//  face in sentence case.
//

import SwiftUI

enum Typography {
    /// Sentence-case section header. Use in place of the legacy
    /// "ALL-CAPS · TRACKED" mono labels.
    static let sectionLabel = Font.system(size: 13, weight: .medium)

    /// Slightly bigger sentence-case label for empty states and
    /// foregrounded card titles.
    static let sectionHeading = Font.system(size: 15, weight: .semibold)

    /// Hero metric — used as the dominant number on a card. Rounded
    /// design gives the digits a friendlier silhouette than the
    /// default system face.
    static let metricHero = Font.system(size: 56, weight: .bold, design: .rounded)

    /// Big metric used for stat rows in cards (workouts / sets /
    /// volume on the Me screen, time / volume / sets in Today's
    /// last-workout card).
    static let statValue = Font.system(size: 26, weight: .bold, design: .rounded)

    /// Unit suffix sized to sit next to `metricHero` / `statValue`.
    /// Monospaced so units don't shift horizontally as the digit
    /// before them changes width.
    static let metricUnit = Font.system(size: 13, weight: .medium, design: .monospaced)

    /// Inline body text — sets descriptions, captions, supporting
    /// copy on cards.
    static let body = Font.system(size: 15, weight: .regular)

    /// Smaller secondary copy — chip subtitles, sub-captions.
    static let caption = Font.system(size: 12, weight: .medium)
}

extension View {
    /// Convenience for the "small dim sentence-case label" pattern
    /// that replaces all the tracked-uppercase labels. Equivalent to
    /// applying `Typography.sectionLabel` + 55% white foreground.
    func sectionLabelStyle(_ opacity: Double = 0.55) -> some View {
        self
            .font(Typography.sectionLabel)
            .foregroundStyle(.white.opacity(opacity))
            .textCase(nil)
            .tracking(0)
    }

    /// Sentence-case heading style for empty states and card
    /// titles.
    func sectionHeadingStyle(_ opacity: Double = 0.85) -> some View {
        self
            .font(Typography.sectionHeading)
            .foregroundStyle(.white.opacity(opacity))
            .textCase(nil)
            .tracking(0)
    }
}
