//
//  CatalogLaunchReconciler.swift
//  vivobody
//
//  Launch-time SwiftData reconciliation for bundled exercises. Generated
//  CatalogData remains source truth for canonical identity and movement fields;
//  custom rows and user-owned logging defaults remain untouched.
//

import Foundation
import SwiftData

struct CatalogReconciliationResult: Equatable {
    let didReconcile: Bool
    let removedItemIDs: [UUID]
    let insertedItemCount: Int
    let reconciledItemCount: Int

    static let unchanged = CatalogReconciliationResult(
        didReconcile: false,
        removedItemIDs: [],
        insertedItemCount: 0,
        reconciledItemCount: 0
    )
}

@MainActor
enum CatalogLaunchReconciler {
    /// Reconcile bundled rows in one rollback-safe transaction. The typed
    /// result lets AppRoot defer Spotlight cleanup until after this returns,
    /// which means no search side effect can precede the successful commit.
    static func reconcile(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        catalogFingerprint: String = CatalogData.sourceFingerprint,
        saveChanges: (ModelContext) throws -> Void = { context in
            try context.saveOrRollback()
        }
    ) throws -> CatalogReconciliationResult {
        guard defaults.string(forKey: SettingsKey.catalogReconciliationFingerprint)
            != catalogFingerprint
        else {
            return .unchanged
        }

        let descriptor = FetchDescriptor<ExerciseCatalogItem>(
            predicate: #Predicate { !$0.isUserCreated }
        )
        let existing = try context.fetch(descriptor)
        let hiddenIDs = CatalogDeletionTombstones.ids(in: defaults)
        let recordsByID = Dictionary(
            uniqueKeysWithValues: CatalogData.records.map { ($0.catalogID, $0) }
        )
        var retainedIDs: Set<String> = []
        var removedIDs: [UUID] = []
        var reconciledCount = 0

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
            item.applyCanonicalCatalogFields(from: record)
            reconciledCount += 1
        }

        var insertedCount = 0
        for (index, record) in CatalogData.records.enumerated()
            where !retainedIDs.contains(record.catalogID)
            && !hiddenIDs.contains(record.catalogID)
        {
            context.insert(
                ExerciseCatalogItem(
                    record: record,
                    createdAt: now.addingTimeInterval(Double(index) * 0.001)
                )
            )
            insertedCount += 1
        }

        do {
            try saveChanges(context)
        } catch {
            // The live path already rolls back through saveOrRollback; this
            // also makes an injected failure obey the same atomic contract.
            context.rollback()
            throw error
        }
        defaults.set(catalogFingerprint, forKey: SettingsKey.catalogReconciliationFingerprint)
        return CatalogReconciliationResult(
            didReconcile: true,
            removedItemIDs: removedIDs,
            insertedItemCount: insertedCount,
            reconciledItemCount: reconciledCount
        )
    }

    /// A store reset or fallback invalidates the external cache token so the
    /// next launch cannot mistake an empty replacement store for a reconciled
    /// one.
    static func invalidate(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: SettingsKey.catalogReconciliationFingerprint)
    }
}

private extension ExerciseCatalogItem {
    /// Restore source-owned fields without overwriting personal logging
    /// defaults, favorites, measured 1RM, install-local identity, or dates.
    func applyCanonicalCatalogFields(from record: CatalogRecord) {
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
