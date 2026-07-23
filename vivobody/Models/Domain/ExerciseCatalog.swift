//
//  ExerciseCatalog.swift
//  vivobody
//
//  Persistent catalog of lifts the user picks from when building a
//  template or adding an exercise mid-workout. Stored as @Model so
//  the user can extend it with custom entries — name + muscle group
//  + equipment + mechanic + pattern + push/pull direction + aliases +
//  categorical muscle roles + sensible defaults — and edit/delete them
//  in place.
//
//  On first launch the catalog is empty; AppRoot calls `seedIfEmpty`
//  to populate it from the bundled `catalog.json` (see `CatalogData`). After
//  that, user adds/edits/deletes flow through SwiftData like any
//  other model. `pruneRemovedSeeds` keeps existing installs in step
//  when a record is retired from the bundled catalog. Templates and
//  sessions copy stable catalog IDs plus display fields at creation
//  time, so renaming a catalog item keeps history connected while
//  deleting one never breaks old workouts.
//

import Foundation
import SwiftData

// MARK: - Equipment

/// Primary piece of gear the lift uses. Drives the equipment filter
/// chip strip at the top of the picker / Library. Stored as the raw
/// value on `ExerciseCatalogItem` so the enum can evolve without
/// migrations.
nonisolated enum Equipment: String, Codable, Hashable, CaseIterable, Sendable {
    case barbell
    case dumbbell
    case cable
    case machine
    case bodyweight
    case kettlebell
    case band
    case other

    nonisolated var displayName: String {
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
nonisolated enum Mechanic: String, Codable, Hashable, CaseIterable, Sendable {
    case compound
    case isolation

    nonisolated var displayName: String {
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
nonisolated enum MovementPattern: String, Codable, Hashable, CaseIterable, Sendable {
    case push     // bench, OHP, dips
    case pull     // rows, pulldowns
    case squat    // back squat, front squat, leg press
    case hinge    // deadlift, RDL, good morning
    case lunge    // split squat, step-up, walking lunge
    case carry    // farmer's carry, suitcase, yoke
    case core     // planks, leg raises, anti-rotation
    case locomotion // gait, skips, and conditioning footwork

    nonisolated var displayName: String {
        switch self {
        case .push:  return "Push"
        case .pull:  return "Pull"
        case .squat: return "Squat"
        case .hinge: return "Hinge"
        case .lunge: return "Lunge"
        case .carry: return "Carry"
        case .core:  return "Core"
        case .locomotion: return "Locomotion"
        }
    }
}

// MARK: - Push/pull direction

/// Whether a push/pull moves the load primarily away from/toward the
/// torso or overhead/down from overhead. Optional because it only has
/// meaning for `.push` and `.pull` movement patterns.
nonisolated enum PushPullDirection: String, Codable, Hashable, CaseIterable, Sendable {
    case horizontal
    case vertical

    nonisolated var displayName: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical:   return "Vertical"
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
nonisolated enum MovementPlane: String, Codable, Hashable, CaseIterable, Sendable {
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
nonisolated enum Laterality: String, Codable, Hashable, CaseIterable, Sendable {
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
    #Index<ExerciseCatalogItem>([\.catalogID])
    var id: UUID = UUID()

    /// Stable ID from the bundled catalog (for example `bench-press`).
    /// Nil only for user-created exercises. Unlike the install-local
    /// UUID, this survives a factory reset and catalog reseed.
    var catalogID: String? = nil

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

    /// Whether this is dynamic strength, isometric strength,
    /// conditioning, or mobility work.
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

    /// Movement pattern (push/pull/squat/hinge/lunge/carry/core).
    /// Optional because isolation work doesn't have a meaningful
    /// pattern. Nil-when-isolation is a soft rule, not enforced in
    /// the store — the editor just hides the pattern selector when
    /// mechanic is isolation.
    var patternRaw: String? = nil

    /// Horizontal vs. vertical orientation for push/pull patterns.
    /// Nil for every other movement pattern. Stored as an optional raw
    /// value so this is an additive field for existing SwiftData stores.
    var directionRaw: String? = nil

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

    /// Concise canonical movement definition used to disambiguate
    /// similarly named exercises. Bundled records always provide one.
    var movementDefinition: String = ""

    /// Explicit categorical muscle roles authored for this item. The
    /// compact Double values encode visual intensity only; analytics
    /// recover roles and use their separate volume credits.
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

    var pattern: MovementPattern? {
        get { patternRaw.flatMap(MovementPattern.init(rawValue:)) }
        set {
            patternRaw = newValue?.rawValue
            if newValue != .push && newValue != .pull {
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

    var plane: MovementPlane {
        get { MovementPlane(rawValue: planeRaw) ?? .sagittal }
        set { planeRaw = newValue.rawValue }
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
            pattern: pattern,
            direction: direction,
            plane: plane,
            laterality: laterality
        )
    }

    /// Muscles worked by categorical role. Bundled and user-created
    /// items persist explicit roles; an unknown empty item stays empty
    /// rather than fabricating anatomy from its browse group.
    var muscleInvolvement: Muscle.Involvement {
        if !muscleInvolvementSnapshot.isEmpty {
            return Muscle.Involvement(snapshot: muscleInvolvementSnapshot)
        }
        return Muscle.involvement(forExerciseNamed: name)
    }

    init(
        id: UUID = UUID(),
        catalogID: String? = nil,
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
        pattern: MovementPattern? = nil,
        direction: PushPullDirection? = nil,
        plane: MovementPlane = .sagittal,
        laterality: Laterality = .bilateral,
        aliases: [String] = [],
        movementDefinition: String = "",
        muscleInvolvement: Muscle.Involvement? = nil,
        isUserCreated: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.catalogID = catalogID
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
        self.patternRaw = (mechanic == .isolation) ? nil : pattern?.rawValue
        self.directionRaw = (mechanic == .compound && (pattern == .push || pattern == .pull))
            ? direction?.rawValue
            : nil
        self.planeRaw = plane.rawValue
        self.lateralityRaw = laterality.rawValue
        self.aliases = aliases
        self.movementDefinition = movementDefinition
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
            pattern: record.patternValue,
            direction: record.directionValue,
            plane: record.planeValue,
            laterality: record.lateralityValue,
            aliases: record.aliasesValue,
            movementDefinition: record.movementDefinition,
            muscleInvolvement: record.muscleInvolvement,
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

    /// Delete seeded items whose stable catalog ID no longer ships in
    /// the bundled catalog. `seedIfEmpty` only runs on an empty store,
    /// so a record removed from `catalog.json` would otherwise linger
    /// on every existing install. User-created entries (nil catalogID)
    /// are never touched, and templates + history are unaffected
    /// because they copy values at pick-time. Returns the deleted
    /// install-local IDs so the caller can deindex them from Spotlight.
    @discardableResult
    static func pruneRemovedSeeds(in context: ModelContext) -> [UUID] {
        let descriptor = FetchDescriptor<ExerciseCatalogItem>(
            predicate: #Predicate { !$0.isUserCreated }
        )
        guard let seeded = try? context.fetch(descriptor), !seeded.isEmpty else { return [] }

        let bundledIDs = Set(CatalogData.records.map(\.catalogID))
        let stale = seeded.filter { item in
            guard let catalogID = item.catalogID else { return false }
            return !bundledIDs.contains(catalogID)
        }
        guard !stale.isEmpty else { return [] }

        let removedIDs = stale.map(\.id)
        for item in stale {
            context.delete(item)
        }
        try? context.saveOrRollback()
        return removedIDs
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

}

// MARK: - Exercise identity

/// The complete comparison contract captured by a custom exercise.
/// Catalog UUID alone is not enough: changing an external lift into an
/// assisted movement, or changing how much bodyweight it carries, makes
/// old loads physically non-interchangeable even when the broad record
/// kind remains "load then reps".
nonisolated struct ExercisePerformanceSignature: Hashable, Sendable {
    /// One basis point keeps the key deterministic without embedding a
    /// floating-point description. The editor works in 5% increments,
    /// while this finer scale also preserves curated fractional values.
    private static let fractionScale = 10_000.0

    let modality: ExerciseModality
    let trackingMode: TrackingMode
    let loadMode: ExerciseLoadMode
    let bodyweightFractionBasisPoints: Int

    init(
        modality: ExerciseModality,
        trackingMode: TrackingMode,
        loadMode: ExerciseLoadMode,
        bodyweightFraction: Double
    ) {
        self.modality = modality
        self.trackingMode = trackingMode
        self.loadMode = loadMode
        let finiteFraction = bodyweightFraction.isFinite ? bodyweightFraction : 0
        let clampedFraction = max(0, min(finiteFraction, 1))
        self.bodyweightFractionBasisPoints = Int(
            (clampedFraction * Self.fractionScale).rounded()
        )
    }

    var performanceKind: PerformanceSemanticKind {
        modality.performanceSemanticKind(
            for: trackingMode,
            loadMode: loadMode
        )
    }

    /// Delimiters and labels are intentionally fixed so this remains a
    /// stable derived identity rather than locale-dependent display text.
    var keyComponent: String {
        [
            performanceKind.rawValue,
            "modality=\(modality.rawValue)",
            "tracking=\(trackingMode.rawValue)",
            "load=\(loadMode.rawValue)",
            "bodyweightBps=\(bodyweightFractionBasisPoints)",
        ].joined(separator: ":")
    }
}

nonisolated enum ExerciseIdentity {
    static func key(
        catalogID: String?,
        catalogItemID: UUID?,
        name: String,
        performanceSignature: ExercisePerformanceSignature? = nil
    ) -> String {
        if let catalogID, !catalogID.isEmpty {
            return "bundled:\(catalogID)"
        }
        if let catalogItemID {
            let base = "catalog:\(catalogItemID.uuidString)"
            guard let performanceSignature else { return base }
            return "\(base):performance:\(performanceSignature.keyComponent)"
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
    var performanceSignature: ExercisePerformanceSignature {
        ExercisePerformanceSignature(
            modality: modality,
            trackingMode: trackingMode,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction
        )
    }

    var performanceSemanticKind: PerformanceSemanticKind {
        performanceSignature.performanceKind
    }

    var historyKey: String {
        ExerciseIdentity.key(
            catalogID: catalogID,
            catalogItemID: id,
            name: name,
            performanceSignature: performanceSignature
        )
    }

    var legacyHistoryKey: String {
        ExerciseIdentity.nameKey(name)
    }
}

extension Exercise {
    var performanceSignature: ExercisePerformanceSignature {
        ExercisePerformanceSignature(
            modality: modality,
            trackingMode: trackingMode,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction
        )
    }

    var performanceSemanticKind: PerformanceSemanticKind {
        performanceSignature.performanceKind
    }

    var historyKey: String {
        ExerciseIdentity.key(
            catalogID: catalogID,
            catalogItemID: catalogItemID,
            name: name,
            performanceSignature: performanceSignature
        )
    }

    var legacyHistoryKey: String {
        ExerciseIdentity.nameKey(name)
    }

    func matchesCatalogItem(_ item: ExerciseCatalogItem) -> Bool {
        if let catalogID, let itemCatalogID = item.catalogID {
            return catalogID == itemCatalogID
        }
        if let catalogItemID {
            return catalogItemID == item.id
                && performanceSignature == item.performanceSignature
        }
        return name.exerciseIdentityName == item.name.exerciseIdentityName
    }
}

extension TemplateExercise {
    var performanceSignature: ExercisePerformanceSignature {
        ExercisePerformanceSignature(
            modality: modality,
            trackingMode: trackingMode,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction
        )
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
