//
//  ExerciseResistanceSemantics.swift
//  vivobody
//
//  Resistance capability and stable performance identity shared by catalog,
//  template, workout, history, and analytics boundaries.
//

import Foundation

/// The complete comparison contract captured by a custom exercise.
/// Catalog UUID alone is not enough: changing resistance interpretation makes
/// old loads physically non-interchangeable even when the record kind matches.
nonisolated struct ExercisePerformanceSignature: Hashable {
    private static let fractionScale = 10000.0

    let modality: ExerciseModality
    let trackingMode: TrackingMode
    let loadMode: ExerciseLoadMode
    let bodyweightFractionBasisPoints: Int
    let tracksResistance: Bool

    init(
        modality: ExerciseModality,
        trackingMode: TrackingMode,
        loadMode: ExerciseLoadMode,
        bodyweightFraction: Double,
        tracksResistance: Bool = true
    ) {
        self.modality = modality
        self.trackingMode = trackingMode
        self.loadMode = loadMode
        self.tracksResistance = tracksResistance
        let finiteFraction = bodyweightFraction.isFinite ? bodyweightFraction : 0
        let clampedFraction = max(0, min(finiteFraction, 1))
        bodyweightFractionBasisPoints = Int(
            (clampedFraction * Self.fractionScale).rounded()
        )
    }

    var performanceKind: PerformanceSemanticKind {
        modality.performanceSemanticKind(for: trackingMode, loadMode: loadMode)
    }

    var keyComponent: String {
        [
            performanceKind.rawValue,
            "modality=\(modality.rawValue)",
            "tracking=\(trackingMode.rawValue)",
            "load=\(loadMode.rawValue)",
            "bodyweightBps=\(bodyweightFractionBasisPoints)",
            "resistance=\(tracksResistance ? "tracked" : "untracked")",
        ].joined(separator: ":")
    }
}

nonisolated enum ExerciseIdentity {
    static func key(
        catalogID: String?,
        catalogItemID: UUID?,
        name: String,
        performanceSignature: ExercisePerformanceSignature? = nil
    ) -> String {
        if let catalogID, !catalogID.isEmpty { return "bundled:\(catalogID)" }
        if let catalogItemID {
            let base = "catalog:\(catalogItemID.uuidString)"
            guard let performanceSignature else { return base }
            return "\(base):performance:\(performanceSignature.keyComponent)"
        }
        return nameKey(name)
    }

    static func nameKey(_ name: String) -> String {
        "name:\(name.exerciseIdentityName)"
    }
}

extension String {
    nonisolated var exerciseIdentityName: String {
        lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ExerciseCatalogItem {
    /// False only for an unloaded bodyweight fixture. Non-comparable bands
    /// retain the real resistance value entered by the user.
    var tracksResistance: Bool {
        ExerciseResistanceCapability.tracksResistance(
            loadMode: loadMode,
            equipment: equipment
        )
    }

    var performanceSignature: ExercisePerformanceSignature {
        ExercisePerformanceSignature(
            modality: modality,
            trackingMode: trackingMode,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction,
            tracksResistance: tracksResistance
        )
    }

    var performanceSemanticKind: PerformanceSemanticKind {
        performanceSignature.performanceKind
    }

    var historyKey: String {
        ExerciseIdentity.key(
            catalogID: catalogID,
            catalogItemID: id,
            name: name,
            performanceSignature: performanceSignature
        )
    }
}

extension Exercise {
    var tracksResistance: Bool {
        ExerciseResistanceCapability.tracksResistance(
            loadMode: loadMode,
            equipment: classification?.equipment
        )
    }

    func trackedWeight(_ weight: Double) -> Double {
        ExerciseResistanceCapability.normalizedWeight(
            weight,
            loadMode: loadMode,
            equipment: classification?.equipment
        )
    }

    var performanceSignature: ExercisePerformanceSignature {
        ExercisePerformanceSignature(
            modality: modality,
            trackingMode: trackingMode,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction,
            tracksResistance: tracksResistance
        )
    }

    var performanceSemanticKind: PerformanceSemanticKind {
        performanceSignature.performanceKind
    }

    var historyKey: String {
        ExerciseIdentity.key(
            catalogID: catalogID,
            catalogItemID: catalogItemID,
            name: name,
            performanceSignature: performanceSignature
        )
    }

    func matchesCatalogItem(_ item: ExerciseCatalogItem) -> Bool {
        if let catalogID, let itemCatalogID = item.catalogID {
            return catalogID == itemCatalogID
        }
        if let catalogItemID {
            return catalogItemID == item.id
                && performanceSignature == item.performanceSignature
        }
        return false
    }
}

extension TemplateExercise {
    var tracksResistance: Bool {
        ExerciseResistanceCapability.tracksResistance(
            loadMode: loadMode,
            equipment: classification?.equipment
        )
    }

    func trackedWeight(_ weight: Double) -> Double {
        ExerciseResistanceCapability.normalizedWeight(
            weight,
            loadMode: loadMode,
            equipment: classification?.equipment
        )
    }

    var performanceSignature: ExercisePerformanceSignature {
        ExercisePerformanceSignature(
            modality: modality,
            trackingMode: trackingMode,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction,
            tracksResistance: tracksResistance
        )
    }

    var historyKey: String {
        ExerciseIdentity.key(
            catalogID: catalogID,
            catalogItemID: catalogItemID,
            name: name,
            performanceSignature: performanceSignature
        )
    }
}
