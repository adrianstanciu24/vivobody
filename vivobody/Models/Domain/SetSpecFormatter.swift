//
//  SetSpecFormatter.swift
//  vivobody
//
//  Single source of truth for the load-aware inline set string that
//  appears in widget snapshots,
//  Live Activity content, and in-app set rows. Extracted from the
//  three identical implementations that lived in WidgetSnapshotWriter,
//  WorkoutLiveActivityController, and Exercise.setLabel.
//

import Foundation

nonisolated enum SetSpecFormatter {
    /// Format one set's working metrics as a compact inline string.
    ///
    ///   • external reps   → "135 x 8"
    ///   • bodyweight reps → "BW x 8" or "BW + 25 x 8"
    ///   • assisted reps   → "40 assist x 8"
    ///   • duration        → "45s", optionally prefixed by load.
    ///
    /// Weight is rendered in the user's unit without a suffix (callers
    /// append the unit label where needed).
    static func format(
        weight: Double,
        reps: Int,
        duration: TimeInterval,
        trackingMode: TrackingMode,
        loadMode: ExerciseLoadMode,
        unit: WeightUnit
    ) -> String {
        switch trackingMode {
        case .reps:
            guard let load = loadMode.loggedLoadLabel(
                weight,
                unit: unit,
                includeUnit: false
            ) else { return "\(reps) reps" }
            return "\(load) x \(reps)"
        case .duration:
            let time = DurationFormatter.compact(duration)
            guard weight > 0,
                  let load = loadMode.loggedLoadLabel(
                    weight,
                    unit: unit,
                    includeUnit: false
                  ) else { return time }
            return "\(load) x \(time)"
        }
    }
}
