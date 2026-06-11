//
//  MuscleBalanceSection.swift
//  vivobody
//
//  The Insights flagship: how many effective sets each muscle received
//  over the last 7 days, judged against its productive volume band.
//  A summary strip ("optimal / build more / resting") leads, then the
//  full roster grouped by body part so push/pull/legs balance reads at
//  a glance, with a legend tying the colours back to the volume model.
//
//  Effective sets come from the graded involvement map: a set counts
//  fully for its target muscle and partially for the muscles that only
//  assist (see `MuscleVolume`) — which is why the numbers carry a
//  decimal, and why a muscle you never isolate can still be in range
//  from all the compound work that hits it.
//

import SwiftUI

struct MuscleBalanceSection: View {
    let stats: [MuscleVolumeStat]

    private static let monoRow = Font.system(size: 17, weight: .bold, design: .monospaced)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary(stats.summary)

            SectionDivider()
                .padding(.vertical, Space.xl)

            bars

            legend
                .padding(.top, Space.xl)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Summary

    private func summary(_ summary: MuscleVolumeSummary) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Muscle balance", trailing: "last 7 days")

            StatStrip(
                stats: [
                    Stat(value: "\(summary.optimalCount)", label: "Optimal", accent: summary.optimalCount > 0),
                    Stat(value: "\(summary.underCount)", label: "Build more"),
                    Stat(value: "\(summary.restingCount)", label: "Resting"),
                ],
                valueFont: InsightsFormat.monoStat,
                edgeAligned: true
            )
            .padding(.vertical, Space.xs)

            insightLine(summary)
        }
    }

    /// One plain-language line naming what to do next: the muscles
    /// most in need of work, or affirmation when everything's covered.
    @ViewBuilder
    private func insightLine(_ summary: MuscleVolumeSummary) -> some View {
        if !summary.hasWindowActivity {
            Text("Nothing trained in the last 7 days — every muscle is resting. Log a workout to bring your balance back to life.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if summary.neglected.isEmpty {
            Text("Every muscle you've trained is in its productive range. Nicely balanced.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            let names = summary.neglected.prefix(3).map { $0.muscle.displayName }
            Text(neglectInsight(names: Array(names)))
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Two-tone insight: the muscle names brightened against the
    /// dimmer surrounding copy. Built as an AttributedString so the
    /// runs flow and wrap as one paragraph (Text `+` is deprecated).
    private func neglectInsight(names: [String]) -> AttributedString {
        var lead = AttributedString("Falling behind: ")
        lead.foregroundColor = Ink.secondary
        var list = AttributedString(names.joined(separator: ", "))
        list.foregroundColor = Ink.primary
        var tail = AttributedString(names.count == 1 ? " needs more volume this week." : " need more volume this week.")
        tail.foregroundColor = Ink.secondary
        return lead + list + tail
    }

    // MARK: - Balance bars

    private var bars: some View {
        // Shared horizontal axis so bars are directly comparable
        // across muscles; headroom past the highest band and the
        // busiest muscle so nothing clips.
        let axisMax = max(24, (stats.map(\.effectiveSets).max() ?? 0).rounded(.up))

        return VStack(alignment: .leading, spacing: Space.xl) {
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                let groupStats = stats
                    .filter { $0.muscle.group == group }
                    .sorted { $0.effectiveSets > $1.effectiveSets }
                if !groupStats.isEmpty {
                    muscleGroupBlock(group: group, stats: groupStats, axisMax: axisMax)
                }
            }
        }
    }

    private func muscleGroupBlock(
        group: MuscleGroup,
        stats: [MuscleVolumeStat],
        axisMax: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(group.displayName)
                .sectionLabelStyle(0.55)

            VStack(spacing: Space.lg) {
                ForEach(stats) { stat in
                    muscleRow(stat, axisMax: axisMax)
                }
            }
        }
    }

    private func muscleRow(_ stat: MuscleVolumeStat, axisMax: Double) -> some View {
        let name = InsightsFormat.rowLabel(for: stat.muscle)
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(name)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)

                if stat.zone == .untrained {
                    Text(restingLabel(stat))
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                }

                Spacer(minLength: Space.sm)

                Text(InsightsFormat.setsLabel(stat.effectiveSets))
                    .font(Self.monoRow)
                    .foregroundStyle(zoneColor(stat.zone))
                    .monospacedDigit()
                Text("sets")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
            }

            MuscleVolumeBar(stat: stat, name: name, axisMax: axisMax)
        }
    }

    private func restingLabel(_ stat: MuscleVolumeStat) -> String {
        guard let days = stat.daysSinceLastTrained else { return "never trained" }
        if days <= 0 { return "trained today" }
        if days == 1 { return "1 day ago" }
        return "\(days) days ago"
    }

    private func zoneColor(_ zone: VolumeZone) -> Color {
        switch zone {
        case .untrained: return Ink.quaternary
        case .under:     return Ink.secondary
        case .optimal:   return Tint.primary
        case .high:      return Tint.danger
        }
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.lg) {
                legendSwatch(color: Ink.secondary, label: "Build more")
                legendSwatch(color: Tint.primary, label: "Optimal")
                legendSwatch(color: Tint.danger, label: "High")
            }
            Text("A set counts fully for its target muscle and partially for the muscles that assist it. The brighter band marks each muscle's productive weekly range.")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: Space.sm) {
            Capsule()
                .fill(color)
                .frame(width: 18, height: 8)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Ink.secondary)
        }
    }
}

// MARK: - Volume bar

/// A muscle's effective-set count drawn against a shared axis. The
/// dim track is the full axis; the brighter inset band is the
/// productive range; the solid fill (zone-coloured) is the work done.
/// A `GeometryReader` reads the row's own width, so the bar always
/// spans the container — no fixed widths anywhere.
private struct MuscleVolumeBar: View {
    let stat: MuscleVolumeStat
    let name: String
    let axisMax: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = { (sets: Double) in w * CGFloat(min(max(sets, 0), axisMax) / axisMax) }
            let bandStart = x(stat.landmark.mev)
            let bandWidth = max(0, x(stat.landmark.optimalHigh) - bandStart)
            let fillWidth = x(stat.effectiveSets)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Surface.cardTint)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Surface.edgeBright)
                    .frame(width: bandWidth)
                    .offset(x: bandStart)

                Capsule()
                    .fill(fillColor)
                    .frame(width: fillWidth)
            }
        }
        .frame(height: 8)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var fillColor: Color {
        switch stat.zone {
        case .untrained: return Ink.quaternary
        case .under:     return Ink.secondary
        case .optimal:   return Tint.primary
        case .high:      return Tint.danger
        }
    }

    private var accessibilityText: String {
        let sets = String(format: "%.1f", stat.effectiveSets)
        return "\(name): \(sets) effective sets this week"
    }
}
