//
//  StrengthTrajectorySection.swift
//  vivobody
//
//  Strength as a real curve, not a bar. The muscle sections read the
//  development model; this asks the other question — is the LOAD on
//  the bar going up? — and answers it the way a lifter actually wants
//  to see: an estimated-1RM line over time, with the all-time best
//  drawn as a record line to chase and each new PR marked on the
//  curve. The lift name and axis units identify exactly what is being
//  measured, while current, best, and all-history change sit below.
//
//  e1RM (Epley) is charted rather than raw top weight so a 5×5 and an
//  8×3 sit on one comparable strength axis. Data comes from
//  `progressByExercise` (the same series the Me tab charts); the
//  trend, PR projection, and ordering come from `strengthOutlook`.
//

import VivoKit
import SwiftUI
import Charts

struct StrengthTrajectorySection: View {
    let board: StrengthOutlookBoard
    let progress: [ExerciseProgress]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit
    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(title: "Strength")

            if !board.hasAny {
                Text("Strength trends appear once you've logged a weighted lift across a few sessions.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if let stat = currentStat {
                    liftHeading(stat)
                    chart(for: stat)
                    liftStats(stat)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart

    private func liftHeading(_ stat: StrengthOutlookStat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(stat.exercise)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Estimated 1RM over time")
                    .panelLegend()
            }

            Spacer(minLength: Space.sm)

            if stat.isFreshPR {
                Text("NEW PR")
                    .font(Typography.micro)
                    .foregroundStyle(Tint.primary)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 2)
                    .overlay(Capsule().stroke(Tint.primaryDim, lineWidth: 1))
                    .accessibilityLabel("New personal record")
            }
        }
    }

    private func chart(for stat: StrengthOutlookStat) -> some View {
        let points = e1rmSeries(for: stat.exercise)
        let color = prColor(stat.trend)
        let best = WeightFormatter.toDisplay(stat.bestE1RM, unit: unit)

        return Chart {
            RuleMark(y: .value("Best", best))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Tint.primary.opacity(Opacity.medium))
                .annotation(position: .top, alignment: .trailing) {
                    Text("All-time best · \(WeightFormatter.string(stat.bestE1RM, unit: unit))")
                        .font(Typography.metricMicro)
                        .foregroundStyle(Tint.primary.opacity(Opacity.strong))
                }

            ForEach(points) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("e1RM", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(color)

                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("e1RM", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.22), color.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                if p.isPR {
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("e1RM", p.value)
                    )
                    .symbolSize(50)
                    .foregroundStyle(Tint.primary)
                }
            }

            // The latest sample glows — a soft halo under a bright core
            // — so "where you are now" pins the eye at the line's end.
            if let last = points.last {
                PointMark(
                    x: .value("Date", last.date),
                    y: .value("e1RM", last.value)
                )
                .symbolSize(260)
                .foregroundStyle(color.opacity(0.22))
                PointMark(
                    x: .value("Date", last.date),
                    y: .value("e1RM", last.value)
                )
                .symbolSize(70)
                .foregroundStyle(color)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .chartXScale(
            range: .plotDimension(
                startPadding: Space.sm,
                endPadding: Space.xl
            )
        )
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text("\(Int(amount.rounded())) \(unit.symbol)")
                            .font(Typography.metricMicro)
                            .foregroundStyle(Ink.tertiary)
                    }
                }
            }
        }
        .frame(height: 200)
        .padding(.top, Space.sm)
        .accessibilityLabel("\(stat.exercise) estimated one-rep max over time")
    }

    private func liftStats(_ stat: StrengthOutlookStat) -> some View {
        let change = changeSinceFirst(for: stat)
        return StatStrip(
            stats: [
                Stat(value: WeightFormatter.string(stat.currentE1RM, unit: unit, includeUnit: false), unit: unit.symbol, label: "Current"),
                Stat(value: WeightFormatter.string(stat.bestE1RM, unit: unit, includeUnit: false), unit: unit.symbol, label: "Best"),
                Stat(value: change.value, unit: unit.symbol, label: change.label, accent: change.isPositive),
            ],
            valueFont: Typography.statValue,
            edgeAligned: true
        )
        .padding(.top, Space.xs)
    }

    // MARK: - Derived

    private var currentStat: StrengthOutlookStat? { board.stats.first }

    /// e1RM points (display units) for one lift, each flagged when it
    /// set a new estimated-1RM record at the moment it was logged.
    private func e1rmSeries(for exercise: String) -> [E1RMPoint] {
        guard let series = progress.first(where: { $0.name.caseInsensitiveCompare(exercise) == .orderedSame }) else {
            return []
        }
        var runningMax = -Double.infinity
        var out: [E1RMPoint] = []
        for point in series.points where point.estimated1RM > 0 {
            let isPR = point.estimated1RM > runningMax
            if isPR { runningMax = point.estimated1RM }
            out.append(
                E1RMPoint(
                    date: point.date,
                    value: WeightFormatter.toDisplay(point.estimated1RM, unit: unit),
                    isPR: isPR
                )
            )
        }
        return out
    }

    private func prColor(_ trend: PRTrend) -> Color {
        switch trend {
        case .climbing:  return Tint.primary
        case .plateaued: return Ink.secondary
        case .slipping:  return Tint.danger
        }
    }

    private func changeSinceFirst(for stat: StrengthOutlookStat) -> (value: String, label: String, isPositive: Bool) {
        guard
            let series = progress.first(where: { $0.name.caseInsensitiveCompare(stat.exercise) == .orderedSame }),
            let first = series.points.first,
            first.estimated1RM > 0
        else {
            return ("—", "Change", false)
        }

        let delta = stat.currentE1RM - first.estimated1RM
        let percentage = delta / first.estimated1RM * 100
        let sign = delta > 0 ? "+" : delta < 0 ? "−" : ""
        let value = sign + WeightFormatter.string(abs(delta), unit: unit, includeUnit: false)
        let percent = "\(sign)\(Int(abs(percentage).rounded()))%"
        return (value, "Change (\(percent))", delta > 0)
    }
}

// MARK: - Chart point

/// A single e1RM sample mapped into display units for the chart, with
/// the record flag so PR sessions can be dotted on the line.
private struct E1RMPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isPR: Bool
}
