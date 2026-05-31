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
}

struct ExerciseDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var group: MuscleGroup

    // Uniform fields — used when isPerSet == false. Always retained
    // when in per-set mode too, so toggling back to uniform doesn't
    // require re-deriving values.
    var plannedSets: Int
    var plannedReps: Int
    var plannedWeight: Double

    /// How the exercise is measured — reps or a timed hold. Carried
    /// from the catalog pick so a plank / dead hang in a template
    /// starts a timed exercise, not a rep count.
    var trackingMode: TrackingMode

    /// Planned hold length (seconds) for `.duration` exercises.
    var plannedDuration: TimeInterval

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
        group: MuscleGroup,
        plannedSets: Int = 3,
        plannedReps: Int = 8,
        plannedWeight: Double = 0,
        trackingMode: TrackingMode = .reps,
        plannedDuration: TimeInterval = 0,
        isPerSet: Bool = false,
        sets: [SetDraft] = []
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.plannedSets = plannedSets
        self.plannedReps = plannedReps
        self.plannedWeight = plannedWeight
        self.trackingMode = trackingMode
        self.plannedDuration = plannedDuration
        self.isPerSet = isPerSet
        self.sets = sets
    }
}

/// One row inside an ExerciseDraft's per-set list. Just weight +
/// reps plus a stable id so SwiftUI's ForEach can identify rows
/// across reorder / insert / delete.
struct SetDraft: Identifiable, Hashable {
    let id: UUID
    var weight: Double
    var reps: Int
    var duration: TimeInterval

    init(id: UUID = UUID(), weight: Double, reps: Int, duration: TimeInterval = 0) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.duration = duration
    }
}

extension ExerciseDraft {
    /// Build from a catalog pick — pre-fills sensible defaults so
    /// the user doesn't always scrub from zero. Starts in uniform
    /// mode; the user can expand to per-set in the editor.
    init(from item: ExerciseCatalogItem) {
        self.init(
            name: item.name,
            group: item.group,
            plannedSets: 3,
            plannedReps: item.defaultReps,
            plannedWeight: item.defaultWeight,
            trackingMode: item.trackingMode,
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
                group: templateExercise.group,
                plannedSets: templateExercise.plannedSets,
                plannedReps: templateExercise.plannedReps,
                plannedWeight: templateExercise.plannedWeight,
                trackingMode: templateExercise.trackingMode,
                plannedDuration: templateExercise.plannedDuration,
                isPerSet: true,
                sets: orderedTemplateSets.map {
                    SetDraft(weight: $0.weight, reps: $0.reps, duration: $0.duration)
                }
            )
        } else {
            self.init(
                name: templateExercise.name,
                group: templateExercise.group,
                plannedSets: templateExercise.plannedSets,
                plannedReps: templateExercise.plannedReps,
                plannedWeight: templateExercise.plannedWeight,
                trackingMode: templateExercise.trackingMode,
                plannedDuration: templateExercise.plannedDuration,
                isPerSet: false,
                sets: []
            )
        }
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
        sets = (0..<count).map { _ in SetDraft(weight: weight, reps: reps, duration: duration) }
        isPerSet = true
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
        return sets.allSatisfy { $0.weight == first.weight && $0.reps == first.reps }
    }

    // MARK: - Summary line

    /// Human-readable summary for the collapsed editor row and the
    /// TemplateDetailScreen list. Uniform mode reads as "3 × 8 @ 135 lb";
    /// per-set mode condenses to a count + range like "5 sets · 135–185 lb".
    /// Caller passes the user's preferred unit so the value type stays
    /// pure and doesn't reach into UserDefaults.
    func summary(unit: WeightUnit) -> String {
        switch trackingMode {
        case .reps:
            if isPerSet, !sets.isEmpty {
                let weights = sets.map(\.weight)
                guard let lo = weights.min(), let hi = weights.max() else { return "" }
                if lo == hi {
                    // All rows happen to be identical — read uniformly.
                    return "\(sets.count) × \(sets[0].reps) @ \(WeightFormatter.string(lo, unit: unit))"
                }
                let loStr = WeightFormatter.string(lo, unit: unit, includeUnit: false)
                let hiStr = WeightFormatter.string(hi, unit: unit)
                return "\(sets.count) sets · \(loStr)–\(hiStr)"
            }
            return "\(plannedSets) × \(plannedReps) @ \(WeightFormatter.string(plannedWeight, unit: unit))"

        case .duration:
            if isPerSet, !sets.isEmpty {
                let durations = sets.map(\.duration)
                guard let lo = durations.min(), let hi = durations.max() else { return "" }
                if lo == hi {
                    return "\(sets.count) × \(DurationFormatter.string(lo)) hold"
                }
                return "\(sets.count) sets · \(DurationFormatter.string(lo))–\(DurationFormatter.string(hi))"
            }
            let base = "\(plannedSets) × \(DurationFormatter.string(plannedDuration)) hold"
            return plannedWeight > 0
                ? "\(base) @ \(WeightFormatter.string(plannedWeight, unit: unit))"
                : base
        }
    }
}
