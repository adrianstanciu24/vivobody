//
//  StrengthSection.swift
//  vivobody
//
//  PR outlook per lift: which estimated 1-rep maxes are climbing,
//  stalled, or slipping. A summary strip tallies the three states, one
//  plain-language line surfaces the nearest PR (or the most pressing
//  stall), then each tracked lift gets a bar showing how close its
//  current estimate sits to its all-time best.
//

import SwiftUI

struct StrengthSection: View {
    let board: StrengthOutlookBoard

    /// How many lifts the outlook lists before folding the rest into
    /// a "+N more" line.
    private static let limit = 6

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Strength", trailing: "PR outlook")

            if !board.hasAny {
                Text("Strength trends appear once you've logged a weighted lift across a few sessions.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                StatStrip(
                    stats: [
                        Stat(value: "\(board.climbingCount)", label: "Climbing", accent: board.climbingCount > 0),
                        Stat(value: "\(board.plateauedCount)", label: "Stalled"),
                        Stat(value: "\(board.slippingCount)", label: "Slipping"),
                    ],
                    valueFont: InsightsFormat.monoStat,
                    edgeAligned: true
                )
                .padding(.vertical, Space.xs)

                insight

                let shown = Array(board.stats.prefix(Self.limit))
                let trailing = board.stats.count - shown.count

                VStack(spacing: Space.lg) {
                    ForEach(shown) { row($0) }
                }

                if trailing > 0 {
                    Text("\(trailing) more \(trailing == 1 ? "lift" : "lifts") tracked.")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One plain-language line: the nearest PR if a lift is climbing,
    /// otherwise the most pressing stall or slide.
    @ViewBuilder
    private var insight: some View {
        if let pr = board.nearestPR {
            if pr.isFreshPR {
                Text(line(name: pr.exercise, lead: "New PR on ", tail: " — ride the momentum."))
                    .font(Typography.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let days = pr.daysToPR {
                Text(line(name: pr.exercise, lead: "Closest PR: ", tail: " — about \(etaPhrase(days)) out at this rate."))
                    .font(Typography.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(line(name: pr.exercise, lead: "", tail: " is climbing back toward its best."))
                    .font(Typography.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if let stalled = board.stats.first(where: { $0.trend == .plateaued }) {
            let tail = stalled.weeksSinceBest.map { " has stalled — \($0)w since its last PR. Time to change a variable." } ?? " has stalled. Time to change a variable."
            Text(line(name: stalled.exercise, lead: "", tail: tail))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } else if let slip = board.stats.first(where: { $0.trend == .slipping }) {
            Text(line(name: slip.exercise, lead: "", tail: " is sliding — re-groove the movement before adding load."))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Two-tone strength line: the lift name brightened against the
    /// dimmer copy (AttributedString; Text `+` is deprecated).
    private func line(name: String, lead: String, tail: String) -> AttributedString {
        var head = AttributedString(lead)
        head.foregroundColor = Ink.secondary
        var lift = AttributedString(name)
        lift.foregroundColor = Ink.primary
        var rest = AttributedString(tail)
        rest.foregroundColor = Ink.secondary
        return head + lift + rest
    }

    private func row(_ stat: StrengthOutlookStat) -> some View {
        let color = prColor(stat.trend)
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(stat.exercise)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                Text(prLabel(stat))
                    .font(Typography.caption)
                    .foregroundStyle(color)
            }
            PRProgressBar(fraction: stat.fractionOfBest, color: color, name: stat.exercise)
        }
    }

    private func prColor(_ trend: PRTrend) -> Color {
        switch trend {
        case .climbing: return Tint.primary
        case .plateaued: return Ink.secondary
        case .slipping: return Tint.danger
        }
    }

    private func prLabel(_ stat: StrengthOutlookStat) -> String {
        switch stat.trend {
        case .climbing:
            if stat.isFreshPR { return "new PR" }
            if let days = stat.daysToPR { return "PR in ~\(etaShort(days))" }
            return "climbing"
        case .plateaued:
            if let w = stat.weeksSinceBest, w > 0 { return "stalled \(w)w" }
            return "stalled"
        case .slipping:
            return "slipping"
        }
    }

    /// Compact ETA for a chip: days under three weeks, else weeks.
    private func etaShort(_ days: Int) -> String {
        days <= 21 ? "\(days)d" : "\(Int((Double(days) / 7).rounded()))w"
    }

    /// Spelled-out ETA for the insight sentence.
    private func etaPhrase(_ days: Int) -> String {
        days <= 21 ? "\(days) days" : "\(Int((Double(days) / 7).rounded())) weeks"
    }
}

// MARK: - PR progress bar

/// How close a lift's current estimated 1-rep max sits to its all-time
/// best — a near-full bar means a PR is within reach. Trend-coloured.
/// Width comes from the container via `GeometryReader`.
private struct PRProgressBar: View {
    let fraction: Double
    let color: Color
    let name: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Surface.cardTint)
                Capsule()
                    .fill(color)
                    .frame(width: w * CGFloat(min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityLabel(Text("\(name) at \(Int((fraction * 100).rounded())) percent of its best"))
    }
}
