//
//  ActivePersonalRecordPresentation.swift
//  vivobody
//
//  Active-workout formatting for a classified live personal record. Domain
//  comparison stays numeric; this UI boundary prepares the persisted hero,
//  unit, and detail strings consumed by the celebration.
//

import Foundation
import VivoKit

nonisolated enum ActivePersonalRecordPresentation {
    static func payload(
        for record: LivePersonalRecord,
        candidate: LivePersonalRecordCandidate,
        unit: WeightUnit
    ) -> ActiveSetPersonalRecordPayload? {
        switch record.advancement {
        case .load:
            guard record.performance.primaryMetricKind == .load else { return nil }
            return ActiveSetPersonalRecordPayload(
                value: WeightFormatter.string(
                    record.performance.primaryMetric,
                    unit: unit,
                    includeUnit: false
                ),
                unit: unit.symbol,
                detail: candidate.loadProfile.mode == .external
                    ? "\(candidate.exerciseName) · New max"
                    : "\(candidate.exerciseName) · New effective load"
            )

        case .repetitions:
            let load = candidate.loadProfile.mode.loggedLoadLabel(
                candidate.loggedWeight,
                unit: unit,
                includeUnit: true
            )
            return ActiveSetPersonalRecordPayload(
                value: "\(candidate.repetitions)",
                unit: candidate.repetitions == 1 ? "rep" : "reps",
                detail: load.map { "\(candidate.exerciseName) · at \($0)" }
                    ?? candidate.exerciseName
            )

        case .duration:
            return ActiveSetPersonalRecordPayload(
                value: DurationFormatter.string(candidate.duration),
                unit: nil,
                detail: "\(candidate.exerciseName) · \(candidate.loadProfile.mode.durationRecordDetail(modality: candidate.modality))"
            )
        }
    }
}
