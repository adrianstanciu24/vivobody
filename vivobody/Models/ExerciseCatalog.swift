//
//  ExerciseCatalog.swift
//  vivobody
//
//  Persistent catalog of lifts the user picks from when building a
//  template or adding an exercise mid-workout. Stored as @Model so
//  the user can extend it with custom entries — name + muscle group
//  + equipment + mechanic + pattern + aliases + sensible defaults —
//  and edit/delete them in place.
//
//  On first launch the catalog is empty; AppRoot calls `seedIfEmpty`
//  to populate it from the bundled `catalog.json` (see `CatalogData`). After
//  that, user adds/edits/deletes flow through SwiftData like any
//  other model. Templates and sessions copy stable catalog IDs plus
//  display fields at creation time, so renaming a catalog item keeps
//  history connected while deleting one never breaks old workouts.
//

import Foundation
import SwiftData

// MARK: - Equipment

/// Primary piece of gear the lift uses. Drives the equipment filter
/// chip strip at the top of the picker / Library. Stored as the raw
/// value on `ExerciseCatalogItem` so the enum can evolve without
/// migrations.
enum Equipment: String, Hashable, CaseIterable {
    case barbell
    case dumbbell
    case cable
    case machine
    case bodyweight
    case kettlebell
    case band
    case other

    var displayName: String {
        switch self {
        case .barbell:    return "Barbell"
        case .dumbbell:   return "Dumbbell"
        case .cable:      return "Cable"
        case .machine:    return "Machine"
        case .bodyweight: return "Bodyweight"
        case .kettlebell: return "Kettlebell"
        case .band:       return "Band"
        case .other:      return "Other"
        }
    }
}

// MARK: - Mechanic

/// Compound (multi-joint) vs. isolation (single-joint). Affects
/// PR-detection sensitivity and which patterns make sense — only
/// compound lifts carry a `MovementPattern`.
enum Mechanic: String, Hashable, CaseIterable {
    case compound
    case isolation

    var displayName: String {
        switch self {
        case .compound:  return "Compound"
        case .isolation: return "Isolation"
        }
    }
}

// MARK: - Movement pattern

/// The primary motor pattern of the lift. Optional — only compound
/// lifts have a meaningful pattern; isolation work is left nil.
/// Useful for programming-aware features (push/pull balance,
/// session structure suggestions) we'll layer in later.
enum MovementPattern: String, Hashable, CaseIterable {
    case push     // bench, OHP, dips
    case pull     // rows, pulldowns
    case squat    // back squat, front squat, leg press
    case hinge    // deadlift, RDL, good morning
    case lunge    // split squat, step-up, walking lunge
    case carry    // farmer's carry, suitcase, yoke
    case core     // planks, leg raises, anti-rotation

    var displayName: String {
        switch self {
        case .push:  return "Push"
        case .pull:  return "Pull"
        case .squat: return "Squat"
        case .hinge: return "Hinge"
        case .lunge: return "Lunge"
        case .carry: return "Carry"
        case .core:  return "Core"
        }
    }
}

// MARK: - Movement plane

/// The anatomical plane the lift's working limbs primarily travel
/// through. Unlike `MovementPattern` (push/pull only) this applies to
/// every exercise, so it's non-optional and defaults to `.sagittal` —
/// where the overwhelming majority of barbell work lives. Drives a
/// future "plane coverage" stat so the user can see whether they ever
/// load the frontal/transverse planes or live entirely in the
/// sagittal one.
///
/// Classification heuristic (kept deliberately simple so tagging is
/// unambiguous and the coverage metric stays honest):
///   • transverse — rotation or a pure horizontal arm ad/abduction:
///     twists, Pallof, flys, pec deck, rear-delt fly, face pull.
///   • frontal    — lateral travel / ab-adduction in the coronal
///     plane: lateral raise, hip ab/adduction, side plank, upright row.
///   • sagittal   — everything else (forward/back, up/down): all
///     squats, hinges, presses, rows, vertical pulls, curls,
///     extensions, planks, carries.
/// Multi-joint presses stay sagittal even though the shoulder
/// horizontally adducts — the press pattern dominates; a pure fly,
/// whose only action is that adduction, is transverse.
enum MovementPlane: String, Hashable, CaseIterable {
    case sagittal
    case frontal
    case transverse

    var displayName: String {
        switch self {
        case .sagittal:   return "Sagittal"
        case .frontal:    return "Frontal"
        case .transverse: return "Transverse"
        }
    }
}

// MARK: - Laterality

/// Whether the lift loads both sides together or one side at a time.
/// Non-optional with a `.bilateral` default — most barbell/machine
/// work is bilateral. Unilateral lifts (split squat, single-arm row,
/// lunges) are logged/loaded per side, so this is the hook a future
/// per-side logging or left/right balance feature reads. Bounded,
/// trivially taggable on seeds and user-created entries alike.
enum Laterality: String, Hashable, CaseIterable {
    case bilateral
    case unilateral

    var displayName: String {
        switch self {
        case .bilateral:  return "Bilateral"
        case .unilateral: return "Unilateral"
        }
    }
}

/// One entry in the picker. Carries a sensible default starting
/// weight so the user doesn't always have to scrub from zero; the
/// weight can still be adjusted per-template afterward.
@Model
final class ExerciseCatalogItem: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var muscleGroupRaw: String = MuscleGroup.chest.rawValue
    var defaultWeight: Double = 0
    var defaultReps: Int = 8

    /// Native kg starting weight (a multiple of 2.5 kg) for kg users,
    /// so a kg scrubber seeds on a clean detent instead of an off-grid
    /// conversion of the lb default (135 lb → 61.2 kg). Nil for
    /// bodyweight / duration lifts and user-created customs, which
    /// fall back to the single lb default. Resolved to canonical lb at
    /// the seed/display boundary; additive defaulted field, so no
    /// migration for existing catalogs.
    var defaultWeightKg: Double? = nil

    /// How this exercise is measured — reps or a timed hold. Stored
    /// as a raw value; defaulted so existing catalogs read as reps
    /// with no migration. Copied to templates / sessions at pick-time.
    var trackingModeRaw: String = TrackingMode.reps.rawValue

    /// Default hold length (seconds) for `.duration` exercises —
    /// the timed counterpart to `defaultReps`. Ignored when the mode
    /// is `.reps`. Additive defaulted field — no migration.
    var defaultDuration: TimeInterval = 0

    /// User-measured true one-rep max, in canonical pounds. A tested
    /// max is more accurate than the Epley estimate, so when this is
    /// set it overrides the estimated e1RM on the detail screen. Nil
    /// means "no measured max — fall back to the estimate from logged
    /// sets." Additive defaulted field — no migration.
    var oneRepMax: Double? = nil

    /// Primary equipment used. Defaults to barbell on a new entry
    /// (matches the most common case for a serious lifter) but can
    /// be edited per-exercise. Stored as raw value so the Equipment
    /// enum can evolve without breaking the schema.
    var equipmentRaw: String = Equipment.barbell.rawValue

    /// Compound vs. isolation. Defaults to compound — a brand-new
    /// "Bench Press"-style entry is more likely compound than not.
    var mechanicRaw: String = Mechanic.compound.rawValue

    /// Movement pattern (push/pull/squat/hinge/lunge/carry/core).
    /// Optional because isolation work doesn't have a meaningful
    /// pattern. Nil-when-isolation is a soft rule, not enforced in
    /// the store — the editor just hides the pattern selector when
    /// mechanic is isolation.
    var patternRaw: String? = nil

    /// Anatomical plane the lift primarily trains. Non-optional with a
    /// `.sagittal` default — every exercise lives in some plane and
    /// most live here. Stored as raw value so `MovementPlane` can
    /// evolve without breaking the schema. Additive defaulted field,
    /// so no migration for existing catalogs.
    var planeRaw: String = MovementPlane.sagittal.rawValue

    /// Bilateral (both sides at once) vs. unilateral (one side at a
    /// time). Non-optional with a `.bilateral` default. Additive
    /// defaulted field, so no migration for existing catalogs.
    var lateralityRaw: String = Laterality.bilateral.rawValue

    /// Alternate names / abbreviations the user might type to find
    /// this exercise. e.g. "BP", "Flat Bench" → Bench Press. Searched
    /// alongside `name` in the picker. Empty by default.
    var aliases: [String] = []

    /// Catalog-level form cues that follow the lift forever. Distinct
    /// from `Exercise.notes` which are session-specific ("shoulder
    /// twinge today"). Surface example: "Brace before unrack. Touch
    /// chest. Drive through legs." Edited inline on the detail
    /// screen. Empty by default.
    var notes: String = ""

    /// Stamped at creation. Used as a sort tiebreaker after
    /// muscle-group and name, so two items with the same name (which
    /// shouldn't happen but isn't enforced) have a stable order.
    var createdAt: Date = Date()

    /// True for entries the user added themselves; false for ones
    /// the first-launch seeder inserted. Not user-visible today
    /// (edit/delete work the same for both), but kept for a potential
    /// future "Reset catalog to defaults" affordance.
    var isUserCreated: Bool = false

    // MARK: - Computed accessors

    var group: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .chest }
        set { muscleGroupRaw = newValue.rawValue }
    }

    /// Canonical-lb default to seed or display for `unit`. kg users get
    /// the native kg default (converted to canonical lb) when one
    /// shipped; everyone else gets the single lb default. Keeps stored
    /// weight canonical while letting each unit start on a clean,
    /// gym-natural number.
    func defaultWeight(forUnit unit: WeightUnit) -> Double {
        guard unit == .kg, let kg = defaultWeightKg else { return defaultWeight }
        return WeightFormatter.toCanonical(kg, unit: .kg)
    }

    /// The seed default resolved against the user's current unit
    /// preference. For value-copying inits (template / workout / draft)
    /// that have no view context to read @AppStorage.
    var defaultWeightSeed: Double {
        defaultWeight(forUnit: .current)
    }

    /// Computed accessor for the tracking-mode enum.
    var trackingMode: TrackingMode {
        get { TrackingMode(rawValue: trackingModeRaw) ?? .reps }
        set { trackingModeRaw = newValue.rawValue }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .barbell }
        set { equipmentRaw = newValue.rawValue }
    }

    var mechanic: Mechanic {
        get { Mechanic(rawValue: mechanicRaw) ?? .compound }
        set {
            mechanicRaw = newValue.rawValue
            // Clearing the pattern when the user switches an exercise
            // to isolation keeps the data honest. The editor enforces
            // this in the UI but mutating directly should follow the
            // same rule.
            if newValue == .isolation {
                patternRaw = nil
            }
        }
    }

    var pattern: MovementPattern? {
        get { patternRaw.flatMap(MovementPattern.init(rawValue:)) }
        set { patternRaw = newValue?.rawValue }
    }

    var plane: MovementPlane {
        get { MovementPlane(rawValue: planeRaw) ?? .sagittal }
        set { planeRaw = newValue.rawValue }
    }

    var laterality: Laterality {
        get { Laterality(rawValue: lateralityRaw) ?? .bilateral }
        set { lateralityRaw = newValue.rawValue }
    }

    /// Muscles worked, with their graded contribution weights. Seeded
    /// items resolve from the curated catalog map; custom names fall
    /// back to their coarse muscle group so analytics still count
    /// user-created exercises.
    var muscleInvolvement: Muscle.Involvement {
        Muscle.involvement(forExerciseNamed: name, fallbackGroup: group)
    }

    init(
        id: UUID = UUID(),
        name: String,
        group: MuscleGroup,
        defaultWeight: Double,
        defaultReps: Int? = nil,
        defaultWeightKg: Double? = nil,
        trackingMode: TrackingMode = .reps,
        defaultDuration: TimeInterval = 0,
        equipment: Equipment = .barbell,
        mechanic: Mechanic = .compound,
        pattern: MovementPattern? = nil,
        plane: MovementPlane = .sagittal,
        laterality: Laterality = .bilateral,
        aliases: [String] = [],
        notes: String = "",
        isUserCreated: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.muscleGroupRaw = group.rawValue
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps ?? (mechanic == .compound ? 8 : 12)
        self.defaultWeightKg = defaultWeightKg
        self.trackingModeRaw = trackingMode.rawValue
        self.defaultDuration = defaultDuration
        self.equipmentRaw = equipment.rawValue
        self.mechanicRaw = mechanic.rawValue
        self.patternRaw = (mechanic == .isolation) ? nil : pattern?.rawValue
        self.planeRaw = plane.rawValue
        self.lateralityRaw = laterality.rawValue
        self.aliases = aliases
        self.notes = notes
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
    }
}

// MARK: - Seeding

extension ExerciseCatalogItem {
    /// Build a catalog item from a decoded `CatalogRecord`. The starter
    /// catalog ships in `catalog.json` (see `CatalogData`); seeding just
    /// mirrors each record into a `@Model` instance the user can edit.
    convenience init(record: CatalogRecord, createdAt: Date) {
        self.init(
            name: record.name,
            group: record.muscleGroup,
            defaultWeight: record.defaultWeightValue,
            defaultReps: record.defaultRepsValue,
            defaultWeightKg: record.defaultWeightKgValue,
            trackingMode: record.trackingModeValue,
            defaultDuration: record.defaultDurationValue,
            equipment: record.equipmentValue,
            mechanic: record.mechanicValue,
            pattern: record.patternValue,
            plane: record.planeValue,
            laterality: record.lateralityValue,
            aliases: record.aliasesValue,
            isUserCreated: false,
            createdAt: createdAt
        )
    }

    /// Insert the starter catalog when the store is empty. Idempotent
    /// — bails immediately if any catalog item already exists. Called
    /// from AppRoot.onAppear so the picker is never empty even on a
    /// brand-new install.
    static func seedIfEmpty(in context: ModelContext) {
        let descriptor = FetchDescriptor<ExerciseCatalogItem>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        // Stagger createdAt slightly so the catalog.json order is
        // preserved when we tie-break by date — otherwise every item
        // shares the same timestamp and falls back to arbitrary
        // FetchDescriptor ordering.
        let base = Date()
        for (i, record) in CatalogData.records.enumerated() {
            let item = ExerciseCatalogItem(
                record: record,
                createdAt: base.addingTimeInterval(Double(i) * 0.001)
            )
            context.insert(item)
        }
        try? context.saveOrRollback()
    }

    /// Wipe the entire catalog and re-seed from the bundled list.
    /// User-created entries are removed alongside any edits to seeded
    /// items — the mental model is "factory reset." Templates and
    /// workout history are unaffected because they copy values at
    /// pick-time and never reference catalog items directly.
    ///
    /// Triggered from Me → Preferences → Reset Exercise Catalog,
    /// behind a destructive-styled confirmation alert.
    static func resetToDefaults(in context: ModelContext) {
        let descriptor = FetchDescriptor<ExerciseCatalogItem>()
        if let existing = try? context.fetch(descriptor) {
            for item in existing {
                context.delete(item)
            }
        }
        try? context.saveOrRollback()
        seedIfEmpty(in: context)
    }

    /// Link legacy copied exercises/templates to catalog rows when the
    /// current names still match, and snapshot muscle involvement so
    /// custom/renamed exercises keep contributing to analytics. Safe
    /// to run repeatedly; it only fills missing additive fields.
    static func backfillCopiedExerciseIdentity(in context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<ExerciseCatalogItem>())) ?? []
        guard !items.isEmpty else { return }

        let itemsByName = Dictionary(
            items.map { ($0.name.exerciseIdentityName, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let itemsByID = Dictionary(
            items.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var changed = false

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        for exercise in exercises {
            let item = exercise.catalogItemID.flatMap { itemsByID[$0] }
                ?? itemsByName[exercise.name.exerciseIdentityName]
            if exercise.catalogItemID == nil, let item {
                exercise.catalogItemID = item.id
                changed = true
            }
            if exercise.muscleInvolvementSnapshot.isEmpty {
                let involvement = item?.muscleInvolvement
                    ?? Muscle.involvement(forExerciseNamed: exercise.name, fallbackGroup: exercise.group)
                exercise.muscleInvolvementSnapshot = involvement.snapshot
                changed = true
            }
        }

        let templateExercises = (try? context.fetch(FetchDescriptor<TemplateExercise>())) ?? []
        for exercise in templateExercises {
            let item = exercise.catalogItemID.flatMap { itemsByID[$0] }
                ?? itemsByName[exercise.name.exerciseIdentityName]
            if exercise.catalogItemID == nil, let item {
                exercise.catalogItemID = item.id
                changed = true
            }
            if exercise.muscleInvolvementSnapshot.isEmpty {
                let involvement = item?.muscleInvolvement
                    ?? Muscle.involvement(forExerciseNamed: exercise.name, fallbackGroup: exercise.group)
                exercise.muscleInvolvementSnapshot = involvement.snapshot
                changed = true
            }
        }

        if changed {
            try? context.saveOrRollback()
        }
    }
}

// MARK: - Exercise identity

nonisolated enum ExerciseIdentity {
    static func key(catalogItemID: UUID?, name: String) -> String {
        if let catalogItemID {
            return "catalog:\(catalogItemID.uuidString)"
        }
        return nameKey(name)
    }

    static func nameKey(_ name: String) -> String {
        "name:\(name.exerciseIdentityName)"
    }
}

extension String {
    nonisolated var exerciseIdentityName: String {
        lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ExerciseCatalogItem {
    var historyKey: String {
        ExerciseIdentity.key(catalogItemID: id, name: name)
    }

    var legacyHistoryKey: String {
        ExerciseIdentity.nameKey(name)
    }
}

extension Exercise {
    var historyKey: String {
        ExerciseIdentity.key(catalogItemID: catalogItemID, name: name)
    }

    var legacyHistoryKey: String {
        ExerciseIdentity.nameKey(name)
    }

    func matchesCatalogItem(_ item: ExerciseCatalogItem) -> Bool {
        if let catalogItemID {
            return catalogItemID == item.id
        }
        return name.exerciseIdentityName == item.name.exerciseIdentityName
    }
}

// MARK: - Grouping helper

extension Array where Element == ExerciseCatalogItem {
    /// Group catalog items by muscle group for the sectioned picker
    /// UI. Group order follows the MuscleGroup enum; items inside
    /// each group are sorted by createdAt (preserves seed order;
    /// user-added items come after the seeded ones in their group).
    var groupedByMuscle: [(group: MuscleGroup, items: [ExerciseCatalogItem])] {
        MuscleGroup.allCases.compactMap { group in
            let items = self
                .filter { $0.group == group }
                .sorted { $0.createdAt < $1.createdAt }
            return items.isEmpty ? nil : (group: group, items: items)
        }
    }
}
