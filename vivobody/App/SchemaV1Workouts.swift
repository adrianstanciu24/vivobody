//
//  SchemaV1Workouts.swift
//  vivobody
//
//  Frozen stored fields and relationships for the first public SwiftData schema.
//  Never evolve these models; runtime behavior belongs to the current schema.
//

import Foundation
import SwiftData

extension VivobodySchemaV1 {
    @Model
    final class WorkoutSession {
        #Index<WorkoutSession>(
            [\.completedAt],
            [\.startedAt],
            [\.id],
            [\.completedAt, \.startedAt]
        )
        var id: UUID = UUID()
        var startedAt: Date = Date()
        var completedAt: Date?
        var restDuration: TimeInterval = 90
        var bodyweightAtStart: Double = ExerciseLoad.unknownBodyweight
        @Relationship(deleteRule: .cascade, inverse: \Exercise.session)
        var exercises: [Exercise] = []
        var isResting: Bool = false
        var restStartedAt: Date? = nil
        var restEndsAt: Date? = nil
        var activeExerciseIndex: Int = 0
        var summaryAnimatedMinutes: Double = 0
        var summaryAnimatedVolume: Double = 0
        var summaryDidCelebrate: Bool = false
        var pendingPRValue: String? = nil
        var pendingPRDetail: String? = nil
        var pendingPRUnit: String? = nil
        var healthKitWorkoutUUID: UUID? = nil

        init() {}
    }

    @Model
    final class Exercise {
        #Index<Exercise>([\.name], [\.catalogID], [\.catalogItemID])
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
        var session: WorkoutSession?
        @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
        var sets: [WorkoutSet] = []

        init() {}
    }

    @Model
    final class WorkoutSet {
        var id: UUID = UUID()
        var weight: Double = 0
        var reps: Int = 0
        var duration: TimeInterval = 0
        var isCompleted: Bool = false
        var repsInReserve: Int = 2
        var rirLogged: Bool = false
        var sortOrder: Int = 0
        var plannedWeight: Double = 0
        var plannedReps: Int = 0
        var plannedDuration: TimeInterval = 0
        var exercise: Exercise?

        init() {}
    }
}
