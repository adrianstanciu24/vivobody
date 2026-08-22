//
//  ExecutionInstructions.swift
//  vivobody
//
//  Structured execution instructions for one catalog exercise. The
//  catalog compiler emits these labeled fields in place of a flat step
//  list: sequential phases (setup, movement, endpoint, return) sit
//  alongside concurrent constraints (controlled joints, support,
//  posture) and disqualifying compensations. `returnPhase` is present
//  exactly for rep-tracked records; `sideOrDirection` exactly for
//  unilateral or carry records.
//

/// One exercise's authored execution contract. Optional fields are
/// conditional on the record's tracking mode, laterality, and pattern —
/// never a tolerance for incomplete authoring.
nonisolated struct ExecutionInstructions: Codable, Equatable {
    let startingPosition: String
    let movement: String
    let endpoint: String
    let returnPhase: String?
    let controlledJoints: String
    let supportAndPosture: String
    /// Each entry names a compensation and what it turns the movement
    /// into. At least one entry, all unique.
    let disqualifyingCompensations: [String]
    let sideOrDirection: String?
}
