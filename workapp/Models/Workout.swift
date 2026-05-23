//
//  Workout.swift
//  workapp
//
//  Persistent domain model. Three @Model classes wired up via
//  @Relationship: WorkoutSession owns Exercises, each Exercise owns
//  WorkoutSets. Cascade-delete propagates from session down. The
//  in-flight session lives un-inserted (transient) while the user is
//  working; only on archive does it get added to the context and
//  saved to disk.
//

import SwiftUI
import SwiftData

// MARK: - Muscle group

/// Stored as the raw value on `Exercise`; exposed as `Exercise.group`.
/// Display name and accent color are derived per case — no need to
/// persist them.
enum MuscleGroup: String, Hashable, CaseIterable {
    case chest, back, shoulders, legs, arms, core

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .legs: return "Legs"
        case .arms: return "Arms"
        case .core: return "Core"
        }
    }

    /// Accent color per muscle group. Read by exercise cards, set-row
    /// progress chips, and (eventually) the streak-calendar fill.
    var accent: Color {
        switch self {
        case .chest:     return Color(red: 0.82, green: 0.30, blue: 0.30)
        case .back:      return Color(red: 0.28, green: 0.62, blue: 0.38)
        case .shoulders: return Color(red: 0.96, green: 0.66, blue: 0.26)
        case .legs:      return Color(red: 0.36, green: 0.54, blue: 0.82)
        case .arms:      return Color(red: 0.66, green: 0.38, blue: 0.76)
        case .core:      return Color(red: 0.52, green: 0.80, blue: 0.62)
        }
    }
}

// MARK: - Exercise

/// One exercise within a session. Holds its plan parameters AND the
/// actual logged sets. SwiftData manages the relationship from both
/// sides — appending to `session.exercises` automatically sets
/// `exercise.session`, and vice versa.
@Model
final class Exercise: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var muscleGroupRaw: String = MuscleGroup.chest.rawValue
    var plannedSets: Int = 3
    var plannedReps: Int = 8
    var plannedWeight: Double = 0

    /// Stable position within the parent session. Used to render
    /// exercises in the order the user planned them; SwiftData
    /// relationships don't guarantee array order on their own.
    var sortOrder: Int = 0

    /// Back-pointer to the owning session. Auto-managed by the
    /// inverse relationship declared on `WorkoutSession.exercises`.
    var session: WorkoutSession?

    /// Free-form per-exercise notes — form cues ("brace harder
    /// before unrack"), pin / plate setup ("safety pins at 4"),
    /// how it felt ("light"). Surfaced on the active exercise card
    /// + summary row. Additive — no migration needed.
    var notes: String = ""

    /// The actual logged sets for this exercise. Cascade-deletes when
    /// the exercise (or its session) is removed.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet] = []

    /// Computed accessor for the muscle group enum. Lets the rest of
    /// the app treat `exercise.group` like a normal property while we
    /// store the raw value for persistence.
    var group: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .chest }
        set { muscleGroupRaw = newValue.rawValue }
    }

    /// Sets returned in their stable order. Used everywhere the UI
    /// needs to enumerate set rows.
    var orderedSets: [WorkoutSet] {
        sets.sorted { $0.sortOrder < $1.sortOrder }
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

        // Pre-populate the planned sets. They start uncompleted at
        // the plan's weight/reps and get updated in-place as the user
        // adjusts the scrubbers and taps complete.
        for i in 0..<plannedSets {
            let set = WorkoutSet(
                weight: plannedWeight,
                reps: plannedReps,
                sortOrder: i
            )
            self.sets.append(set)
        }
    }
}

// MARK: - Set

/// One logged set within an exercise. The unit of completion.
@Model
final class WorkoutSet: Identifiable {
    var id: UUID = UUID()
    var weight: Double = 0
    var reps: Int = 0
    var isCompleted: Bool = false

    /// Stable position within the parent exercise.
    var sortOrder: Int = 0

    /// Back-pointer to the owning exercise. Auto-managed by the
    /// inverse relationship on `Exercise.sets`.
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        isCompleted: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }
}

// MARK: - Sample data

/// Templates for the seeded "Today's Plan". Returns fresh @Model
/// instances each call — these are NOT inserted into any context;
/// the caller is responsible for that (typically by attaching them
/// to a WorkoutSession and inserting the session on archive).
extension Exercise {
    /// Build a fresh, ready-to-start exercise from a previously-logged
    /// one. Same name, group, sort-order, and a separate WorkoutSet
    /// per source set (preserving each set's individual weight/reps —
    /// straight-set workouts and pyramid sets both round-trip). All
    /// `isCompleted` flags are reset so the new exercise reads as a
    /// clean plan. The returned instance is NOT inserted into any
    /// context — wire it into a WorkoutSession and let the session
    /// archive flow handle persistence.
    static func freshCopy(of source: Exercise) -> Exercise {
        let sourceSets = source.orderedSets
        let firstSet = sourceSets.first
        // Pass plannedSets: 0 so the initializer doesn't auto-populate
        // a uniform set list — we want the exact per-set values from
        // the source, including any variation across sets.
        let copy = Exercise(
            name: source.name,
            group: source.group,
            plannedSets: 0,
            plannedReps: firstSet?.reps ?? source.plannedReps,
            plannedWeight: firstSet?.weight ?? source.plannedWeight,
            sortOrder: source.sortOrder
        )
        for (i, sourceSet) in sourceSets.enumerated() {
            copy.sets.append(
                WorkoutSet(
                    weight: sourceSet.weight,
                    reps: sourceSet.reps,
                    isCompleted: false,
                    sortOrder: i
                )
            )
        }
        return copy
    }

    static func samplePlan() -> [Exercise] {
        let templates: [(name: String, group: MuscleGroup, sets: Int, reps: Int, weight: Double)] = [
            ("Bench Press",    .chest,     3, 8, 135),
            ("Barbell Row",    .back,      3, 8, 115),
            ("Overhead Press", .shoulders, 3, 8, 95),
            ("Back Squat",     .legs,      3, 8, 185),
        ]
        return templates.enumerated().map { i, t in
            Exercise(
                name: t.name,
                group: t.group,
                plannedSets: t.sets,
                plannedReps: t.reps,
                plannedWeight: t.weight,
                sortOrder: i
            )
        }
    }
}
