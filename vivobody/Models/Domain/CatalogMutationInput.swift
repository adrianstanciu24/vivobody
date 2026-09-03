//
//  CatalogMutationInput.swift
//  vivobody
//
//  Immutable, UI-independent input for one catalog save transaction. It
//  normalizes persisted text at the boundary while retaining the validated
//  identity, anatomy, classification, load, and logging-default semantics.
//

import Foundation

nonisolated struct CatalogMutationInput: Equatable {
    let name: String
    let execution: ExecutionInstructions?
    let group: MuscleGroup
    let defaultWeight: Double
    let trackingMode: TrackingMode
    let modality: ExerciseModality
    let loadMode: ExerciseLoadMode
    let bodyweightFraction: Double
    let defaultDuration: TimeInterval
    let equipment: Equipment
    let mechanic: Mechanic
    let trainingRole: TrainingRole
    let pattern: MovementPattern?
    let direction: PushPullDirection?
    let planes: [MovementPlane]
    let laterality: Laterality
    let muscleInvolvementSnapshot: [String: Double]
    let aliases: [String]

    init(
        name: String,
        execution: ExecutionInstructions?,
        group: MuscleGroup,
        defaultWeight: Double,
        trackingMode: TrackingMode,
        modality: ExerciseModality,
        loadMode: ExerciseLoadMode,
        bodyweightFraction: Double,
        defaultDuration: TimeInterval,
        equipment: Equipment,
        mechanic: Mechanic,
        trainingRole: TrainingRole,
        pattern: MovementPattern?,
        direction: PushPullDirection?,
        planes: [MovementPlane],
        laterality: Laterality,
        muscleInvolvementSnapshot: [String: Double],
        aliases: [String]
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.execution = execution
        self.group = group
        self.defaultWeight = defaultWeight
        self.trackingMode = trackingMode
        self.modality = modality
        self.loadMode = loadMode
        self.bodyweightFraction = bodyweightFraction
        self.defaultDuration = defaultDuration
        self.equipment = equipment
        self.mechanic = mechanic
        self.trainingRole = trainingRole
        self.pattern = pattern
        self.direction = direction
        self.planes = MovementPlane.canonicalized(planes)
        self.laterality = laterality
        self.muscleInvolvementSnapshot = muscleInvolvementSnapshot
        self.aliases = Self.normalizedAliases(aliases)
    }

    var muscleInvolvement: Muscle.Involvement {
        Muscle.Involvement(snapshot: muscleInvolvementSnapshot)
    }

    var requiresDirection: Bool {
        mechanic == .compound && (pattern == .push || pattern == .pull)
    }

    var tracksResistance: Bool {
        ExerciseResistanceCapability.tracksResistance(
            loadMode: loadMode,
            equipment: equipment
        )
    }

    private static func normalizedAliases(_ aliases: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for alias in aliases {
            let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else {
                continue
            }
            result.append(trimmed)
        }
        return result
    }
}
