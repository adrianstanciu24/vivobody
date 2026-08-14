//
//  ExerciseStrengthTrendCard.swift
//  vivobody
//
//  The per-exercise estimated-strength instrument used by Exercise
//  Detail's e1RM progress mode. Before four comparable workouts span
//  two weeks it renders a bold dormant curve with honest sample/time
//  progress. Once qualified, it presents the cached StrengthOutlook
//  verdict and the selected range of rep-adjusted e1RM history.
//

import Charts
import SwiftUI
import VivoKit

struct ExerciseStrengthTrendCard: View {
    let exerciseName: String
    let progress: ExerciseProgress?
    let stat: StrengthOutlookStat?
    let readinessDates: [Date]
    let visiblePoints: [ExerciseProgressPoint]
    let rangeLabel: String
    let unit: WeightUnit

    var body: some View {
        if let stat {
            populatedCard(stat)
        } else {
            buildingCard
        }
    }

    // MARK: - Building state

    private var buildingCard: some View {
        let state = buildingState

        return VStack(alignment: .leading, spacing: Space.lg) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                    Text("Trend building")
                        .panelLegendType()
                        .foregroundStyle(Tint.primary)
                    Spacer(minLength: Space.sm)
                    Text(state.progressLabel)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Trend building")
                        .panelLegendType()
                        .foregroundStyle(Tint.primary)
                    Text(state.progressLabel)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                }
            }

            Text("Four workouts make a curve")
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            ExerciseStrengthCurvePlaceholder(
                workouts: state.workouts,
                spanDays: state.spanDays
            )
            .frame(height: 142)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(exerciseName)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(state.guidance(exerciseName: exerciseName))
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.xl)
        .contentCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel(exerciseName: exerciseName))
    }

    private var buildingState: ExerciseStrengthBuildingState {
        let now = Date()
        let calendar = Calendar.current
        let progressDates = (progress?.points ?? [])
            .filter { $0.date <= now && $0.estimated1RM > 0 }
            .map(\.date)
        let eligibleDates = readinessDates.isEmpty
            ? progressDates
            : readinessDates.filter { $0 <= now }
        let window = Array(
            eligibleDates
                .sorted()
                .suffix(StrengthOutlookBoard.recentWindow)
        )
        let latest = window.last
        let first = window.first ?? latest
        let span: Int = if let first, let latest {
            max(
                0,
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: first),
                    to: calendar.startOfDay(for: latest)
                ).day ?? 0
            )
        } else {
            0
        }
        return ExerciseStrengthBuildingState(
            workouts: min(window.count, StrengthOutlookBoard.minPoints),
            spanDays: min(span, StrengthOutlookBoard.minimumSpanDays)
        )
    }

    // MARK: - Qualified trend

    private func populatedCard(_ stat: StrengthOutlookStat) -> some View {
        let now = Date()
        let points = visiblePoints
            .filter { $0.date <= now && $0.estimated1RM > 0 }
            .sorted { $0.date < $1.date }
        let delta = chartDelta(points)
        let color = trendColor(stat.trend)

        return VStack(alignment: .leading, spacing: Space.lg) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                    Text("Recent e1RM · \(confidenceTitle(stat.confidence))")
                        .panelLegendType()
                        .foregroundStyle(color)
                    Spacer(minLength: Space.sm)
                    Text("LAST \(stat.sampleCount) WORKOUTS · \(stat.spanDays) DAYS")
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Recent e1RM · \(confidenceTitle(stat.confidence))")
                        .panelLegendType()
                        .foregroundStyle(color)
                    Text("LAST \(stat.sampleCount) WORKOUTS · \(stat.spanDays) DAYS")
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                }
            }

            Text(trendHeadline(stat.trend))
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: Space.md) {
                    currentValue(stat)
                    Spacer(minLength: Space.sm)
                    if let delta {
                        rangeChange(delta, alignment: .trailing)
                    }
                }

                VStack(alignment: .leading, spacing: Space.sm) {
                    currentValue(stat)
                    if let delta {
                        rangeChange(delta, alignment: .leading)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summaryAccessibilityLabel(stat: stat, delta: delta))

            trendRead(stat, color: color)

            if points.count >= 2 {
                strengthChart(points: points, stat: stat, color: color)
            } else {
                rangePlaceholder
            }
        }
        .padding(Space.xl)
        .contentCard()
    }

    private func currentValue(_ stat: StrengthOutlookStat) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(WeightFormatter.string(stat.currentE1RM, unit: unit, includeUnit: false))
                .font(Typography.statValue)
                .foregroundStyle(Ink.primary)
                .monospacedDigit()
            Text(unit.symbol)
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
        }
    }

    private func rangeChange(
        _ delta: Double,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(WeightFormatter.deltaString(delta, unit: unit))
                .font(Typography.metricInline)
                .foregroundStyle(
                    delta > 0
                        ? Tint.primary
                        : (delta < 0 ? Tint.danger : Ink.secondary)
                )
                .monospacedDigit()
            Text("\(rangeLabel.uppercased()) NET CHANGE")
                .panelLegend()
        }
    }

    private func trendRead(_ stat: StrengthOutlookStat, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .top, spacing: Space.md) {
                Image(systemName: trendSymbol(stat.trend))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                Text(trendDetail(stat))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(estimateRecencyLabel(stat.daysSinceLastEstimate))
                .panelLegend()
        }
        .padding(Space.md)
        .contentChip(tint: color.opacity(0.10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(trendTitle(stat.trend)). \(trendDetail(stat)) \(estimateRecencyLabel(stat.daysSinceLastEstimate))."
        )
    }

    private func strengthChart(
        points: [ExerciseProgressPoint],
        stat: StrengthOutlookStat,
        color: Color
    ) -> some View {
        let best = WeightFormatter.toDisplay(stat.bestE1RM, unit: unit)
        let current = WeightFormatter.toDisplay(stat.currentE1RM, unit: unit)
        let showsBestRule = abs(current - best) > 1e-6
        let domain = yDomain(
            points: points,
            additionalValue: showsBestRule ? best : nil
        )

        return Chart {
            if showsBestRule {
                RuleMark(y: .value("e1RM high", best))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Ink.tertiary.opacity(Opacity.medium))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("e1RM HIGH · \(WeightFormatter.string(stat.bestE1RM, unit: unit))")
                            .font(Typography.metricMicro)
                            .foregroundStyle(Ink.tertiary)
                    }
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(
                        "Estimated 1RM",
                        WeightFormatter.toDisplay(point.estimated1RM, unit: unit)
                    )
                )
                .interpolationMethod(.monotone)
                .lineStyle(
                    StrokeStyle(
                        lineWidth: 2.5,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .foregroundStyle(color)
            }

            if let last = points.last {
                let value = WeightFormatter.toDisplay(last.estimated1RM, unit: unit)
                PointMark(
                    x: .value("Date", last.date),
                    y: .value("Estimated 1RM", value)
                )
                .symbolSize(160)
                .foregroundStyle(color.opacity(0.20))
                PointMark(
                    x: .value("Date", last.date),
                    y: .value("Estimated 1RM", value)
                )
                .symbolSize(58)
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
        .frame(height: 190)
        .accessibilityLabel("\(exerciseName) estimated one-rep max over \(rangeLabel.lowercased())")
        .accessibilityValue(chartAccessibilityValue(points: points, stat: stat))
    }

    private var rangePlaceholder: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Rectangle()
                        .fill(Surface.edge)
                        .frame(height: 0.5)
                    if index < 2 { Spacer() }
                }
            }

            Text("Choose a longer range to draw this curve")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(height: 190)
        .accessibilityLabel("Choose a longer range to draw the estimated strength curve")
    }

    // MARK: - Derived presentation

    private func chartDelta(_ points: [ExerciseProgressPoint]) -> Double? {
        guard let first = points.first, let last = points.last,
              first.id != last.id else { return nil }
        return last.estimated1RM - first.estimated1RM
    }

    private func yDomain(
        points: [ExerciseProgressPoint],
        additionalValue: Double?
    ) -> ClosedRange<Double> {
        var values = points.map {
            WeightFormatter.toDisplay($0.estimated1RM, unit: unit)
        }
        if let additionalValue { values.append(additionalValue) }
        guard let low = values.min(), let high = values.max() else { return 0 ... 1 }
        let minimumSpread = unit == .kg ? 5.0 : 10.0
        let spread = max(high - low, minimumSpread)
        let padding = spread * 0.14
        return max(0, low - padding) ... (high + padding)
    }

    private func confidenceTitle(_ confidence: StrengthTrendConfidence) -> String {
        confidence == .established ? "Established" : "Early read"
    }

    private func trendHeadline(_ trend: PRTrend) -> String {
        switch trend {
        case .climbing: "Strength is climbing"
        case .plateaued: "Holding steady"
        case .slipping: "Strength is trending down"
        }
    }

    private func trendTitle(_ trend: PRTrend) -> String {
        switch trend {
        case .climbing: "Climbing"
        case .plateaued: "Holding steady"
        case .slipping: "Trending down"
        }
    }

    private func trendSymbol(_ trend: PRTrend) -> String {
        switch trend {
        case .climbing: "arrow.up.right"
        case .plateaued: "arrow.right"
        case .slipping: "arrow.down.right"
        }
    }

    private func trendColor(_ trend: PRTrend) -> Color {
        switch trend {
        case .climbing: Tint.primary
        case .plateaued: Ink.secondary
        case .slipping: Tint.danger
        }
    }

    private func trendDetail(_ stat: StrengthOutlookStat) -> String {
        let base = if stat.isRecentE1RMHigh {
            "Your latest 1–12 rep set produced a new estimated-strength high."
        } else if stat.isLatestE1RMHigh {
            "Your latest strength estimate remains your all-time e1RM high."
        } else if let days = stat.daysToE1RMHigh {
            "The established line meets your e1RM high in about \(days) \(days == 1 ? "day" : "days")."
        } else {
            switch stat.trend {
            case .climbing:
                "Your recent strength estimates are moving up."
            case .plateaued:
                "Your recent strength estimates are holding in a narrow range."
            case .slipping:
                "Your recent strength estimates are moving down."
            }
        }

        if let estimateDays = stat.daysSinceLastEstimate,
           let trainedDays = stat.daysSinceLastTrained,
           trainedDays < estimateDays
        {
            return base + " Newer sets were outside 1–12 reps or lacked a comparable load."
        }
        return base
    }

    private func estimateRecencyLabel(_ days: Int?) -> String {
        guard let days else { return "Estimate date unknown" }
        switch days {
        case 0: return "Estimate today"
        case 1: return "Estimate 1d ago"
        case 2 ..< 14: return "Estimate \(days)d ago"
        case 14 ..< 70: return "Estimate \(days / 7)w ago"
        default: return "Estimate \(days / 30)mo ago"
        }
    }

    private func summaryAccessibilityLabel(
        stat: StrengthOutlookStat,
        delta: Double?
    ) -> String {
        var label = "Current estimated one-rep max, \(WeightFormatter.string(stat.currentE1RM, unit: unit))"
        if let delta {
            label += ", \(WeightFormatter.deltaString(delta, unit: unit)), \(rangeLabel.lowercased()) net change"
        }
        return label
    }

    private func chartAccessibilityValue(
        points: [ExerciseProgressPoint],
        stat: StrengthOutlookStat
    ) -> String {
        guard let first = points.first, let last = points.last else {
            return "No points in this range"
        }
        return "\(points.count) workouts, from \(WeightFormatter.string(first.estimated1RM, unit: unit)) to \(WeightFormatter.string(last.estimated1RM, unit: unit)); all-time e1RM high \(WeightFormatter.string(stat.bestE1RM, unit: unit))."
    }
}

// MARK: - Building-state instrument

private struct ExerciseStrengthBuildingState {
    let workouts: Int
    let spanDays: Int

    var progressLabel: String {
        "\(workouts)/\(StrengthOutlookBoard.minPoints) WORKOUTS · \(spanDays)/\(StrengthOutlookBoard.minimumSpanDays) DAYS"
    }

    func guidance(exerciseName: String) -> String {
        "Repeat \(exerciseName) for 1–12 reps until the series reaches \(StrengthOutlookBoard.minPoints) workouts across at least \(StrengthOutlookBoard.minimumSpanDays) days. Its rep-adjusted strength curve will appear here."
    }

    func accessibilityLabel(exerciseName: String) -> String {
        "Strength trend building for \(exerciseName). \(workouts) of \(StrengthOutlookBoard.minPoints) workouts and \(spanDays) of \(StrengthOutlookBoard.minimumSpanDays) days. \(guidance(exerciseName: exerciseName))"
    }
}

/// A dormant version of the populated e1RM chart. The dashed curve is
/// future structure, never invented training data. Qualifying workouts
/// light its four nodes while elapsed span reveals the connecting trace.
private struct ExerciseStrengthCurvePlaceholder: View {
    let workouts: Int
    let spanDays: Int

    private var revealedFraction: CGFloat {
        let workoutProgress = CGFloat(workouts) / CGFloat(StrengthOutlookBoard.minPoints)
        let dayProgress = CGFloat(spanDays) / CGFloat(StrengthOutlookBoard.minimumSpanDays)
        return min(1, max(0, min(workoutProgress, dayProgress)))
    }

    var body: some View {
        VStack(spacing: Space.xs) {
            GeometryReader { proxy in
                let points = ExerciseStrengthPlaceholderGeometry.points(in: proxy.size)

                ZStack {
                    VStack(spacing: 0) {
                        placeholderRule
                        Spacer()
                        placeholderRule
                        Spacer()
                        placeholderRule
                    }
                    .padding(.vertical, 8)

                    ExerciseStrengthPlaceholderPath()
                        .stroke(
                            Ink.primary.opacity(0.16),
                            style: StrokeStyle(
                                lineWidth: 2,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: [7, 7]
                            )
                        )

                    if revealedFraction > 0 {
                        ExerciseStrengthPlaceholderPath()
                            .trim(from: 0, to: revealedFraction)
                            .stroke(
                                Tint.primary,
                                style: StrokeStyle(
                                    lineWidth: 3,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                            .shadow(color: Tint.primary.opacity(0.55), radius: 8)
                    }

                    ForEach(points.indices, id: \.self) { index in
                        let isFilled = index < workouts
                        Circle()
                            .fill(isFilled ? Tint.primary : Surface.cardTintBright)
                            .frame(
                                width: isFilled ? 13 : 10,
                                height: isFilled ? 13 : 10
                            )
                            .overlay {
                                Circle()
                                    .stroke(
                                        isFilled
                                            ? Tint.primary.opacity(0.75)
                                            : Surface.edgeBright,
                                        lineWidth: 1
                                    )
                            }
                            .shadow(
                                color: isFilled ? Tint.primary.opacity(0.58) : .clear,
                                radius: 7
                            )
                            .position(points[index])
                    }
                }
            }

            HStack {
                Text("First estimate")
                    .panelLegend()
                Spacer()
                Text("Trend ready")
                    .panelLegend()
            }
        }
        .accessibilityHidden(true)
    }

    private var placeholderRule: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
    }
}

private nonisolated enum ExerciseStrengthPlaceholderGeometry {
    private static let normalizedPoints = [
        CGPoint(x: 0.02, y: 0.76),
        CGPoint(x: 0.34, y: 0.53),
        CGPoint(x: 0.66, y: 0.62),
        CGPoint(x: 0.98, y: 0.20),
    ]

    static func points(in size: CGSize) -> [CGPoint] {
        let horizontalInset: CGFloat = 8
        let verticalInset: CGFloat = 8
        let width = max(0, size.width - horizontalInset * 2)
        let height = max(0, size.height - verticalInset * 2)
        return normalizedPoints.map { point in
            CGPoint(
                x: horizontalInset + point.x * width,
                y: verticalInset + point.y * height
            )
        }
    }
}

private struct ExerciseStrengthPlaceholderPath: Shape {
    func path(in rect: CGRect) -> Path {
        let points = ExerciseStrengthPlaceholderGeometry.points(in: rect.size)
        guard let first = points.first else { return Path() }

        var path = Path()
        path.move(to: first)
        for index in 1 ..< points.count {
            let previous = points[index - 1]
            let next = points[index]
            let midpointX = (previous.x + next.x) / 2
            path.addCurve(
                to: next,
                control1: CGPoint(x: midpointX, y: previous.y),
                control2: CGPoint(x: midpointX, y: next.y)
            )
        }
        return path
    }
}
