//
//  ExerciseDominanceSection.swift
//
//  The lifetime composition of your training: which lifts carry the
//  tonnage. Ranks every exercise by its share of all-time volume
//  (weight × reps) and shows the top ~6 as proportion bars, with the
//  remainder collapsed into an "Other" row. One line reads the
//  concentration — whether two lifts are doing half the work, one
//  lift dominates outright, or volume is spread across the catalog.
//
//  The #1 lift wears the accent so the headline concentration reads
//  instantly; the rest sit in grayscale luminance. Volume is shown
//  in the user's display unit via `WeightFormatter`.
//

import SwiftUI

struct ExerciseDominanceSection: View {
    let board: ExerciseDominanceBoard

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
                insight
                ranking
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ranking card

    private var ranking: some View {
        VStack(spacing: Space.md) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                rowView(for: row, isTop: index == 0)
            }
        }
        .padding(Space.xl)
        .contentCard()
    }

    private func rowView(for row: DominanceRow, isTop: Bool) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Text(row.name)
                    .font(Typography.body)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                Spacer(minLength: Space.sm)
                Text("\(Int((row.share * 100).rounded()))%")
                    .font(Typography.metricUnit)
                    .foregroundStyle(isTop ? Tint.primary : Ink.secondary)
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
                Text(WeightFormatter.volumeString(row.volume, unit: unit))
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            ShareBar(fraction: row.share, tint: isTop ? Tint.primary : Ink.secondary)
        }
    }

    // MARK: - Insight line

    private var insight: some View {
        Text(line)
            .font(Typography.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var line: AttributedString {
        if board.topTwoShare > 0.5 {
            let pct = Int((board.topTwoShare * 100).rounded())
            var lead = AttributedString("\(pct)% "); lead.foregroundColor = Ink.primary
            var rest = AttributedString("of your volume rides on two lifts.")
            rest.foregroundColor = Ink.secondary
            return lead + rest
        }

        if board.topShare > 0.4, let top = board.top {
            let pct = Int((top.share * 100).rounded())
            var lead = AttributedString("\(top.name) "); lead.foregroundColor = Ink.primary
            var mid = AttributedString("alone carries "); mid.foregroundColor = Ink.secondary
            var pctStr = AttributedString("\(pct)%"); pctStr.foregroundColor = Ink.primary
            var tail = AttributedString(" of your volume.")
            tail.foregroundColor = Ink.secondary
            return lead + mid + pctStr + tail
        }

        let count = board.stats.count
        var lead = AttributedString("Volume spread "); lead.foregroundColor = Ink.primary
        var rest = AttributedString("across \(count) \(count == 1 ? "lift" : "lifts").")
        rest.foregroundColor = Ink.secondary
        return lead + rest
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
