//
//  ExerciseDominanceSection.swift
//
//  The lifetime composition of your training: which lifts carry the
//  tonnage. Ranks every exercise by its share of all-time volume
//  (weight × reps) and draws the top ~6 as full-weight proportion
//  bars — the bar is the message, with the lift name riding above it
//  and the share and tonnage trailing. The remainder collapses into
//  an "Other" row.
//
//  The #1 lift wears the accent gradient so the headline
//  concentration reads from three feet away; the rest fade down a
//  luminance ramp by rank. A compound/isolation split rides at the
//  card's foot as a compact two-segment bar — the "what kind of lifts
//  are these?" companion to "which lifts?". One caption line below
//  the card reads the concentration.
//

import VivoKit
import SwiftUI

struct ExerciseDominanceSection: View {
    let board: ExerciseDominanceBoard
    let split: CompositionSplit

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Composition", trailing: "all time")

            if !board.hasAny {
                Text("As you log weighted sets, this ranks every lift by its share of your all-time volume so you can see which exercises are doing the heavy lifting — and which are coasting.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ranking
                caption
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ranking card

    private var ranking: some View {
        VStack(spacing: Space.lg) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                rowView(for: row, rank: index)
            }

            if split.hasData {
                SectionDivider()
                movementSplit
            }
        }
        .padding(Space.xl)
        .contentCard()
    }

    private func rowView(for row: DominanceRow, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: Space.xs + 2) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(row.name)
                    .font(rank == 0 ? Typography.sectionHeading : Typography.caption)
                    .foregroundStyle(rank == 0 ? Ink.primary : Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: Space.sm)
                Text("\(Int((row.share * 100).rounded()))%")
                    .font(Typography.metricUnit)
                    .foregroundStyle(rank == 0 ? Tint.primary : Ink.secondary)
                    .monospacedDigit()
                Text(WeightFormatter.volumeString(row.volume, unit: unit))
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.quaternary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            DominanceBar(share: row.share, rank: rank)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Movement split footer

    /// Compound vs isolation over the last 4 weeks, folded in as the
    /// card's coda: one two-segment bar plus a single legend line.
    private var movementSplit: some View {
        let compound = split.share(.compound)
        let isolation = split.share(.isolation)

        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Movement")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
                Spacer(minLength: Space.sm)
                Text("last 4 weeks")
                    .panelLegend()
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Tint.primary.opacity(0.85))
                        .frame(width: max(4, geo.size.width * compound))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Ink.quaternary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 12)
            .accessibilityHidden(true)

            HStack(spacing: Space.xs) {
                Text("Compound \(Int((compound * 100).rounded()))%")
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
                Text("·")
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.quaternary)
                Text("Isolation \(Int((isolation * 100).rounded()))%")
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
                    .monospacedDigit()
                Spacer(minLength: Space.sm)
                Text("\(split.classifiedTotal) \(split.classifiedTotal == 1 ? "set" : "sets")")
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.quaternary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Movement split: compound \(Int((compound * 100).rounded())) percent, isolation \(Int((isolation * 100).rounded())) percent")
    }

    // MARK: - Caption

    private var caption: some View {
        Text(line)
            .font(Typography.caption)
            .foregroundStyle(Ink.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var line: String {
        if board.topTwoShare > 0.5 {
            let pct = Int((board.topTwoShare * 100).rounded())
            return "\(pct)% of your volume rides on two lifts."
        }
        if board.topShare > 0.4, let top = board.top {
            let pct = Int((top.share * 100).rounded())
            return "\(top.name) alone carries \(pct)% of your volume."
        }
        let count = board.stats.count
        return "Volume spread across \(count) \(count == 1 ? "lift" : "lifts")."
    }

    // MARK: - Derived rows

    /// The top 6 lifts, with the remainder (if any) collapsed into a
    /// single "Other (N lifts)" row carrying the summed share and
    /// volume.
    private var rows: [DominanceRow] {
        let stats = board.stats
        guard stats.count > 7 else {
            return stats.map { DominanceRow(name: $0.name, share: $0.share, volume: $0.volume) }
        }

        let top = stats.prefix(6)
        let rest = stats.dropFirst(6)
        let restShare = rest.reduce(0) { $0 + $1.share }
        let restVolume = rest.reduce(0) { $0 + $1.volume }
        let restCount = rest.count

        return top.map { DominanceRow(name: $0.name, share: $0.share, volume: $0.volume) }
            + [DominanceRow(
                name: "Other (\(restCount) \(restCount == 1 ? "lift" : "lifts"))",
                share: restShare,
                volume: restVolume
            )]
    }
}

// MARK: - Row data

private struct DominanceRow: Identifiable, Hashable {
    /// Synthetic identity — display names are unique within a board,
    /// and the collapsed "Other" row is stable per render.
    var id: String { name }
    let name: String
    let share: Double
    let volume: Double
}

// MARK: - Dominance bar

/// A proportion bar with real mass: a full-width dim track, filled to
/// the lift's share. The top rank burns in an accent gradient with a
/// soft glow; lower ranks fade down a gray luminance ramp so the
/// hierarchy reads from the bars alone.
private struct DominanceBar: View {
    let share: Double
    let rank: Int

    private var barHeight: CGFloat { rank == 0 ? 20 : 14 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Surface.cardTint)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(fill)
                    .frame(width: max(5, geo.size.width * share))
                    .shadow(
                        color: rank == 0 ? Tint.primary.opacity(0.35) : .clear,
                        radius: 6
                    )
            }
        }
        .frame(height: barHeight)
        .accessibilityHidden(true)
    }

    private var fill: LinearGradient {
        if rank == 0 {
            return LinearGradient(
                colors: [Tint.primaryShadow, Tint.primary],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        let ramp: Double = max(0.18, 0.55 - Double(rank) * 0.07)
        return LinearGradient(
            colors: [Ink.primary.opacity(ramp), Ink.primary.opacity(ramp)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
