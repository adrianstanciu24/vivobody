//
//  WorkoutReceiptMetric.swift
//  vivobody
//
//  Pure value, label, unit, and accessibility semantics for the primary
//  metric shared by live, Today, and History workout receipts.
//

import Foundation

/// One honest primary metric for a workout receipt. Views remain responsible
/// for layout and styling, including personal-record treatment.
nonisolated struct WorkoutReceiptMetric: Hashable {
    enum Kind: Hashable {
        case volume(ComparableTonnageAvailability)
        case reps
        case timedWork
    }

    /// Receipt surfaces keep their established density: compact cards may
    /// abbreviate large volume while the live hero retains the full value.
    enum VolumeDisplayStyle {
        case compact
        case full
    }

    let kind: Kind
    let value: String
    let qualifier: String?
    let unit: String?
    let label: String
    let accessibilityLabel: String
}

extension WorkoutSession {
    /// Select the receipt's primary metric in stable product order: volume,
    /// repetitions, then timed work. The final timed-work fallback intentionally
    /// preserves the established `0s` receipt for sessions without logged work.
    @MainActor
    func primaryReceiptMetric(
        unit: WeightUnit,
        volumeDisplayStyle: WorkoutReceiptMetric.VolumeDisplayStyle = .compact
    ) -> WorkoutReceiptMetric {
        if hasReceiptTonnageAxis {
            return volumeReceiptMetric(unit: unit, displayStyle: volumeDisplayStyle)
        }
        let reps = totalReps
        if reps > 0 {
            let repsLabel = reps == 1 ? "rep" : "reps"
            return WorkoutReceiptMetric(
                kind: .reps,
                value: "\(reps)",
                qualifier: nil,
                unit: nil,
                label: "Reps",
                accessibilityLabel: "\(reps) \(repsLabel)"
            )
        }
        let timedWork = totalTimedWork
        let seconds = max(0, Int(timedWork.rounded()))
        let secondsLabel = seconds == 1 ? "second" : "seconds"
        return WorkoutReceiptMetric(
            kind: .timedWork,
            value: DurationFormatter.compact(timedWork),
            qualifier: nil,
            unit: nil,
            label: "Timed work",
            accessibilityLabel: "\(seconds) \(secondsLabel) of timed work"
        )
    }

    @MainActor
    private func volumeReceiptMetric(
        unit: WeightUnit,
        displayStyle: WorkoutReceiptMetric.VolumeDisplayStyle
    ) -> WorkoutReceiptMetric {
        let summary = receiptTonnageSummary
        let kind = WorkoutReceiptMetric.Kind.volume(summary.availability)
        switch summary.availability {
        case .complete:
            return WorkoutReceiptMetric(
                kind: kind,
                value: volumeValue(
                    summary.knownSubtotal,
                    unit: unit,
                    displayStyle: displayStyle
                ),
                qualifier: nil,
                unit: unit.symbol,
                label: "Volume",
                accessibilityLabel: volumeAccessibilityLabel(
                    summary.knownSubtotal,
                    unit: unit,
                    noun: "volume"
                )
            )
        case .partial:
            let knownVolumeAccessibility = volumeAccessibilityLabel(
                summary.knownSubtotal,
                unit: unit,
                noun: "known volume"
            )
            return WorkoutReceiptMetric(
                kind: kind,
                value: volumeValue(
                    summary.knownSubtotal,
                    unit: unit,
                    displayStyle: displayStyle
                ),
                qualifier: "+",
                unit: unit.symbol,
                label: "Known volume · total unavailable",
                accessibilityLabel: "\(knownVolumeAccessibility); total unavailable"
            )
        case .unavailable:
            return WorkoutReceiptMetric(
                kind: kind,
                value: "—",
                qualifier: nil,
                unit: nil,
                label: "Volume unavailable",
                accessibilityLabel: "Volume unavailable"
            )
        }
    }

    @MainActor
    private func volumeValue(
        _ canonicalPounds: Double,
        unit: WeightUnit,
        displayStyle: WorkoutReceiptMetric.VolumeDisplayStyle
    ) -> String {
        switch displayStyle {
        case .compact:
            WeightFormatter.volumeValue(canonicalPounds, unit: unit)
        case .full:
            WeightFormatter.fullVolumeValue(canonicalPounds, unit: unit)
        }
    }

    private func volumeAccessibilityLabel(
        _ canonicalPounds: Double,
        unit: WeightUnit,
        noun: String
    ) -> String {
        let expandedValue = Int(WeightFormatter.toDisplay(canonicalPounds, unit: unit))
        let unitName = switch (unit, expandedValue) {
        case (.lb, 1): "pound"
        case (.kg, 1): "kilogram"
        case (.lb, _): "pounds"
        case (.kg, _): "kilograms"
        }
        return "\(expandedValue) \(unitName) of \(noun)"
    }
}
