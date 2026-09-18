//
//  SchemaV1Templates.swift
//  vivobody
//
//  Frozen stored fields and relationships for the first public SwiftData schema.
//  Never evolve these models; runtime behavior belongs to the current schema.
//

import Foundation
import SwiftData

extension VivobodySchemaV1 {
    @Model
    final class WorkoutTemplate {
        var id: UUID = UUID()
        var name: String = "New Template"
        var createdAt: Date = Date()
        var sortOrder: Int = 0
        var lastUsedAt: Date?
        var scheduledWeekdays: [Int] = []
        @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
        var exercises: [TemplateExercise] = []

        init() {}
    }

    @Model
    final class TemplateExercise {
        var id: UUID = UUID()
        var name: String = ""
        var catalogItemID: UUID? = nil
        var catalogID: String? = nil
        var familyID: String? = nil
        var muscleGroupRaw: String = MuscleGroup.chest.rawValue
        var plannedSets: Int = 3
        var plannedReps: Int = 8
        var plannedWeight: Double = 0
        var muscleInvolvementSnapshot: [String: Double] = [:]
        var equipmentRaw: String? = nil
        var mechanicRaw: String? = nil
        var trainingRoleRaw: String? = nil
        var patternRaw: String? = nil
        var directionRaw: String? = nil
        var planeRaws: [String] = []
        var lateralityRaw: String? = nil
        var trackingModeRaw: String = TrackingMode.reps.rawValue
        var modalityRaw: String = ExerciseModality.dynamicStrength.rawValue
        var loadModeRaw: String = ExerciseLoadMode.external.rawValue
        var bodyweightFraction: Double = 0
        var plannedDuration: TimeInterval = 0
        var sortOrder: Int = 0
        var supersetID: UUID? = nil
        var template: WorkoutTemplate?
        @Relationship(deleteRule: .cascade, inverse: \TemplateSet.exercise)
        var sets: [TemplateSet] = []

        init() {}
    }

    @Model
    final class TemplateSet {
        var id: UUID = UUID()
        var weight: Double = 0
        var reps: Int = 0
        var duration: TimeInterval = 0
        var sortOrder: Int = 0
        var exercise: TemplateExercise?

        init() {}
    }
}
