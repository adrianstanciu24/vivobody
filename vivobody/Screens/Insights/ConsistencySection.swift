//
//  ConsistencySection.swift
//  vivobody
//
//  Training rhythm over the last 6 months: a summary strip (workouts
//  per week, week streak, days trained), completed weekly set-count
//  graph, and a contribution heatmap of daily sets. The heatmap
//  divides the available width across its weeks, so it fills any
//  device cleanly.
//

import VivoKit
import SwiftUI
import Charts

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
                        Stat(value: InsightsFormat.perWeekLabel(report.sessionsPerWeek), label: "Workouts / wk", accent: report.sessionsPerWeek >= 2),
                        Stat(value: "\(report.weekStreak)", label: "Week streak"),
                        Stat(value: "\(report.daysTrainedInWindow)", label: "Days trained"),
                    ],
                    valueFont: Typography.statValue,
                    edgeAligned: true
                )
                .padding(.vertical, Space.xs)

                weeklyVolumeSpark

                ConsistencyHeatmap(weeks: report.weeks, daysTrained: report.daysTrainedInWindow)

                heatmapLegend
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sets-per-week sparkline

    /// Completed set count per week across the same six-month window
    /// as the heatmap. The current partial week is omitted so a week
    /// in progress never looks like a sudden drop in training.
    private var weeklyVolumeSpark: some View {
        let weekly = report.weeks.dropLast().enumerated().map { index, column in
            WeeklyVolumePoint(
                week: index,
                sets: column.filter(\.isInRange).reduce(0) { $0 + $1.sets }
            )
        }
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("Sets per week")
                    .panelLegend()
                Spacer()
                Text("\(weekly.last?.sets ?? 0) last week")
                    .panelLegend()
            }
            Chart(weekly) { point in
                AreaMark(
                    x: .value("Week", point.week),
                    y: .value("Sets", point.sets)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Tint.primary.opacity(0.28), Tint.primary.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Week", point.week),
                    y: .value("Sets", point.sets)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Tint.primary.opacity(Opacity.strong))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 48)
            .accessibilityLabel(Text("Completed sets per week over the last six months"))
        }
    }

    // MARK: - Heatmap legend

    private var heatmapLegend: some View {
        HStack(spacing: Space.sm) {
            Text("Daily sets")
                .panelLegend()
            Spacer()
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

/// One bar of the weekly-volume sparkline: total completed sets in a
/// given week of the heatmap window.
private struct WeeklyVolumePoint: Identifiable {
    var id: Int { week }
    let week: Int
    let sets: Int
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
                        .stroke(Ink.secondary, lineWidth: 1.5)
                }
            }
    }
}
