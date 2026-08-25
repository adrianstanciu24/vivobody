//
//  ExerciseClassification.swift
//  vivobody
//
//  Movement metadata shared by catalog items, template exercises, and
//  logged exercises: equipment, mechanic, pattern, push/pull direction,
//  planes, and laterality. Catalog picks snapshot their classification
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
nonisolated enum PerformanceSemanticKind: String, Codable, Hashable {
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
            true
        case .unrankedReps, .unrankedDuration:
            false
        }
    }

    nonisolated var comparesLoad: Bool {
        switch self {
        case .dynamicLoadAndReps,
             .powerLoadAndReps,
             .isometricLoadAndDuration:
            true
        case .isometricDuration, .unrankedReps, .unrankedDuration:
            false
        }
    }
}

/// The kind of physical work an exercise represents. Modality gates
/// analytics that would otherwise fabricate strength volume or PRs for
/// conditioning and mobility drills.
nonisolated enum ExerciseModality: String, Codable, Hashable, CaseIterable {
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
        case .dynamicStrength: "Dynamic Strength"
        case .isometricStrength: "Isometric Strength"
        case .power: "Power / Explosive"
        case .conditioning: "Conditioning"
        case .mobility: "Mobility"
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
            true
        default:
            false
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
        case let (.dynamicStrength, .reps, mode) where mode.supportsLoadComparison:
            .dynamicLoadAndReps
        case (.power, .reps, .external):
            .powerLoadAndReps
        case let (.isometricStrength, .duration, mode) where mode.supportsLoadComparison:
            .isometricLoadAndDuration
        case (.isometricStrength, .duration, .nonComparable):
            .isometricDuration
        case (_, .reps, _):
            .unrankedReps
        case (_, .duration, _):
            .unrankedDuration
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
    /// Optional only for legacy or unknown snapshots; every current
    /// catalog item has an authored programming placement.
    let trainingRole: TrainingRole?
    /// Optional — isolation work has no compound movement pattern.
    let pattern: MovementPattern?
    /// Optional — only push/pull patterns have a direction.
    let direction: PushPullDirection?
    /// One or more cardinal anatomical planes authored by the family.
    /// Order is canonical and stable for display/snapshot equality.
    let planes: [MovementPlane]
    let laterality: Laterality

    nonisolated init(
        equipment: Equipment,
        mechanic: Mechanic,
        trainingRole: TrainingRole? = nil,
        pattern: MovementPattern?,
        direction: PushPullDirection?,
        planes: [MovementPlane],
        laterality: Laterality
    ) {
        self.equipment = equipment
        self.mechanic = mechanic
        self.trainingRole = trainingRole
        self.pattern = pattern
        self.direction = direction
        self.planes = MovementPlane.canonicalized(planes)
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
        trainingRoleRaw: String? = nil,
        patternRaw: String?,
        directionRaw: String?,
        planeRaws: [String],
        lateralityRaw: String?
    ) {
        guard
            let equipmentRaw,
            let equipment = Equipment(rawValue: equipmentRaw),
            let mechanicRaw,
            let mechanic = Mechanic(rawValue: mechanicRaw),
            let lateralityRaw,
            let laterality = Laterality(rawValue: lateralityRaw)
        else {
            return nil
        }

        let trainingRole: TrainingRole?
        if let trainingRoleRaw {
            guard let value = TrainingRole(rawValue: trainingRoleRaw) else { return nil }
            trainingRole = value
        } else {
            trainingRole = nil
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

        let planes = planeRaws.compactMap(MovementPlane.init(rawValue:))
        guard !planes.isEmpty,
              planes.count == planeRaws.count,
              Set(planes).count == planes.count
        else { return nil }

        self.init(
            equipment: equipment,
            mechanic: mechanic,
            trainingRole: trainingRole,
            pattern: pattern,
            direction: direction,
            planes: planes,
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
