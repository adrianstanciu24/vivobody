//
//  ExerciseStaminaSection.swift
//  vivobody
//
//  Reuses one immutable stamina instrument in Exercise Detail and Insights.
//  A rep-by-set trace and matched-load history expose both shape and scope;
//  held-back sets have diamond marks and equivalent accessibility semantics.
//

import Charts
import SwiftUI
import VivoKit

struct ExerciseStaminaSection: View {
    let report: ExerciseStamina?
    let isUnlocked: Bool
    let onUnlock: () -> Void

    var body: some View {
        if let report, report.latest != nil {
            if isUnlocked {
                ExerciseStaminaInstrument(report: report)
            } else {
                LockedProCover(title: "Set-series stamina", action: onUnlock) {
                    ExerciseStaminaInstrument(report: report)
                }
            }
        }
    }
}

struct ExerciseStaminaInstrument: View {
    let report: ExerciseStamina
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(SettingsKey.weightUnit) private var unitRaw: String = SettingsDefaults.weightUnit
    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    var body: some View {
        if let latest = report.latest {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Set-series stamina").font(Typography.title)
                    .accessibilityIdentifier("exerciseStaminaSection").accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        let layout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.md))
                        layout {
                            Text(latest.isHeldBack ? "Held back" : "\(Int((latest.retention * 100).rounded()))%")
                                .font(Typography.statValue).foregroundStyle(Tint.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            if !latest.isHeldBack {
                                Text("reps held").font(Typography.headline).foregroundStyle(Ink.secondary)
                            }
                        }
                        Text("\(loadLabel(latest)) · \(latest.reps.count) sets")
                            .font(Typography.headline).foregroundStyle(Ink.secondary)
                        Text(latest.date, format: .dateTime.month(.abbreviated).day().year())
                            .font(Typography.caption).foregroundStyle(Ink.tertiary)
                    }
                    repsChart(latest)
                    if latest.isHeldBack {
                        Text("◆ Held back · higher logged RIR")
                            .font(Typography.caption).foregroundStyle(Ink.secondary)
                    } else if latest.hasUnratedSets {
                        Text("Effort not fully logged").font(Typography.caption).foregroundStyle(Ink.secondary)
                    }
                    if report.trend.count >= 2 {
                        Rectangle().fill(Surface.edge).frame(height: 0.5)
                        Text("Same-load history").font(Typography.headline).foregroundStyle(Ink.secondary)
                        trendChart
                    }
                }
                .padding(Space.xl).contentCard()
            }
        }
    }

    private func loadLabel(_ series: StaminaSeries) -> String {
        if series.loadProfile.mode == .nonComparable { return "Unquantified resistance" }
        let weight = WeightFormatter.string(series.weight, unit: unit)
        switch series.loadProfile.mode {
        case .assistanceSubtracted: return "\(weight) assistance"
        case .bodyweightAdded: return "\(weight) added"
        default: return weight
        }
    }

    private func repsChart(_ series: StaminaSeries) -> some View {
        Chart {
            ForEach(series.reps.indices, id: \.self) { index in
                LineMark(x: .value("Set", index + 1), y: .value("Reps", series.reps[index]))
                    .foregroundStyle(Tint.primary)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                PointMark(x: .value("Set", index + 1), y: .value("Reps", series.reps[index]))
                    .symbol(series.heldBackIndices.contains(index) ? .diamond : .circle)
                    .symbolSize(65)
                    .foregroundStyle(series.heldBackIndices.contains(index) ? Ink.secondary : Tint.primary)
                    .annotation(position: .top, spacing: 8) {
                        if series.reps.count <= 6 || index == 0 || index == series.reps.count - 1 {
                            Text("\(series.reps[index])").font(Typography.metricInline)
                                .foregroundStyle(Ink.primary).monospacedDigit()
                        }
                    }
            }
        }
        .chartYScale(domain: 0 ... Double(max(1, series.reps.max() ?? 1)) * (dynamicTypeSize.isAccessibilitySize ? 1.7 : 1.35))
        .chartXScale(domain: 0.75 ... Double(series.reps.count) + 0.25)
        .chartXAxis {
            AxisMarks(values: series.reps.count <= 6 ? Array(1 ... series.reps.count) : [1, series.reps.count / 2, series.reps.count]) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self) {
                        Text("\(index)").font(Typography.metricMicro).foregroundStyle(Ink.secondary)
                    }
                }
            }
        }
        .chartXAxisLabel("Set", alignment: .trailing)
        .chartYAxis(.hidden)
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 280 : InsightChartCanvas.hero)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("exerciseStaminaTrace")
        .accessibilityLabel(seriesAccessibility(series))
    }

    private var trendChart: some View {
        Chart {
            RuleMark(y: .value("First-set reps", 100)).foregroundStyle(Ink.quaternary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            ForEach(report.trend) { series in
                LineMark(x: .value("Date", series.date), y: .value("Held", series.retention * 100))
                    .foregroundStyle(Tint.primary).lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Date", series.date), y: .value("Held", series.retention * 100))
                    .foregroundStyle(Tint.primary).symbolSize(28)
            }
        }
        .chartYScale(domain: 0 ... max(110, (report.trend.map(\.retention).max() ?? 1) * 110))
        .chartXScale(range: .plotDimension(startPadding: 12, endPadding: 24))
        .chartXAxis {
            AxisMarks(values: [report.trend.first?.date, report.trend.last?.date].compactMap(\.self)) { value in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel(anchor: value.as(Date.self) == report.trend.first?.date ? .topLeading : .topTrailing) {
                    if let date = value.as(Date.self) {
                        VStack(spacing: 0) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                            if trendSpansYears {
                                Text(date, format: .dateTime.year())
                            }
                        }
                        .font(Typography.metricMicro).foregroundStyle(Ink.secondary)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .fixedSize()
                    }
                }
            }
        }
        .chartYAxis { InsightChartAxis.values { "\(Int($0))%" } }
        .frame(height: InsightChartCanvas.hero)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("exerciseStaminaTrend")
        .accessibilityLabel("Same-load history. All time. " + report.trend.map {
            "\($0.date.formatted(date: .abbreviated, time: .omitted)), \(Int(($0.retention * 100).rounded())) percent of first-set reps"
        }.joined(separator: ". "))
    }

    private var trendSpansYears: Bool {
        guard let first = report.trend.first, let last = report.trend.last else { return false }
        return Calendar.current.component(.year, from: first.date) != Calendar.current.component(.year, from: last.date)
    }

    private func seriesAccessibility(_ series: StaminaSeries) -> String {
        let sets = series.reps.indices.map { index in
            let rating = series.rir[index].map { "RIR \($0)" } ?? "RIR not logged"
            return "Set \(index + 1), \(series.reps[index]) reps, \(rating)\(series.heldBackIndices.contains(index) ? ", held back" : "")"
        }.joined(separator: ". ")
        return "\(series.name). \(loadLabel(series)). \(series.date.formatted(date: .abbreviated, time: .omitted)). \(sets). \(series.isHeldBack ? "Held-back series, excluded from pattern retention." : "Holds \(Int((series.retention * 100).rounded())) percent of first-set reps.")"
    }
}
