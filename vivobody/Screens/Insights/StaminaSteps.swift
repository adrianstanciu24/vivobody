//
//  StaminaSteps.swift
//  vivobody
//
//  Set-to-set rep instruments for set-series stamina: a split bar of fewer,
//  same, and more reps, and the typical reps for each set position. Colors
//  stay neutral because fewer reps in later sets is normal training.
//

import Charts
import SwiftUI
import VivoKit

struct StaminaStepsRow: View {
    let pattern: SetSeriesStamina.Pattern
    let showsSeriesCount: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(pattern.pattern.displayName).font(Typography.headline).foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                if showsSeriesCount {
                    Text("\(pattern.series.count) series")
                        .font(Typography.caption).foregroundStyle(Ink.secondary).monospacedDigit()
                }
            }
            RepStepsSummary(steps: pattern.steps)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityRead(pattern))
    }

    static func accessibilityRead(_ pattern: SetSeriesStamina.Pattern) -> String {
        "\(pattern.pattern.displayName), \(pattern.series.count) series: \(pattern.steps.accessibilityRead)"
    }
}

extension RepSteps {
    var accessibilityRead: String {
        "fewer reps on \(fewer) of \(total) set-to-set steps, same on \(same), more on \(more)"
    }
}

struct RepStepsSummary: View {
    let steps: RepSteps

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            RepStepsBar(steps: steps)
            RepStepsLegend(steps: steps)
        }
    }
}

private extension RepSteps.Kind {
    var label: String {
        switch self {
        case .fewer: "Fewer"
        case .same: "Same"
        case .more: "More"
        }
    }

    var color: Color {
        switch self {
        case .fewer: Tint.primaryDim
        case .same: Tint.primary
        case .more: Ink.tertiary
        }
    }
}

private struct RepStepsBar: View {
    let steps: RepSteps
    private let gap: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let visible = RepSteps.Kind.allCases.filter { steps.count($0) > 0 }
            let available = max(0, proxy.size.width - gap * CGFloat(max(0, visible.count - 1)))
            HStack(spacing: gap) {
                ForEach(visible, id: \.self) { kind in
                    Rectangle().fill(kind.color)
                        .frame(width: available * CGFloat(steps.count(kind)) / CGFloat(max(1, steps.total)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Surface.cardTintBright)
            .clipShape(Capsule())
        }
        .frame(height: InstrumentBarHeight.standard)
        .accessibilityHidden(true)
    }
}

private struct RepStepsLegend: View {
    let steps: RepSteps

    var body: some View {
        let percentages = steps.percentages
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.lg) { items(percentages) }
            VStack(alignment: .leading, spacing: Space.xs) { items(percentages) }
        }
    }

    private func items(_ percentages: [RepSteps.Kind: Int]) -> some View {
        ForEach(RepSteps.Kind.allCases, id: \.self) { kind in
            HStack(spacing: Space.xs) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(kind.color)
                    .frame(width: 10, height: 10)
                Text(kind.label).font(Typography.caption).foregroundStyle(Ink.secondary)
                Text("\(percentages[kind] ?? 0)%")
                    .font(Typography.metricInline).foregroundStyle(Ink.primary).monospacedDigit()
            }
            .fixedSize()
        }
    }
}

struct TypicalSetsBlock: View {
    let title: String
    let sets: [TypicalSet]
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Typical reps per set").panelLegend()
            TypicalSetsChart(title: title, sets: sets, identifier: identifier)
        }
    }
}

private struct TypicalSetsChart: View {
    let title: String
    let sets: [TypicalSet]
    let identifier: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Chart {
            if let first = sets.first {
                RuleMark(y: .value("First set", first.reps)).foregroundStyle(Ink.quaternary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            ForEach(sets) { set in
                LineMark(x: .value("Set", set.number), y: .value("Reps", set.reps))
                    .foregroundStyle(Tint.primary)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                PointMark(x: .value("Set", set.number), y: .value("Reps", set.reps))
                    .symbolSize(65)
                    .foregroundStyle(Tint.primary)
                    // Labels under the first-set rule go below their point so they never cross it.
                    .annotation(position: set.reps < (sets.first?.reps ?? 0) ? .bottom : .top, spacing: 8) {
                        Text(Self.repsText(set.reps)).font(Typography.metricInline)
                            .foregroundStyle(Ink.primary).monospacedDigit()
                    }
            }
        }
        .chartYScale(domain: 0 ... max(1, sets.map(\.reps).max() ?? 1) * (dynamicTypeSize.isAccessibilitySize ? 1.7 : 1.35))
        .chartXScale(domain: 0.75 ... Double(max(1, sets.count)) + 0.25)
        .chartXAxis {
            AxisMarks(values: sets.map(\.number)) { value in
                AxisValueLabel {
                    if let number = value.as(Int.self) {
                        Text("\(number)").font(Typography.metricMicro).foregroundStyle(Ink.secondary)
                    }
                }
            }
        }
        .chartXAxisLabel("Set", alignment: .trailing)
        .chartYAxis(.hidden)
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 280 : InsightChartCanvas.hero)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(accessibilityLabel)
    }

    private static func repsText(_ reps: Double) -> String {
        reps.formatted(.number.precision(.fractionLength(0 ... 1)))
    }

    private var accessibilityLabel: String {
        let reads = sets.map { "Set \($0.number), \(Self.repsText($0.reps)) reps from \($0.seriesCount) series" }
        return "\(title) typical reps per set. All time. " + reads.joined(separator: ". ")
    }
}
