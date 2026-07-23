//
//  CatalogData.swift
//  vivobody
//
//  Strict decoder and validator for the bundled exercise catalog.
//  catalog.json is authored by Scripts/curate.py and is a build-time
//  contract: malformed enums, missing required biomechanics fields,
//  duplicate stable IDs, or ambiguous names fail loudly rather than
//  acquiring silent defaults.
//

import Foundation

// MARK: - Decoded record

/// One fully curated exercise shipped in catalog.json. Optional values
/// are optional by domain meaning, not to tolerate incomplete records.
nonisolated struct CatalogRecord: Decodable, Sendable {
    struct MuscleAssignment: Decodable, Sendable {
        let muscle: Muscle
        let role: MuscleRole
    }

    let catalogID: String
    let name: String
    let group: MuscleGroup
    let defaultWeight: Double
    let defaultWeightKg: Double?
    let reps: Int
    let trackingMode: TrackingMode
    let defaultDuration: TimeInterval?
    let equipment: Equipment
    let mechanic: Mechanic
    let pattern: MovementPattern?
    let direction: PushPullDirection?
    let plane: MovementPlane
    let laterality: Laterality
    let aliases: [String]
    let bodyweightFraction: Double
    let modality: ExerciseModality
    let loadMode: ExerciseLoadMode
    let movementDefinition: String
    let involvement: [MuscleAssignment]

    // Compatibility-free projections used by persistent seeding.
    var muscleGroup: MuscleGroup { group }
    var defaultWeightValue: Double { defaultWeight }
    var defaultRepsValue: Int { reps }
    var defaultWeightKgValue: Double? { defaultWeightKg }
    var defaultDurationValue: TimeInterval { defaultDuration ?? 0 }
    var trackingModeValue: TrackingMode { trackingMode }
    var equipmentValue: Equipment { equipment }
    var mechanicValue: Mechanic { mechanic }
    var patternValue: MovementPattern? { pattern }
    var directionValue: PushPullDirection? { direction }
    var planeValue: MovementPlane { plane }
    var lateralityValue: Laterality { laterality }
    var aliasesValue: [String] { aliases }
    var bodyweightFractionValue: Double { bodyweightFraction }

    var muscleInvolvement: Muscle.Involvement {
        Muscle.Involvement(contributions: involvement.map {
            .init(muscle: $0.muscle, role: $0.role)
        })
    }

    var classification: ExerciseClassification {
        ExerciseClassification(
            equipment: equipment,
            mechanic: mechanic,
            pattern: pattern,
            direction: direction,
            plane: plane,
            laterality: laterality
        )
    }
}

// MARK: - Loaded catalog

/// Loads and caches the bundled catalog once. Both indexes are safe
/// because validation rejects duplicate normalized names and stable IDs.
nonisolated enum CatalogData {
    static let records: [CatalogRecord] = load()

    static let byName: [String: CatalogRecord] = Dictionary(
        uniqueKeysWithValues: records.map { (normalized($0.name), $0) }
    )

    static let byCatalogID: [String: CatalogRecord] = Dictionary(
        uniqueKeysWithValues: records.map { ($0.catalogID, $0) }
    )

    static func record(forExerciseNamed name: String) -> CatalogRecord? {
        byName[normalized(name)]
    }

    static func record(forCatalogID catalogID: String) -> CatalogRecord? {
        byCatalogID[catalogID]
    }

    /// Exposed internally so domain tests can prove malformed bundled
    /// records fail instead of receiving fallback classifications.
    static func decode(_ data: Data) throws -> [CatalogRecord] {
        let records = try JSONDecoder().decode([CatalogRecord].self, from: data)
        try validate(records)
        return records
    }

    private static func load() -> [CatalogRecord] {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            preconditionFailure("catalog.json is missing from the app bundle")
        }

        do {
            return try decode(Data(contentsOf: url))
        } catch {
            preconditionFailure("Invalid bundled catalog.json: \(error)")
        }
    }

    static func validate(_ records: [CatalogRecord]) throws {
        guard !records.isEmpty else { throw ValidationError.emptyCatalog }

        var catalogIDs: Set<String> = []
        var names: Set<String> = []

        for record in records {
            let normalizedName = normalized(record.name)
            guard !normalizedName.isEmpty else {
                throw ValidationError.emptyName(record.catalogID)
            }
            guard names.insert(normalizedName).inserted else {
                throw ValidationError.duplicateName(record.name)
            }
        }

        var aliases: Set<String> = []

        for record in records {
            guard isStableCatalogID(record.catalogID) else {
                throw ValidationError.invalidCatalogID(record.catalogID)
            }
            guard catalogIDs.insert(record.catalogID).inserted else {
                throw ValidationError.duplicateCatalogID(record.catalogID)
            }

            let definition = record.movementDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !definition.isEmpty else {
                throw ValidationError.emptyMovementDefinition(record.catalogID)
            }
            let definitionWords = definition
                .split(whereSeparator: \.isWhitespace)
                .map {
                    String($0)
                        .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                        .lowercased()
                }
                .filter { !$0.isEmpty }
            let repeatsAdjacentWord = zip(definitionWords, definitionWords.dropFirst())
                .contains { pair in pair.0 == pair.1 }
            guard
                definition.count >= 24,
                definition.first?.isUppercase == true,
                definition.last == "." || definition.last == "!" || definition.last == "?",
                !repeatsAdjacentWord
            else {
                throw ValidationError.invalidMovementDefinition(record.catalogID)
            }
            guard record.defaultWeight >= 0, record.reps > 0 else {
                throw ValidationError.invalidDefaults(record.catalogID)
            }
            guard (0...1).contains(record.bodyweightFraction) else {
                throw ValidationError.invalidBodyweightFraction(record.catalogID)
            }
            if let kilograms = record.defaultWeightKg {
                let gridUnits = kilograms / 2.5
                guard kilograms > 0, abs(gridUnits.rounded() - gridUnits) < 0.000_001 else {
                    throw ValidationError.invalidKilogramDefault(record.catalogID)
                }
            }
            guard record.trackingMode != .duration || (record.defaultDuration ?? 0) > 0 else {
                throw ValidationError.missingDuration(record.catalogID)
            }

            switch record.modality {
            case .dynamicStrength:
                guard record.trackingMode == .reps else {
                    throw ValidationError.invalidModalityTracking(record.catalogID)
                }
            case .isometricStrength:
                guard record.trackingMode == .duration else {
                    throw ValidationError.invalidModalityTracking(record.catalogID)
                }
            case .power:
                guard record.trackingMode == .reps else {
                    throw ValidationError.invalidModalityTracking(record.catalogID)
                }
            case .conditioning, .mobility:
                break
            }

            switch record.loadMode {
            case .external, .nonComparable:
                guard record.bodyweightFraction == 0 else {
                    throw ValidationError.invalidLoadFraction(record.catalogID)
                }
            case .bodyweightAdded, .assistanceSubtracted:
                guard record.bodyweightFraction > 0 else {
                    throw ValidationError.invalidLoadFraction(record.catalogID)
                }
            }

            // A band color or nominal stack value is not a force at the
            // joint: resistance varies through the range of motion and
            // between products. Until the model captures a calibrated
            // force curve, band work must remain explicitly unranked.
            if record.equipment == .band, record.loadMode != .nonComparable {
                throw ValidationError.comparableBandLoad(record.catalogID)
            }

            switch record.mechanic {
            case .compound:
                guard record.pattern != nil else {
                    throw ValidationError.invalidMechanicPattern(record.catalogID)
                }
            case .isolation:
                guard record.pattern == nil else {
                    throw ValidationError.invalidMechanicPattern(record.catalogID)
                }
            }

            let muscles = record.involvement.map(\.muscle)
            guard !muscles.isEmpty else {
                throw ValidationError.emptyInvolvement(record.catalogID)
            }
            guard Set(muscles).count == muscles.count else {
                throw ValidationError.duplicateMuscle(record.catalogID)
            }
            if record.modality.requiresPrimaryMuscle {
                guard record.involvement.contains(where: { $0.role == .primary }) else {
                    throw ValidationError.missingPrimary(record.catalogID)
                }
                guard record.involvement.contains(where: {
                    $0.role == .primary && $0.muscle.group == record.group
                }) else {
                    throw ValidationError.primaryGroupMismatch(record.catalogID)
                }
            }

            let isPushPull = record.pattern == .push || record.pattern == .pull
            guard isPushPull == (record.direction != nil) else {
                throw ValidationError.invalidDirection(record.catalogID)
            }

            for alias in record.aliases {
                let normalizedAlias = normalized(alias)
                guard !normalizedAlias.isEmpty, !names.contains(normalizedAlias) else {
                    throw ValidationError.aliasConflictsWithName(alias)
                }
                guard aliases.insert(normalizedAlias).inserted else {
                    throw ValidationError.duplicateAlias(alias)
                }
            }
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func isStableCatalogID(_ value: String) -> Bool {
        guard
            !value.isEmpty,
            value.first != "-",
            value.last != "-",
            !value.contains("--")
        else {
            return false
        }
        return value.unicodeScalars.allSatisfy { scalar in
            (97...122).contains(scalar.value)
                || (48...57).contains(scalar.value)
                || scalar.value == 45
        }
    }

    enum ValidationError: Error, Equatable, CustomStringConvertible {
        case emptyCatalog
        case invalidCatalogID(String)
        case duplicateCatalogID(String)
        case emptyName(String)
        case duplicateName(String)
        case emptyMovementDefinition(String)
        case invalidMovementDefinition(String)
        case invalidDefaults(String)
        case invalidBodyweightFraction(String)
        case invalidKilogramDefault(String)
        case missingDuration(String)
        case invalidModalityTracking(String)
        case invalidLoadFraction(String)
        case comparableBandLoad(String)
        case invalidMechanicPattern(String)
        case emptyInvolvement(String)
        case duplicateMuscle(String)
        case missingPrimary(String)
        case primaryGroupMismatch(String)
        case invalidDirection(String)
        case aliasConflictsWithName(String)
        case duplicateAlias(String)

        var description: String {
            switch self {
            case .emptyCatalog: return "catalog contains no records"
            case .invalidCatalogID(let id): return "invalid catalogID '\(id)'"
            case .duplicateCatalogID(let id): return "duplicate catalogID '\(id)'"
            case .emptyName(let id): return "record '\(id)' has an empty name"
            case .duplicateName(let name): return "duplicate exercise name '\(name)'"
            case .emptyMovementDefinition(let id): return "record '\(id)' has no movement definition"
            case .invalidMovementDefinition(let id): return "record '\(id)' has a malformed movement definition"
            case .invalidDefaults(let id): return "record '\(id)' has invalid weight/reps defaults"
            case .invalidBodyweightFraction(let id): return "record '\(id)' has an invalid bodyweight fraction"
            case .invalidKilogramDefault(let id): return "record '\(id)' has an invalid kilogram default"
            case .missingDuration(let id): return "duration record '\(id)' has no positive default duration"
            case .invalidModalityTracking(let id): return "record '\(id)' has modality-incompatible tracking"
            case .invalidLoadFraction(let id): return "record '\(id)' has load-mode-incompatible bodyweight fraction"
            case .comparableBandLoad(let id): return "band record '\(id)' claims a comparable load"
            case .invalidMechanicPattern(let id): return "record '\(id)' has mechanic-incompatible movement pattern"
            case .emptyInvolvement(let id): return "record '\(id)' has no muscle involvement"
            case .duplicateMuscle(let id): return "record '\(id)' assigns the same muscle more than once"
            case .missingPrimary(let id): return "strength/power record '\(id)' has no primary muscle"
            case .primaryGroupMismatch(let id): return "strength/power record '\(id)' group has no matching primary muscle"
            case .invalidDirection(let id): return "record '\(id)' has inconsistent push/pull direction"
            case .aliasConflictsWithName(let alias): return "alias '\(alias)' conflicts with a canonical name"
            case .duplicateAlias(let alias): return "duplicate alias '\(alias)'"
            }
        }
    }
}
