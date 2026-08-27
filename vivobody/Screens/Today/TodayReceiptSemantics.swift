//
//  TodayReceiptSemantics.swift
//  vivobody
//
//  Honest metric selection for Today's most-recent-workout receipt.
//

import Foundation

extension TodayScreen {
    func lastWorkoutVolumeStat(for session: WorkoutSession) -> Stat {
        guard session.hasReceiptTonnageAxis else {
            if session.totalReps > 0 {
                return Stat(value: "\(session.totalReps)", label: "Reps")
            }
            return Stat(
                value: DurationFormatter.compact(session.totalTimedWork),
                label: "Timed work"
            )
        }

        let summary = session.receiptTonnageSummary
        switch summary.availability {
        case .complete:
            return Stat(
                value: volumeLabel(summary.knownSubtotal),
                unit: unit.symbol,
                label: "Volume",
                accent: lastWorkoutHasPR
            )
        case .partial:
            return Stat(
                value: "\(volumeLabel(summary.knownSubtotal))+",
                unit: unit.symbol,
                label: "Known volume"
            )
        case .unavailable:
            return Stat(value: "—", label: "Volume unavailable")
        }
    }
}
