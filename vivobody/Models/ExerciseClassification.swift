//
//  ExerciseClassification.swift
//  vivobody
//
//  A static, by-name resolver for an exercise's movement metadata —
//  equipment, mechanic (compound/isolation), movement pattern, plane,
//  and laterality. It exists to close the same gap the muscle map and
//  bodyweight-fraction table already close: a logged `Exercise` (or
//  `TemplateExercise`) copies only name + group + plan defaults, so it
//  carries none of the classification fields that live on
//  `ExerciseCatalogItem`. Movement-distribution stats (push/pull
//  ratio, plane coverage, compound-vs-isolation split, bilateral-vs-
//  unilateral) therefore had nothing to read for a logged lift.
//
//  Like `Muscle.involvement(forExerciseNamed:)` and
//  `ExerciseLoad.bodyweightFraction(forExerciseNamed:)`, this resolves
//  purely by name and needs no model reference, so it works
//  retroactively across all history for any seeded lift — even if the
//  catalog item was later edited, renamed, or deleted.
//
//  The map is derived directly from `ExerciseCatalogItem.seedItems`,
//  the single source of truth for the starter catalog, so there is
//  nothing to keep in sync by hand: new seed rows are classified
//  automatically. Names absent from the seed list (user-created
//  custom exercises) resolve to `nil`; callers that want the user's
//  own tagging for those should fall back to a live catalog lookup by
//  name before defaulting.
//

import Foundation

/// The movement metadata for one exercise, resolved by name.
struct ExerciseClassification: Hashable {
    let equipment: Equipment
    let mechanic: Mechanic
    /// Optional — isolation work has no meaningful pattern.
    let pattern: MovementPattern?
    let plane: MovementPlane
    let laterality: Laterality
}

extension ExerciseClassification {
    /// Classification for a seeded exercise, resolved by name
    /// (case-insensitive). `nil` for names absent from the starter
    /// catalog — typically user-created custom exercises.
    static func forExerciseNamed(_ name: String) -> ExerciseClassification? {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return seedIndex[key]
    }

    /// Lowercased-name → classification, built once from the seed
    /// catalog. Duplicate names (which the catalog shouldn't contain)
    /// keep the first occurrence.
    private static let seedIndex: [String: ExerciseClassification] = {
        Dictionary(
            ExerciseCatalogItem.seedItems.map { seed in
                (
                    seed.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                    ExerciseClassification(
                        equipment: seed.equipment,
                        mechanic: seed.mechanic,
                        pattern: seed.pattern,
                        plane: seed.plane,
                        laterality: seed.laterality
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }()
}
