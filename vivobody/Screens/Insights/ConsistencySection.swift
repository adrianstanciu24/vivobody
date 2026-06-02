//
//  ConsistencySection.swift
//  vivobody
//
//  Training rhythm over the last 6 months: a summary strip (sessions
//  per week, week streak, average reps-in-reserve), a plain-language
//  read of frequency and effort, and a GitHub-style contribution
//  heatmap of every training day. The heatmap divides the available
//  width across its weeks — no fixed cell sizes — so it fills any
//  device cleanly.
//

import SwiftUI

struct ConsistencySection: View {
    let report: ConsistencyReport

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Consistency", trailing: "last 6 months")

            if !report.hasActivity {
                Text("Your training calendar fills in here as you log sessions — six months of work at a glance, the way you've grown used to seeing it elsewhere.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                StatStrip(
                    stats: [
                        Stat(value: InsightsFormat.perWeekLabel(report.sessionsPerWeek), label: "Per week", accent: report.sessionsPerWeek >= 2),
                        Stat(value: "\(report.weekStreak)", label: "Week streak"),
                        Stat(value: rirLabel(report.averageRIR), label: "Avg RIR"),
                    ],
                    valueFont: InsightsFormat.monoStat,
                    edgeAligned: true
                )
                .padding(.vertical, Space.xs)

                insight

                ConsistencyHeatmap(weeks: report.weeks, daysTrained: report.daysTrainedInWindow)

                heatmapLegend
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two clauses: the training rhythm (frequency, and the streak
    /// when it's worth celebrating) and the effort read from RIR.
    @ViewBuilder
    private var insight: some View {
        Text(line(report))
            .font(Typography.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func line(_ report: ConsistencyReport) -> AttributedString {
        var freq = AttributedString(InsightsFormat.perWeekLabel(report.sessionsPerWeek) + "×")
        freq.foregroundColor = Ink.primary
        var perWeek = AttributedString(" per week")
        perWeek.foregroundColor = Ink.secondary
        var line = freq + perWeek

        if report.weekStreak >= 2 {
            var sep = AttributedString(", ")
            sep.foregroundColor = Ink.secondary
            var run = AttributedString("\(report.weekStreak) weeks")
            run.foregroundColor = Ink.primary
            var unbroken = AttributedString(" unbroken")
            unbroken.foregroundColor = Ink.secondary
            line += sep + run + unbroken
        }

        var stop = AttributedString(". ")
        stop.foregroundColor = Ink.secondary
        line += stop

        if let rir = report.averageRIR {
            var lead = AttributedString("Sets average ")
            lead.foregroundColor = Ink.secondary
            var value = AttributedString(rirLabel(rir) + " in reserve")
            value.foregroundColor = Ink.primary
            var verdict = AttributedString(" — " + effortVerdict(rir) + ".")
            verdict.foregroundColor = Ink.secondary
            line += lead + value + verdict
        }

        return line
    }

    /// How the average RIR reads as training intent.
    private func effortVerdict(_ rir: Double) -> String {
        if rir < ConsistencyReport.targetRIRLow { return "grinding near failure, so guard recovery" }
        if rir <= ConsistencyReport.targetRIRHigh { return "right in the growth zone" }
        return "leaving a lot in the tank"
    }

    private func rirLabel(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    // MARK: - Heatmap legend

    private var heatmapLegend: some View {
        HStack(spacing: Space.sm) {
            Text("Less")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
            ForEach(0...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(heatmapFill(level: level))
                    .frame(width: 10, height: 10)
            }
            Text("More")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
        }
    }
}

/// Shade for a heatmap level — a faint card tint at rest ramping
/// to the full accent on a big day.
private func heatmapFill(level: Int) -> Color {
    switch level {
    case 1:  return Tint.primary.opacity(0.30)
    case 2:  return Tint.primary.opacity(0.55)
    case 3:  return Tint.primary.opacity(0.78)
    case 4:  return Tint.primary
    default: return Surface.cardTint
    }
}

// MARK: - Consistency heatmap

/// Six months of training days as a GitHub-style contribution grid:
/// columns are weeks (oldest → newest), rows are weekdays (Sun → Sat).
/// Each cell is shaded by that day's set volume; today wears a ring,
/// and days still in the future of the current week sit faint.
private struct ConsistencyHeatmap: View {
    let weeks: [[ConsistencyDay]]
    let daysTrained: Int

    /// The only constant is the gap between cells. `LazyVGrid` keeps
    /// the 26 week columns inside the proposed width, so the heatmap
    /// participates in the parent vertical scroll instead of creating
    /// its own intrinsic horizontal size.
    private let spacing: CGFloat = 3
    private var rowCount: Int { max(weeks.map(\.count).max() ?? 0, 1) }
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 2), spacing: spacing),
            count: max(weeks.count, 1)
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(0..<rowCount, id: \.self) { dayIndex in
                ForEach(weeks.indices, id: \.self) { weekIndex in
                    if weeks[weekIndex].indices.contains(dayIndex) {
                        dayCell(weeks[weekIndex][dayIndex])
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Training calendar: \(daysTrained) days trained in the last six months"))
    }

    private func dayCell(_ day: ConsistencyDay) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(heatmapFill(level: day.level))
            .aspectRatio(1, contentMode: .fit)
            .opacity(day.isInRange ? 1 : 0.3)
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                }
            }
    }
}
