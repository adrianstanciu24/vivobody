//
//  Workout.swift
//  vivobody
//
//  Persistent domain model. Three @Model classes wired up via
//  @Relationship: WorkoutSession owns Exercises, each Exercise owns
//  WorkoutSets. Cascade-delete propagates from session down. The
//  in-flight session is saved as a SwiftData draft while the user is
//  working; archive stamps completedAt so history queries can see it.
//

import VivoKit
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

    /// Neutral marker tint for muscle-group affordances. Deliberately
    /// a single grayscale value for every group: the app has ONE
    /// accent (Volt), and muscle identity is carried by the text
    /// label, not a rainbow of dots. Kept as a property so existing
    /// call sites (dots, chips, calendar) compile while the screens
    /// migrate to text-only group labels.
    var accent: Color { Ink.tertiary }
}

// MARK: - Tracking mode

/// How an exercise's sets are measured. Most lifts are `reps`
/// (weight × reps); isometric / timed work (plank, dead hang,
/// timed carries) is `duration` — a held interval in seconds, with
/// weight still optional (weighted plank, loaded carry). Stored as
/// a raw value on the catalog item, the template exercise, and the
/// session exercise so the enum can evolve without migrations.
enum TrackingMode: String, Hashable, CaseIterable {
    case reps
    case duration

    var displayName: String {
        switch self {
        case .reps:     return "Reps"
        case .duration: return "Time"
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
    #Index<Exercise>([\.name])
    var id: UUID = UUID()
    var name: String = ""
    var catalogItemID: UUID? = nil
    var muscleGroupRaw: String = MuscleGroup.chest.rawValue
    var plannedSets: Int = 3
    var plannedReps: Int = 8
    var plannedWeight: Double = 0

    /// Snapshot of the catalog item's graded muscle involvement at
    /// pick-time. This keeps custom/renamed/deleted catalog exercises
    /// contributing to analytics even when their display name changes
    /// later. Empty for legacy rows; computed access falls back to the
    /// current catalog name, then to the coarse muscle group.
    var muscleInvolvementSnapshot: [String: Double] = [:]

    /// Pick-time movement classification. All raw fields are optional
    /// so a row without a snapshot remains honestly unknown rather than
    /// inheriting catalog-editor defaults. Pattern and direction can
    /// also be nil within an otherwise complete snapshot.
    var equipmentRaw: String? = nil
    var mechanicRaw: String? = nil
    var patternRaw: String? = nil
    var directionRaw: String? = nil
    var planeRaw: String? = nil
    var lateralityRaw: String? = nil

    /// How this exercise is measured — reps or a timed hold. Stored
    /// as a raw value; defaulted so existing data reads as reps with
    /// no migration. Copied from the catalog/template at pick-time.
    var trackingModeRaw: String = TrackingMode.reps.rawValue

    /// Planned hold length (seconds) for `.duration` exercises.
    /// Mirrors `plannedReps` for the timed case; ignored when the
    /// mode is `.reps`. Additive defaulted field — no migration.
    var plannedDuration: TimeInterval = 0

    /// Stable position within the parent session. Used to render
    /// exercises in the order the user planned them; SwiftData
    /// relationships don't guarantee array order on their own.
    var sortOrder: Int = 0

    /// Back-pointer to the owning session. Auto-managed by the
    /// inverse relationship declared on `WorkoutSession.exercises`.
    var session: WorkoutSession?

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

    /// Computed accessor for the tracking-mode enum.
    var trackingMode: TrackingMode {
        get { TrackingMode(rawValue: trackingModeRaw) ?? .reps }
        set { trackingModeRaw = newValue.rawValue }
    }

    /// Muscles worked, with their graded contribution weights. New
    /// rows read their pick-time snapshot; legacy rows fall back to
    /// the current catalog name, then to the coarse muscle group.
    var muscleInvolvement: Muscle.Involvement {
        if !muscleInvolvementSnapshot.isEmpty {
            return Muscle.Involvement(snapshot: muscleInvolvementSnapshot)
        }
        return Muscle.involvement(forExerciseNamed: name, fallbackGroup: group)
    }

    /// Snapshotted movement metadata wins over name lookup so custom
    /// exercises and renamed catalog entries remain classifiable.
    /// Rows with no snapshot retain the bundled-name fallback.
    var classification: ExerciseClassification? {
        ExerciseClassification(
            equipmentRaw: equipmentRaw,
            mechanicRaw: mechanicRaw,
            patternRaw: patternRaw,
            directionRaw: directionRaw,
            planeRaw: planeRaw,
            lateralityRaw: lateralityRaw
        ) ?? ExerciseClassification.forExerciseNamed(name)
    }

    /// Sets returned in their stable order. Used everywhere the UI
    /// needs to enumerate set rows.
    var orderedSets: [WorkoutSet] {
        sets.sorted { $0.sortOrder < $1.sortOrder }
    }

    init(
        id: UUID = UUID(),
        name: String,
        catalogItemID: UUID? = nil,
        group: MuscleGroup,
        plannedSets: Int = 3,
        plannedReps: Int = 8,
        plannedWeight: Double,
        muscleInvolvement: Muscle.Involvement? = nil,
        classification: ExerciseClassification? = nil,
        trackingMode: TrackingMode = .reps,
        plannedDuration: TimeInterval = 0,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.catalogItemID = catalogItemID
        self.muscleGroupRaw = group.rawValue
        self.plannedSets = plannedSets
        self.plannedReps = plannedReps
        self.plannedWeight = plannedWeight
        self.muscleInvolvementSnapshot = (muscleInvolvement ?? Muscle.involvement(forExerciseNamed: name, fallbackGroup: group)).snapshot
        self.equipmentRaw = classification?.equipment.rawValue
        self.mechanicRaw = classification?.mechanic.rawValue
        self.patternRaw = classification?.pattern?.rawValue
        self.directionRaw = classification?.direction?.rawValue
        self.planeRaw = classification?.plane.rawValue
        self.lateralityRaw = classification?.laterality.rawValue
        self.trackingModeRaw = trackingMode.rawValue
        self.plannedDuration = plannedDuration
        self.sortOrder = sortOrder

        // Pre-populate the planned sets. They start uncompleted at
        // the plan's weight/reps/duration and get updated in-place as
        // the user adjusts the scrubbers and taps complete.
        for i in 0..<plannedSets {
            let set = WorkoutSet(
                weight: plannedWeight,
                reps: plannedReps,
                duration: plannedDuration,
                sortOrder: i,
                plannedWeight: plannedWeight,
                plannedReps: plannedReps,
                plannedDuration: plannedDuration
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

    /// Held interval (seconds) for sets on a `.duration` exercise.
    /// Zero for the reps case. Additive defaulted field — no
    /// migration; the owning exercise's `trackingMode` decides which
    /// of `reps` / `duration` is the source of truth for this set.
    var duration: TimeInterval = 0

    var isCompleted: Bool = false

    /// Reps in reserve — how many more reps the lifter felt they had
    /// left at the end of this set. The session-logged read on how
    /// hard the set was pushed: 0 = trained to failure, 5 = many left
    /// in the tank. Clamped to a 0…5 scale (the usable RIR range;
    /// beyond that the self-estimate is noise). Defaults to 2, the
    /// standard hypertrophy target. Additive defaulted field — no
    /// migration. Only meaningful for `.reps` exercises; left at the
    /// default and ignored for timed holds.
    var repsInReserve: Int = 2

    /// Whether the lifter explicitly set `repsInReserve` for this set.
    /// `repsInReserve` defaults to 2 and has no "unset" value of its
    /// own, so a freshly-spawned set is indistinguishable from one the
    /// user deliberately rated as RIR 2. This flag — flipped true only
    /// when the RIR control is actually touched — lets effort stats
    /// (sets-to-failure, intensity trends, RIR consistency, etc.)
    /// count only real readings and report honest coverage. Stays
    /// false for `.duration` holds, which carry no RIR. Additive
    /// defaulted field — no migration.
    var rirLogged: Bool = false

    /// Stable position within the parent exercise.
    var sortOrder: Int = 0

    /// The planned target this set was spawned from — the template's
    /// per-set prescription, or the previous session's logged value
    /// for a fresh copy — captured at spawn time so it survives the
    /// in-place edits that overwrite `weight`/`reps`/`duration` as the
    /// user logs the actual set. Zero means "no plan was recorded":
    /// pre-snapshot data, or an ad-hoc set added mid-workout. Enables
    /// exact planned-vs-actual adherence even for pyramid / per-set
    /// programming, where the owning Exercise's uniform `planned*`
    /// fields only reflect the first set. Additive defaulted fields —
    /// no migration.
    var plannedWeight: Double = 0
    var plannedReps: Int = 0
    var plannedDuration: TimeInterval = 0

    /// Back-pointer to the owning exercise. Auto-managed by the
    /// inverse relationship on `Exercise.sets`.
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        duration: TimeInterval = 0,
        isCompleted: Bool = false,
        repsInReserve: Int = 2,
        rirLogged: Bool = false,
        sortOrder: Int = 0,
        plannedWeight: Double = 0,
        plannedReps: Int = 0,
        plannedDuration: TimeInterval = 0
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.isCompleted = isCompleted
        self.repsInReserve = repsInReserve
        self.rirLogged = rirLogged
        self.sortOrder = sortOrder
        self.plannedWeight = plannedWeight
        self.plannedReps = plannedReps
        self.plannedDuration = plannedDuration
    }
}

// MARK: - Set display

extension Exercise {
    /// Compact, mode-aware label for one set's logged/planned metric,
    /// with the weight value carried in the user's unit (no unit
    /// suffix — callers append it where they want it):
    ///   • reps     → "135 x 8"
    ///   • duration → "0:45", or "25 x 0:45" when the hold is loaded.
    /// The single source of truth for how a set reads across the
    /// summary, history, picker, and detail surfaces.
    func setLabel(_ set: WorkoutSet, unit: WeightUnit) -> String {
        SetSpecFormatter.format(
            weight: set.weight,
            reps: set.reps,
            duration: set.duration,
            trackingMode: trackingMode,
            unit: unit
        )
    }
}

extension WorkoutSession {
    /// Display label for an exercise's representative top set,
    /// mode-aware. Nil when nothing's been completed yet.
    func topSetLabel(for exercise: Exercise, unit: WeightUnit) -> String? {
        guard let top = topSet(for: exercise) else { return nil }
        return exercise.setLabel(top, unit: unit)
    }
}

// MARK: - Sample data

/// Templates for the seeded "Today's Plan". Returns fresh @Model
/// instances each call — these are NOT inserted into any context;
/// the caller is responsible for that (typically by attaching them
/// to a draft WorkoutSession inserted at workout start).
extension Exercise {
    /// Build a fresh, ready-to-start exercise from a previously-logged
    /// one. Same name, group, sort-order, and a separate WorkoutSet
    /// per source set (preserving each set's individual weight/reps —
    /// straight-set workouts and pyramid sets both round-trip). All
    /// `isCompleted` flags are reset so the new exercise reads as a
    /// clean plan. The returned instance is NOT inserted into any
    /// context — wire it into a WorkoutSession and let the session
    /// draft/archive flow handle persistence.
    static func freshCopy(of source: Exercise) -> Exercise {
        let sourceSets = source.orderedSets
        let firstSet = sourceSets.first
        // Pass plannedSets: 0 so the initializer doesn't auto-populate
        // a uniform set list — we want the exact per-set values from
        // the source, including any variation across sets.
        let copy = Exercise(
            name: source.name,
            catalogItemID: source.catalogItemID,
            group: source.group,
            plannedSets: 0,
            plannedReps: firstSet?.reps ?? source.plannedReps,
            plannedWeight: firstSet?.weight ?? source.plannedWeight,
            muscleInvolvement: source.muscleInvolvement,
            classification: source.classification,
            trackingMode: source.trackingMode,
            plannedDuration: firstSet?.duration ?? source.plannedDuration,
            sortOrder: source.sortOrder
        )
        for (i, sourceSet) in sourceSets.enumerated() {
            copy.sets.append(
                WorkoutSet(
                    weight: sourceSet.weight,
                    reps: sourceSet.reps,
                    duration: sourceSet.duration,
                    isCompleted: false,
                    sortOrder: i,
                    plannedWeight: sourceSet.weight,
                    plannedReps: sourceSet.reps,
                    plannedDuration: sourceSet.duration
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
