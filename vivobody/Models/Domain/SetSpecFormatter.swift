//
//  SetSpecFormatter.swift
//  vivobody
//
//  Single source of truth for the inline "weight x reps" or
//  "weight x duration" string that appears in widget snapshots,
//  Live Activity content, and in-app set rows. Extracted from the
//  three identical implementations that lived in WidgetSnapshotWriter,
//  WorkoutLiveActivityController, and Exercise.setLabel.
//

import Foundation

nonisolated enum SetSpecFormatter {
    /// Format one set's working metrics as a compact inline string.
    ///
    ///   • reps     → "135 x 8"
    ///   • duration → "45s", or "25 x 1:30" when the hold is loaded.
    ///
    /// Weight is rendered in the user's unit without a suffix (callers
    /// append the unit label where needed).
    static func format(
        weight: Double,
        reps: Int,
        duration: TimeInterval,
        trackingMode: TrackingMode,
        unit: WeightUnit
    ) -> String {
        switch trackingMode {
        case .reps:
            return "\(WeightFormatter.string(weight, unit: unit, includeUnit: false)) x \(reps)"
        case .duration:
            let time = DurationFormatter.compact(duration)
            guard weight > 0 else { return time }
            return "\(WeightFormatter.string(weight, unit: unit, includeUnit: false)) x \(time)"
        }
    }
}
