//
//  IntensityMixSection.swift
//
//  How completed, rep-tracked strength sets are distributed across
//  low (1–5), moderate (6–12), and high (13+) rep ranges. A concise
//  28-day mix leads; the closing instrument carries the longer-term,
//  set-weighted slope and its evidence tier. The old 12-week bar chart
//  duplicated those reads while consuming most of the screen, so the
//  section now stays focused on mix and direction.
//

import VivoKit
import SwiftUI

struct IntensityMixSection: View {
    let mix: IntensityMix
    let weeks: [IntensityWeek]
    let migration: RepRangeMigrationReport

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                trailing: repRangesBuildingLabel,
                trailingIsInProgress: repRangesAreBuilding
            )

            if !hasWeeklyData {
                InsightBuildingCard(
                    title: "Your rep-range picture starts here",
                    detail: "Log completed strength sets with reps to reveal low, moderate, and high-rep work. A clear current mix forms after six sets.",
                    progress: 0,
                    progressLabel: "0/\(IntensityMix.minimumClearSampleSets) REP-TRACKED SETS",
                    accessibilityProgress: "0 of \(IntensityMix.minimumClearSampleSets) rep-tracked sets"
                )
            } else {
                VStack(alignment: .leading, spacing: Space.lg) {
                    currentMixHero
                    zoneLegend
                }
                .padding(Space.xl)
                .contentCard()

                trendSummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var repRangesAreBuilding: Bool {
        !hasWeeklyData || !migration.hasTrend || mix.hasSparseSample
    }

    private var repRangesBuildingLabel: String? {
        if !hasWeeklyData { return "waiting for rep sets" }
        if !migration.hasTrend { return "trend building" }
        if mix.hasSparseSample { return "mix taking shape" }
        return nil
    }

    // MARK: - Current mix

    @ViewBuilder
    private var currentMixHero: some View {
        if let dominant = mix.dominant {
            VStack(alignment: .leading, spacing: Space.sm) {
                dominantHeading(dominant)

                currentMixBar

                Text(currentSampleCopy)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(dominant.label), \(percentage(for: dominant)) percent. \(currentSampleCopy). \(dominant.repRange) reps")
        } else {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("No sets in the last 28 days")
                    .font(Typography.display)
                    .foregroundStyle(Ink.primary)
                Text("Earlier rep-tracked strength sets still contribute to the trend below.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
            }
        }
    }

    @ViewBuilder
    private func dominantHeading(_ dominant: IntensityZone) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Space.xs) {
                dominantPercentage(dominant)
                Text(dominant.label)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                Text("\(dominant.repRange) reps")
                    .panelLegend()
            }
        } else {
            HStack(alignment: .lastTextBaseline, spacing: Space.md) {
                dominantPercentage(dominant)

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(dominant.label)
                        .font(Typography.title)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                    Text("\(dominant.repRange) reps")
                        .panelLegend()
                }
                .padding(.bottom, Space.xs)

                Spacer(minLength: 0)
            }
        }
    }

    private func dominantPercentage(_ dominant: IntensityZone) -> some View {
        Text("\(percentage(for: dominant))%")
            .font(Typography.metricHero)
            .foregroundStyle(dominant == accentZone ? Tint.primary : Ink.primary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var currentSampleCopy: String {
        let sample = "\(setLabel(mix.total)) from rep-tracked strength work in the last 28 days"
        return mix.hasSparseSample ? "Early read · \(sample)" : "Based on \(sample)"
    }

    private var currentMixBar: some View {
        GeometryReader { proxy in
            let populated = IntensityZone.allCases.filter { mix.count($0) > 0 }
            let spacing: CGFloat = 2
            let gaps = spacing * CGFloat(max(0, populated.count - 1))
            let availableWidth = max(0, proxy.size.width - gaps)

            HStack(spacing: spacing) {
                ForEach(populated, id: \.self) { zone in
                    Rectangle()
                        .fill(color(zone))
                        .frame(width: availableWidth * mix.share(zone))
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    // MARK: - Zone legend

    private var zoneLegend: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.md) {
                    ForEach(IntensityZone.allCases, id: \.self) { zone in
                        legendRow(for: zone)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: Space.sm) {
                    ForEach(IntensityZone.allCases, id: \.self) { zone in
                        legendColumn(for: zone)
                    }
                }
            }
        }
    }

    private func legendColumn(for zone: IntensityZone) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            legendName(for: zone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(legendDetail(for: zone))
                .font(Typography.metricMicro)
                .foregroundStyle(Ink.tertiary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func legendRow(for zone: IntensityZone) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            legendName(for: zone)
            Spacer(minLength: Space.sm)
            Text(legendDetail(for: zone))
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: Space.tapMin)
        .accessibilityElement(children: .combine)
    }

    private func legendName(for zone: IntensityZone) -> some View {
        HStack(spacing: Space.xs) {
            Circle()
                .fill(color(zone))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(zone.label)
                .font(Typography.caption)
                .foregroundStyle(zone == accentZone ? Ink.primary : Ink.secondary)
        }
    }

    private func legendDetail(for zone: IntensityZone) -> String {
        guard mix.hasData else { return "\(zone.repRange) reps" }
        return "\(zone.repRange) · \(percentage(for: zone))%"
    }

    // MARK: - Rep trend

    @ViewBuilder
    private var trendSummary: some View {
        if migration.hasData {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(alignment: .top, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Latest active week")
                            .panelLegend()
                        Text(format(migration.currentAverage))
                            .font(Typography.metricLg)
                            .foregroundStyle(Ink.primary)
                            .monospacedDigit()
                        Text("avg reps / set")
                            .panelLegend()
                    }

                    Spacer(minLength: 0)

                    trendMetric
                }

                if migration.hasTrend {
                    qualifiedTrendFooter
                } else {
                    buildingTrendFooter
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .contentChip()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(trendAccessibilityLabel)
        }
    }

    private var trendMetric: some View {
        VStack(alignment: .trailing, spacing: Space.xs) {
            Text(migration.hasTrend ? "Weekly trend" : "Trend progress")
                .panelLegend()
            Text(migration.hasTrend ? signedSlope : trendWeekProgress)
                .font(Typography.metricLg)
                .foregroundStyle(migration.hasTrend ? trendColor : Tint.inProgress)
                .monospacedDigit()
            Text(migration.hasTrend ? "reps / week" : "active weeks")
                .panelLegend()
        }
    }

    private var qualifiedTrendFooter: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            Text(trendLabel)
                .panelLegendType()
                .foregroundStyle(trendColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xs + 2)
                .contentChip(tint: trendColor.opacity(0.10))

            Spacer(minLength: Space.sm)

            Text(trendSampleLabel)
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buildingTrendFooter: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Space.sm) {
                    buildingTrendLabel
                    Spacer(minLength: Space.sm)
                    setReadinessLabel
                }

                VStack(alignment: .leading, spacing: Space.sm) {
                    buildingTrendLabel
                    setReadinessLabel
                }
            }

            SegmentLadder(
                fraction: trendBuildingProgress,
                segments: 24,
                tint: Tint.inProgress,
                height: 5,
                spacing: 3
            )

            Text(trendRequirementText)
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buildingTrendLabel: some View {
        HStack(spacing: Space.sm) {
            BuildingSignalDot()
            Text("Building rep trend")
                .panelLegendType()
                .foregroundStyle(Tint.inProgress)
        }
    }

    private var setReadinessLabel: some View {
        Text(trendSetProgressLabel)
            .panelLegend()
            .foregroundStyle(Ink.secondary)
            .monospacedDigit()
    }

    private var trendLabel: String {
        guard migration.hasTrend else { return "Building trend" }
        switch migration.verdict {
        case .towardStrength:  return "Lower-rep shift"
        case .towardEndurance: return "Higher-rep shift"
        case .stable:          return "Stable range"
        }
    }

    private var trendAccessibilityLabel: String {
        guard migration.hasTrend else {
            return "Latest active week averaged \(format(migration.currentAverage)) reps per set. Rep trend building. \(trendSetAccessibilityLabel). \(trendWeekAccessibilityLabel). \(trendRequirementText)"
        }
        return "Latest active week averaged \(format(migration.currentAverage)) reps per set. Weighted trend \(signedSlope) reps per week. \(trendLabel). \(trendSampleLabel)."
    }

    private var trendColor: Color {
        guard migration.hasTrend else { return Tint.inProgress }
        return migration.verdict != .stable ? Tint.primary : Ink.secondary
    }

    private var signedSlope: String {
        String(format: "%+.2f", migration.slopePerWeek)
    }

    private var trendWeekProgress: String {
        let weeks = min(migration.points.count, RepRangeMigrationReport.minimumTrendWeeks)
        return "\(weeks)/\(RepRangeMigrationReport.minimumTrendWeeks)"
    }

    private var trendSetProgressLabel: String {
        let remaining = max(0, RepRangeMigrationReport.minimumTrendSets - migration.totalSets)
        if remaining == 0 {
            return "Enough sets logged"
        }
        return "\(remaining) \(remaining == 1 ? "set" : "sets") to go"
    }

    private var trendSetAccessibilityLabel: String {
        let sets = min(migration.totalSets, RepRangeMigrationReport.minimumTrendSets)
        return "Set requirement: \(sets) of \(RepRangeMigrationReport.minimumTrendSets) sets"
    }

    private var trendWeekAccessibilityLabel: String {
        let weeks = min(migration.points.count, RepRangeMigrationReport.minimumTrendWeeks)
        return "Week requirement: \(weeks) of \(RepRangeMigrationReport.minimumTrendWeeks) active weeks"
    }

    private var trendRequirementText: String {
        let sets = max(0, RepRangeMigrationReport.minimumTrendSets - migration.totalSets)
        let weeks = max(0, RepRangeMigrationReport.minimumTrendWeeks - migration.points.count)

        if sets > 0, weeks > 0 {
            return "Add \(sets) more rep-tracked \(sets == 1 ? "set" : "sets") across \(weeks) more \(weeks == 1 ? "week" : "weeks") to reveal the weekly direction."
        }
        if sets > 0 {
            return "Add \(sets) more rep-tracked \(sets == 1 ? "set" : "sets") to reveal the weekly direction."
        }
        if weeks > 0 {
            return "Add rep-tracked sets in \(weeks) more \(weeks == 1 ? "week" : "weeks") to reveal the weekly direction."
        }
        return "Your weekly direction is ready."
    }

    private var trendSampleLabel: String {
        switch migration.confidence {
        case .established:
            return "Established · \(setLabel(migration.totalSets)) across \(weekLabel(migration.points.count))"
        case .emerging:
            return "Emerging · \(setLabel(migration.totalSets)) across \(weekLabel(migration.points.count))"
        case .insufficient:
            let sets = min(migration.totalSets, RepRangeMigrationReport.minimumTrendSets)
            let weeks = min(migration.points.count, RepRangeMigrationReport.minimumTrendWeeks)
            return "\(sets)/\(RepRangeMigrationReport.minimumTrendSets) sets · \(weeks)/\(RepRangeMigrationReport.minimumTrendWeeks) active weeks"
        }
    }

    private var trendBuildingProgress: Double {
        let setProgress = Double(migration.totalSets)
            / Double(RepRangeMigrationReport.minimumTrendSets)
        let weekProgress = Double(migration.points.count)
            / Double(RepRangeMigrationReport.minimumTrendWeeks)
        return min(1, max(0, min(setProgress, weekProgress)))
    }

    // MARK: - Formatting

    private func percentage(for zone: IntensityZone) -> Int {
        Int((mix.share(zone) * 100).rounded())
    }

    private func setLabel(_ count: Int) -> String {
        "\(count) set\(count == 1 ? "" : "s")"
    }

    private func weekLabel(_ count: Int) -> String {
        "\(count) active week\(count == 1 ? "" : "s")"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    // MARK: - Colors

    private func color(_ zone: IntensityZone) -> Color {
        if zone == accentZone { return Tint.primary }
        switch zone {
        case .strength:    return Ink.secondary
        case .hypertrophy: return Ink.tertiary
        case .endurance:   return Ink.quaternary
        }
    }
}
