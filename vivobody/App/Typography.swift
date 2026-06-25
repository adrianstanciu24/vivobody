//
//  Typography.swift
//  vivobody
//
//  Centralised text roles. Replaces the dozens of ad-hoc
//  `.font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(2)`
//  sites scattered across the app.
//
//  Two families, no exceptions:
//    • NUMERIC — always monospaced. Stats, metrics, units and digits
//      line up vertically and never jitter as their values change
//      width. Seven sizes, one family.
//    • TEXT — system default. Titles, labels, body and captions in
//      sentence case. Eight sizes.
//
//  If a site needs a size that isn't here, the answer is almost
//  always one of these — not a new one. Pick the nearest role.
//

import SwiftUI

enum Typography {

    // MARK: - Numeric (monospaced)
    //
    // Reserved for digits, stat values, metrics and unit suffixes.
    // Monospaced keeps columns of numbers aligned and stops a value
    // shifting horizontally as its digit-widths change. Apply
    // `.monospacedDigit()` at the site for live-updating numbers.

    /// The single celebratory giant number — PR overlay, the live
    /// rep/weight hero on the active-exercise card.
    static let bigMetric = Font.system(size: 104, weight: .bold, design: .monospaced)

    /// Hero metric — the single dominant number on a screen/card
    /// (volume hero, current body weight).
    static let metricHero = Font.system(size: 56, weight: .bold, design: .monospaced)

    /// Secondary big number — set/rep counters, completion totals.
    static let metricLg = Font.system(size: 40, weight: .bold, design: .monospaced)

    /// Stat-strip value — the workouts / sets / volume numbers that
    /// sit in a row of stats.
    static let statValue = Font.system(size: 28, weight: .bold, design: .monospaced)

    /// Inline numeric value — a number sitting within a row or set
    /// summary, smaller than a stat-strip hero.
    static let metricInline = Font.system(size: 16, weight: .semibold, design: .monospaced)

    /// Unit suffix and small numeric labels — sized to sit next to a
    /// number without competing with it.
    static let metricUnit = Font.system(size: 13, weight: .medium, design: .monospaced)

    /// Smallest numeric — axis ticks, sub-stats, the tiny mono labels
    /// that replace the legacy tracked-uppercase captions.
    static let metricMicro = Font.system(size: 11, weight: .medium, design: .monospaced)

    // MARK: - Text (system default)

    /// Largest non-numeric role — the name of the thing in focus
    /// (exercise name on the active card / detail header).
    static let display = Font.system(size: 30, weight: .bold)

    /// Card / row title — the name of a thing (exercise, template,
    /// session). The everyday large text role.
    static let title = Font.system(size: 20, weight: .semibold)

    /// Emphasised body — primary button labels, list-row titles,
    /// foregrounded copy that needs more weight than `body`.
    static let headline = Font.system(size: 16, weight: .semibold)

    /// Inline body text — descriptions, supporting copy, list values.
    static let body = Font.system(size: 16, weight: .regular)

    /// Sentence-case heading for empty-state headings and
    /// foregrounded card titles where `title` is too large.
    static let sectionHeading = Font.system(size: 15, weight: .semibold)

    /// Small sentence-case label. Replaces every legacy
    /// "ALL-CAPS · TRACKED" mono label. Section headers, stat labels.
    static let sectionLabel = Font.system(size: 13, weight: .medium)

    /// Smallest copy — chip subtitles, sub-captions, metadata.
    static let caption = Font.system(size: 12, weight: .medium)

    /// Tiniest text — micro badges, dense overlays.
    static let micro = Font.system(size: 10, weight: .medium)
}

extension View {
    /// Convenience for the "small dim sentence-case label" pattern
    /// that replaces all the tracked-uppercase labels. Sentence case,
    /// no tracking, tertiary ink by default.
    func sectionLabelStyle(_ opacity: Double = Opacity.soft) -> some View {
        self
            .font(Typography.sectionLabel)
            .foregroundStyle(Ink.primary.opacity(opacity))
            .textCase(nil)
            .tracking(0)
    }

    /// Sentence-case heading style for empty states and card
    /// titles.
    func sectionHeadingStyle(_ opacity: Double = Opacity.strong) -> some View {
        self
            .font(Typography.sectionHeading)
            .foregroundStyle(Ink.primary.opacity(opacity))
            .textCase(nil)
            .tracking(0)
    }
}
