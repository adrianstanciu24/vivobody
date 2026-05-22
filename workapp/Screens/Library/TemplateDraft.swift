//
//  TemplateDraft.swift
//  workapp
//
//  Value-type editing buffer for the template editor. Driving the
//  TextField (and per-exercise scrubbers) off plain Swift values
//  instead of a live @Model means zero SwiftData observation in the
//  hot path. The @Model objects are only constructed (or mutated)
//  at the moment of Save.
//

import Foundation

struct TemplateDraft {
    var name: String = ""
    var exercises: [ExerciseDraft] = []
}

struct ExerciseDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var group: MuscleGroup
    var plannedSets: Int
    var plannedReps: Int
    var plannedWeight: Double

    init(
        id: UUID = UUID(),
        name: String,
        group: MuscleGroup,
        plannedSets: Int = 3,
        plannedReps: Int = 8,
        plannedWeight: Double = 0
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.plannedSets = plannedSets
        self.plannedReps = plannedReps
        self.plannedWeight = plannedWeight
    }
}

extension ExerciseDraft {
    /// Build from a catalog pick — pre-fills sensible defaults so
    /// the user doesn't always scrub from zero.
    init(from item: ExerciseCatalogItem) {
        self.init(
            name: item.name,
            group: item.group,
            plannedSets: 3,
            plannedReps: item.defaultReps,
            plannedWeight: item.defaultWeight
        )
    }

    /// Hydrate from an existing TemplateExercise in `.edit` mode.
    init(from templateExercise: TemplateExercise) {
        self.init(
            name: templateExercise.name,
            group: templateExercise.group,
            plannedSets: templateExercise.plannedSets,
            plannedReps: templateExercise.plannedReps,
            plannedWeight: templateExercise.plannedWeight
        )
    }
}
