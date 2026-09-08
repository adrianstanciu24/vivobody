//
//  ExerciseStaminaSection.swift
//  vivobody
//
//  All-time exercise retention and individual series history.
//  Movement comparisons belong to Insights; rep traces are available on demand.
//

import Charts
import SwiftUI
import VivoKit

struct ExerciseStaminaSection: View {
    let report: ExerciseStamina?

    var body: some View {
        if let report, report.latest != nil {
            ExerciseStaminaInstrument(report: report)
        }
    }
}

struct ExerciseStaminaInstrument: View {
    let report: ExerciseStamina
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDate: Date?
    @AppStorage(SettingsKey.weightUnit) private var unitRaw: String = SettingsDefaults.weightUnit
    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Set-series stamina").font(Typography.title)
                .accessibilityIdentifier("exerciseStaminaSection").accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Space.xl) {
                if let retention = report.overallRetention {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("Overall · all time").panelLegend()
                        Text("\(Int((retention * 100).rounded()))%")
                            .font(Typography.statValue).foregroundStyle(Tint.primaryText)
                            .accessibilityLabel("Overall reps retained, \(Int((retention * 100).rounded())) percent, all time")
                            .accessibilityIdentifier("exerciseStaminaOverall")
                        Text("Reps retained compared with your first set.")
                            .font(Typography.caption).foregroundStyle(Ink.secondary)
                        Text("Based on \(report.includedSeries.count) set series · all time")
                            .font(Typography.caption).foregroundStyle(Ink.secondary)
                    }
                    trendChart
                    Text("Each point is one set series. Weight and set count may vary.")
                        .font(Typography.caption).foregroundStyle(Ink.secondary)
                    if let selectedSeries {
                        seriesLink(selectedSeries)
                    }
                } else {
                    Text("Held-back series only").font(Typography.headline).foregroundStyle(Ink.primary)
                    Text("No series available for the overall average yet.")
                        .font(Typography.caption).foregroundStyle(Ink.secondary)
                }
                NavigationLink {
                    InsightsDrilloutScreen(title: "Set series") {
                        LazyVStack(alignment: .leading, spacing: Space.lg) {
                            ForEach(report.series.reversed()) { series in
                                seriesLink(series)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("View set series")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(Typography.body).frame(minHeight: 44)
                }
                .accessibilityIdentifier("exerciseStaminaSeriesLink")
            }
            .padding(Space.xl).contentCard()
        }
    }

    private var selectedSeries: StaminaSeries? {
        guard let selectedDate else { return nil }
        return report.includedSeries.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private func seriesLink(_ series: StaminaSeries) -> some View {
        NavigationLink {
            InsightsDrilloutScreen(title: "Set series") {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text(series.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(Typography.title)
                    Text("\(loadLabel(series)) · \(series.reps.count) sets")
                        .font(Typography.headline)
                    Text(series.isHeldBack ? "Held back" : "\(Int((series.retention * 100).rounded()))% reps retained")
                        .font(Typography.headline).foregroundStyle(Tint.primaryText)
                    repsChart(series)
                    if series.isHeldBack {
                        Text("◆ Held back · higher logged RIR. Excluded from the overall average.")
                    } else if series.hasUnratedSets {
                        Text("Effort not fully logged")
                    }
                }
                .font(Typography.body)
            }
        } label: {
            HStack(spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(series.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(Typography.headline).foregroundStyle(Ink.primary)
                    Text("\(loadLabel(series)) · \(series.reps.count) sets · \(series.isHeldBack ? "Held back" : "\(Int((series.retention * 100).rounded()))% retained")")
                        .font(Typography.caption).foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Typography.caption).foregroundStyle(Ink.secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(Space.lg).contentCard()
            .contentShape(Rectangle())
        }
        .accessibilityLabel(seriesAccessibility(series))
        .accessibilityIdentifier(series.id == report.latest?.id ? "exerciseStaminaLatestSeries" : "exerciseStaminaSeries-\(series.id)")
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
            ForEach(report.includedSeries) { series in
                PointMark(x: .value("Date", series.date), y: .value("Held", series.retention * 100))
                    .foregroundStyle(Tint.primary).symbolSize(45)
            }
        }
        .chartYScale(domain: 0 ... max(110, (report.includedSeries.map(\.retention).max() ?? 1) * 110))
        .chartXSelection(value: $selectedDate)
        .chartXScale(range: .plotDimension(startPadding: 12, endPadding: 24))
        .chartXAxis {
            AxisMarks(values: Array(Set([report.includedSeries.first?.date, report.includedSeries.last?.date].compactMap(\.self))).sorted()) { value in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel(anchor: value.as(Date.self) == report.includedSeries.first?.date ? .topLeading : .topTrailing) {
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
        .accessibilityLabel("Set-series history. All time. Each point is one series. " + report.includedSeries.map {
            "\($0.date.formatted(date: .abbreviated, time: .omitted)), \(Int(($0.retention * 100).rounded())) percent of first-set reps"
        }.joined(separator: ". "))
    }

    private var trendSpansYears: Bool {
        guard let first = report.includedSeries.first, let last = report.includedSeries.last else { return false }
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
