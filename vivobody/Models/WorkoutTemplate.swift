//
//  WorkoutTemplate.swift
//  vivobody
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
    /// Library card subtitle. Counts explicit per-set rows when
    /// present, falling back to the uniform `plannedSets`.
    var totalPlannedSets: Int {
        exercises.reduce(0) { $0 + $1.effectiveSetCount }
    }
}

// MARK: - Template exercise

/// One exercise within a template. Stores plan parameters only —
/// no logged sets, no completion state. When the user starts a
/// workout from the parent template, each TemplateExercise spawns
/// a fresh Exercise with its planned sets populated.
///
/// Two storage modes coexist:
///   • UNIFORM  — `plannedSets × plannedReps × plannedWeight`, the
///     quick path. `sets` is empty.
///   • PER SET — explicit `sets: [TemplateSet]` rows when the user
///     needs pyramid / wave / variable-weight programming. When
///     `sets` is non-empty, the uniform fields are kept as fallback
///     defaults but the per-set rows are the source of truth.
///
/// Switching is purely a UI mode decision in the editor; the model
/// just stores whatever the editor decided to write.
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

    /// Per-set rows for pyramid / wave / variable programming.
    /// When this is non-empty, the uniform `plannedSets/Reps/Weight`
    /// fields are stale — consumers should use `orderedSets` instead.
    @Relationship(deleteRule: .cascade, inverse: \TemplateSet.exercise)
    var sets: [TemplateSet] = []

    /// Computed accessor for the muscle group enum. Lets the rest of
    /// the app treat `templateExercise.group` like a normal property
    /// while we store the raw value for persistence.
    var group: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .chest }
        set { muscleGroupRaw = newValue.rawValue }
    }

    /// Sets in their stable order. Use everywhere the UI enumerates
    /// per-set rows — SwiftData relationship arrays aren't ordered.
    var orderedSets: [TemplateSet] {
        sets.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// True when the user has populated explicit per-set rows. When
    /// false, the uniform fields are the source of truth.
    var hasPerSetData: Bool { !sets.isEmpty }

    /// Effective set count — orderedSets count when per-set, else
    /// the uniform `plannedSets`. Used by template-level rollups.
    var effectiveSetCount: Int {
        hasPerSetData ? sets.count : plannedSets
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

// MARK: - Template set

/// One planned set within a TemplateExercise. Only present when the
/// exercise is in per-set mode (pyramid / wave / variable). Cascade-
/// deleted when the parent exercise (or its template) is removed.
@Model
final class TemplateSet: Identifiable {
    var id: UUID = UUID()
    var weight: Double = 0
    var reps: Int = 0

    /// Stable position within the parent exercise's `sets`.
    var sortOrder: Int = 0

    /// Back-pointer to the owning template exercise. Auto-managed
    /// via the inverse relationship.
    var exercise: TemplateExercise?

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.sortOrder = sortOrder
    }
}

// MARK: - Exercise bridge

extension Exercise {
    /// Create a fresh, ready-to-start Exercise from a TemplateExercise.
    /// Two paths:
    ///   • Per-set template — spawn an Exercise with no auto-sets,
    ///     then append one WorkoutSet per TemplateSet (preserving
    ///     each row's individual weight × reps). Pyramid / wave
    ///     templates round-trip correctly.
    ///   • Uniform template — existing path: the Exercise init
    ///     auto-populates `plannedSets` identical WorkoutSets.
    ///
    /// In both cases the returned instance is NOT inserted into any
    /// context — the caller wires it into a WorkoutSession and the
    /// session's archive flow handles persistence.
    convenience init(from templateExercise: TemplateExercise) {
        if templateExercise.hasPerSetData {
            let orderedSets = templateExercise.orderedSets
            // plannedSets:0 → init skips auto-populating uniform sets.
            // We then attach the explicit per-set rows below.
            self.init(
                name: templateExercise.name,
                group: templateExercise.group,
                plannedSets: 0,
                plannedReps: orderedSets.first?.reps ?? templateExercise.plannedReps,
                plannedWeight: orderedSets.first?.weight ?? templateExercise.plannedWeight,
                sortOrder: templateExercise.sortOrder
            )
            for (i, templateSet) in orderedSets.enumerated() {
                self.sets.append(
                    WorkoutSet(
                        weight: templateSet.weight,
                        reps: templateSet.reps,
                        sortOrder: i
                    )
                )
            }
        } else {
            self.init(
                name: templateExercise.name,
                group: templateExercise.group,
                plannedSets: templateExercise.plannedSets,
                plannedReps: templateExercise.plannedReps,
                plannedWeight: templateExercise.plannedWeight,
                sortOrder: templateExercise.sortOrder
            )
        }
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
