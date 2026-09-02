//
//  TodayReceiptSemantics.swift
//  vivobody
//
//  Today's adapter for the shared primary workout-receipt metric.
//

import Foundation

extension TodayScreen {
    func lastWorkoutReceiptStat(for session: WorkoutSession) -> Stat {
        let metric = session.primaryReceiptMetric(unit: unit)
        let accentsPersonalRecord = switch metric.kind {
        case .volume(.complete): lastWorkoutHasPR
        case .volume(.partial), .volume(.unavailable), .reps, .timedWork: false
        }
        let label = if case .volume(.partial) = metric.kind {
            "Known volume"
        } else {
            metric.label
        }

        return Stat(
            value: metric.value + (metric.qualifier ?? ""),
            unit: metric.unit,
            label: label,
            accessibilityLabel: metric.accessibilityLabel,
            accent: accentsPersonalRecord
        )
    }
}
