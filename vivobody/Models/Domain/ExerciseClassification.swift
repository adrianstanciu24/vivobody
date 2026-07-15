//
//  ExerciseClassification.swift
//  vivobody
//
//  A static, by-name resolver for an exercise's movement metadata —
//  equipment, mechanic (compound/isolation), movement pattern,
//  push/pull direction, plane, and laterality. It exists to close the
//  same gap the muscle map and
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
//  Resolution reads the bundled catalog (`CatalogData`), the single
//  source of truth for the starter catalog, so there is nothing to keep
//  in sync by hand: every catalog record is classified automatically.
//  Names absent from the catalog (user-created custom exercises) resolve
//  to `nil`; callers that want the user's own tagging for those should
//  fall back to a live catalog lookup by name before defaulting.
//

import Foundation

/// The movement metadata for one exercise, resolved by name.
struct ExerciseClassification: Hashable {
    let equipment: Equipment
    let mechanic: Mechanic
    /// Optional — isolation work has no meaningful pattern.
    let pattern: MovementPattern?
    /// Optional — only push/pull patterns have a direction.
    let direction: PushPullDirection?
    let plane: MovementPlane
    let laterality: Laterality
}

extension ExerciseClassification {
    /// Classification for a seeded exercise, resolved by name
    /// (case-insensitive) from the bundled catalog (`CatalogData`).
    /// `nil` for names absent from the catalog — typically user-created
    /// custom exercises.
    static func forExerciseNamed(_ name: String) -> ExerciseClassification? {
        CatalogData.record(forExerciseNamed: name)?.classification
    }
}
