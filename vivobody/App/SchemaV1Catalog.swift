//
//  SchemaV1Catalog.swift
//  vivobody
//
//  Frozen stored fields and relationships for the first public SwiftData schema.
//  Never evolve these models; runtime behavior belongs to the current schema.
//

import Foundation
import SwiftData

extension VivobodySchemaV1 {
    @Model
    final class ExerciseCatalogItem {
        #Index<ExerciseCatalogItem>([\.catalogID])
        var id: UUID = UUID()
        var catalogID: String? = nil
        var familyID: String? = nil
        var name: String = ""
        var muscleGroupRaw: String = MuscleGroup.chest.rawValue
        var defaultWeight: Double = 0
        var defaultReps: Int = 8
        var defaultWeightKg: Double? = nil
        var trackingModeRaw: String = TrackingMode.reps.rawValue
        var modalityRaw: String = ExerciseModality.dynamicStrength.rawValue
        var loadModeRaw: String = ExerciseLoadMode.external.rawValue
        var bodyweightFraction: Double = 0
        var defaultDuration: TimeInterval = 0
        var oneRepMax: Double? = nil
        var equipmentRaw: String = Equipment.barbell.rawValue
        var mechanicRaw: String = Mechanic.compound.rawValue
        var trainingRoleRaw: String? = nil
        var patternRaw: String? = nil
        var directionRaw: String? = nil
        var planeRaws: [String] = [MovementPlane.sagittal.rawValue]
        var lateralityRaw: String = Laterality.bilateral.rawValue
        var aliases: [String] = []
        var execution: ExecutionInstructions? = nil
        var muscleInvolvementSnapshot: [String: Double] = [:]
        var createdAt: Date = Date()
        var isUserCreated: Bool = false
        var isFavorite: Bool = false

        init() {}
    }

    @Model
    final class BodyWeightEntry {
        #Index<BodyWeightEntry>([\.date])
        var id: UUID = UUID()
        var date: Date = Date()
        var weight: Double = 0

        init() {}
    }
}
