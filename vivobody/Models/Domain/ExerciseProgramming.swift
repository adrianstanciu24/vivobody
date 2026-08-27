//
//  ExerciseProgramming.swift
//  vivobody
//
//  Orthogonal exercise-programming vocabulary: mechanical complexity and
//  conventional training placement shared by catalog, filters, and Insights.
//  Compound movement-pattern biomechanics remain in ExerciseCatalog.swift.
//

import Foundation

// MARK: - Mechanic

/// Compound (multi-joint) vs. isolation (single-joint). Only compound
/// lifts carry a `MovementPattern`; `TrainingRole` is the orthogonal
/// programming classification shared by both mechanics.
nonisolated enum Mechanic: String, Codable, Hashable, CaseIterable {
    case compound
    case isolation

    nonisolated var displayName: String {
        switch self {
        case .compound: "Compound"
        case .isolation: "Isolation"
        }
    }
}

// MARK: - Training role

/// Conventional programming placement used for discovery and
/// mechanic-separated analysis. This is authored product taxonomy,
/// not a claim that every exercise literally pushes or pulls a load.
nonisolated enum TrainingRole: String, Codable, Hashable, CaseIterable {
    case push
    case pull
    case legs
    case core
    case other

    nonisolated var displayName: String {
        switch self {
        case .push: "Push"
        case .pull: "Pull"
        case .legs: "Legs"
        case .core: "Core"
        case .other: "Other"
        }
    }

    nonisolated static func defaultRole(for pattern: MovementPattern?) -> TrainingRole {
        switch pattern {
        case .push: .push
        case .pull: .pull
        case .squat, .hinge, .lunge: .legs
        case .core: .core
        case .carry, nil: .other
        }
    }
}
