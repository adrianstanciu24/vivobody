//
//  CatalogData.swift
//  vivobody
//
//  The single source of truth for the starter exercise catalog,
//  decoded once from the bundled `catalog.json` (generated from the
//  wger open exercise database by Scripts/transform_wger.py — wger
//  data is Creative Commons licensed).
//
//  Before this file the catalog lived in four hand-authored, name-keyed
//  Swift tables that had to be kept in sync by hand:
//    • ExerciseCatalogItem.seedItems  (defaults + classification)
//    • Muscle.defaultMap              (graded involvement)
//    • ExerciseClassification         (derived from seedItems)
//    • ExerciseLoad.fractions         (bodyweight fraction)
//  All four now read from one `CatalogRecord` per exercise, so there is
//  nothing to keep consistent by hand: regenerate catalog.json and the
//  whole app follows.
//
//  Resolution stays by lowercased name (not by model reference) so a
//  logged `Exercise` — which copies only its name — still resolves its
//  muscles, classification, and bodyweight load retroactively across
//  all history, exactly as before.
//

import Foundation

// MARK: - Decoded record

/// One exercise as shipped in catalog.json. Only `name` and `group` are
/// required — everything else is optional so the bundled catalog can
/// start as a names-only roster (imported from wger) and be enriched one
/// exercise at a time with our own authored data. Enum-typed fields are
/// stored as raw strings and projected to the app enums through computed
/// accessors (with sensible defaults) so an uncurated record still
/// decodes and a future catalog can add cases without a decode failure.
nonisolated struct CatalogRecord: Decodable, Sendable {
    /// One graded muscle contribution (weight ∈ 0...1).
    struct MuscleWeight: Decodable, Sendable {
        let muscle: String
        let weight: Double
    }

    let name: String
    let group: String
    let defaultWeight: Double?
    let defaultWeightKg: Double?
    let reps: Int?
    let trackingMode: String?
    let defaultDuration: TimeInterval?
    let equipment: String?
    let mechanic: String?
    let pattern: String?
    let direction: String?
    let plane: String?
    let laterality: String?
    let aliases: [String]?
    let bodyweightFraction: Double?
    let involvement: [MuscleWeight]?

    // MARK: Projected enum accessors (defaults apply to uncurated records)

    var muscleGroup: MuscleGroup { MuscleGroup(rawValue: group) ?? .chest }
    var defaultWeightValue: Double { defaultWeight ?? 0 }
    var defaultRepsValue: Int { reps ?? (mechanicValue == .compound ? 8 : 12) }
    /// Native kg seed (multiple of 2.5 kg), or nil for unloaded /
    /// uncurated records — those fall back to the lb default.
    var defaultWeightKgValue: Double? { defaultWeightKg }
    var defaultDurationValue: TimeInterval { defaultDuration ?? 0 }
    var trackingModeValue: TrackingMode { trackingMode.flatMap(TrackingMode.init(rawValue:)) ?? .reps }
    var equipmentValue: Equipment { equipment.flatMap(Equipment.init(rawValue:)) ?? .other }
    var mechanicValue: Mechanic { mechanic.flatMap(Mechanic.init(rawValue:)) ?? .compound }
    var patternValue: MovementPattern? { pattern.flatMap(MovementPattern.init(rawValue:)) }
    var directionValue: PushPullDirection? { direction.flatMap(PushPullDirection.init(rawValue:)) }
    var planeValue: MovementPlane { plane.flatMap(MovementPlane.init(rawValue:)) ?? .sagittal }
    var lateralityValue: Laterality { laterality.flatMap(Laterality.init(rawValue:)) ?? .bilateral }
    var aliasesValue: [String] { aliases ?? [] }
    var bodyweightFractionValue: Double { bodyweightFraction ?? 0 }

    /// Graded involvement, dropping any muscle name the app doesn't model.
    var muscleInvolvement: Muscle.Involvement {
        Muscle.Involvement(contributions: (involvement ?? []).compactMap { mw in
            guard let m = Muscle(rawValue: mw.muscle) else { return nil }
            return (muscle: m, weight: mw.weight)
        })
    }

    /// Movement metadata, for the by-name classification resolver.
    var classification: ExerciseClassification {
        ExerciseClassification(
            equipment: equipmentValue,
            mechanic: mechanicValue,
            pattern: patternValue,
            direction: directionValue,
            plane: planeValue,
            laterality: lateralityValue
        )
    }
}

// MARK: - Loaded catalog

/// Loads and caches the bundled catalog once. `records` preserves file
/// order (the transform sorts by group then name); `byName` is the
/// lowercased-name index every resolver reads.
nonisolated enum CatalogData {
    static let records: [CatalogRecord] = load()

    static let byName: [String: CatalogRecord] = Dictionary(
        records.map { ($0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), $0) },
        uniquingKeysWith: { first, _ in first }
    )

    static func record(forExerciseNamed name: String) -> CatalogRecord? {
        byName[name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    private static func load() -> [CatalogRecord] {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            assertionFailure("catalog.json missing from the app bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([CatalogRecord].self, from: data)
        } catch {
            assertionFailure("Failed to load catalog.json: \(error)")
            return []
        }
    }
}
