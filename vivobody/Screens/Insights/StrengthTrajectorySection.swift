//
//  StrengthTrajectorySection.swift
//  vivobody
//
//  Strength as a real curve, not a bar. The muscle sections read the
//  development model; this asks the other question — is the LOAD on
//  the bar going up? — and answers it with a recent estimated-1RM
//  trajectory. One current value, one period change, and one endpoint
//  carry the hierarchy; the all-time-best rule appears only when it
//  differs from the current value.
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
                    liftSummary(stat)
                    chart(for: stat)
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

    private func liftSummary(_ stat: StrengthOutlookStat) -> some View {
        let points = chartPoints(for: stat.exercise)
        let delta = chartDelta(points)

        return HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(WeightFormatter.string(stat.currentE1RM, unit: unit, includeUnit: false))
                    .font(Typography.statValue)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                Text(unit.symbol)
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
            }

            Spacer(minLength: Space.md)

            if let delta {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(WeightFormatter.deltaString(delta.value, unit: unit))
                        .font(Typography.metricInline)
                        .foregroundStyle(delta.value > 0 ? Tint.primary : Ink.secondary)
                        .monospacedDigit()
                    Text(delta.label)
                        .panelLegend()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summaryAccessibilityLabel(stat: stat, delta: delta))
    }

    private func chart(for stat: StrengthOutlookStat) -> some View {
        let points = chartPoints(for: stat.exercise)
        let color = prColor(stat.trend)
        let best = WeightFormatter.toDisplay(stat.bestE1RM, unit: unit)
        let showsBestRule = abs(stat.currentE1RM - stat.bestE1RM) > 1e-6
        let domain = yDomain(for: points, including: showsBestRule ? best : nil)

        return Chart {
            if showsBestRule {
                RuleMark(y: .value("Best", best))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Ink.tertiary.opacity(Opacity.medium))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("BEST · \(WeightFormatter.string(stat.bestE1RM, unit: unit))")
                            .font(Typography.metricMicro)
                            .foregroundStyle(Ink.tertiary)
                    }
            }

            ForEach(points) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("e1RM", WeightFormatter.toDisplay(p.value, unit: unit))
                )
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(color)
            }

            if let last = points.last {
                let value = WeightFormatter.toDisplay(last.value, unit: unit)
                PointMark(
                    x: .value("Date", last.date),
                    y: .value("e1RM", value)
                )
                .symbolSize(150)
                .foregroundStyle(color.opacity(0.18))
                PointMark(
                    x: .value("Date", last.date),
                    y: .value("e1RM", value)
                )
                .symbolSize(55)
                .foregroundStyle(color)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
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
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
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
        .frame(height: 180)
        .accessibilityLabel("\(stat.exercise) estimated one-rep max over time")
    }

    // MARK: - Derived

    private var currentStat: StrengthOutlookStat? { board.stats.first }

    private func e1rmSeries(for exercise: String) -> [E1RMPoint] {
        guard let series = progress.first(where: { $0.name.caseInsensitiveCompare(exercise) == .orderedSame }) else {
            return []
        }
        return series.points.compactMap { point in
            guard point.estimated1RM > 0 else { return nil }
            return E1RMPoint(date: point.date, value: point.estimated1RM)
        }
    }

    private func chartPoints(for exercise: String) -> [E1RMPoint] {
        let all = e1rmSeries(for: exercise)
        guard let latest = all.last else { return [] }
        let cutoff = latest.date.addingTimeInterval(-84 * 86_400)
        let recent = all.filter { $0.date >= cutoff }
        return recent.count >= 2 ? recent : Array(all.suffix(2))
    }

    private func chartDelta(_ points: [E1RMPoint]) -> (value: Double, label: String)? {
        guard let first = points.first, let last = points.last, first.id != last.id else { return nil }
        let days = max(1, Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1)
        let label: String
        if days >= 14 {
            label = "\(max(2, Int((Double(days) / 7).rounded()))) WK CHANGE"
        } else {
            label = "\(days) DAY CHANGE"
        }
        return (last.value - first.value, label)
    }

    private func yDomain(for points: [E1RMPoint], including additionalValue: Double?) -> ClosedRange<Double> {
        var values = points.map { WeightFormatter.toDisplay($0.value, unit: unit) }
        if let additionalValue {
            values.append(additionalValue)
        }
        guard let low = values.min(), let high = values.max() else { return 0 ... 1 }
        let minimumSpread = unit == .kg ? 5.0 : 10.0
        let spread = max(high - low, minimumSpread)
        let padding = spread * 0.14
        return max(0, low - padding) ... (high + padding)
    }

    private func summaryAccessibilityLabel(
        stat: StrengthOutlookStat,
        delta: (value: Double, label: String)?
    ) -> String {
        var label = "Current estimated one-rep max, \(WeightFormatter.string(stat.currentE1RM, unit: unit))"
        if let delta {
            label += ", \(WeightFormatter.deltaString(delta.value, unit: unit)), \(delta.label.lowercased())"
        }
        return label
    }

    private func prColor(_ trend: PRTrend) -> Color {
        switch trend {
        case .climbing:  return Tint.primary
        case .plateaued: return Ink.secondary
        case .slipping:  return Tint.danger
        }
    }

}

// MARK: - Chart point

private struct E1RMPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
