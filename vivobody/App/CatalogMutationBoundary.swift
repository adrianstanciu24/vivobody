//
//  CatalogMutationBoundary.swift
//  vivobody
//
//  Transaction boundary for create, duplicate, edit, delete, and factory-reset
//  catalog operations. Every SwiftData change commits through saveOrRollback;
//  UserDefaults tombstones and Spotlight updates run only after that commit.
//

import Foundation
import SwiftData

@MainActor
enum CatalogMutationTarget {
    case create
    case duplicate(source: ExerciseCatalogItem)
    case edit(item: ExerciseCatalogItem)
}

@MainActor
enum CatalogMutationResult {
    case created(ExerciseCatalogItem)
    case duplicated(ExerciseCatalogItem)
    case edited(ExerciseCatalogItem)
    case deleted(itemID: UUID)
    case reset(insertedItemCount: Int)

    var savedItem: ExerciseCatalogItem? {
        switch self {
        case let .created(item), let .duplicated(item), let .edited(item): item
        case .deleted, .reset: nil
        }
    }
}

@MainActor
struct CatalogMutationEffects {
    let indexExercise: @MainActor (ExerciseCatalogItem) -> Void
    let removeExercise: @MainActor (UUID) -> Void
    let reindexAll: @MainActor ([WorkoutTemplate], [ExerciseCatalogItem]) -> Void

    static let live = CatalogMutationEffects(
        indexExercise: SpotlightIndexer.index,
        removeExercise: SpotlightIndexer.removeExercise,
        reindexAll: SpotlightIndexer.reindexAll
    )

    static let none = CatalogMutationEffects(
        indexExercise: { _ in },
        removeExercise: { _ in },
        reindexAll: { _, _ in }
    )
}

@MainActor
struct CatalogMutationBoundary {
    private let context: ModelContext
    private let defaults: UserDefaults
    private let effects: CatalogMutationEffects
    private let saveChanges: (ModelContext) throws -> Void
    private let now: () -> Date

    init(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        effects: CatalogMutationEffects = .live,
        saveChanges: @escaping (ModelContext) throws -> Void = { context in
            try context.saveOrRollback()
        },
        now: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.defaults = defaults
        self.effects = effects
        self.saveChanges = saveChanges
        self.now = now
    }

    /// Persist previously validated immutable input while preserving the exact
    /// create, duplicate, restricted bundled-edit, and custom-edit contracts.
    @discardableResult
    func save(
        _ input: CatalogMutationInput,
        target: CatalogMutationTarget,
        unit: WeightUnit
    ) throws -> CatalogMutationResult {
        switch target {
        case .create:
            let item = makeCustomItem(from: input, defaultReps: nil)
            context.insert(item)
            try commit()
            effects.indexExercise(item)
            return .created(item)

        case let .duplicate(source):
            let item = makeCustomItem(from: input, defaultReps: source.defaultReps)
            context.insert(item)
            try commit()
            effects.indexExercise(item)
            return .duplicated(item)

        case let .edit(item):
            if item.catalogID != nil, !item.isUserCreated {
                applyBundledDefaults(from: input, to: item, unit: unit)
            } else {
                applyCustomEdit(from: input, to: item, unit: unit)
            }
            try commit()
            effects.indexExercise(item)
            return .edited(item)
        }
    }

    /// Delete one catalog row and record a bundled tombstone only after the
    /// deletion commits, preventing launch reconciliation from resurrecting it.
    @discardableResult
    func delete(_ item: ExerciseCatalogItem) throws -> CatalogMutationResult {
        let itemID = item.id
        let bundledID = item.isUserCreated ? nil : item.catalogID
        context.delete(item)
        try commit()

        if let bundledID {
            CatalogDeletionTombstones.record(bundledID, in: defaults)
        }
        effects.removeExercise(itemID)
        return .deleted(itemID: itemID)
    }

    /// Atomically replace the complete SwiftData catalog with generated source
    /// truth. Defaults and Spotlight are intentionally post-commit follow-up.
    @discardableResult
    func resetToDefaults() throws -> CatalogMutationResult {
        let existing = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        for item in existing {
            context.delete(item)
        }

        let base = now()
        let seededItems = CatalogData.records.enumerated().map { index, record in
            ExerciseCatalogItem(
                record: record,
                createdAt: base.addingTimeInterval(Double(index) * 0.001)
            )
        }
        for item in seededItems {
            context.insert(item)
        }

        try commit()
        CatalogDeletionTombstones.clear(in: defaults)
        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        effects.reindexAll(templates, seededItems)
        return .reset(insertedItemCount: seededItems.count)
    }

    private func makeCustomItem(
        from input: CatalogMutationInput,
        defaultReps: Int?
    ) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            name: input.name,
            group: input.group,
            defaultWeight: input.tracksResistance ? input.defaultWeight : 0,
            defaultReps: defaultReps,
            trackingMode: input.trackingMode,
            modality: input.modality,
            loadMode: input.loadMode,
            bodyweightFraction: input.bodyweightFraction,
            defaultDuration: input.defaultDuration,
            equipment: input.equipment,
            mechanic: input.mechanic,
            trainingRole: input.trainingRole,
            pattern: input.mechanic == .compound ? input.pattern : nil,
            direction: input.requiresDirection ? input.direction : nil,
            planes: input.planes,
            laterality: input.laterality,
            aliases: input.aliases,
            execution: input.execution,
            muscleInvolvement: input.muscleInvolvement,
            isUserCreated: true
        )
    }

    private func applyBundledDefaults(
        from input: CatalogMutationInput,
        to item: ExerciseCatalogItem,
        unit: WeightUnit
    ) {
        let defaultWeight = input.tracksResistance ? input.defaultWeight : 0
        let weightChanged = defaultWeight != item.defaultWeight
        item.defaultWeight = defaultWeight
        if weightChanged {
            item.defaultWeightKg = unit == .kg && input.tracksResistance
                ? WeightFormatter.toDisplay(defaultWeight, unit: .kg)
                : nil
        }
        item.defaultDuration = input.defaultDuration
    }

    private func applyCustomEdit(
        from input: CatalogMutationInput,
        to item: ExerciseCatalogItem,
        unit: WeightUnit
    ) {
        let editedSignature = ExercisePerformanceSignature(
            modality: input.modality,
            trackingMode: input.trackingMode,
            loadMode: input.loadMode,
            bodyweightFraction: input.bodyweightFraction,
            tracksResistance: input.tracksResistance
        )
        let performanceSemanticsChanged = item.performanceSignature != editedSignature
        let defaultWeight = input.tracksResistance ? input.defaultWeight : 0

        item.name = input.name
        item.group = input.group
        let weightChanged = defaultWeight != item.defaultWeight
        item.defaultWeight = defaultWeight
        if weightChanged {
            item.defaultWeightKg = unit == .kg && input.tracksResistance
                ? WeightFormatter.toDisplay(defaultWeight, unit: .kg)
                : nil
        }
        item.trackingMode = input.trackingMode
        item.modality = input.modality
        item.loadMode = input.loadMode
        item.bodyweightFraction = input.bodyweightFraction
        item.defaultDuration = input.defaultDuration
        item.equipment = input.equipment
        item.mechanic = input.mechanic
        item.trainingRole = input.trainingRole
        item.pattern = input.mechanic == .compound ? input.pattern : nil
        item.direction = input.requiresDirection ? input.direction : nil
        item.planes = input.planes
        item.laterality = input.laterality
        item.aliases = input.aliases
        item.execution = input.execution
        item.muscleInvolvementSnapshot = input.muscleInvolvementSnapshot
        if performanceSemanticsChanged {
            item.oneRepMax = nil
        }
    }

    private func commit() throws {
        do {
            try saveChanges(context)
        } catch {
            // Production commits already roll back through saveOrRollback.
            // Keep the injected failure seam equally safe for focused tests.
            context.rollback()
            throw error
        }
    }
}
