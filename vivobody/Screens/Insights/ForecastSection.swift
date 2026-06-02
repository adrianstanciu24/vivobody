//
//  ForecastSection.swift
//  vivobody
//
//  The "if you stop now" view: which muscles would detrain first, and
//  how soon. A leaderboard of the most at-risk regions, each with a
//  bar showing development today (dim) against the level it would hold
//  at the horizon (solid) — the dim tail is what you'd lose. Reads as
//  an urgent nudge when something fades within the week, otherwise as
//  a calm "you're covered, here's the order it would unwind."
//

import SwiftUI

struct ForecastSection: View {
    let board: MuscleForecastBoard

    /// How many muscles the leaderboard shows before folding the rest
    /// into a "+N more" line — keeps the forecast a focused priority
    /// list rather than a full roster (that's what Momentum is for).
    private static let limit = 6

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Forecast", trailing: "if you stop now")

            if !board.hasDeveloped {
                Text("Your forecast appears once your muscles have built development worth holding onto.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let shown = Array(board.ranked.prefix(Self.limit))
                let trailing = board.ranked.count - shown.count

                insight

                VStack(spacing: Space.lg) {
                    ForEach(shown) { row($0) }
                }

                if trailing > 0 {
                    Text("\(trailing) more \(trailing == 1 ? "muscle holds" : "muscles hold") on longer.")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Forward-looking line. Reads as a nudge when something fades
    /// within the week, otherwise as a calm "you're covered, but
    /// here's the order it would unwind" leaderboard caption.
    @ViewBuilder
    private var insight: some View {
        let names = board.ranked.prefix(3).map { InsightsFormat.rowLabel(for: $0.muscle) }
        if board.isUrgent {
            Text(insightText(names: names, lead: "Train soon: ", tail: names.count == 1 ? " starts fading within the week." : " start fading within the week."))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } else if let days = board.soonestFadeDays {
            Text(insightText(names: names, lead: "Well covered. Stop now and ", tail: names.count == 1 ? " fades first, in about \(days) days." : " fade first, in about \(days) days."))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Two-tone forecast line: the named muscles brightened against
    /// the dimmer copy (AttributedString; Text `+` is deprecated).
    private func insightText(names: [String], lead: String, tail: String) -> AttributedString {
        var head = AttributedString(lead)
        head.foregroundColor = Ink.secondary
        var list = AttributedString(names.joined(separator: ", "))
        list.foregroundColor = Ink.primary
        var rest = AttributedString(tail)
        rest.foregroundColor = Ink.secondary
        return head + list + rest
    }

    private func row(_ stat: MuscleForecastStat) -> some View {
        let name = InsightsFormat.rowLabel(for: stat.muscle)
        let color = fadeColor(stat.daysUntilFade)
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(name)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                Text(fadeLabel(stat.daysUntilFade))
                    .font(Typography.caption)
                    .foregroundStyle(color)
            }
            ForecastBar(
                current: stat.currentAdaptation,
                projected: stat.projectedAdaptation,
                color: color,
                name: name
            )
        }
    }

    private func fadeColor(_ days: Int) -> Color {
        if days <= 3 { return Tint.danger }
        if days <= 7 { return Tint.primary }
        return Ink.secondary
    }

    private func fadeLabel(_ days: Int) -> String {
        if days <= 1 { return "fading now" }
        return "fades in \(days)d"
    }
}

// MARK: - Forecast bar

/// A muscle's development today (the dim full reach) with its
/// projected level at the horizon drawn solid on top. The dim tail
/// past the solid fill is the development forecast to be lost. Width
/// comes from the container via `GeometryReader`.
private struct ForecastBar: View {
    let current: Double
    let projected: Double
    let color: Color
    let name: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Surface.cardTint)
                Capsule()
                    .fill(color.opacity(0.28))
                    .frame(width: w * CGFloat(min(max(current, 0), 1)))
                Capsule()
                    .fill(color)
                    .frame(width: w * CGFloat(min(max(projected, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var accessibilityText: String {
        let now = Int((current * 100).rounded())
        let then = Int((projected * 100).rounded())
        return "\(name) development \(now) percent now, \(then) percent projected"
    }
}
