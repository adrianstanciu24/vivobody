//
//  ExerciseCatalogTaxonomy.swift
//  vivobody
//
//  Pure classification vocabulary shared by the persistent catalog, copied
//  workout snapshots, filtering, and analytics. These raw-value enums stay
//  independent from SwiftData model access and generated catalog records.
//

import Foundation

// MARK: - Equipment

/// Primary piece of gear the lift uses. Drives the equipment filter
/// chip strip at the top of the picker / Library. Stored as a raw value
/// on persistent exercise snapshots so the enum can evolve safely.
nonisolated enum Equipment: String, Codable, Hashable, CaseIterable {
    case barbell
    case dumbbell
    case cable
    case machine
    case bodyweight
    case kettlebell
    case band
    case gripTrainer
    case trapBar, abWheel, gluteHamDeveloper
    case other

    nonisolated var displayName: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .cable: "Cable"
        case .machine: "Machine"
        case .bodyweight: "Bodyweight"
        case .kettlebell: "Kettlebell"
        case .band: "Band"
        case .gripTrainer: "Grip Trainer"
        case .trapBar: "Trap Bar"
        case .abWheel: "Ab Wheel"
        case .gluteHamDeveloper: "GHD"
        case .other: "Other"
        }
    }
}

// MARK: - Movement pattern

/// The dominant compound motor pattern. Isolation work is described by
/// its joint action in the catalog and uses `TrainingRole` for PPL-style
/// programming placement.
nonisolated enum MovementPattern: String, Codable, Hashable, CaseIterable {
    case push // bench, OHP, dips
    case pull // rows, pulldowns
    case squat // back squat, front squat, leg press
    case hinge // deadlift, RDL, good morning
    case lunge // split squat, step-up, walking lunge
    case carry // farmer's carry, suitcase, yoke
    case core // planks, leg raises, anti-rotation
    case hang // passive and active straight-arm hangs

    nonisolated var displayName: String {
        switch self {
        case .push: "Push"
        case .pull: "Pull"
        case .squat: "Squat"
        case .hinge: "Hinge"
        case .lunge: "Lunge"
        case .carry: "Carry"
        case .core: "Core"
        case .hang: "Hang"
        }
    }
}

// MARK: - Push/pull direction

/// Whether a push/pull moves the load primarily away from/toward the
/// torso or overhead/down from overhead. Optional because it only has
/// meaning for `.push` and `.pull` movement patterns.
nonisolated enum PushPullDirection: String, Codable, Hashable, CaseIterable {
    case horizontal
    case vertical
    case diagonal

    nonisolated var displayName: String {
        switch self {
        case .horizontal: "Horizontal"
        case .vertical: "Vertical"
        case .diagonal: "Diagonal"
        }
    }
}

// MARK: - Movement plane

/// One cardinal anatomical plane in a family's reviewed action basis.
/// Exercises can author multiple components; direction (including a
/// diagonal push/pull) remains a separate classification dimension.
nonisolated enum MovementPlane: String, Codable, Hashable, CaseIterable {
    case sagittal
    case frontal
    case transverse

    nonisolated var displayName: String {
        switch self {
        case .sagittal: "Sagittal"
        case .frontal: "Frontal"
        case .transverse: "Transverse"
        }
    }

    nonisolated static func canonicalized(_ values: [MovementPlane]) -> [MovementPlane] {
        let selected = Set(values)
        return allCases.filter(selected.contains)
    }
}

// MARK: - Laterality

/// Whether the lift loads both sides together or one side at a time.
/// Catalog and workout snapshots default to bilateral, while unilateral
/// entries retain their per-side logging semantics.
nonisolated enum Laterality: String, Codable, Hashable, CaseIterable {
    case bilateral
    case unilateral

    nonisolated var displayName: String {
        switch self {
        case .bilateral: "Bilateral"
        case .unilateral: "Unilateral"
        }
    }
}
