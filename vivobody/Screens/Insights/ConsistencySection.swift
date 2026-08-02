//
//  ConsistencySection.swift
//  vivobody
//
//  Training rhythm at two honest time scales: a four-week cadence and
//  RIR-coverage read, then a six-month calendar with weekly set trend.
//  The current streak sits between them because it reads the full
//  archive rather than either fixed window. Month and weekday anchors
//  keep the compact heatmap calendar-readable on every device.
//

import VivoKit
import SwiftUI
import Charts

struct ConsistencySection: View {
    let report: ConsistencyReport

    private let settledRhythmWorkouts = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Consistency",
                trailing: consistencyBuildingLabel,
                trailingIsInProgress: consistencyIsBuilding
            )

            if !report.hasActivity {
                InsightBuildingCard(
                    title: "Your training rhythm starts here",
                    detail: "Complete a workout to start collecting training days, weekly set volume, and your four-week cadence.",
                    progress: 0,
                    progressLabel: "0/\(settledRhythmWorkouts) RECENT WORKOUTS",
                    accessibilityProgress: "0 of \(settledRhythmWorkouts) recent workouts"
                )
            } else {
                recentRhythmCard

                if report.weekStreak > 0 {
                    streakChip
                }

                calendarCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var consistencyIsBuilding: Bool {
        !report.hasActivity || report.recentSessions < settledRhythmWorkouts
    }

    private var consistencyBuildingLabel: String? {
        if !report.hasActivity { return "waiting for first workout" }
        if report.recentSessions == 0 { return "recent rhythm waiting" }
        if report.recentSessions < settledRhythmWorkouts {
            return "\(report.recentSessions)/\(settledRhythmWorkouts) workouts"
        }
        return nil
    }

    // MARK: - Recent rhythm

    private var recentRhythmCard: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            cardHeading("Recent rhythm", timeframe: "last 4 weeks")

            if report.hasRecentActivity {
                StatStrip(
                    stats: [
                        Stat(
                            value: InsightsFormat.perWeekLabel(report.sessionsPerWeek),
                            label: "Workouts / wk"
                        ),
                        Stat(
                            value: "\(report.recentSessions)",
                            label: report.recentSessions == 1 ? "Workout" : "Workouts"
                        ),
                        Stat(
                            value: report.averageRIR.map(formatRIR) ?? "—",
                            label: "Avg RIR"
                        ),
                    ],
                    valueFont: Typography.statValue,
                    edgeAligned: true
                )
                .padding(.vertical, Space.xs)

                if report.recentSessions < settledRhythmWorkouts {
                    rhythmBuildingStatus
                }

                rirCoverage
            } else {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        BuildingSignalDot(size: 10)
                        Text("Recent rhythm waiting")
                            .font(Typography.title)
                            .foregroundStyle(Ink.primary)
                    }
                    Text("Your six-month calendar is still shown below.")
                        .font(Typography.body)
                        .foregroundStyle(Ink.secondary)
                }
            }
        }
        .padding(Space.xl)
        .contentCard()
    }

    private var rhythmBuildingStatus: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                BuildingSignalDot()
                Text("Rhythm taking shape")
                    .panelLegendType()
                    .foregroundStyle(Tint.inProgress)
                Spacer(minLength: Space.sm)
                Text("\(report.recentSessions)/\(settledRhythmWorkouts) WORKOUTS")
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
            }

            SegmentLadder(
                fraction: Double(report.recentSessions) / Double(settledRhythmWorkouts),
                segments: 20,
                tint: Tint.inProgress,
                height: 5,
                spacing: 3
            )

            Text(earlyReadText)
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .contentChip(tint: Tint.inProgress.opacity(0.07))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rhythm taking shape. \(report.recentSessions) of \(settledRhythmWorkouts) recent workouts. \(earlyReadText)")
    }

    private var rirCoverage: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text("Reps in reserve coverage")
                    .panelLegend()
                Spacer(minLength: Space.sm)
                Text(rirCoverageLabel)
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
            }

            SegmentLadder(
                fraction: report.rirCoverage,
                segments: 20,
                tint: Tint.primary,
                height: 5,
                spacing: 2
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rirCoverageAccessibilityLabel)
    }

    private var rirCoverageLabel: String {
        guard report.rirEligibleSets > 0 else { return "No eligible rep sets" }
        return "\(report.rirLoggedSets) of \(report.rirEligibleSets) sets"
    }

    private var rirCoverageAccessibilityLabel: String {
        guard report.rirEligibleSets > 0 else {
            return "Reps in reserve coverage: no eligible rep sets in the last 4 weeks"
        }
        return "Reps in reserve logged on \(report.rirLoggedSets) of \(report.rirEligibleSets) eligible sets in the last 4 weeks"
    }

    private var earlyReadText: String {
        "Keep logging through this four-week window; cadence settles after four workouts."
    }

    private var streakChip: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Text("Current week streak")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
            Spacer(minLength: Space.sm)
            Text(weekLabel(report.weekStreak))
                .font(Typography.metricInline)
                .foregroundStyle(Ink.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, Space.lg)
        .frame(minHeight: 52)
        .contentChip()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Six-month calendar

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            cardHeading("Training calendar", timeframe: "last 6 months")

            StatStrip(
                stats: [
                    Stat(value: "\(activeWeeksInWindow)", label: "Active weeks"),
                    Stat(value: "\(report.daysTrainedInWindow)", label: "Days trained"),
                ],
                valueFont: Typography.statValue,
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

    private func cardHeading(_ title: String, timeframe: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Text(title)
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.primary)
            Spacer(minLength: Space.sm)
            Text(timeframe)
                .panelLegend()
        }
    }

    private var activeWeeksInWindow: Int {
        report.weeks.filter { week in
            week.contains { $0.isInRange && $0.sets > 0 }
        }.count
    }

    private func formatRIR(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func weekLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "week" : "weeks")"
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
                Text("Weekly sets")
                    .panelLegend()
                Spacer()
                Text("Last full week · \(setLabel(weekly.last?.sets ?? 0))")
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
            .accessibilityValue(weeklySparkAccessibilityValue(weekly))
        }
    }

    private func weeklySparkAccessibilityValue(
        _ weekly: [WeeklyVolumePoint]
    ) -> String {
        let active = weekly.filter { $0.sets > 0 }.count
        let latest = weekly.last?.sets ?? 0
        let peak = weekly.map(\.sets).max() ?? 0
        return "\(active) active \(active == 1 ? "week" : "weeks"). Last full week, \(setLabel(latest)). Peak week, \(setLabel(peak))."
    }

    private func setLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "set" : "sets")"
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
    private var rowCount: Int { max(weeks.map(\.count).max() ?? 0, 1) }
    private var columnCount: Int { max(weeks.count, 1) }
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

            ForEach(0..<rowCount, id: \.self) { index in
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
        let activeWeeks = weeks.filter { week in
            week.contains { $0.isInRange && $0.sets > 0 }
        }.count
        let recentDays = weeks.suffix(4)
            .flatMap { $0 }
            .filter { $0.isInRange && $0.sets > 0 }
            .count
        let latest = weeks.flatMap { $0 }
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
    var id: Int { weekIndex }
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
