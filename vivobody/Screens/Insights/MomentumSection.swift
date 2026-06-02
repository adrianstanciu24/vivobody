//
//  MomentumSection.swift
//  vivobody
//
//  Growth trend per muscle: which regions are climbing, holding, or
//  fading, read off the development model's adaptation level. A
//  summary strip tallies the three states, one plain-language line
//  names what's slipping (most urgent) or affirms what's climbing,
//  then the muscles sort into growing / holding / fading buckets with
//  a thin trend-coloured development bar each.
//

import SwiftUI

struct MomentumSection: View {
    let board: MuscleMomentumBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Momentum", trailing: "growth trend")

            if !board.hasAny {
                Text("Momentum appears once your muscles start to develop — keep logging sessions and their trends will show here.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                StatStrip(
                    stats: [
                        Stat(value: "\(board.growingCount)", label: "Growing", accent: board.growingCount > 0),
                        Stat(value: "\(board.holdingCount)", label: "Holding"),
                        Stat(value: "\(board.fadingCount)", label: "Fading"),
                    ],
                    valueFont: InsightsFormat.monoStat,
                    edgeAligned: true
                )
                .padding(.vertical, Space.xs)

                insight

                VStack(alignment: .leading, spacing: Space.xl) {
                    bucket(title: "Growing", stats: board.growing)
                    bucket(title: "Holding", stats: board.holding)
                    bucket(title: "Fading", stats: board.fading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One plain-language line: what's slipping (most urgent), else an
    /// affirmation tuned to whether anything's climbing.
    @ViewBuilder
    private var insight: some View {
        if !board.fading.isEmpty {
            let names = board.fading.prefix(3).map { InsightsFormat.rowLabel(for: $0.muscle) }
            Text(slippingInsight(names: names))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } else if !board.growing.isEmpty {
            Text("Everything you're training is trending up. Keep the overload coming.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Your trained muscles are holding steady. Add a little load or volume to start climbing again.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Two-tone "losing ground" line, the slipping muscles brightened
    /// against the dimmer copy (Text `+` is deprecated, so AttributedString).
    private func slippingInsight(names: [String]) -> AttributedString {
        var lead = AttributedString("Losing ground: ")
        lead.foregroundColor = Ink.secondary
        var list = AttributedString(names.joined(separator: ", "))
        list.foregroundColor = Ink.primary
        var tail = AttributedString(". Train them this week to hold your gains.")
        tail.foregroundColor = Ink.secondary
        return lead + list + tail
    }

    @ViewBuilder
    private func bucket(title: String, stats: [MuscleMomentumStat]) -> some View {
        if !stats.isEmpty {
            VStack(alignment: .leading, spacing: Space.md) {
                Text(title)
                    .sectionLabelStyle(0.55)
                VStack(spacing: Space.lg) {
                    ForEach(stats) { row($0) }
                }
            }
        }
    }

    private func row(_ stat: MuscleMomentumStat) -> some View {
        let name = InsightsFormat.rowLabel(for: stat.muscle)
        let color = trendColor(stat.trend)
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Image(systemName: trendSymbol(stat.trend))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(name)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                if stat.trend == .fading, let days = stat.daysSinceLastTrained {
                    Text(recencyShort(days))
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer(minLength: Space.sm)
                Text(trendWord(stat.trend))
                    .font(Typography.caption)
                    .foregroundStyle(color)
            }
            DevelopmentBar(adaptation: stat.adaptation, color: color, name: name)
        }
    }

    private func trendSymbol(_ trend: MomentumTrend) -> String {
        switch trend {
        case .growing: return "arrow.up.right"
        case .holding: return "minus"
        case .fading:  return "arrow.down.right"
        }
    }

    private func trendWord(_ trend: MomentumTrend) -> String {
        switch trend {
        case .growing: return "growing"
        case .holding: return "holding"
        case .fading:  return "fading"
        }
    }

    private func trendColor(_ trend: MomentumTrend) -> Color {
        switch trend {
        case .growing: return Tint.primary
        case .holding: return Ink.secondary
        case .fading:  return Tint.danger
        }
    }

    private func recencyShort(_ days: Int) -> String {
        if days <= 0 { return "today" }
        if days == 1 { return "1d ago" }
        return "\(days)d ago"
    }
}

// MARK: - Development bar

/// A muscle's development level (adaptation, `0...1`) drawn as a thin
/// trend-coloured fill. Slimmer than the volume bar so the two
/// instruments don't read as the same scale. Width comes from the
/// container via `GeometryReader`, so it stays responsive.
private struct DevelopmentBar: View {
    let adaptation: Double
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
                    .frame(width: w * CGFloat(min(max(adaptation, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityLabel(Text("\(name) development \(Int((adaptation * 100).rounded())) percent"))
    }
}
