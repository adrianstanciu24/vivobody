//
//  CatalogData.swift
//  vivobody
//
//  Strict decoder and validator for the bundled exercise catalog.
//  catalog.json is deterministically compiled from specs/catalog
//  by Scripts/catalog.py. It is a build-time contract: malformed
//  enums, missing required biomechanics fields, duplicate stable IDs,
//  or ambiguous names fail loudly rather than acquiring silent defaults.
//

import Foundation

// MARK: - Decoded record

/// One fully curated exercise shipped in catalog.json. Optional values
/// are optional by domain meaning, not to tolerate incomplete records.
nonisolated struct CatalogRecord: Decodable {
    struct MuscleAssignment: Decodable {
        let muscle: Muscle
        let role: MuscleRole
    }

    let familyID: String
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
    let planes: [MovementPlane]
    let laterality: Laterality
    let aliases: [String]
    /// Sparse editorial prior for broad in-app and Spotlight searches.
    /// Nil means no catalog-authored boost; text relevance and user
    /// signals still decide whether and where the item appears.
    let searchPriority: Int?
    let bodyweightFraction: Double
    let modality: ExerciseModality
    let loadMode: ExerciseLoadMode
    let movementSteps: [String]
    let involvement: [MuscleAssignment]

    /// Canonical projections used by persistent synchronization.
    var muscleGroup: MuscleGroup {
        group
    }

    var defaultWeightValue: Double {
        defaultWeight
    }

    var defaultRepsValue: Int {
        reps
    }

    var defaultWeightKgValue: Double? {
        defaultWeightKg
    }

    var defaultDurationValue: TimeInterval {
        defaultDuration ?? 0
    }

    var trackingModeValue: TrackingMode {
        trackingMode
    }

    var equipmentValue: Equipment {
        equipment
    }

    var mechanicValue: Mechanic {
        mechanic
    }

    var patternValue: MovementPattern? {
        pattern
    }

    var directionValue: PushPullDirection? {
        direction
    }

    var planeValues: [MovementPlane] {
        planes
    }

    var lateralityValue: Laterality {
        laterality
    }

    var aliasesValue: [String] {
        aliases
    }

    var searchPriorityValue: Int {
        searchPriority ?? 0
    }

    var bodyweightFractionValue: Double {
        bodyweightFraction
    }

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
            planes: planes,
            laterality: laterality
        )
    }
}

// MARK: - Loaded catalog

/// Loads and caches the bundled catalog once. Both indexes are safe
/// because validation rejects duplicate normalized names and stable IDs.
nonisolated enum CatalogData {
    private static let sourceData = loadData()

    static let records: [CatalogRecord] = load(sourceData)

    /// Stable FNV-1a digest of the generated resource bytes. This is not a
    /// security primitive; it is a compact change token for local caches such
    /// as Spotlight.
    static let sourceFingerprint: String = {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in sourceData {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let value = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - value.count) + value
    }()

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

    private static func loadData() -> Data {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            preconditionFailure("catalog.json is missing from the app bundle")
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            preconditionFailure("Unable to read bundled catalog.json: \(error)")
        }
    }

    private static func load(_ data: Data) -> [CatalogRecord] {
        do {
            return try decode(data)
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
            guard isStableCatalogID(record.familyID) else {
                throw ValidationError.invalidFamilyID(record.familyID)
            }
            guard catalogIDs.insert(record.catalogID).inserted else {
                throw ValidationError.duplicateCatalogID(record.catalogID)
            }

            try validateMovementSteps(record)
            guard record.defaultWeight >= 0, record.reps > 0 else {
                throw ValidationError.invalidDefaults(record.catalogID)
            }
            guard record.defaultWeight == 0 || record.defaultWeightKg != nil else {
                throw ValidationError.missingKilogramDefault(record.catalogID)
            }
            guard (0 ... 100).contains(record.searchPriorityValue) else {
                throw ValidationError.invalidSearchPriority(record.catalogID)
            }
            guard (0 ... 1).contains(record.bodyweightFraction) else {
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
            guard !record.planes.isEmpty,
                  Set(record.planes).count == record.planes.count
            else {
                throw ValidationError.invalidPlanes(record.catalogID)
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

    private static func validateMovementSteps(_ record: CatalogRecord) throws {
        guard
            (2 ... 10).contains(record.movementSteps.count),
            Set(record.movementSteps).count == record.movementSteps.count
        else {
            throw ValidationError.invalidMovementSteps(record.catalogID)
        }

        for step in record.movementSteps {
            let trimmed = step.trimmingCharacters(in: .whitespacesAndNewlines)
            let words = trimmed
                .split(whereSeparator: \.isWhitespace)
                .map {
                    String($0)
                        .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                        .lowercased()
                }
                .filter { !$0.isEmpty }
            let repeatsAdjacentWord = zip(words, words.dropFirst())
                .contains { pair in pair.0 == pair.1 }
            guard
                trimmed == step,
                trimmed.count >= 12,
                trimmed.first?.isUppercase == true,
                trimmed.last.map({ ".!?".contains($0) }) == true,
                !repeatsAdjacentWord
            else {
                throw ValidationError.invalidMovementSteps(record.catalogID)
            }
        }
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
            (97 ... 122).contains(scalar.value)
                || (48 ... 57).contains(scalar.value)
                || scalar.value == 45
        }
    }

    enum ValidationError: Error, Equatable, CustomStringConvertible {
        case emptyCatalog
        case invalidCatalogID(String)
        case invalidFamilyID(String)
        case duplicateCatalogID(String)
        case emptyName(String)
        case duplicateName(String)
        case invalidMovementSteps(String)
        case invalidDefaults(String)
        case invalidSearchPriority(String)
        case invalidBodyweightFraction(String)
        case missingKilogramDefault(String)
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
        case invalidPlanes(String)
        case aliasConflictsWithName(String)
        case duplicateAlias(String)

        var description: String {
            switch self {
            case .emptyCatalog: "catalog contains no records"
            case let .invalidCatalogID(id): "invalid catalogID '\(id)'"
            case let .invalidFamilyID(id): "invalid familyID '\(id)'"
            case let .duplicateCatalogID(id): "duplicate catalogID '\(id)'"
            case let .emptyName(id): "record '\(id)' has an empty name"
            case let .duplicateName(name): "duplicate exercise name '\(name)'"
            case let .invalidMovementSteps(id): "record '\(id)' has malformed movement steps"
            case let .invalidDefaults(id): "record '\(id)' has invalid weight/reps defaults"
            case let .invalidSearchPriority(id): "record '\(id)' has an invalid search priority"
            case let .invalidBodyweightFraction(id): "record '\(id)' has an invalid bodyweight fraction"
            case let .missingKilogramDefault(id): "record '\(id)' has a positive weight but no kilogram default"
            case let .invalidKilogramDefault(id): "record '\(id)' has an invalid kilogram default"
            case let .missingDuration(id): "duration record '\(id)' has no positive default duration"
            case let .invalidModalityTracking(id): "record '\(id)' has modality-incompatible tracking"
            case let .invalidLoadFraction(id): "record '\(id)' has load-mode-incompatible bodyweight fraction"
            case let .comparableBandLoad(id): "band record '\(id)' claims a comparable load"
            case let .invalidMechanicPattern(id): "record '\(id)' has mechanic-incompatible movement pattern"
            case let .emptyInvolvement(id): "record '\(id)' has no muscle involvement"
            case let .duplicateMuscle(id): "record '\(id)' assigns the same muscle more than once"
            case let .missingPrimary(id): "strength/power record '\(id)' has no primary muscle"
            case let .primaryGroupMismatch(id): "strength/power record '\(id)' group has no matching primary muscle"
            case let .invalidDirection(id): "record '\(id)' has inconsistent push/pull direction"
            case let .invalidPlanes(id): "record '\(id)' has invalid movement planes"
            case let .aliasConflictsWithName(alias): "alias '\(alias)' conflicts with a canonical name"
            case let .duplicateAlias(alias): "duplicate alias '\(alias)'"
            }
        }
    }
}
