//
//  WorkoutLoadComparisonChart.swift
//  vivobody
//
//  Shared Health-inspired cumulative-load instrument for workout receipts:
//  one common scale, orange for this workout, and gray for archive average.
//

import Charts
import SwiftUI
import VivoKit

struct WorkoutLoadComparisonChart: View {
    let comparison: WorkoutLoadComparison
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            readouts
            chart
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Workout load comparison")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("workoutLoadComparisonChart")
    }

    private var readouts: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Space.xxl) {
                readout(
                    label: "This workout",
                    value: comparison.currentTotal,
                    color: Tint.primaryText
                )
                Spacer(minLength: Space.sm)
                readout(
                    label: "Average",
                    value: comparison.averageTotal,
                    color: Ink.secondary
                )
            }

            VStack(alignment: .leading, spacing: Space.lg) {
                readout(
                    label: "This workout",
                    value: comparison.currentTotal,
                    color: Tint.primaryText
                )
                readout(
                    label: "Average",
                    value: comparison.averageTotal,
                    color: Ink.secondary
                )
            }
        }
    }

    private func readout(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(color)
            }
            HStack(alignment: .lastTextBaseline, spacing: Space.xs) {
                Text(WeightFormatter.volumeValue(value, unit: unit))
                    .font(Typography.statValueCompact)
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit.symbol)
                    .font(Typography.metricUnit)
                    .foregroundStyle(color.opacity(Opacity.emphasis))
            }
        }
    }

    private var chart: some View {
        VStack(spacing: Space.xs) {
            Chart {
                ForEach(comparison.averagePoints) { point in
                    LineMark(
                        x: .value("Workout progress", point.progress),
                        y: .value("Average load", displayValue(point.value)),
                        series: .value("Series", "Average")
                    )
                    .foregroundStyle(Ink.tertiary)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)
                }

                ForEach(comparison.currentPoints) { point in
                    LineMark(
                        x: .value("Workout progress", point.progress),
                        y: .value("This workout load", displayValue(point.value)),
                        series: .value("Series", "This workout")
                    )
                    .foregroundStyle(Tint.primary)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)
                }

                if let averageEnd = comparison.averagePoints.last {
                    endpoint(averageEnd, color: Ink.tertiary, label: "Average finish")
                }
                if let currentEnd = comparison.currentPoints.last {
                    endpoint(currentEnd, color: Tint.primary, label: "This workout finish")
                }
            }
            .chartXScale(domain: 0 ... 1, range: .plotDimension(startPadding: 4, endPadding: 4))
            .chartYScale(domain: 0 ... displayValue(comparison.scaleMaximum))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 126)

            HStack {
                Text("Start")
                Spacer()
                Text("Finish")
            }
            .font(Typography.metricMicro)
            .foregroundStyle(Ink.tertiary)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .frame(height: 150)
    }

    private func endpoint(
        _ point: WorkoutLoadPoint,
        color: Color,
        label: String
    ) -> some ChartContent {
        PointMark(
            x: .value("Progress", point.progress),
            y: .value(label, displayValue(point.value))
        )
        .foregroundStyle(color)
        .symbolSize(48)
    }

    private func displayValue(_ canonicalPounds: Double) -> Double {
        WeightFormatter.toDisplay(canonicalPounds, unit: unit)
    }

    private var accessibilityValue: String {
        let current = spokenVolume(comparison.currentTotal)
        let average = spokenVolume(comparison.averageTotal)
        let count = comparison.averageWorkoutCount
        let workoutNoun = count == 1 ? "workout" : "workouts"
        return "This workout, \(current). Average, \(average), across \(count) comparable \(workoutNoun). Lines show cumulative load from workout start to finish."
    }

    private func spokenVolume(_ canonicalPounds: Double) -> String {
        let value = Int(displayValue(canonicalPounds).rounded())
        let noun = switch (unit, value) {
        case (.lb, 1): "pound"
        case (.kg, 1): "kilogram"
        case (.lb, _): "pounds"
        case (.kg, _): "kilograms"
        }
        return "\(value) \(noun) of comparable volume"
    }
}
