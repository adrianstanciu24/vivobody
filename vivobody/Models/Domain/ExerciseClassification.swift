//
//  ExerciseClassification.swift
//  vivobody
//
//  Movement metadata shared by catalog items, template exercises, and
//  logged exercises: equipment, mechanic, pattern, push/pull direction,
//  plane, and laterality. Catalog picks snapshot their classification
//  into templates and sessions so custom or renamed exercises remain
//  classifiable. Rows without a snapshot can still resolve a bundled
//  exercise by name, preserving the historical catalog fallback without
//  inventing defaults for unknown exercises.
//

import Foundation

/// The movement metadata for one exercise, resolved by name.
nonisolated struct ExerciseClassification: Hashable {
    let equipment: Equipment
    let mechanic: Mechanic
    /// Optional — isolation work has no meaningful pattern.
    let pattern: MovementPattern?
    /// Optional — only push/pull patterns have a direction.
    let direction: PushPullDirection?
    let plane: MovementPlane
    let laterality: Laterality

    nonisolated init(
        equipment: Equipment,
        mechanic: Mechanic,
        pattern: MovementPattern?,
        direction: PushPullDirection?,
        plane: MovementPlane,
        laterality: Laterality
    ) {
        self.equipment = equipment
        self.mechanic = mechanic
        self.pattern = pattern
        self.direction = direction
        self.plane = plane
        self.laterality = laterality
    }
}

extension ExerciseClassification {
    /// Reconstruct a persisted snapshot. The four universally-required
    /// fields act as the presence marker; pattern and direction remain
    /// genuinely optional within a valid classification.
    nonisolated init?(
        equipmentRaw: String?,
        mechanicRaw: String?,
        patternRaw: String?,
        directionRaw: String?,
        planeRaw: String?,
        lateralityRaw: String?
    ) {
        guard
            let equipmentRaw,
            let equipment = Equipment(rawValue: equipmentRaw),
            let mechanicRaw,
            let mechanic = Mechanic(rawValue: mechanicRaw),
            let planeRaw,
            let plane = MovementPlane(rawValue: planeRaw),
            let lateralityRaw,
            let laterality = Laterality(rawValue: lateralityRaw)
        else {
            return nil
        }

        let pattern: MovementPattern?
        if let patternRaw {
            guard let value = MovementPattern(rawValue: patternRaw) else { return nil }
            pattern = value
        } else {
            pattern = nil
        }

        let direction: PushPullDirection?
        if let directionRaw {
            guard let value = PushPullDirection(rawValue: directionRaw) else { return nil }
            direction = value
        } else {
            direction = nil
        }

        self.init(
            equipment: equipment,
            mechanic: mechanic,
            pattern: pattern,
            direction: direction,
            plane: plane,
            laterality: laterality
        )
    }

    /// Classification for a seeded exercise, resolved by name
    /// (case-insensitive) from the bundled catalog (`CatalogData`).
    /// `nil` for names absent from the catalog — typically user-created
    /// custom exercises.
    nonisolated static func forExerciseNamed(_ name: String) -> ExerciseClassification? {
        CatalogData.record(forExerciseNamed: name)?.classification
    }
}
