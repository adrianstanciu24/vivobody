//
//  DebugCatalogFixtures.swift
//  vivobody
//
//  DEBUG-only factories that keep verification seeds tied to catalog semantics.
//

import Foundation

#if DEBUG

    func debugCatalogRecord(named name: String) -> CatalogRecord {
        guard let record = CatalogData.record(forExerciseNamed: name) else {
            preconditionFailure("Debug seed references unknown catalog exercise: \(name)")
        }
        return record
    }

    func debugCatalogExercise(
        named name: String,
        plannedSets: Int,
        plannedReps: Int,
        plannedWeight: Double,
        plannedDuration: TimeInterval? = nil,
        sortOrder: Int
    ) -> Exercise {
        let record = debugCatalogRecord(named: name)
        return Exercise(
            name: record.name,
            catalogID: record.catalogID,
            familyID: record.familyID,
            group: record.group,
            plannedSets: plannedSets,
            plannedReps: plannedReps,
            plannedWeight: plannedWeight,
            muscleInvolvement: record.muscleInvolvement,
            classification: record.classification,
            trackingMode: record.trackingMode,
            modality: record.modality,
            loadMode: record.loadMode,
            bodyweightFraction: record.bodyweightFraction,
            plannedDuration: plannedDuration ?? record.defaultDurationValue,
            sortOrder: sortOrder
        )
    }

    func debugCatalogTemplateExercise(
        named name: String,
        plannedSets: Int,
        plannedReps: Int,
        plannedWeight: Double,
        sortOrder: Int
    ) -> TemplateExercise {
        let record = debugCatalogRecord(named: name)
        return TemplateExercise(
            name: record.name,
            catalogID: record.catalogID,
            familyID: record.familyID,
            group: record.group,
            plannedSets: plannedSets,
            plannedReps: plannedReps,
            plannedWeight: plannedWeight,
            muscleInvolvement: record.muscleInvolvement,
            classification: record.classification,
            trackingMode: record.trackingMode,
            modality: record.modality,
            loadMode: record.loadMode,
            bodyweightFraction: record.bodyweightFraction,
            plannedDuration: record.defaultDurationValue,
            sortOrder: sortOrder
        )
    }

#endif
