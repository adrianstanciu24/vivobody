//
//  ConsistencySection.swift
//  vivobody
//
//  Training rhythm as one card led by the calendar, not by prose. A
//  slim stat strip (weekly cadence, days trained, average RIR) tops the
//  card, the weekly-sets sparkline draws the six-month volume trend in
//  bold orange, and the contribution heatmap is the section's main
//  instrument with month and weekday anchors. RIR coverage shrinks to
//  one legend line on the sparkline; the week streak moves to the
//  section header's trailing status. Before any workout exists, a
//  dormant canvas holds the same geometry while the first four recent
//  workouts collect.
//

import Charts
import SwiftUI
import VivoKit

struct ConsistencySection: View {
    let report: ConsistencyReport

    private let settledRhythmWorkouts = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Consistency",
                trailing: trailingStatus,
                trailingIsInProgress: isBuilding
            )

            if !report.hasActivity {
                DormantSlotsCanvas(
                    slotCount: settledRhythmWorkouts,
                    filledSlots: report.recentSessions,
                    legend: "\(report.recentSessions)/\(settledRhythmWorkouts) recent workouts",
                    accessibilityLabel: "Consistency signal building. \(report.recentSessions) of \(settledRhythmWorkouts) recent workouts completed. Complete a workout to start the training calendar."
                )
                .frame(height: InsightChartCanvas.hero)
                .padding(Space.xl)
                .contentCard()
            } else {
                calendarCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header status

    private var trailingStatus: String {
        if !report.hasActivity { return "waiting for first workout" }
        if report.recentSessions < settledRhythmWorkouts {
            return "\(report.recentSessions)/\(settledRhythmWorkouts) workouts"
        }
        if report.weekStreak > 0 {
            return "\(report.weekStreak)-week streak"
        }
        return "last 6 months"
    }

    private var isBuilding: Bool {
        !report.hasActivity || report.recentSessions < settledRhythmWorkouts
    }

    // MARK: - Calendar card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            StatStrip(
                stats: [
                    Stat(
                        value: InsightsFormat.perWeekLabel(report.sessionsPerWeek),
                        label: "Workouts / wk"
                    ),
                    Stat(
                        value: "\(report.daysTrainedInWindow)",
                        label: "Days trained"
                    ),
                    Stat(
                        value: report.averageRIR.map(formatRIR) ?? "—",
                        label: "Avg RIR"
                    ),
                ],
                edgeAligned: true
            )
            .padding(.vertical, Space.xs)

            weeklyVolumeSpark

            ConsistencyHeatmap(
                weeks: report.weeks,
                daysTrained: report.daysTrainedInWindow
            )

            heatmapLegend
        }
        .padding(Space.xl)
        .contentCard()
    }

    // MARK: - Sets-per-week sparkline

    /// Completed set count per week across the same six-month window
    /// as the heatmap. The current partial week is omitted so a week
    /// in progress never looks like a sudden drop in training. The
    /// legend's trailing token doubles as the RIR-coverage read.
    private var weeklyVolumeSpark: some View {
        let weekly = report.weeks.dropLast().enumerated().map { index, column in
            WeeklyVolumePoint(
                week: index,
                sets: column.filter(\.isInRange).reduce(0) { $0 + $1.sets }
            )
        }
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("Weekly sets")
                    .panelLegend()
                Spacer()
                Text(rirCoverageToken)
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
            .frame(height: InsightChartCanvas.compact)
            .accessibilityLabel(Text("Completed sets per week over the last six months"))
            .accessibilityValue(weeklySparkAccessibilityValue(weekly))
        }
    }

    private var rirCoverageToken: String {
        guard report.rirEligibleSets > 0 else { return "no RIR-eligible sets" }
        return "RIR \(report.rirLoggedSets)/\(report.rirEligibleSets) sets"
    }

    private func weeklySparkAccessibilityValue(
        _ weekly: [WeeklyVolumePoint]
    ) -> String {
        let active = weekly.count(where: { $0.sets > 0 })
        let latest = weekly.last?.sets ?? 0
        let peak = weekly.map(\.sets).max() ?? 0
        return "\(active) active \(active == 1 ? "week" : "weeks"). Last full week, \(setLabel(latest)). Peak week, \(setLabel(peak))."
    }

    private func setLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "set" : "sets")"
    }

    private func formatRIR(_ value: Double) -> String {
        String(format: "%.1f", value)
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
            ForEach(0 ... 4, id: \.self) { level in
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

/// One point of the weekly-volume sparkline: total completed sets in a
/// given week of the heatmap window.
private struct WeeklyVolumePoint: Identifiable {
    var id: Int {
        week
    }

    let week: Int
    let sets: Int
}

/// Shade for a heatmap level — a faint card tint at rest ramping
/// to the full accent on a big day.
private func heatmapFill(level: Int) -> Color {
    switch level {
    case 1: Tint.primary.opacity(0.30)
    case 2: Tint.primary.opacity(0.55)
    case 3: Tint.primary.opacity(0.78)
    case 4: Tint.primary
    default: Surface.cardTint
    }
}

// MARK: - Consistency heatmap

/// Six months of training days as a contribution grid: columns are
/// locale-aware weeks (oldest → newest), rows are weekdays. Month and
/// weekday anchors make the compressed calendar orientable; today wears
/// a ring, and future days in the current week sit faint.
private struct ConsistencyHeatmap: View {
    let weeks: [[ConsistencyDay]]
    let daysTrained: Int

    private let spacing: CGFloat = 3
    private let weekdayGutter: CGFloat = 14
    private let anchorGap: CGFloat = 4
    private var rowCount: Int {
        max(weeks.map(\.count).max() ?? 0, 1)
    }

    private var columnCount: Int {
        max(weeks.count, 1)
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 2), spacing: spacing),
            count: columnCount
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            monthAnchorRow

            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(0 ..< rowCount, id: \.self) { dayIndex in
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
            .padding(.leading, weekdayGutter + anchorGap)
            .overlay(alignment: .topLeading) {
                weekdayAnchorOverlay
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Training calendar")
        .accessibilityValue(accessibilitySummary)
    }

    private var monthAnchorRow: some View {
        GeometryReader { proxy in
            let usableWidth = max(0, proxy.size.width - weekdayGutter - anchorGap)
            let step = (usableWidth + spacing) / CGFloat(columnCount)

            ZStack(alignment: .topLeading) {
                ForEach(monthAnchors) { anchor in
                    Text(anchor.label)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                        .offset(
                            x: weekdayGutter + anchorGap
                                + min(
                                    CGFloat(anchor.weekIndex) * step,
                                    max(0, usableWidth - 24)
                                )
                        )
                }
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    private var weekdayAnchorOverlay: some View {
        GeometryReader { proxy in
            let gridWidth = max(0, proxy.size.width - weekdayGutter - anchorGap)
            let cell = max(
                2,
                (gridWidth - spacing * CGFloat(columnCount - 1))
                    / CGFloat(columnCount)
            )

            ForEach(0 ..< rowCount, id: \.self) { index in
                Text(weekdayLabel(at: index))
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Ink.tertiary)
                    .frame(width: weekdayGutter, height: cell)
                    .offset(y: CGFloat(index) * (cell + spacing))
            }
        }
        .accessibilityHidden(true)
    }

    private var monthAnchors: [HeatmapMonthAnchor] {
        var anchors: [HeatmapMonthAnchor] = []
        var previousMonth: Int?
        let calendar = Calendar.current

        for (index, week) in weeks.enumerated() {
            guard let date = week.first?.date else { continue }
            let month = calendar.component(.month, from: date)
            if previousMonth != month {
                anchors.append(HeatmapMonthAnchor(
                    weekIndex: index,
                    label: date.formatted(.dateTime.month(.abbreviated))
                ))
                previousMonth = month
            }
        }
        return anchors
    }

    private func weekdayLabel(at index: Int) -> String {
        guard let date = weeks.first?.element(at: index)?.date else { return "" }
        return date.formatted(.dateTime.weekday(.narrow))
    }

    private var accessibilitySummary: String {
        let activeWeeks = weeks.count(where: { week in
            week.contains { $0.isInRange && $0.sets > 0 }
        })
        let recentDays = weeks.suffix(4)
            .flatMap(\.self)
            .count(where: { $0.isInRange && $0.sets > 0 })

        let latest = weeks.flatMap(\.self)
            .filter { $0.isInRange && $0.sets > 0 }
            .max { $0.date < $1.date }

        var parts = [
            "\(daysTrained) trained \(daysTrained == 1 ? "day" : "days") across \(activeWeeks) active \(activeWeeks == 1 ? "week" : "weeks") in the last 6 months",
            "\(recentDays) trained \(recentDays == 1 ? "day" : "days") in the last 4 weeks",
        ]
        if let latest {
            parts.append(
                "Most recent, \(latest.date.formatted(date: .long, time: .omitted)), \(latest.sets) \(latest.sets == 1 ? "set" : "sets")"
            )
        }
        return parts.joined(separator: ". ") + "."
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

private struct HeatmapMonthAnchor: Identifiable {
    var id: Int {
        weekIndex
    }

    let weekIndex: Int
    let label: String
}

private extension Collection {
    func element(at offset: Int) -> Element? {
        guard offset >= 0 else { return nil }
        let index = self.index(startIndex, offsetBy: offset, limitedBy: endIndex)
        guard let index, index != endIndex else { return nil }
        return self[index]
    }
}
