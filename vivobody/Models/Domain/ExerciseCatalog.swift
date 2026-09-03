//
//  ExerciseCatalog.swift
//  vivobody
//
//  Persistent catalog used for templates, mid-workout additions, and custom entries:
//  identity, display fields, logging defaults, aliases, categorical muscle
//  roles, and raw-value accessors for the shared classification vocabulary.
//
//  AppRoot reconciles bundled entries with the generated `catalog.json`
//  (see `CatalogData`) on every launch, so ongoing exercise-authoring edits,
//  additions, and removals reach the development store. User logging defaults,
//  favorites, measured 1RM values, and custom entries remain untouched.
//  Templates and sessions copy stable IDs and display fields, preserving logged workouts.
//

import Foundation
import SwiftData

/// One entry in the picker. Carries a sensible default starting
/// weight so the user doesn't always have to scrub from zero; the
/// weight can still be adjusted per-template afterward.
@Model
final class ExerciseCatalogItem: Identifiable {
    #Index<ExerciseCatalogItem>([\.catalogID])
    var id: UUID = UUID()

    /// Stable ID from the bundled catalog (for example `bench-press`).
    /// Nil only for user-created exercises. Unlike the install-local
    /// UUID, this survives a factory reset and catalog reseed.
    var catalogID: String? = nil

    /// Stable movement-family identity from the compiled catalog.
    /// Nil only for user-created exercises.
    var familyID: String? = nil

    var name: String = ""
    var muscleGroupRaw: String = MuscleGroup.chest.rawValue
    var defaultWeight: Double = 0
    var defaultReps: Int = 8

    /// Native kg starting weight (a multiple of 2.5 kg) for kg users,
    /// so a kg scrubber seeds on a clean detent instead of an off-grid
    /// conversion of the lb default (135 lb → 61.2 kg). Nil for
    /// zero-weight or otherwise unloaded bodyweight/duration lifts and
    /// user-created customs, which fall back to the single lb default.
    /// Resolved to canonical lb at the seed/display boundary; additive
    /// defaulted field, so no migration for existing catalogs.
    var defaultWeightKg: Double? = nil

    /// How this exercise is measured — reps or a timed hold. Stored
    /// as a raw value; defaulted so existing catalogs read as reps
    /// with no migration. Copied to templates / sessions at pick-time.
    var trackingModeRaw: String = TrackingMode.reps.rawValue

    /// Whether this is rep strength, hold strength, or explosive work.
    var modalityRaw: String = ExerciseModality.dynamicStrength.rawValue

    /// How logged resistance combines with body weight.
    var loadModeRaw: String = ExerciseLoadMode.external.rawValue

    /// Share of body weight carried by the movement. Its meaning is
    /// governed by `loadMode`; external and non-comparable work use 0.
    var bodyweightFraction: Double = 0

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
    /// "Barbell Bench Press"-style entry is more likely compound than not.
    var mechanicRaw: String = Mechanic.compound.rawValue

    /// Cross-mechanic programming placement. Optional storage preserves
    /// the honest unknown state for pre-existing custom catalog rows.
    var trainingRoleRaw: String? = nil

    /// Compound movement pattern; nil for isolation work. The editor hides
    /// this selector when mechanic is isolation, but storage does not enforce
    /// that soft rule.
    var patternRaw: String? = nil

    /// Horizontal vs. vertical orientation for push/pull patterns.
    /// Nil for every other movement pattern. Stored as an optional raw
    /// value so this is an additive field for existing SwiftData stores.
    var directionRaw: String? = nil

    /// Canonical plane components. Every compiled record has one or more
    /// values.
    var planeRaws: [String] = [MovementPlane.sagittal.rawValue]

    /// Bilateral (both sides at once) vs. unilateral (one side at a
    /// time). Non-optional with a `.bilateral` default. Additive
    /// defaulted field, so no migration for existing catalogs.
    var lateralityRaw: String = Laterality.bilateral.rawValue

    /// Alternate names / abbreviations the user might type to find
    /// this exercise. e.g. "BP", "Flat Bench" → Bench Press. Searched
    /// alongside `name` in the picker. Empty by default.
    var aliases: [String] = []

    /// Structured execution instructions. Bundled records provide the
    /// full object; manually created exercises have none.
    var execution: ExecutionInstructions? = nil

    /// Explicit categorical muscle roles authored for this item. The
    /// compact Double values encode role identity for snapshot
    /// compatibility; analytics and rendering derive their own credit.
    var muscleInvolvementSnapshot: [String: Double] = [:]

    /// Stamped at creation. Used as a sort tiebreaker after
    /// muscle-group and name, so two items with the same name (which
    /// shouldn't happen but isn't enforced) have a stable order.
    var createdAt: Date = Date()

    /// True for entries the user added themselves; false for ones
    /// the first-launch seeder inserted. Not user-visible today
    /// (edit/delete work the same for both), but kept for a potential
    /// future "Reset catalog to defaults" affordance.
    var isUserCreated: Bool = false

    /// User-starred favorite. Toggled from the Library catalog list,
    /// the exercise picker, and the exercise detail toolbar; surfaces
    /// a Favorites filter chip on both browse surfaces. Additive
    /// defaulted field — no migration.
    var isFavorite: Bool = false

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
                directionRaw = nil
            }
        }
    }

    var trainingRole: TrainingRole? {
        get { trainingRoleRaw.flatMap(TrainingRole.init(rawValue:)) }
        set { trainingRoleRaw = newValue?.rawValue }
    }

    var pattern: MovementPattern? {
        get { patternRaw.flatMap(MovementPattern.init(rawValue:)) }
        set {
            patternRaw = newValue?.rawValue
            if newValue != .push, newValue != .pull {
                directionRaw = nil
            }
        }
    }

    var direction: PushPullDirection? {
        get { directionRaw.flatMap(PushPullDirection.init(rawValue:)) }
        set {
            directionRaw = (pattern == .push || pattern == .pull)
                ? newValue?.rawValue
                : nil
        }
    }

    /// User-facing movement label, combining direction with push/pull
    /// while leaving the other movement patterns unchanged.
    var movementLabel: String? {
        guard let pattern else { return nil }
        if let direction, pattern == .push || pattern == .pull {
            return "\(direction.displayName) \(pattern.displayName)"
        }
        return pattern.displayName
    }

    /// Bundled discovery prior, resolved by stable ID instead of copied
    /// into SwiftData. Catalog updates therefore improve search ordering
    /// on existing installs without overwriting user edits or migrating
    /// the persistent store. User-created exercises have no default boost.
    var searchPriority: Int {
        guard let catalogID else { return 0 }
        return CatalogData.record(forCatalogID: catalogID)?.searchPriorityValue ?? 0
    }

    var planes: [MovementPlane] {
        get {
            let decoded = planeRaws.compactMap(MovementPlane.init(rawValue:))
            guard !decoded.isEmpty, decoded.count == planeRaws.count else {
                return [.sagittal]
            }
            return MovementPlane.canonicalized(decoded)
        }
        set {
            let canonical = MovementPlane.canonicalized(newValue)
            let resolved = canonical.isEmpty ? [.sagittal] : canonical
            planeRaws = resolved.map(\.rawValue)
        }
    }

    var laterality: Laterality {
        get { Laterality(rawValue: lateralityRaw) ?? .bilateral }
        set { lateralityRaw = newValue.rawValue }
    }

    /// Movement metadata copied into templates and logged exercises at
    /// pick-time. Catalog fields are non-optional where the taxonomy
    /// requires a value, so every catalog item has a classification.
    var classification: ExerciseClassification {
        ExerciseClassification(
            equipment: equipment,
            mechanic: mechanic,
            trainingRole: trainingRole,
            pattern: pattern,
            direction: direction,
            planes: planes,
            laterality: laterality
        )
    }

    /// Muscles worked by categorical role — a pure decode of the
    /// authored canonical snapshot. Custom items stay explicit and
    /// never fabricate anatomy from a bundled name or browse group.
    var muscleInvolvement: Muscle.Involvement {
        Muscle.Involvement(snapshot: muscleInvolvementSnapshot)
    }

    init(
        id: UUID = UUID(),
        catalogID: String? = nil,
        familyID: String? = nil,
        name: String,
        group: MuscleGroup,
        defaultWeight: Double,
        defaultReps: Int? = nil,
        defaultWeightKg: Double? = nil,
        trackingMode: TrackingMode = .reps,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external,
        bodyweightFraction: Double = 0,
        defaultDuration: TimeInterval = 0,
        equipment: Equipment = .barbell,
        mechanic: Mechanic = .compound,
        trainingRole: TrainingRole? = nil,
        pattern: MovementPattern? = nil,
        direction: PushPullDirection? = nil,
        planes: [MovementPlane] = [.sagittal],
        laterality: Laterality = .bilateral,
        aliases: [String] = [],
        execution: ExecutionInstructions? = nil,
        muscleInvolvement: Muscle.Involvement? = nil,
        isUserCreated: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.catalogID = catalogID
        self.familyID = familyID
        self.name = name
        self.muscleGroupRaw = group.rawValue
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps ?? (mechanic == .compound ? 8 : 12)
        self.defaultWeightKg = defaultWeightKg
        self.trackingModeRaw = trackingMode.rawValue
        self.modalityRaw = modality.rawValue
        self.loadModeRaw = loadMode.rawValue
        self.bodyweightFraction = max(0, min(bodyweightFraction, 1))
        self.defaultDuration = defaultDuration
        self.equipmentRaw = equipment.rawValue
        self.mechanicRaw = mechanic.rawValue
        self.trainingRoleRaw = trainingRole?.rawValue
        self.patternRaw = (mechanic == .isolation) ? nil : pattern?.rawValue
        self.directionRaw = (mechanic == .compound && (pattern == .push || pattern == .pull))
            ? direction?.rawValue
            : nil
        let canonicalPlanes = MovementPlane.canonicalized(planes)
        let resolvedPlanes = canonicalPlanes.isEmpty ? [.sagittal] : canonicalPlanes
        self.planeRaws = resolvedPlanes.map(\.rawValue)
        self.lateralityRaw = laterality.rawValue
        self.aliases = aliases
        self.execution = execution
        self.muscleInvolvementSnapshot = muscleInvolvement?.snapshot ?? [:]
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
            catalogID: record.catalogID,
            familyID: record.familyID,
            name: record.name,
            group: record.muscleGroup,
            defaultWeight: record.defaultWeightValue,
            defaultReps: record.defaultRepsValue,
            defaultWeightKg: record.defaultWeightKgValue,
            trackingMode: record.trackingModeValue,
            modality: record.modality,
            loadMode: record.loadMode,
            bodyweightFraction: record.bodyweightFraction,
            defaultDuration: record.defaultDurationValue,
            equipment: record.equipmentValue,
            mechanic: record.mechanicValue,
            trainingRole: record.trainingRoleValue,
            pattern: record.patternValue,
            direction: record.directionValue,
            planes: record.planeValues,
            laterality: record.lateralityValue,
            aliases: record.aliasesValue,
            execution: record.execution,
            muscleInvolvement: record.muscleInvolvement,
            isUserCreated: false,
            createdAt: createdAt
        )
    }
}

// MARK: - Grouping helper

extension [ExerciseCatalogItem] {
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
