//
//  ExerciseDetailChartSemantics.swift
//  vivobody
//
//  Pure metric, range, point, placeholder, record, and accessibility
//  presentation for the Exercise Detail progress instrument.
//

import Foundation

nonisolated enum ExerciseDetailChartMetric: String, CaseIterable, Identifiable {
    case weight, e1rm, volume, reps

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .weight: "Load"
        case .e1rm: "e1RM"
        case .volume: "Volume"
        case .reps: "Reps"
        }
    }
}

nonisolated enum ExerciseDetailChartRange: String, CaseIterable, Identifiable {
    case oneMonth, threeMonths, sixMonths, all

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .all: "All"
        }
    }

    var trendLabel: String {
        self == .all ? "All-time" : label
    }

    func cutoff(now: Date, calendar: Calendar) -> Date? {
        let months: Int? = switch self {
        case .oneMonth: -1
        case .threeMonths: -3
        case .sixMonths: -6
        case .all: nil
        }
        return months.flatMap {
            calendar.date(byAdding: .month, value: $0, to: now)
        }
    }
}

/// A chart-ready value detached from SwiftUI and the live archive. Construction
/// uses the read model's single captured `now`, so future filtering and range
/// cutoffs cannot disagree during one render.
nonisolated struct ExerciseDetailChartPresentation: Hashable {
    struct PlottablePoint: Identifiable, Hashable {
        let point: ExerciseProgressPoint
        let value: Double
        let valueLabel: String

        var id: UUID {
            point.id
        }
    }

    struct Placeholder: Hashable {
        let legend: String
        let unitLabel: String?
        let plottedValue: String?
        let showsNextSlot: Bool
        let accessibilityLabel: String
    }

    let effectiveMetric: ExerciseDetailChartMetric
    let availableMetrics: [ExerciseDetailChartMetric]
    let range: ExerciseDetailChartRange
    let progressThroughNow: ExerciseProgress?
    let strengthTrendReadinessDates: [Date]
    let visiblePoints: [ExerciseProgressPoint]
    let plottablePoints: [PlottablePoint]
    let personalRecordPointIDs: Set<UUID>
    let metricAccessibilityName: String
    let chartAccessibilityLabel: String
    let chartAccessibilityValue: String
    let placeholder: Placeholder?
    let isStrengthTrend: Bool
    let showsRangeControls: Bool

    init(
        readModel: ExerciseDetailReadModel,
        selectedMetric: ExerciseDetailChartMetric,
        range: ExerciseDetailChartRange,
        unit: WeightUnit,
        calendar: Calendar = .current
    ) {
        let exercise = readModel.exercise
        let progress = readModel.progress
        let metrics = Self.availableMetrics(for: exercise)
        let metric = metrics.contains(selectedMetric) ? selectedMetric : metrics[0]
        let cutoff = range.cutoff(now: readModel.now, calendar: calendar)
        let visible = Self.visiblePoints(
            progress: progress,
            exercise: exercise,
            metric: metric,
            cutoff: cutoff,
            now: readModel.now
        )
        let plottable = visible.compactMap { point -> PlottablePoint? in
            guard let value = Self.chartValue(
                for: point,
                exercise: exercise,
                metric: metric,
                unit: unit
            ) else { return nil }
            return PlottablePoint(
                point: point,
                value: value,
                valueLabel: Self.accessibilityValue(
                    value,
                    exercise: exercise,
                    metric: metric,
                    unit: unit
                )
            )
        }
        let metricName = Self.metricAccessibilityName(
            exercise: exercise,
            metric: metric
        )
        let singleSessionInRange = Self.singleSessionIsInRange(
            sessionCount: readModel.sessionCount,
            latest: readModel.latestHistoryInstance,
            cutoff: cutoff
        )

        effectiveMetric = metric
        availableMetrics = metrics
        self.range = range
        progressThroughNow = progress.map {
            ExerciseProgress(
                catalogID: $0.catalogID,
                catalogItemID: $0.catalogItemID,
                name: $0.name,
                group: $0.group,
                points: $0.points.filter { $0.date <= readModel.now }
            )
        }
        strengthTrendReadinessDates = readModel.strengthTrendReadinessDates
            .filter { $0 <= readModel.now }
        visiblePoints = visible
        plottablePoints = plottable
        personalRecordPointIDs = Self.personalRecordPointIDs(
            progress: progress,
            exercise: exercise,
            metric: metric
        )
        metricAccessibilityName = metricName
        chartAccessibilityLabel = "\(exercise.name) \(metricName.lowercased()) progress"
        chartAccessibilityValue = Self.accessibilitySummary(
            points: plottable
        )
        isStrengthTrend = metric == .e1rm
        showsRangeControls = metric == .e1rm
            ? readModel.strengthTrendStat != nil
            : readModel.sessionCount >= 2
        placeholder = plottable.count < 2
            ? Self.placeholder(
                points: plottable,
                readModel: readModel,
                metric: metric,
                unit: unit,
                singleSessionInRange: singleSessionInRange
            )
            : nil
    }

    private static func availableMetrics(
        for exercise: ExerciseDetailReadModel.ExerciseDescriptor
    ) -> [ExerciseDetailChartMetric] {
        if exercise.trackingMode == .reps, !exercise.tracksResistance {
            return [.reps]
        }
        return exercise.supportsEstimatedOneRepMax
            ? [.weight, .e1rm, .volume]
            : [.weight]
    }

    private static func visiblePoints(
        progress: ExerciseProgress?,
        exercise: ExerciseDetailReadModel.ExerciseDescriptor,
        metric: ExerciseDetailChartMetric,
        cutoff: Date?,
        now: Date
    ) -> [ExerciseProgressPoint] {
        guard let progress else { return [] }
        return progress.points.filter { point in
            guard point.date <= now else { return false }
            if let cutoff, point.date < cutoff { return false }
            switch metric {
            case .weight where exercise.performanceSemanticKind.comparesLoad:
                return point.effectiveTopLoad != nil
            case .e1rm:
                return point.estimated1RM > 0
            case .volume:
                return point.comparableTonnageAvailability == .complete
            case .weight, .reps:
                return true
            }
        }
    }

    private static func personalRecordPointIDs(
        progress: ExerciseProgress?,
        exercise: ExerciseDetailReadModel.ExerciseDescriptor,
        metric: ExerciseDetailChartMetric
    ) -> Set<UUID> {
        guard let progress, exercise.supportsPerformanceRecord else { return [] }
        if exercise.trackingMode == .reps, metric == .volume { return [] }
        if exercise.trackingMode == .duration || metric == .weight {
            return Set(progress.points.filter(\.isStrengthPR).map(\.id))
        }

        var result = Set<UUID>()
        var runningMaximum = -Double.infinity
        for point in progress.points {
            let value = point.estimated1RM
            guard value > 0, value > runningMaximum else { continue }
            runningMaximum = value
            result.insert(point.id)
        }
        return result
    }

    private static func chartValue(
        for point: ExerciseProgressPoint,
        exercise: ExerciseDetailReadModel.ExerciseDescriptor,
        metric: ExerciseDetailChartMetric,
        unit: WeightUnit
    ) -> Double? {
        if exercise.trackingMode == .duration {
            if exercise.performanceSemanticKind.comparesLoad {
                return point.effectiveTopLoad.map {
                    WeightFormatter.toDisplay($0, unit: unit)
                }
            }
            return point.topDuration
        }
        switch metric {
        case .weight:
            return point.historyTopLoad.map {
                WeightFormatter.toDisplay($0, unit: unit)
            }
        case .e1rm:
            return WeightFormatter.toDisplay(point.estimated1RM, unit: unit)
        case .volume:
            guard point.comparableTonnageAvailability == .complete else {
                return nil
            }
            return WeightFormatter.toDisplay(point.totalVolume, unit: unit)
        case .reps:
            return point.topReps > 0 ? Double(point.topReps) : nil
        }
    }

    private static func metricAccessibilityName(
        exercise: ExerciseDetailReadModel.ExerciseDescriptor,
        metric: ExerciseDetailChartMetric
    ) -> String {
        if exercise.trackingMode == .duration {
            return exercise.performanceSemanticKind.comparesLoad
                ? "Effective load"
                : "Duration"
        }
        return switch metric {
        case .weight: "Load"
        case .e1rm: "Estimated one-rep max"
        case .volume: "Volume"
        case .reps: "Reps"
        }
    }

    private static func accessibilitySummary(
        points: [PlottablePoint]
    ) -> String {
        guard let first = points.first, let last = points.last else {
            return "No progress data"
        }
        let firstDate = first.point.date.formatted(date: .abbreviated, time: .omitted)
        let lastDate = last.point.date.formatted(date: .abbreviated, time: .omitted)
        return "\(points.count) sessions. From \(first.valueLabel) on \(firstDate) to \(last.valueLabel) on \(lastDate)."
    }

    private static func placeholder(
        points: [PlottablePoint],
        readModel: ExerciseDetailReadModel,
        metric: ExerciseDetailChartMetric,
        unit: WeightUnit,
        singleSessionInRange: Bool
    ) -> Placeholder {
        let exercise = readModel.exercise
        let pointValue = points.count == 1 ? points[0] : nil
        let fallbackValue = pointValue == nil ? singleSessionValue(
            readModel: readModel,
            metric: metric,
            unit: unit,
            isInRange: singleSessionInRange
        ) : nil
        let plottedValue = pointValue?.valueLabel ?? fallbackValue.map {
            accessibilityValue(
                $0,
                exercise: exercise,
                metric: metric,
                unit: unit
            )
        }
        let legend: String = switch readModel.sessionCount {
        case 0:
            "Trend unlocks at 2 sessions"
        case 1:
            singleSessionInRange
                ? "One more session draws the line"
                : "No sessions in this range"
        default:
            points.isEmpty
                ? "No sessions in this range"
                : "Only one session in this range"
        }
        let message = readModel.sessionCount == 0
            || (readModel.sessionCount == 1 && singleSessionInRange)
            ? "Complete this exercise in another workout to draw its trend."
            : "Choose a longer range or log another session."
        let unitLabel: String? = if metric == .reps {
            "reps"
        } else if exercise.trackingMode == .duration,
                  !exercise.performanceSemanticKind.comparesLoad
        {
            nil
        } else {
            unit.symbol
        }
        return Placeholder(
            legend: legend,
            unitLabel: unitLabel,
            plottedValue: plottedValue,
            showsNextSlot: readModel.sessionCount < 2,
            accessibilityLabel: "Progress chart unavailable. \(message)"
        )
    }

    private static func singleSessionIsInRange(
        sessionCount: Int,
        latest: ExerciseHistoryInstance?,
        cutoff: Date?
    ) -> Bool {
        guard sessionCount == 1, let latest else { return false }
        return cutoff.map { latest.date >= $0 } ?? true
    }

    private static func singleSessionValue(
        readModel: ExerciseDetailReadModel,
        metric: ExerciseDetailChartMetric,
        unit: WeightUnit,
        isInRange: Bool
    ) -> Double? {
        guard isInRange, let latest = readModel.latestHistoryInstance else {
            return nil
        }
        let exercise = readModel.exercise
        let set = latest.representativeSet
        if exercise.trackingMode == .duration {
            if exercise.performanceSemanticKind.comparesLoad {
                return latest.effectiveRepresentativeLoad.map {
                    WeightFormatter.toDisplay($0, unit: unit)
                }
            }
            return set.duration > 0 ? set.duration : nil
        }
        if metric == .reps {
            return set.reps > 0 ? Double(set.reps) : nil
        }
        guard metric == .weight else { return nil }
        let historyLoad = latest.effectiveRepresentativeLoad
            ?? (latest.loadMode == .nonComparable ? max(0, set.weight) : nil)
        return historyLoad.map { WeightFormatter.toDisplay($0, unit: unit) }
    }

    private static func accessibilityValue(
        _ value: Double,
        exercise: ExerciseDetailReadModel.ExerciseDescriptor,
        metric: ExerciseDetailChartMetric,
        unit: WeightUnit
    ) -> String {
        if metric == .reps { return "\(Int(value.rounded())) reps" }
        if exercise.trackingMode == .duration,
           !exercise.performanceSemanticKind.comparesLoad
        {
            return DurationFormatter.string(value)
        }
        let formatted = value.formatted(
            .number.precision(.fractionLength(0 ... 1))
        )
        return "\(formatted) \(unit.symbol)"
    }
}
