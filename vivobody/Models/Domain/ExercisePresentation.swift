//
//  ExercisePresentation.swift
//  vivobody
//
//  Shared presentation vocabulary for exercise type, custom-exercise
//  authoring, and logged-load semantics. Duration is a hold for isometric
//  strength; invalid legacy combinations retain neutral time terminology.
//  Summary and accessibility helpers keep
//  bodyweight, added load, assistance, and non-comparable resistance distinct
//  at every UI boundary.
//

import Foundation

extension ExerciseModality {
    /// Custom authoring exposes the lifter-focused work types in product order.
    nonisolated static let customExerciseChoices: [Self] = [
        .dynamicStrength,
        .isometricStrength,
        .power,
    ]

    /// Broader category used where the logging measure has its own row.
    nonisolated var categoryDisplayName: String {
        switch self {
        case .dynamicStrength, .isometricStrength: "Strength"
        case .power: "Power / Explosive"
        }
    }

    nonisolated var measureDisplayName: String {
        switch self {
        case .dynamicStrength, .power: "Reps"
        case .isometricStrength: "Hold"
        }
    }

    /// User-facing noun for one duration-tracked effort.
    nonisolated var durationLabel: String {
        switch self {
        case .isometricStrength: "Hold"
        case .dynamicStrength, .power: "Time"
        }
    }

    nonisolated var durationLabelLowercased: String {
        switch self {
        case .isometricStrength: "hold"
        case .dynamicStrength, .power: "time"
        }
    }

    /// Natural plural for summaries whose timed sets have a range.
    nonisolated var durationCountLabel: String {
        switch self {
        case .isometricStrength: "holds"
        case .dynamicStrength, .power: "timed sets"
        }
    }
}

extension ExerciseLoadMode {
    /// The custom editor names the value the user enters. Assistance is
    /// intentionally shorter than the underlying bodyweight subtraction.
    nonisolated var customExerciseChoiceName: String {
        self == .assistanceSubtracted ? "Assistance" : displayName
    }

    /// One concrete example keeps the uncommon Assistance choice legible
    /// without turning the picker into a load-model explanation.
    nonisolated var customExerciseChoiceLabel: String {
        switch self {
        case .assistanceSubtracted:
            "Assistance · Assisted pull-up/chin-up machine"
        case .external, .bodyweightAdded, .nonComparable:
            customExerciseChoiceName
        }
    }

    /// Copy for a duration-record celebration. Comparable loaded
    /// isometrics rank duration only as the tie-breaker at the standing
    /// best load, so calling the result the all-time longest hold would
    /// overstate what the record comparison established.
    nonisolated func durationRecordDetail(modality: ExerciseModality) -> String {
        supportsLoadComparison
            ? "Longer at this load"
            : "Longest \(modality.durationLabelLowercased)"
    }

    /// Compact raw-load wording for plan and history summaries. Unlike a
    /// bare weight string, this preserves what the logged number means.
    nonisolated func summaryLoadLabel(
        _ loggedWeight: Double,
        unit: WeightUnit,
        includeUnit: Bool = true
    ) -> String? {
        let weight = max(0, loggedWeight)
        let formatted = WeightFormatter.string(weight, unit: unit, includeUnit: includeUnit)

        switch self {
        case .external:
            return weight > 0 ? formatted : nil
        case .bodyweightAdded:
            return weight > 0 ? "BW + \(formatted)" : "BW"
        case .assistanceSubtracted:
            return weight > 0 ? "\(formatted) assist" : "Unassisted"
        case .nonComparable:
            return weight > 0 ? "\(formatted) resistance" : nil
        }
    }

    /// Semantic range counterpart to `summaryLoadLabel`. Used for
    /// pyramid/wave plans whose explicit sets do not share one load.
    nonisolated func summaryLoadRangeLabel(
        _ firstWeight: Double,
        _ secondWeight: Double,
        unit: WeightUnit
    ) -> String? {
        let lower = max(0, min(firstWeight, secondWeight))
        let upper = max(0, max(firstWeight, secondWeight))
        guard lower != upper else {
            return summaryLoadLabel(lower, unit: unit)
        }

        let lowerValue = WeightFormatter.string(lower, unit: unit, includeUnit: false)
        let upperValue = WeightFormatter.string(upper, unit: unit, includeUnit: true)
        switch self {
        case .external:
            return "\(lowerValue)–\(upperValue)"
        case .bodyweightAdded:
            return lower > 0
                ? "BW + \(lowerValue)–\(upperValue)"
                : "BW–BW + \(upperValue)"
        case .assistanceSubtracted:
            return lower > 0
                ? "\(lowerValue)–\(upperValue) assist"
                : "Unassisted–\(upperValue) assist"
        case .nonComparable:
            return upper > 0 ? "\(lowerValue)–\(upperValue) resistance" : nil
        }
    }

    /// Spoken description for a rep-based completion action. Assistance
    /// is deliberately phrased as assistance—not resistance—so increasing
    /// the logged number never sounds like a heavier performance.
    nonisolated func completionAccessibilityLabel(
        reps: Int,
        loggedWeight: Double,
        unit: WeightUnit
    ) -> String {
        let base = "\(reps) reps"
        guard let load = accessibilityLoadDescription(loggedWeight, unit: unit) else {
            return base
        }
        return "\(base) \(load)"
    }

    /// Phrase that can follow either a reps count or a duration.
    nonisolated func accessibilityLoadDescription(
        _ loggedWeight: Double,
        unit: WeightUnit
    ) -> String? {
        let weight = max(0, loggedWeight)
        let value = WeightFormatter.string(weight, unit: unit, includeUnit: false)
        let unitName = unit.displayName.lowercased()

        switch self {
        case .external:
            return weight > 0 ? "at \(value) \(unitName)" : nil
        case .bodyweightAdded:
            return weight > 0
                ? "at bodyweight plus \(value) \(unitName)"
                : "at bodyweight"
        case .assistanceSubtracted:
            return weight > 0
                ? "with \(value) \(unitName) of assistance"
                : "unassisted"
        case .nonComparable:
            return weight > 0
                ? "with \(value) \(unitName) of resistance"
                : nil
        }
    }
}
