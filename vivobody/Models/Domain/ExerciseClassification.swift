//
//  ExerciseClassification.swift
//  vivobody
//
//  Movement metadata shared by catalog items, template exercises, and
//  logged exercises: equipment, mechanic, pattern, push/pull direction,
//  plane, and laterality. Catalog picks snapshot their classification
//  into templates and sessions so custom or renamed exercises remain
//  classifiable. Rows constructed directly from a bundled canonical name
//  can still resolve that catalog classification, while unknown names do
//  not acquire invented defaults.
//

import Foundation

// MARK: - Exercise modality

/// The exact comparison contract for one exercise series. Custom
/// exercises include this value in their history identity so changing a
/// custom item from, for example, a loaded lift to a timed hold starts a
/// new honest series instead of merging incompatible performances.
nonisolated enum PerformanceSemanticKind: String, Codable, Hashable, Sendable {
    case dynamicLoadAndReps
    case powerLoadAndReps
    case isometricLoadAndDuration
    case isometricDuration
    case unrankedReps
    case unrankedDuration

    nonisolated var supportsRecord: Bool {
        switch self {
        case .dynamicLoadAndReps,
             .powerLoadAndReps,
             .isometricLoadAndDuration,
             .isometricDuration:
            return true
        case .unrankedReps, .unrankedDuration:
            return false
        }
    }

    nonisolated var comparesLoad: Bool {
        switch self {
        case .dynamicLoadAndReps,
             .powerLoadAndReps,
             .isometricLoadAndDuration:
            return true
        case .isometricDuration, .unrankedReps, .unrankedDuration:
            return false
        }
    }
}

/// The kind of physical work an exercise represents. Modality gates
/// analytics that would otherwise fabricate strength volume or PRs for
/// conditioning and mobility drills.
nonisolated enum ExerciseModality: String, Codable, Hashable, CaseIterable, Sendable {
    case dynamicStrength
    case isometricStrength
    /// Explosive jumps, throws, catches, and Olympic-lift derivatives.
    /// These are performance movements, but reps are not interchangeable
    /// with hypertrophy hard sets and implement weight is often not a
    /// sufficient comparison axis.
    case power
    case conditioning
    case mobility

    nonisolated var displayName: String {
        switch self {
        case .dynamicStrength: return "Dynamic Strength"
        case .isometricStrength: return "Isometric Strength"
        case .power: return "Power / Ballistic"
        case .conditioning: return "Conditioning"
        case .mobility: return "Mobility"
        }
    }

    /// Dynamic and isometric strength work can credit primary and
    /// secondary muscles with hypertrophy-oriented hard sets. Power,
    /// conditioning, and mobility do not.
    nonisolated var supportsHardSetAnalytics: Bool {
        self == .dynamicStrength || self == .isometricStrength
    }

    /// Strength and power movements must identify at least one actual
    /// force-producing target. Conditioning and mobility may instead
    /// describe whole-body work or passive/control roles without
    /// pretending a stabilizer is a prime mover.
    nonisolated var requiresPrimaryMuscle: Bool {
        self == .dynamicStrength || self == .isometricStrength || self == .power
    }

    /// Whether the modality and tracking unit form a meaningful
    /// strength-PR comparison.
    nonisolated func supportsStrengthPR(for trackingMode: TrackingMode) -> Bool {
        switch (self, trackingMode) {
        case (.dynamicStrength, .reps), (.isometricStrength, .duration):
            return true
        default:
            return false
        }
    }

    /// Exact record semantics including resistance interpretation. Power
    /// earns load records only for rep-tracked external implements;
    /// jumps, bands, and bodyweight ballistic work remain unranked.
    nonisolated func performanceSemanticKind(
        for trackingMode: TrackingMode,
        loadMode: ExerciseLoadMode
    ) -> PerformanceSemanticKind {
        switch (self, trackingMode, loadMode) {
        case (.dynamicStrength, .reps, let mode) where mode.supportsLoadComparison:
            return .dynamicLoadAndReps
        case (.power, .reps, .external):
            return .powerLoadAndReps
        case (.isometricStrength, .duration, let mode) where mode.supportsLoadComparison:
            return .isometricLoadAndDuration
        case (.isometricStrength, .duration, .nonComparable):
            return .isometricDuration
        case (_, .reps, _):
            return .unrankedReps
        case (_, .duration, _):
            return .unrankedDuration
        }
    }

    nonisolated func supportsPerformanceRecord(
        for trackingMode: TrackingMode,
        loadMode: ExerciseLoadMode
    ) -> Bool {
        performanceSemanticKind(
            for: trackingMode,
            loadMode: loadMode
        ).supportsRecord
    }

    /// Tonnage is distinct from hypertrophy hard-set credit. Dynamic
    /// strength with comparable resistance and external-load power both
    /// have meaningful load × reps, while power never becomes a hard set.
    nonisolated func supportsComparableTonnage(
        for trackingMode: TrackingMode,
        loadMode: ExerciseLoadMode
    ) -> Bool {
        guard trackingMode == .reps else { return false }
        switch self {
        case .dynamicStrength:
            return loadMode.supportsLoadComparison
        case .power:
            return loadMode == .external
        case .isometricStrength, .conditioning, .mobility:
            return false
        }
    }

    /// Estimated 1RM remains a dynamic-strength construct. Comparable
    /// power records use the directly logged load/reps only.
    nonisolated func supportsEstimatedOneRepMax(
        for trackingMode: TrackingMode,
        loadMode: ExerciseLoadMode
    ) -> Bool {
        self == .dynamicStrength
            && trackingMode == .reps
            && loadMode.supportsLoadComparison
    }
}

/// The movement metadata for one exercise, resolved by name.
nonisolated struct ExerciseClassification: Hashable {
    let equipment: Equipment
    let mechanic: Mechanic
    /// Optional — isolation work has no meaningful pattern.
    let pattern: MovementPattern?
    /// Optional — only push/pull patterns have a direction.
    let direction: PushPullDirection?
    let plane: MovementPlane
    let laterality: Laterality

    nonisolated init(
        equipment: Equipment,
        mechanic: Mechanic,
        pattern: MovementPattern?,
        direction: PushPullDirection?,
        plane: MovementPlane,
        laterality: Laterality
    ) {
        self.equipment = equipment
        self.mechanic = mechanic
        self.pattern = pattern
        self.direction = direction
        self.plane = plane
        self.laterality = laterality
    }
}

extension ExerciseClassification {
    /// Reconstruct a persisted snapshot. The four universally-required
    /// fields act as the presence marker; pattern and direction remain
    /// genuinely optional within a valid classification.
    nonisolated init?(
        equipmentRaw: String?,
        mechanicRaw: String?,
        patternRaw: String?,
        directionRaw: String?,
        planeRaw: String?,
        lateralityRaw: String?
    ) {
        guard
            let equipmentRaw,
            let equipment = Equipment(rawValue: equipmentRaw),
            let mechanicRaw,
            let mechanic = Mechanic(rawValue: mechanicRaw),
            let planeRaw,
            let plane = MovementPlane(rawValue: planeRaw),
            let lateralityRaw,
            let laterality = Laterality(rawValue: lateralityRaw)
        else {
            return nil
        }

        let pattern: MovementPattern?
        if let patternRaw {
            guard let value = MovementPattern(rawValue: patternRaw) else { return nil }
            pattern = value
        } else {
            pattern = nil
        }

        let direction: PushPullDirection?
        if let directionRaw {
            guard let value = PushPullDirection(rawValue: directionRaw) else { return nil }
            direction = value
        } else {
            direction = nil
        }

        self.init(
            equipment: equipment,
            mechanic: mechanic,
            pattern: pattern,
            direction: direction,
            plane: plane,
            laterality: laterality
        )
    }

    /// Classification for a seeded exercise, resolved by name
    /// (case-insensitive) from the bundled catalog (`CatalogData`).
    /// `nil` for names absent from the catalog — typically user-created
    /// custom exercises.
    nonisolated static func forExerciseNamed(_ name: String) -> ExerciseClassification? {
        CatalogData.record(forExerciseNamed: name)?.classification
    }
}
