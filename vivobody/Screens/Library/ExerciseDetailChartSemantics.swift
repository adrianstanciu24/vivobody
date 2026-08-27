//
//  ExerciseDetailChartSemantics.swift
//  vivobody
//
//  Metric availability, filtering, records, and values for Exercise Detail charts.
//

import Foundation

extension ExerciseDetailScreen {
    func visiblePoints(from progress: ExerciseProgress?) -> [ExerciseProgressPoint] {
        guard let progress else { return [] }
        let now = Date()
        var points = progress.points.filter { $0.date <= now }
        if let cutoff = range.cutoff {
            points = points.filter { $0.date >= cutoff }
        }
        if effectiveChartMetric == .weight,
           item.performanceSemanticKind.comparesLoad
        {
            points = points.filter { $0.effectiveTopLoad != nil }
        } else if effectiveChartMetric == .e1rm {
            points = points.filter { $0.estimated1RM > 0 }
        } else if effectiveChartMetric == .volume {
            points = points.filter {
                $0.comparableTonnageAvailability == .complete
            }
        }
        return points
    }

    func prPointIDs(from progress: ExerciseProgress?) -> Set<UUID> {
        guard let progress,
              supportsPerformanceRecord else { return [] }
        if item.trackingMode == .reps, effectiveChartMetric == .volume {
            return []
        }
        if item.trackingMode == .duration || effectiveChartMetric == .weight {
            return Set(progress.points.filter(\.isStrengthPR).map(\.id))
        }
        var ids = Set<UUID>()
        var runningMax = -Double.infinity
        for point in progress.points {
            let value = point.estimated1RM
            guard value > 0 else { continue }
            if value > runningMax {
                runningMax = value
                ids.insert(point.id)
            }
        }
        return ids
    }

    func chartValue(for point: ExerciseProgressPoint) -> Double? {
        if item.trackingMode == .duration {
            if item.performanceSemanticKind.comparesLoad {
                guard let effectiveLoad = point.effectiveTopLoad else { return nil }
                return WeightFormatter.toDisplay(effectiveLoad, unit: unit)
            }
            return point.topDuration
        }
        switch effectiveChartMetric {
        case .weight:
            guard let historyLoad = point.historyTopLoad else { return nil }
            return WeightFormatter.toDisplay(historyLoad, unit: unit)
        case .e1rm:
            return WeightFormatter.toDisplay(point.estimated1RM, unit: unit)
        case .volume:
            guard point.comparableTonnageAvailability == .complete else { return nil }
            return WeightFormatter.toDisplay(point.totalVolume, unit: unit)
        case .reps:
            return point.topReps > 0 ? Double(point.topReps) : nil
        }
    }

    var effectiveChartMetric: ChartMetric {
        availableChartMetrics.contains(chartMetric) ? chartMetric : availableChartMetrics[0]
    }

    var availableChartMetrics: [ChartMetric] {
        if item.trackingMode == .reps, !item.tracksResistance { return [.reps] }
        return supportsEstimatedOneRepMax ? [.weight, .e1rm, .volume] : [.weight]
    }

    var supportsPerformanceRecord: Bool {
        item.performanceSemanticKind.supportsRecord
    }

    var supportsEstimatedOneRepMax: Bool {
        item.modality.supportsEstimatedOneRepMax(
            for: item.trackingMode,
            loadMode: item.loadMode
        )
    }

    var strengthTrendStat: StrengthOutlookStat? {
        guard supportsEstimatedOneRepMax else { return nil }
        return sessionAnalytics?.strength.stat(forHistoryKey: historyKey)
    }

    var strengthTrendReadinessDates: [Date] {
        guard supportsEstimatedOneRepMax else { return [] }
        return sessionAnalytics?.exerciseHistorySummaries[historyKey]?
            .estimatedOneRepMaxDates ?? []
    }
}
