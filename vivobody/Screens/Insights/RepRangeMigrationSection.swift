//
//  RepRangeMigrationSection.swift
//  vivobody
//
//  The rep-range drift section for the Insights tab. IntensityMix
//  reads today's emphasis; this charts the longer arc — the average
//  reps per working set, week over week, so a quiet program shift
//  (a hypertrophy block sneaking everything up to 12s, or a strength
//  block pulling sets back toward triples) is visible as a curve, not
//  a vibe. Two faint reference lines mark the IntensityMix zone
//  boundaries (5 = strength / hypertrophy edge, 12 = hypertrophy /
//  endurance edge) so the drift reads against the zones it crosses.
//
//  Data comes from `repRangeMigration`; the chart follows the
//  `StrengthTrajectorySection` pattern (LineMark + AreaMark gradient,
//  monotone interpolation, token-driven axes).
//

import VivoKit
import SwiftUI
import Charts

struct RepRangeMigrationSection: View {
    let report: RepRangeMigrationReport

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Rep trend", trailing: "12 weeks")

            if !report.hasTrend {
                Text("Rep-range trends appear once you've logged reps-mode sets across at least three different weeks.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                insight
                chart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Insight

    @ViewBuilder
    private var insight: some View {
        Text(insightLine)
            .font(Typography.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var insightLine: AttributedString {
        let earlier = formatted(report.earlierAverage)
        let current = formatted(report.currentAverage)

        switch report.verdict {
        case .towardStrength:
            var lead = AttributedString("Your average set has drifted \(earlier) → \(current) reps — trending heavier.")
            lead.foregroundColor = Tint.danger
            return lead
        case .towardEndurance:
            var lead = AttributedString("Your average set has drifted \(earlier) → \(current) reps — trending higher-rep.")
            lead.foregroundColor = Tint.primary
            return lead
        case .stable:
            var lead = AttributedString("Your average rep range has held steady around \(current) reps/set.")
            lead.foregroundColor = Ink.secondary
            return lead
        }
    }

    /// One-decimal reps formatting for the insight copy.
    private func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    // MARK: - Chart

    private var chart: some View {
        let color = Tint.primary

        return Chart {
            // Zone boundary reference lines.
            RuleMark(y: .value("Strength edge", 5))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                .foregroundStyle(Ink.tertiary.opacity(Opacity.soft))
                .annotation(position: .top, alignment: .trailing) {
                    Text("strength")
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.tertiary.opacity(Opacity.medium))
                }

            RuleMark(y: .value("Endurance edge", 12))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                .foregroundStyle(Ink.tertiary.opacity(Opacity.soft))
                .annotation(position: .bottom, alignment: .trailing) {
                    Text("endurance")
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.tertiary.opacity(Opacity.medium))
                }

            ForEach(report.points) { p in
                LineMark(
                    x: .value("Week", p.weekStart),
                    y: .value("Avg reps", p.averageReps)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(color)

                AreaMark(
                    x: .value("Week", p.weekStart),
                    y: .value("Avg reps", p.averageReps)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.22), color.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(height: 160)
        .padding(.top, Space.sm)
        .contentCard()
        .accessibilityLabel("Average reps per set over 12 weeks")
    }
}
