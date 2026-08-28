//
//  ExerciseCatalog.swift
//  vivobody
//
//  Persistent catalog of lifts used to build templates or add exercises
//  mid-workout. Stored as @Model so users can extend it with custom entries:
//  name, muscle group, equipment, mechanic, training role, compound pattern,
//  direction, aliases, categorical muscle roles, and sensible defaults.
//
//  AppRoot reconciles bundled entries with the generated `catalog.json`
//  (see `CatalogData`) on every launch, so ongoing exercise-authoring edits,
//  additions, and removals reach the development store. User logging defaults,
//  favorites, measured 1RM values, and custom entries remain untouched.
//  Templates and sessions copy stable catalog IDs plus display fields at
//  creation time, so deleting a catalog entry never breaks logged workouts.
//

import Foundation
import SwiftData

// MARK: - Equipment

/// Primary piece of gear the lift uses. Drives the equipment filter
/// chip strip at the top of the picker / Library. Stored as the raw
/// value on `ExerciseCatalogItem` so the enum can evolve without
/// migrations.
nonisolated enum Equipment: String, Codable, Hashable, CaseIterable {
    case barbell
    case dumbbell
    case cable
    case machine
    case bodyweight
    case kettlebell
    case band
    case gripTrainer
    case trapBar
    case other

    nonisolated var displayName: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .cable: "Cable"
        case .machine: "Machine"
        case .bodyweight: "Bodyweight"
        case .kettlebell: "Kettlebell"
        case .band: "Band"
        case .gripTrainer: "Grip Trainer"
        case .trapBar: "Trap Bar"
        case .other: "Other"
        }
    }
}

// MARK: - Movement pattern

/// The dominant compound motor pattern. Isolation work is described by
/// its joint action in the catalog and uses `TrainingRole` for PPL-style
/// programming placement.
nonisolated enum MovementPattern: String, Codable, Hashable, CaseIterable {
    case push // bench, OHP, dips
    case pull // rows, pulldowns
    case squat // back squat, front squat, leg press
    case hinge // deadlift, RDL, good morning
    case lunge // split squat, step-up, walking lunge
    case carry // farmer's carry, suitcase, yoke
    case core // planks, leg raises, anti-rotation
    case hang // passive and active straight-arm hangs

    nonisolated var displayName: String {
        switch self {
        case .push: "Push"
        case .pull: "Pull"
        case .squat: "Squat"
        case .hinge: "Hinge"
        case .lunge: "Lunge"
        case .carry: "Carry"
        case .core: "Core"
        case .hang: "Hang"
        }
    }
}

// MARK: - Push/pull direction

/// Whether a push/pull moves the load primarily away from/toward the
/// torso or overhead/down from overhead. Optional because it only has
/// meaning for `.push` and `.pull` movement patterns.
nonisolated enum PushPullDirection: String, Codable, Hashable, CaseIterable {
    case horizontal
    case vertical
    case diagonal

    nonisolated var displayName: String {
        switch self {
        case .horizontal: "Horizontal"
        case .vertical: "Vertical"
        case .diagonal: "Diagonal"
        }
    }
}

// MARK: - Movement plane

/// One cardinal anatomical plane in a family's reviewed action basis.
/// Exercises can author multiple components; direction (including a
/// diagonal push/pull) remains a separate classification dimension.
nonisolated enum MovementPlane: String, Codable, Hashable, CaseIterable {
    case sagittal
    case frontal
    case transverse

    var displayName: String {
        switch self {
        case .sagittal: "Sagittal"
        case .frontal: "Frontal"
        case .transverse: "Transverse"
        }
    }

    nonisolated static func canonicalized(_ values: [MovementPlane]) -> [MovementPlane] {
        let selected = Set(values)
        return allCases.filter(selected.contains)
    }
}

// MARK: - Laterality

/// Whether the lift loads both sides together or one side at a time.
/// Non-optional with a `.bilateral` default — most barbell/machine
/// work is bilateral. Unilateral lifts (split squat, single-arm row,
/// lunges) are logged/loaded per side, so this is the hook a future
/// per-side logging or left/right balance feature reads. Bounded,
/// trivially taggable on seeds and user-created entries alike.
nonisolated enum Laterality: String, Codable, Hashable, CaseIterable {
    case bilateral
    case unilateral

    var displayName: String {
        switch self {
        case .bilateral: "Bilateral"
        case .unilateral: "Unilateral"
        }
    }
}

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

    /// Reconcile the persistent bundled rows with the generated catalog.
    /// Canonical identity, anatomy, and movement semantics follow the source;
    /// personal logging defaults, favorites, measured 1RM values, install-local
    /// IDs, and user-created exercises remain untouched. Returns removed local
    /// IDs so AppRoot can clear their Spotlight entries.
    @discardableResult
    static func synchronizeBundledCatalog(
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) -> [UUID] {
        let descriptor = FetchDescriptor<ExerciseCatalogItem>(
            predicate: #Predicate { !$0.isUserCreated }
        )
        guard let existing = try? context.fetch(descriptor) else { return [] }
        let hiddenIDs = hiddenBundledIDs(in: defaults)
        let recordsByID = Dictionary(
            uniqueKeysWithValues: CatalogData.records.map { ($0.catalogID, $0) }
        )
        var retainedIDs: Set<String> = []
        var removedIDs: [UUID] = []

        for item in existing {
            guard
                let catalogID = item.catalogID,
                !hiddenIDs.contains(catalogID),
                let record = recordsByID[catalogID],
                retainedIDs.insert(catalogID).inserted
            else {
                removedIDs.append(item.id)
                context.delete(item)
                continue
            }
            item.applyCanonicalFields(from: record)
        }

        let base = Date()
        for (index, record) in CatalogData.records.enumerated()
            where !retainedIDs.contains(record.catalogID)
            && !hiddenIDs.contains(record.catalogID)
        {
            context.insert(
                ExerciseCatalogItem(
                    record: record,
                    createdAt: base.addingTimeInterval(Double(index) * 0.001)
                )
            )
        }

        do {
            try context.saveOrRollback()
            return removedIDs
        } catch {
            return []
        }
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
        do {
            try context.saveOrRollback()
        } catch {
            return
        }
        clearBundledCatalogDeletions()
        synchronizeBundledCatalog(in: context)
    }

    /// Delete one visible catalog row and remember explicit removals of
    /// bundled records so launch reconciliation does not resurrect them.
    @discardableResult
    static func deleteFromCatalog(
        _ item: ExerciseCatalogItem,
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> UUID {
        let id = item.id
        let bundledID = item.isUserCreated ? nil : item.catalogID
        context.delete(item)
        try context.saveOrRollback()

        if let bundledID {
            var hiddenIDs = hiddenBundledIDs(in: defaults)
            hiddenIDs.insert(bundledID)
            defaults.set(hiddenIDs.sorted(), forKey: SettingsKey.hiddenBundledCatalogIDs)
        }
        return id
    }

    static func clearBundledCatalogDeletions(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: SettingsKey.hiddenBundledCatalogIDs)
    }

    private static func hiddenBundledIDs(in defaults: UserDefaults) -> Set<String> {
        Set(defaults.stringArray(forKey: SettingsKey.hiddenBundledCatalogIDs) ?? [])
    }

    private func applyCanonicalFields(from record: CatalogRecord) {
        catalogID = record.catalogID
        familyID = record.familyID
        name = record.name
        group = record.group
        defaultReps = record.reps
        trackingMode = record.trackingMode
        modality = record.modality
        loadMode = record.loadMode
        bodyweightFraction = record.bodyweightFraction
        equipment = record.equipment
        mechanic = record.mechanic
        trainingRole = record.trainingRole
        pattern = record.pattern
        direction = record.direction
        planes = record.planes
        laterality = record.laterality
        aliases = record.aliases
        execution = record.execution
        muscleInvolvementSnapshot = record.muscleInvolvement.snapshot
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
