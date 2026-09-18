//
//  TemplateDraft.swift
//  vivobody
//
//  Value-type editing buffer for the template editor. Driving the
//  TextField (and per-exercise scrubbers) off plain Swift values
//  instead of a live @Model means zero SwiftData observation in the
//  hot path. The @Model objects are only constructed (or mutated)
//  at the moment of Save.
//
//  Per-exercise data has two modes — uniform (single sets/reps/
//  weight triple) and per-set (explicit rows for pyramid / wave
//  programming). `ExerciseDraft.isPerSet` is the mode flag the
//  editor reads; the legacy uniform fields are always kept in sync
//  as a fallback so existing call sites and the WorkoutTemplate
//  uniform path keep working.
//

import Foundation

struct TemplateDraft {
    var name: String = ""
    var exercises: [ExerciseDraft] = []

    /// Weekdays this template is pinned to (Calendar weekday numbers,
    /// 1 = Sunday … 7 = Saturday). Surfaces it on Today's "Up next"
    /// card. Empty = unscheduled.
    var scheduledWeekdays: [Int] = []
}

struct ExerciseDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var catalogItemID: UUID?
    var catalogID: String?
    var familyID: String?
    var group: MuscleGroup

    // Uniform fields — used when isPerSet == false. Always retained
    // when in per-set mode too, so toggling back to uniform doesn't
    // require re-deriving values.
    var plannedSets: Int
    var plannedReps: Int
    var plannedWeight: Double
    var loadPolicy: TemplateLoadPolicy
    var hasStartingLoad: Bool

    /// Pick-time muscle snapshot. Carried through the value draft so
    /// editing a template does not strip analytics identity.
    var muscleInvolvementSnapshot: [String: Double]

    /// Pick-time movement metadata carried through value-type editing
    /// so saving or reconfiguring a template does not strip it.
    var classification: ExerciseClassification?

    /// How the exercise is measured — reps or a timed hold. Carried
    /// from the catalog pick so a plank / dead hang in a template
    /// starts a timed exercise, not a rep count.
    var trackingMode: TrackingMode

    /// Pick-time analytics and resistance semantics. These travel with
    /// the draft so reconfiguring a template cannot strip the catalog
    /// exercise's interpretation before it becomes logged history.
    var modality: ExerciseModality
    var loadMode: ExerciseLoadMode
    var bodyweightFraction: Double

    /// Planned hold length (seconds) for `.duration` exercises.
    var plannedDuration: TimeInterval

    /// Superset membership carried through the value draft — adjacent
    /// rows sharing an ID form one alternating group. The editor's
    /// seam control writes it; Save copies it onto the TemplateExercise.
    var supersetID: UUID?

    /// True when explicit per-set rows are the source of truth for
    /// this exercise. False = uniform.
    var isPerSet: Bool

    /// Explicit per-set rows. Populated whenever `isPerSet == true`;
    /// can also linger when the user toggled back to uniform but we
    /// keep the data around in case they switch back.
    var sets: [SetDraft]

    init(
        id: UUID = UUID(),
        name: String,
        catalogItemID: UUID? = nil,
        catalogID: String? = nil,
        familyID: String? = nil,
        group: MuscleGroup,
        plannedSets: Int = 3,
        plannedReps: Int = 8,
        plannedWeight: Double = 0,
        loadPolicy: TemplateLoadPolicy = .fixed,
        hasStartingLoad: Bool = true,
        muscleInvolvement: Muscle.Involvement? = nil,
        classification: ExerciseClassification? = nil,
        trackingMode: TrackingMode = .reps,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external,
        bodyweightFraction: Double = 0,
        plannedDuration: TimeInterval = 0,
        supersetID: UUID? = nil,
        isPerSet: Bool = false,
        sets: [SetDraft] = []
    ) {
        self.id = id
        self.name = name
        self.catalogItemID = catalogItemID
        self.catalogID = catalogID
        self.familyID = familyID
        self.group = group
        self.plannedSets = plannedSets
        self.plannedReps = plannedReps
        self.loadPolicy = loadPolicy
        self.hasStartingLoad = hasStartingLoad
        self.plannedWeight = ExerciseResistanceCapability.normalizedWeight(
            plannedWeight,
            loadMode: loadMode,
            equipment: classification?.equipment
        )
        self.muscleInvolvementSnapshot = (muscleInvolvement ?? Muscle.involvement(forExerciseNamed: name)).snapshot
        self.classification = classification
        self.trackingMode = trackingMode
        self.modality = modality
        self.loadMode = loadMode
        self.bodyweightFraction = max(0, min(bodyweightFraction, 1))
        self.plannedDuration = plannedDuration
        self.supersetID = supersetID
        self.isPerSet = isPerSet
        let tracksResistance = ExerciseResistanceCapability.tracksResistance(
            loadMode: loadMode,
            equipment: classification?.equipment
        )
        self.sets = sets.map { set in
            var set = set
            if !tracksResistance { set.weight = 0 }
            return set
        }
    }
}

/// One row inside an ExerciseDraft's per-set list. Weight, reps, and
/// a stable id so SwiftUI's ForEach can identify rows across reorder
/// / insert / delete.
struct SetDraft: Identifiable, Hashable {
    let id: UUID
    var weight: Double
    var reps: Int
    var duration: TimeInterval

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.duration = duration
    }
}

extension ExerciseDraft {
    var tracksResistance: Bool {
        ExerciseResistanceCapability.tracksResistance(
            loadMode: loadMode,
            equipment: classification?.equipment
        )
    }

    func trackedWeight(_ weight: Double) -> Double {
        ExerciseResistanceCapability.normalizedWeight(
            weight,
            loadMode: loadMode,
            equipment: classification?.equipment
        )
    }

    /// Build from a catalog pick with editable set/rep/time targets.
    /// Load follows compatible history; its first-workout fallback is unset.
    init(from item: ExerciseCatalogItem) {
        self.init(
            name: item.name,
            catalogItemID: item.id,
            catalogID: item.catalogID,
            familyID: item.familyID,
            group: item.group,
            plannedSets: 3,
            plannedReps: item.defaultReps,
            plannedWeight: 0,
            loadPolicy: .lastWorkout,
            hasStartingLoad: false,
            muscleInvolvement: item.muscleInvolvement,
            classification: item.classification,
            trackingMode: item.trackingMode,
            modality: item.modality,
            loadMode: item.loadMode,
            bodyweightFraction: item.bodyweightFraction,
            plannedDuration: item.defaultDuration,
            isPerSet: false,
            sets: []
        )
    }

    /// Hydrate from an existing TemplateExercise in `.edit` mode.
    /// Picks the right mode based on whether the underlying template
    /// has explicit per-set rows. Uniform fields are always carried
    /// over so they're available if the user toggles modes.
    init(from templateExercise: TemplateExercise) {
        let orderedTemplateSets = templateExercise.orderedSets
        if !orderedTemplateSets.isEmpty {
            self.init(
                name: templateExercise.name,
                catalogItemID: templateExercise.catalogItemID,
                catalogID: templateExercise.catalogID,
                familyID: templateExercise.familyID,
                group: templateExercise.group,
                plannedSets: templateExercise.plannedSets,
                plannedReps: templateExercise.plannedReps,
                plannedWeight: templateExercise.plannedWeight,
                loadPolicy: templateExercise.loadPolicy,
                hasStartingLoad: templateExercise.hasStartingLoad,
                muscleInvolvement: templateExercise.muscleInvolvement,
                classification: templateExercise.classification,
                trackingMode: templateExercise.trackingMode,
                modality: templateExercise.modality,
                loadMode: templateExercise.loadMode,
                bodyweightFraction: templateExercise.bodyweightFraction,
                plannedDuration: templateExercise.plannedDuration,
                supersetID: templateExercise.supersetID,
                isPerSet: true,
                sets: orderedTemplateSets.map {
                    SetDraft(weight: $0.weight, reps: $0.reps, duration: $0.duration)
                }
            )
        } else {
            self.init(
                name: templateExercise.name,
                catalogItemID: templateExercise.catalogItemID,
                catalogID: templateExercise.catalogID,
                familyID: templateExercise.familyID,
                group: templateExercise.group,
                plannedSets: templateExercise.plannedSets,
                plannedReps: templateExercise.plannedReps,
                plannedWeight: templateExercise.plannedWeight,
                loadPolicy: templateExercise.loadPolicy,
                hasStartingLoad: templateExercise.hasStartingLoad,
                muscleInvolvement: templateExercise.muscleInvolvement,
                classification: templateExercise.classification,
                trackingMode: templateExercise.trackingMode,
                modality: templateExercise.modality,
                loadMode: templateExercise.loadMode,
                bodyweightFraction: templateExercise.bodyweightFraction,
                plannedDuration: templateExercise.plannedDuration,
                supersetID: templateExercise.supersetID,
                isPerSet: false,
                sets: []
            )
        }
    }

    /// Materialize the persisted model when the template editor saves.
    /// Keeping this bridge on the draft makes the catalog → draft →
    /// template snapshot path explicit and directly testable.
    func makeTemplateExercise(sortOrder: Int) -> TemplateExercise {
        let fallbackReps = isPerSet ? (sets.first?.reps ?? plannedReps) : plannedReps
        let fallbackWeight = isPerSet ? (sets.first?.weight ?? plannedWeight) : plannedWeight
        let fallbackCount = isPerSet ? max(1, sets.count) : plannedSets
        let fallbackDuration = isPerSet ? (sets.first?.duration ?? plannedDuration) : plannedDuration

        let exercise = TemplateExercise(
            name: name,
            catalogItemID: catalogItemID,
            catalogID: catalogID,
            familyID: familyID,
            group: group,
            plannedSets: fallbackCount,
            plannedReps: fallbackReps,
            plannedWeight: fallbackWeight,
            muscleInvolvement: Muscle.Involvement(snapshot: muscleInvolvementSnapshot),
            classification: classification,
            trackingMode: trackingMode,
            modality: modality,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction,
            plannedDuration: fallbackDuration,
            sortOrder: sortOrder
        )
        exercise.loadPolicy = isPerSet ? .fixed : loadPolicy
        exercise.hasStartingLoad = hasStartingLoad
        exercise.supersetID = supersetID

        if isPerSet {
            for (index, set) in sets.enumerated() {
                exercise.sets.append(
                    TemplateSet(
                        weight: set.weight,
                        reps: set.reps,
                        duration: set.duration,
                        sortOrder: index
                    )
                )
            }
        }
        return exercise
    }

    // MARK: - Mode transitions

    /// Materialize per-set rows from the uniform fields. No-op if
    /// we're already in per-set mode with rows present.
    mutating func switchToPerSet() {
        guard !isPerSet || sets.isEmpty else {
            isPerSet = true
            return
        }
        let count = max(1, plannedSets)
        let weight = plannedWeight
        let reps = plannedReps
        let duration = plannedDuration
        sets = (0 ..< count).map { _ in SetDraft(weight: weight, reps: reps, duration: duration) }
        isPerSet = true
        loadPolicy = .fixed
        hasStartingLoad = true
    }

    /// Collapse explicit rows back to uniform. Only safe when every
    /// row carries identical weight & reps — otherwise calling this
    /// silently flattens variation. The editor should call
    /// `canCollapseToUniform` first.
    mutating func switchToUniform() {
        if let first = sets.first {
            plannedSets = sets.count
            plannedReps = first.reps
            plannedWeight = first.weight
            plannedDuration = first.duration
        }
        isPerSet = false
        sets = []
    }

    /// True when every per-set row carries identical weight + reps,
    /// so collapsing to uniform is lossless.
    var canCollapseToUniform: Bool {
        guard let first = sets.first else { return true }
        return sets.allSatisfy {
            $0.weight == first.weight && $0.reps == first.reps
                && $0.duration == first.duration
        }
    }

    var targetSummary: String {
        let count = isPerSet ? sets.count : plannedSets
        if trackingMode == .duration {
            let values = isPerSet ? sets.map(\.duration) : [plannedDuration]
            let lo = values.min() ?? plannedDuration
            let hi = values.max() ?? plannedDuration
            let time = lo == hi ? DurationFormatter.string(lo) : "\(DurationFormatter.string(lo))–\(DurationFormatter.string(hi))"
            return "\(count) × \(time) \(modality.durationLabelLowercased)"
        }
        let values = isPerSet ? sets.map(\.reps) : [plannedReps]
        let lo = values.min() ?? plannedReps
        let hi = values.max() ?? plannedReps
        return lo == hi ? "\(count) × \(lo)" : "\(count) × \(lo)–\(hi)"
    }

    func summary(unit: WeightUnit) -> String {
        loadSummary(history: nil, unit: unit)
    }
}

extension ExerciseDraft {
    var performanceSignature: ExercisePerformanceSignature {
        ExercisePerformanceSignature(modality: modality, trackingMode: trackingMode, loadMode: loadMode,
                                     bodyweightFraction: bodyweightFraction, tracksResistance: tracksResistance)
    }

    var historyKey: String {
        ExerciseIdentity.key(catalogID: catalogID, catalogItemID: catalogItemID, name: name, performanceSignature: performanceSignature)
    }

    func loadSummary(history: ExerciseHistorySummary?, unit: WeightUnit) -> String {
        guard tracksResistance else { return targetSummary }
        let last = history?.mostRecentInstance(matching: performanceSignature)
        let resolution = isPerSet
            ? TemplateLoadResolution(weights: sets.map { trackedWeight($0.weight) }, source: "Fixed", date: nil)
            : TemplateLoadResolution.resolve(policy: loadPolicy, setCount: plannedSets,
                                             startingWeight: hasStartingLoad ? plannedWeight : nil,
                                             lastWeights: last?.completedSetPrescription.map { trackedWeight($0.weight) } ?? [], lastDate: last?.date)
        return "\(targetSummary) · \(resolution.summary(loadMode: loadMode, unit: unit))"
    }
}
