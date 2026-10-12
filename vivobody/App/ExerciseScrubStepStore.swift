//
//  ExerciseScrubStepStore.swift
//  vivobody
//
//  Per-exercise scrub increments shared by the active workout, Edit Set,
//  and the exercise editor. Nil means "never chosen", so the caller's
//  default (unit plate step or 5s) still applies after a unit change.
//

import Foundation

nonisolated struct ExerciseScrubSteps: Equatable {
    /// Weight step in the display unit that was active when it was picked.
    var weight: Double?
    /// Duration step in seconds.
    var duration: Double?
}

nonisolated enum ExerciseScrubStepStore {
    static func load(
        catalogID: String?,
        catalogItemID: UUID,
        defaults: UserDefaults = .standard
    ) -> ExerciseScrubSteps {
        ExerciseScrubSteps(
            weight: number(
                SettingsKey.weightStep(catalogID: catalogID, catalogItemID: catalogItemID),
                in: defaults
            ),
            duration: number(
                SettingsKey.durationStep(catalogID: catalogID, catalogItemID: catalogItemID),
                in: defaults
            )
        )
    }

    /// Writes only chosen values; an unset step never overwrites a stored one.
    static func store(
        _ steps: ExerciseScrubSteps,
        catalogID: String?,
        catalogItemID: UUID,
        defaults: UserDefaults = .standard
    ) {
        if let weight = steps.weight {
            defaults.set(
                weight,
                forKey: SettingsKey.weightStep(catalogID: catalogID, catalogItemID: catalogItemID)
            )
        }
        if let duration = steps.duration {
            defaults.set(
                duration,
                forKey: SettingsKey.durationStep(catalogID: catalogID, catalogItemID: catalogItemID)
            )
        }
    }

    private static func number(_ key: String, in defaults: UserDefaults) -> Double? {
        (defaults.object(forKey: key) as? NSNumber)?.doubleValue
    }
}
