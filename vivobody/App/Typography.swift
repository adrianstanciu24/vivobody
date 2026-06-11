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
    // The scale is six roles. If a new site needs a size that isn't
    // here, the answer is almost always one of these — not a new one.

    /// Hero metric — the single dominant number on a screen/card.
    /// Rounded gives the digits a confident, friendly silhouette.
    /// Apply `.monospacedDigit()` at the site so it never jitters.
    static let metricHero = Font.system(size: 56, weight: .bold, design: .rounded)

    /// Secondary big number — stat-strip values (workouts / sets /
    /// volume). Same rounded family as the hero, one step down.
    static let statValue = Font.system(size: 28, weight: .bold, design: .rounded)

    /// Card / row title — the name of a thing (exercise, template,
    /// session). The largest non-numeric role.
    static let title = Font.system(size: 20, weight: .semibold)

    /// Inline body text — descriptions, supporting copy, list values.
    static let body = Font.system(size: 16, weight: .regular)

    /// Small sentence-case label. Replaces every legacy
    /// "ALL-CAPS · TRACKED" mono label. Section headers, stat labels.
    static let sectionLabel = Font.system(size: 13, weight: .medium)

    /// Slightly bigger sentence-case label for empty-state headings
    /// and foregrounded card titles where `title` is too large.
    static let sectionHeading = Font.system(size: 15, weight: .semibold)

    /// Smallest copy — chip subtitles, sub-captions, metadata.
    static let caption = Font.system(size: 12, weight: .medium)

    /// Unit suffix sized to sit next to a number. Monospaced is
    /// reserved for digits/units so they don't shift horizontally as
    /// the value before them changes width.
    static let metricUnit = Font.system(size: 13, weight: .medium, design: .monospaced)
}

extension View {
    /// Convenience for the "small dim sentence-case label" pattern
    /// that replaces all the tracked-uppercase labels. Sentence case,
    /// no tracking, tertiary ink by default.
    func sectionLabelStyle(_ opacity: Double = 0.45) -> some View {
        self
            .font(Typography.sectionLabel)
            .foregroundStyle(Ink.primary.opacity(opacity))
            .textCase(nil)
            .tracking(0)
    }

    /// Sentence-case heading style for empty states and card
    /// titles.
    func sectionHeadingStyle(_ opacity: Double = 0.85) -> some View {
        self
            .font(Typography.sectionHeading)
            .foregroundStyle(Ink.primary.opacity(opacity))
            .textCase(nil)
            .tracking(0)
    }
}
