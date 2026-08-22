//
//  IntensityMixSection.swift
//
//  Rep-range distribution as one bold instrument: twelve weeks of
//  completed, rep-tracked strength sets stacked across low (1–5),
//  moderate (6–12), and high (13+) ranges. The section's dominant zone
//  wears the accent across every week so orange keeps one meaning; the
//  other zones step down through gray, and the current partial week is
//  dimmed so a week in progress never reads as a drop in volume. The
//  set-weighted migration verdict ("lower-rep shift") lives in the
//  section header's trailing status instead of a text panel.
//
//  An earlier text-led layout removed this chart for duplicating the
//  surrounding reads. It returns slimmer now that the prose it
//  duplicated is gone: the chart is the read, not an illustration of
//  one. Before any rep-tracked sets exist, a dormant canvas holds the
//  same geometry while the six-set sample collects.
//

import Charts
import SwiftUI
import VivoKit

struct IntensityMixSection: View {
    let mix: IntensityMix
    let weeks: [IntensityWeek]
    let migration: RepRangeMigrationReport

    private var hasWeeklyData: Bool {
        weeks.contains { $0.total > 0 }
    }

    /// Recent data leads when available; otherwise the range carrying
    /// the most sets across the 12-week trend window owns the accent.
    private var accentZone: IntensityZone? {
        if let recent = mix.dominant { return recent }
        let totals = Dictionary(
            uniqueKeysWithValues: IntensityZone.allCases.map { zone in
                (zone, weeks.reduce(0) { $0 + $1.count(zone) })
            }
        )
        guard totals.values.reduce(0, +) > 0 else { return nil }
        return IntensityZone.allCases.max {
            totals[$0, default: 0] < totals[$1, default: 0]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Rep ranges",
                trailing: trailingStatus,
                trailingIsInProgress: isBuilding,
                accessibilityIdentifier: "insightsRepMixInstrument"
            )

            if !hasWeeklyData {
                DormantSlotsCanvas(
                    slotCount: IntensityMix.minimumClearSampleSets,
                    filledSlots: 0,
                    legend: "0/\(IntensityMix.minimumClearSampleSets) rep-tracked sets",
                    accessibilityLabel: "Rep-range signal building. 0 of \(IntensityMix.minimumClearSampleSets) rep-tracked strength sets collected. Log completed strength sets with reps to draw the weekly mix."
                )
                .frame(height: InsightChartCanvas.hero)
                .padding(Space.xl)
                .contentCard()
            } else {
                VStack(alignment: .leading, spacing: Space.lg) {
                    InsightChartLegend(
                        items: IntensityZone.allCases.map { zone in
                            InsightChartLegend.Item(
                                label: "\(zone.repRange) reps",
                                color: color(zone),
                                swatch: .fill
                            )
                        },
                        trailing: "last 12 weeks"
                    )

                    chart
                }
                .padding(Space.xl)
                .contentCard()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header status

    private var trailingStatus: String {
        if !hasWeeklyData { return "waiting for rep sets" }
        if !migration.hasTrend { return "trend building" }
        return switch migration.verdict {
        case .towardStrength: "lower-rep shift"
        case .towardEndurance: "higher-rep shift"
        case .stable: "stable range"
        }
    }

    private var isBuilding: Bool {
        !hasWeeklyData || !migration.hasTrend
    }

    // MARK: - Weekly chart

    private var chart: some View {
        Chart(chartRows) { row in
            BarMark(
                x: .value("Week", row.weekStart, unit: .weekOfYear),
                y: .value("Sets", row.sets)
            )
            .foregroundStyle(color(row.zone))
            .opacity(row.isPartial ? 0.55 : 1)
            .cornerRadius(2)
        }
        .chartXAxis { InsightChartAxis.dates() }
        .chartYAxis { InsightChartAxis.counts() }
        .frame(height: InsightChartCanvas.hero)
        .accessibilityLabel("Weekly rep-range mix")
        .accessibilityValue(chartAccessibilitySummary)
    }

    private var chartRows: [WeekZoneSets] {
        weeks.flatMap { week in
            IntensityZone.allCases.map { zone in
                WeekZoneSets(
                    weekStart: week.weekStart,
                    zone: zone,
                    sets: week.count(zone),
                    isPartial: week.isCurrentWeek
                )
            }
        }
    }

    private var chartAccessibilitySummary: String {
        let activeWeeks = weeks.count(where: { $0.total > 0 })
        let sets = weeks.reduce(0) { $0 + $1.total }
        var summary = "\(sets) rep-tracked \(sets == 1 ? "set" : "sets") across \(activeWeeks) active \(activeWeeks == 1 ? "week" : "weeks")"
        if let dominant = accentZone {
            summary += ". Dominant range, \(dominant.label.lowercased()) (\(dominant.repRange) reps)"
        }
        return summary
    }

    // MARK: - Colors

    private func color(_ zone: IntensityZone) -> Color {
        if zone == accentZone { return Tint.primary }
        switch zone {
        case .strength: return Ink.secondary
        case .hypertrophy: return Ink.tertiary
        case .endurance: return Ink.quaternary
        }
    }
}

/// One zone's set count inside one calendar week of the trend window.
private struct WeekZoneSets: Identifiable {
    let weekStart: Date
    let zone: IntensityZone
    let sets: Int
    let isPartial: Bool

    var id: String {
        "\(weekStart.timeIntervalSince1970)-\(zone.repRange)"
    }
}
