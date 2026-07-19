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

    /// Weekdays this template is scheduled on, as `Calendar` weekday
    /// numbers (1 = Sunday … 7 = Saturday). Empty means unscheduled.
    /// Drives the Today "Up next" card. Additive defaulted field — no
    /// migration.
    var scheduledWeekdays: [Int] = []

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

    /// Whether the user has pinned this template to any weekday.
    var isScheduled: Bool { !scheduledWeekdays.isEmpty }

    /// Whether this template is scheduled on the given `Calendar`
    /// weekday number (1 = Sunday … 7 = Saturday).
    func isScheduled(on weekday: Int) -> Bool {
        scheduledWeekdays.contains(weekday)
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
    var catalogItemID: UUID? = nil

    /// Stable bundled-catalog identity copied with the planned lift.
    /// Nil for user-created exercises.
    var catalogID: String? = nil

    var muscleGroupRaw: String = MuscleGroup.chest.rawValue
    var plannedSets: Int = 3
    var plannedReps: Int = 8
    var plannedWeight: Double = 0

    /// Pick-time muscle snapshot copied from the catalog item. Used
    /// when spawning a WorkoutSession exercise so renamed custom
    /// lifts keep contributing to muscle analytics.
    var muscleInvolvementSnapshot: [String: Double] = [:]

    /// Pick-time movement classification. Optional raw values preserve
    /// an honest "not snapshotted" state for unknown rows instead of
    /// silently applying catalog-editor defaults.
    var equipmentRaw: String? = nil
    var mechanicRaw: String? = nil
    var patternRaw: String? = nil
    var directionRaw: String? = nil
    var planeRaw: String? = nil
    var lateralityRaw: String? = nil

    /// How this exercise is measured — reps or a timed hold. Stored
    /// as a raw value; defaulted so existing templates read as reps
    /// with no migration. Copied to the spawned Exercise at start.
    var trackingModeRaw: String = TrackingMode.reps.rawValue

    /// Analytics semantics copied from the selected catalog item and
    /// passed unchanged into every workout spawned from this template.
    var modalityRaw: String = ExerciseModality.dynamicStrength.rawValue
    var loadModeRaw: String = ExerciseLoadMode.external.rawValue
    var bodyweightFraction: Double = 0

    /// Planned hold length (seconds) for `.duration` exercises.
    /// Mirrors `plannedReps` for the timed case. Additive defaulted
    /// field — no migration.
    var plannedDuration: TimeInterval = 0

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

    /// Computed accessor for the tracking-mode enum.
    var trackingMode: TrackingMode {
        get { TrackingMode(rawValue: trackingModeRaw) ?? .reps }
        set { trackingModeRaw = newValue.rawValue }
    }

    var modality: ExerciseModality {
        get { ExerciseModality(rawValue: modalityRaw) ?? .dynamicStrength }
        set { modalityRaw = newValue.rawValue }
    }

    var loadMode: ExerciseLoadMode {
        get { ExerciseLoadMode(rawValue: loadModeRaw) ?? .external }
        set { loadModeRaw = newValue.rawValue }
    }

    var loadProfile: ExerciseLoadProfile {
        ExerciseLoadProfile(mode: loadMode, bodyweightFraction: bodyweightFraction)
    }

    /// Snapshotted movement metadata wins; templates without a snapshot
    /// retain the bundled-name fallback used before classification was
    /// persisted.
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
        catalogItemID: UUID? = nil,
        catalogID: String? = nil,
        group: MuscleGroup,
        plannedSets: Int = 3,
        plannedReps: Int = 8,
        plannedWeight: Double,
        muscleInvolvement: Muscle.Involvement? = nil,
        classification: ExerciseClassification? = nil,
        trackingMode: TrackingMode = .reps,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external,
        bodyweightFraction: Double = 0,
        plannedDuration: TimeInterval = 0,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.catalogItemID = catalogItemID
        self.catalogID = catalogID
        self.muscleGroupRaw = group.rawValue
        self.plannedSets = plannedSets
        self.plannedReps = plannedReps
        self.plannedWeight = plannedWeight
        self.muscleInvolvementSnapshot = (muscleInvolvement ?? Muscle.involvement(forExerciseNamed: name)).snapshot
        self.equipmentRaw = classification?.equipment.rawValue
        self.mechanicRaw = classification?.mechanic.rawValue
        self.patternRaw = classification?.pattern?.rawValue
        self.directionRaw = classification?.direction?.rawValue
        self.planeRaw = classification?.plane.rawValue
        self.lateralityRaw = classification?.laterality.rawValue
        self.trackingModeRaw = trackingMode.rawValue
        self.modalityRaw = modality.rawValue
        self.loadModeRaw = loadMode.rawValue
        self.bodyweightFraction = max(0, min(bodyweightFraction, 1))
        self.plannedDuration = plannedDuration
        self.sortOrder = sortOrder
    }

    /// Build a template exercise from a catalog pick. Muscles are
    /// resolved by name from the curated map, so nothing to copy.
    convenience init(from item: ExerciseCatalogItem, sortOrder: Int) {
        self.init(
            name: item.name,
            catalogItemID: item.id,
            catalogID: item.catalogID,
            group: item.group,
            plannedSets: 3,
            plannedReps: item.defaultReps,
            plannedWeight: item.defaultWeightSeed,
            muscleInvolvement: item.muscleInvolvement,
            classification: item.classification,
            trackingMode: item.trackingMode,
            modality: item.modality,
            loadMode: item.loadMode,
            bodyweightFraction: item.bodyweightFraction,
            plannedDuration: item.defaultDuration,
            sortOrder: sortOrder
        )
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

    /// Planned hold length (seconds) for a set on a `.duration`
    /// exercise. Zero for the reps case. Additive defaulted field.
    var duration: TimeInterval = 0

    /// Planned set intent, copied into the workout at start. Additive
    /// defaulted field so old rows remain working sets.
    var kindRaw: String = WorkoutSetKind.working.rawValue

    var kind: WorkoutSetKind {
        get { WorkoutSetKind(rawValue: kindRaw) ?? .working }
        set { kindRaw = newValue.rawValue }
    }

    /// Stable position within the parent exercise's `sets`.
    var sortOrder: Int = 0

    /// Back-pointer to the owning template exercise. Auto-managed
    /// via the inverse relationship.
    var exercise: TemplateExercise?

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        duration: TimeInterval = 0,
        kind: WorkoutSetKind = .working,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.kindRaw = kind.rawValue
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
                catalogItemID: templateExercise.catalogItemID,
                catalogID: templateExercise.catalogID,
                group: templateExercise.group,
                plannedSets: 0,
                plannedReps: orderedSets.first?.reps ?? templateExercise.plannedReps,
                plannedWeight: orderedSets.first?.weight ?? templateExercise.plannedWeight,
                muscleInvolvement: Muscle.Involvement(snapshot: templateExercise.muscleInvolvementSnapshot),
                classification: templateExercise.classification,
                trackingMode: templateExercise.trackingMode,
                modality: templateExercise.modality,
                loadMode: templateExercise.loadMode,
                bodyweightFraction: templateExercise.bodyweightFraction,
                plannedDuration: orderedSets.first?.duration ?? templateExercise.plannedDuration,
                sortOrder: templateExercise.sortOrder
            )
            for (i, templateSet) in orderedSets.enumerated() {
                self.sets.append(
                    WorkoutSet(
                        weight: templateSet.weight,
                        reps: templateSet.reps,
                        duration: templateSet.duration,
                        kind: templateSet.kind,
                        sortOrder: i,
                        plannedWeight: templateSet.weight,
                        plannedReps: templateSet.reps,
                        plannedDuration: templateSet.duration
                    )
                )
            }
        } else {
            self.init(
                name: templateExercise.name,
                catalogItemID: templateExercise.catalogItemID,
                catalogID: templateExercise.catalogID,
                group: templateExercise.group,
                plannedSets: templateExercise.plannedSets,
                plannedReps: templateExercise.plannedReps,
                plannedWeight: templateExercise.plannedWeight,
                muscleInvolvement: Muscle.Involvement(snapshot: templateExercise.muscleInvolvementSnapshot),
                classification: templateExercise.classification,
                trackingMode: templateExercise.trackingMode,
                modality: templateExercise.modality,
                loadMode: templateExercise.loadMode,
                bodyweightFraction: templateExercise.bodyweightFraction,
                plannedDuration: templateExercise.plannedDuration,
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
            catalogItemID: item.id,
            catalogID: item.catalogID,
            group: item.group,
            plannedSets: 3,
            plannedReps: item.defaultReps,
            plannedWeight: item.defaultWeightSeed,
            muscleInvolvement: item.muscleInvolvement,
            classification: item.classification,
            trackingMode: item.trackingMode,
            modality: item.modality,
            loadMode: item.loadMode,
            bodyweightFraction: item.bodyweightFraction,
            plannedDuration: item.defaultDuration,
            sortOrder: sortOrder
        )
    }
}
