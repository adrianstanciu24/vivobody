//
//  InvolvementSnapshotRepair.swift
//  vivobody
//
//  One-time, generation-gated repair of persisted muscle-involvement
//  snapshots. Older taxonomies stored keys and weights that no longer
//  decode (`glutes`, graded 0.4/0.7 tiers), and two exact historical
//  Machine Hip Abduction snapshots earn a known catalog-role upgrade.
//  This pass rewrites those rows from the bundled catalog ONCE at
//  launch, so the hot-path accessors (`Exercise.muscleInvolvement`,
//  `TemplateExercise.muscleInvolvement`,
//  `ExerciseCatalogItem.muscleInvolvement`) stay a pure snapshot
//  decode with no per-access recovery logic.
//
//  Rules, unchanged from the retired `Muscle.resolvedInvolvement`:
//    • Valid pick-time roles are immutable — a canonical snapshot
//      with a primary muscle is never touched (except the exact,
//      known Hip Abduction upgrades).
//    • Legacy bundled snapshots recover from the catalog by stable
//      ID, then by canonical name for rows saved before catalog IDs
//      existed. A strength/power catalog snapshot with roles but no
//      primary is another legacy signature and also recovers.
//    • Custom catalog items never borrow bundled anatomy by name;
//      they keep whatever still decodes.
//
//  Runs before the first analytics generation (AppRoot critical
//  path); cost on a normal launch is one UserDefaults read. Bump
//  `generation` if a future taxonomy change needs another pass.
//

import Foundation
import SwiftData

enum InvolvementSnapshotRepair {
    /// Bump to re-run the pass after a future taxonomy change.
    static let generation = 1

    /// Rewrite every legacy snapshot in the store, then stamp the
    /// generation. The stamp is only advanced when the save succeeds,
    /// so a failed pass retries on the next launch.
    @MainActor
    static func runIfNeeded(
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        guard defaults.integer(forKey: SettingsKey.involvementRepairGeneration) < generation else {
            return
        }

        var changed = false

        if let items = try? context.fetch(FetchDescriptor<ExerciseCatalogItem>()) {
            for item in items {
                guard let repaired = repairedSnapshot(
                    from: item.muscleInvolvementSnapshot,
                    catalogID: item.catalogID,
                    exerciseName: item.name,
                    allowsCatalogNameLookup: !item.isUserCreated
                ) else { continue }
                item.muscleInvolvementSnapshot = repaired
                changed = true
            }
        }

        if let templateExercises = try? context.fetch(FetchDescriptor<TemplateExercise>()) {
            for exercise in templateExercises {
                guard let repaired = repairedSnapshot(
                    from: exercise.muscleInvolvementSnapshot,
                    catalogID: exercise.catalogID,
                    exerciseName: exercise.name
                ) else { continue }
                exercise.muscleInvolvementSnapshot = repaired
                changed = true
            }
        }

        if let exercises = try? context.fetch(FetchDescriptor<Exercise>()) {
            for exercise in exercises {
                guard let repaired = repairedSnapshot(
                    from: exercise.muscleInvolvementSnapshot,
                    catalogID: exercise.catalogID,
                    exerciseName: exercise.name
                ) else { continue }
                exercise.muscleInvolvementSnapshot = repaired
                changed = true
            }
        }

        if changed {
            do {
                try context.saveOrRollback()
            } catch {
                // Leave the stamp untouched; the pass retries next launch.
                return
            }
        }
        defaults.set(generation, forKey: SettingsKey.involvementRepairGeneration)
    }

    /// The repaired snapshot for one row, or nil when the stored
    /// snapshot is already correct and must not be rewritten.
    nonisolated static func repairedSnapshot(
        from snapshot: [String: Double],
        catalogID: String?,
        exerciseName: String,
        allowsCatalogNameLookup: Bool = true
    ) -> [String: Double]? {
        let stored = Muscle.Involvement(snapshot: snapshot)
        let isCanonical = Muscle.Involvement.isCanonicalSnapshot(snapshot)
        let isKnownHipAbductionSnapshot = isHistoricalHipAbductionSnapshot(
            snapshot,
            catalogID: catalogID,
            exerciseName: exerciseName,
            allowsCatalogNameLookup: allowsCatalogNameLookup
        )
        if isCanonical, stored.hasPrimary, !isKnownHipAbductionSnapshot { return nil }

        let recordByID = catalogID.flatMap { CatalogData.record(forCatalogID: $0) }
        let recordByName = allowsCatalogNameLookup
            ? CatalogData.record(forExerciseNamed: exerciseName)
            : nil
        if let record = recordByID ?? recordByName {
            // A strength/power catalog snapshot containing only
            // secondary/stabilizer roles is another legacy signature:
            // an obsolete primary key was decoded away, then the
            // remaining valid entries were re-saved.
            if !isCanonical
                || (record.modality.requiresPrimaryMuscle && !stored.hasPrimary)
                || isKnownHipAbductionSnapshot {
                let repaired = record.muscleInvolvement.snapshot
                return repaired == snapshot ? nil : repaired
            }
        }

        // Unknown or custom rows keep only the roles that still
        // decode; anatomy is never invented from a browse group.
        let decoded = stored.snapshot
        return decoded == snapshot ? nil : decoded
    }

    /// The two exact Machine Hip Abduction snapshots that predate the
    /// TFL region / core-stabilizer removal and earn a catalog upgrade
    /// despite being canonical with a primary.
    private nonisolated static func isHistoricalHipAbductionSnapshot(
        _ snapshot: [String: Double],
        catalogID: String?,
        exerciseName: String,
        allowsCatalogNameLookup: Bool
    ) -> Bool {
        let isBundledMachineHipAbduction = catalogID == "machine-hip-abduction"
            || (
                catalogID == nil
                    && allowsCatalogNameLookup
                    && exerciseName.caseInsensitiveCompare("Machine Hip Abduction") == .orderedSame
            )
        guard isBundledMachineHipAbduction else { return false }

        let historicalStabilizers = [
            Muscle.Involvement.Contribution(muscle: .abs, role: .stabilizer),
            Muscle.Involvement.Contribution(muscle: .obliques, role: .stabilizer),
            Muscle.Involvement.Contribution(muscle: .hipFlexors, role: .stabilizer),
        ]
        let preTFLSnapshot = Muscle.Involvement(contributions: [
            .init(muscle: .gluteMed, role: .primary),
        ] + historicalStabilizers).snapshot
        let preCoreRemovalSnapshot = Muscle.Involvement(contributions: [
            .init(muscle: .gluteMed, role: .primary),
            .init(muscle: .tensorFasciaeLatae, role: .secondary),
        ] + historicalStabilizers).snapshot
        return snapshot == preTFLSnapshot || snapshot == preCoreRemovalSnapshot
    }
}
