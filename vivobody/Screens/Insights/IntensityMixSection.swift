//
//  IntensityMixSection.swift
//
//  The rep-range distribution of your working sets over the last four
//  weeks: how much sits in the heavy strength range (1–5), the
//  growth/hypertrophy range (6–12), and the higher-rep endurance
//  range (13+). A 100% stacked bar (Swift Charts) shows the split at
//  a glance with inline percentage labels; a structured legend below
//  carries the zone names, rep ranges, set counts, and percentages.
//  One line reads the emphasis and nudges the gap.
//
//  Hypertrophy wears the accent as the productive default zone; the
//  heavy and high-rep ends sit in grayscale luminance — one accent,
//  hierarchy by brightness, like the rest of the app.
//

import SwiftUI
import Charts

struct IntensityMixSection: View {
    let mix: IntensityMix

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Intensity", trailing: "last 4 weeks")

            if !mix.hasData {
                Text("As you log weighted sets, this splits them across the strength, hypertrophy, and endurance rep ranges so you can see what your training really emphasises.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                insight
                intensityChart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart

    private var intensityChart: some View {
        VStack(spacing: Space.md) {
            Chart(slices) { slice in
                BarMark(
                    x: .value("Percent", mix.share(slice.zone) * 100),
                    y: .value("Category", "All")
                )
                .foregroundStyle(by: .value("Zone", slice.zone.label))
                .annotation(position: .overlay) {
                    if mix.share(slice.zone) > 0.08 {
                        Text("\(Int((mix.share(slice.zone) * 100).rounded()))%")
                            .font(Typography.metricMicro)
                            .foregroundStyle(labelColor(slice.zone))
                            .monospacedDigit()
                    }
                }
            }
            .chartForegroundStyleScale(domain: IntensityZone.allCases.map(\.label), range: IntensityZone.allCases.map { color($0) })
            .chartLegend(.hidden)
            .chartXScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .accessibilityLabel("Intensity mix distribution")

            legend
        }
        .padding(Space.xl)
        .contentCard()
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(spacing: Space.sm) {
            ForEach(slices) { slice in
                HStack(spacing: Space.sm) {
                    Circle()
                        .fill(color(slice.zone))
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(slice.zone.label)
                        .font(Typography.body)
                        .foregroundStyle(Ink.primary)
                    Text(slice.zone.repRange)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                    Spacer(minLength: Space.sm)
                    Text("\(slice.count) \(slice.count == 1 ? "set" : "sets")")
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                    Text("\(Int((mix.share(slice.zone) * 100).rounded()))%")
                        .font(Typography.metricUnit)
                        .foregroundStyle(slice.zone == mix.dominant ? Tint.primary : Ink.tertiary)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Insight line

    private var insight: some View {
        Text(line)
            .font(Typography.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var line: AttributedString {
        guard let dominant = mix.dominant else {
            return AttributedString("")
        }
        let pct = Int((mix.share(dominant) * 100).rounded())

        if mix.share(dominant) < 0.5 {
            var a = AttributedString("A balanced spread"); a.foregroundColor = Ink.primary
            var b = AttributedString(" across rep ranges — heavy, hypertrophy, and higher-rep work all represented.")
            b.foregroundColor = Ink.secondary
            return a + b
        }

        var lead = AttributedString("\(pct)% "); lead.foregroundColor = Ink.primary
        var mid = AttributedString("of your sets are "); mid.foregroundColor = Ink.secondary
        var zoneName = AttributedString("\(dominant.label.lowercased()) work (\(dominant.repRange))")
        zoneName.foregroundColor = Ink.primary
        var nudge = AttributedString(". " + advice(for: dominant)); nudge.foregroundColor = Ink.secondary
        return lead + mid + zoneName + nudge
    }

    private func advice(for zone: IntensityZone) -> String {
        switch zone {
        case .strength:
            return "Heavy and neural — fold in some 6–12 work to add size to the strength."
        case .hypertrophy:
            return mix.share(.strength) < 0.15
                ? "Squarely in the growth zone — add a little heavy 1–5 work to keep driving your e1RM."
                : "Squarely in the growth zone, with heavy work backing it up."
        case .endurance:
            return "High-rep and metabolic — drop the reps and add load to drive strength and size."
        }
    }

    // MARK: - Derived

    private var slices: [IntensitySlice] {
        IntensityZone.allCases.compactMap { zone in
            let count = mix.count(zone)
            guard count > 0 else { return nil }
            return IntensitySlice(zone: zone, count: count)
        }
    }

    private func color(_ zone: IntensityZone) -> Color {
        switch zone {
        case .strength:    return Ink.secondary
        case .hypertrophy: return Tint.primary
        case .endurance:   return Ink.quaternary
        }
    }

    /// Label color per zone for readability inside the bar — dark text
    /// on the bright accent and light gray, light text on the dark
    /// endurance segment.
    private func labelColor(_ zone: IntensityZone) -> Color {
        switch zone {
        case .strength:    return .black.opacity(0.7)
        case .hypertrophy: return Tint.onAccent.opacity(0.85)
        case .endurance:   return .white.opacity(0.7)
        }
    }
}

// MARK: - Chart data

private struct IntensitySlice: Identifiable {
    let id = UUID()
    let zone: IntensityZone
    let count: Int
}
