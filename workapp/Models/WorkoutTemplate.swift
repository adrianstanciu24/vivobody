//
//  WorkoutTemplate.swift
//  workapp
//
//  Blueprint for a workout — the user's named, reusable plan
//  ("Push Day A", "Legs"). Distinct from WorkoutSession (a log of
//  an actual lifting bout) because templates have no notion of
//  start/end time, completion, or per-set logged data. They define
//  the *intent*; sessions record what actually happened.
//
//  A user starts a workout *from* a template via
//  `AppState.startWorkoutFromTemplate(_:)`, which clones each
//  TemplateExercise into a fresh Exercise (with planned weight/reps
//  populated and `isCompleted` reset to false on every set).
//

import SwiftUI
import SwiftData

@Model
final class WorkoutTemplate: Identifiable {
    var id: UUID = UUID()
    var name: String = "New Template"
    var createdAt: Date = Date()

    /// Stable ordering for the Library list. New templates append
    /// at the end; manual reordering bumps these.
    var sortOrder: Int = 0

    /// When this template was last used to start a workout. Surfaced
    /// on the Library card so users can see what they've been doing
    /// recently. Nil until the template's first use.
    var lastUsedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise] = []

    init(
        id: UUID = UUID(),
        name: String = "New Template",
        exercises: [TemplateExercise] = [],
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.lastUsedAt = nil
    }

    /// Exercises in their stable plan order — use this everywhere
    /// the UI enumerates the template's contents.
    var orderedExercises: [TemplateExercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Distinct muscle groups touched by this template — drives the
    /// colored capsules on the Library card.
    var muscleGroups: [MuscleGroup] {
        var seen: Set<String> = []
        var result: [MuscleGroup] = []
        for ex in orderedExercises where !seen.contains(ex.muscleGroupRaw) {
            seen.insert(ex.muscleGroupRaw)
            result.append(ex.group)
        }
        return result
    }

    /// Total planned-set count across all exercises. Used in the
    /// Library card subtitle.
    var totalPlannedSets: Int {
        exercises.reduce(0) { $0 + $1.plannedSets }
    }
}

// MARK: - Template exercise

/// One exercise within a template. Stores plan parameters only —
/// no logged sets, no completion state. When the user starts a
/// workout from the parent template, each TemplateExercise spawns
/// a fresh Exercise with its planned sets populated.
@Model
final class TemplateExercise: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var muscleGroupRaw: String = MuscleGroup.chest.rawValue
    var plannedSets: Int = 3
    var plannedReps: Int = 8
    var plannedWeight: Double = 0

    /// Stable position within the parent template.
    var sortOrder: Int = 0

    /// Back-pointer to the owning template. Auto-managed by the
    /// inverse relationship declared on `WorkoutTemplate.exercises`.
    var template: WorkoutTemplate?

    /// Computed accessor for the muscle group enum. Lets the rest of
    /// the app treat `templateExercise.group` like a normal property
    /// while we store the raw value for persistence.
    var group: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .chest }
        set { muscleGroupRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        group: MuscleGroup,
        plannedSets: Int = 3,
        plannedReps: Int = 8,
        plannedWeight: Double,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.muscleGroupRaw = group.rawValue
        self.plannedSets = plannedSets
        self.plannedReps = plannedReps
        self.plannedWeight = plannedWeight
        self.sortOrder = sortOrder
    }
}

// MARK: - Exercise bridge

extension Exercise {
    /// Create a fresh, ready-to-start Exercise from a TemplateExercise.
    /// All sets begin uncompleted at the template's planned weight/reps,
    /// inheriting the count from `plannedSets`. The returned instance
    /// is NOT inserted into any context — the caller wires it into a
    /// WorkoutSession and the session's archive flow handles persistence.
    convenience init(from templateExercise: TemplateExercise) {
        self.init(
            name: templateExercise.name,
            group: templateExercise.group,
            plannedSets: templateExercise.plannedSets,
            plannedReps: templateExercise.plannedReps,
            plannedWeight: templateExercise.plannedWeight,
            sortOrder: templateExercise.sortOrder
        )
    }

    /// Create a fresh Exercise from a catalog pick. Used when the
    /// user adds an exercise mid-workout — the new exercise starts
    /// with 3 planned sets at the catalog's default weight & reps,
    /// which the user can adjust in the active card.
    convenience init(from item: ExerciseCatalogItem, sortOrder: Int) {
        self.init(
            name: item.name,
            group: item.group,
            plannedSets: 3,
            plannedReps: item.defaultReps,
            plannedWeight: item.defaultWeight,
            sortOrder: sortOrder
        )
    }
}
