//
//  CatalogDraft.swift
//  vivobody
//
//  Value-type editing buffer and normalized search-term helpers for
//  custom exercise creation, editing, and duplication. SwiftData models
//  are touched only when the editor commits the completed draft.
//

import Foundation

// MARK: - Draft

/// Value-type buffer for the editor. The @Model isn't bound to the
/// fields directly — the editor mutates the draft, only writing back
/// to the model on Save. This avoids two known SwiftData/TextField
/// edge cases: typing latency and partial commits if the sheet is
/// dismissed before Save.
struct CatalogDraft {
    var name: String
    var execution: ExecutionInstructions?
    var group: MuscleGroup
    var defaultWeight: Double
    var trackingMode: TrackingMode
    var modality: ExerciseModality
    var loadMode: ExerciseLoadMode
    var bodyweightFraction: Double
    var defaultDuration: TimeInterval
    var equipment: Equipment
    var mechanic: Mechanic
    var trainingRole: TrainingRole
    var pattern: MovementPattern?
    var direction: PushPullDirection?
    var planes: [MovementPlane]
    var laterality: Laterality
    var muscleInvolvementSnapshot: [String: Double]

    /// Raw editor input for aliases — comma-separated free text.
    /// Parsed into `[String]` on save via `parsedAliases`. Keeping
    /// the raw form here lets the user keep typing without us
    /// reformatting their input mid-stream.
    var aliasesInput: String

    static let empty = CatalogDraft(
        name: "",
        execution: nil,
        group: .chest,
        defaultWeight: 0,
        trackingMode: .reps,
        modality: .dynamicStrength,
        loadMode: .external,
        bodyweightFraction: 0,
        defaultDuration: 45,
        equipment: .barbell,
        mechanic: .compound,
        trainingRole: .push,
        pattern: .push,
        direction: .horizontal,
        planes: [.sagittal],
        laterality: .bilateral,
        muscleInvolvementSnapshot: [:],
        aliasesInput: ""
    )

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
        aliasesInput: String
    ) {
        self.name = name
        self.execution = execution
        self.group = group
        self.defaultWeight = defaultWeight
        self.trackingMode = trackingMode
        self.modality = modality
        self.loadMode = loadMode
        self.bodyweightFraction = max(0, min(bodyweightFraction, 1))
        self.defaultDuration = defaultDuration
        self.equipment = equipment
        self.mechanic = mechanic
        self.trainingRole = trainingRole
        self.pattern = pattern
        self.direction = direction
        self.planes = MovementPlane.canonicalized(planes)
        self.laterality = laterality
        self.muscleInvolvementSnapshot = muscleInvolvementSnapshot
        self.aliasesInput = aliasesInput
    }

    init(from item: ExerciseCatalogItem) {
        self.name = item.name
        self.execution = item.execution
        self.group = item.group
        self.defaultWeight = item.defaultWeight
        self.trackingMode = item.trackingMode
        self.modality = item.modality
        self.loadMode = item.loadMode
        self.bodyweightFraction = item.bodyweightFraction
        self.defaultDuration = item.defaultDuration > 0 ? item.defaultDuration : 45
        self.equipment = item.equipment
        self.mechanic = item.mechanic
        self.trainingRole = item.trainingRole ?? TrainingRole.defaultRole(for: item.pattern)
        self.pattern = item.pattern
        self.direction = item.direction
        self.planes = item.planes
        self.laterality = item.laterality
        self.muscleInvolvementSnapshot = item.muscleInvolvement.snapshot
        // Rebuild the comma-separated string so the editor's text
        // field reflects the stored list. Two-space readability for
        // long lists, but the parser tolerates either.
        self.aliasesInput = item.aliases.joined(separator: ", ")
    }

    /// Draft prefilled to fork an existing catalog item into a
    /// user-created copy: identical semantics, anatomy, and defaults,
    /// under a fresh identity. Aliases are cleared because the source
    /// owns them in the shared name/alias namespace. `defaultWeight`
    /// comes from the caller so the seed can resolve against the
    /// user's unit — a kg user keeps the source's clean kg-grid
    /// default instead of the off-grid lb conversion. The editor
    /// refines the provisional "(Custom)" name against the live
    /// catalog on appear (see `duplicateName(base:taken:)`).
    init(duplicating item: ExerciseCatalogItem, defaultWeight: Double) {
        self.init(from: item)
        name = "\(item.name) (Custom)"
        aliasesInput = ""
        self.defaultWeight = defaultWeight
    }

    /// Suggested name for a user-created copy of an exercise named
    /// `base`: "X (Custom)", incrementing to "X (Custom 2)" and so on
    /// until it clears the taken name/alias set. Comparison uses the
    /// same normalization as the editor's uniqueness validation, so
    /// the suggestion always saves cleanly.
    static func duplicateName(base: String, taken: Set<String>) -> String {
        let takenKeys = Set(taken.map(\.catalogSearchTermKey))
        let first = "\(base) (Custom)"
        guard takenKeys.contains(first.catalogSearchTermKey) else { return first }
        var suffix = 2
        while takenKeys.contains("\(base) (Custom \(suffix))".catalogSearchTermKey) {
            suffix += 1
        }
        return "\(base) (Custom \(suffix))"
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

    var showsLoggingDefaults: Bool {
        trackingMode == .duration || tracksResistance
    }

    var muscleSummary: String {
        let involvement = muscleInvolvement
        let primary = involvement.primary.map(\.displayName).joined(separator: " · ")
        let supportingCount = involvement.secondary.count + involvement.stabilizers.count
        guard !primary.isEmpty else {
            let visual = (involvement.secondary + involvement.stabilizers)
                .map(\.displayName)
                .joined(separator: " · ")
            return visual.isEmpty ? "No muscles selected" : "\(visual) · Anatomy context only"
        }
        guard supportingCount > 0 else { return "\(primary) · Primary" }
        let suffix = supportingCount == 1 ? "1 supporting muscle" : "\(supportingCount) supporting muscles"
        return "\(primary) · \(suffix)"
    }

    /// Freeze the validated editor buffer into the UI-independent payload
    /// consumed by the catalog transaction boundary.
    func mutationInput(using validation: CatalogDraftValidation) -> CatalogMutationInput {
        CatalogMutationInput(
            name: validation.normalizedName,
            execution: execution,
            group: group,
            defaultWeight: defaultWeight,
            trackingMode: trackingMode,
            modality: modality,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction,
            defaultDuration: defaultDuration,
            equipment: equipment,
            mechanic: mechanic,
            trainingRole: trainingRole,
            pattern: pattern,
            direction: direction,
            planes: planes,
            laterality: laterality,
            muscleInvolvementSnapshot: muscleInvolvementSnapshot,
            aliases: validation.normalizedAliases
        )
    }

    // MARK: - Dependent selections

    /// Changes the browse group without inferring anatomy. A real group
    /// change requires the user to author a fresh role map; reselecting the
    /// current group preserves the work already entered.
    mutating func selectMuscleGroup(_ group: MuscleGroup) {
        guard self.group != group else { return }
        self.group = group
        muscleInvolvementSnapshot = [:]
    }

    /// Applies the load constraint imposed by fixtures whose resistance
    /// cannot be compared honestly.
    mutating func selectEquipment(_ equipment: Equipment) {
        self.equipment = equipment
        if equipment.requiresNonComparableLoad {
            loadMode = .nonComparable
            bodyweightFraction = 0
        }
    }

    /// Every custom modality owns one required logging measure.
    mutating func selectModality(_ modality: ExerciseModality) {
        self.modality = modality
        trackingMode = modality.requiredTrackingMode
    }

    /// Isolation lifts carry no compound pattern. Returning to compound
    /// restores the editor's existing Push/Horizontal starting point only
    /// when no prior pattern remains.
    mutating func selectMechanic(_ mechanic: Mechanic) {
        self.mechanic = mechanic
        switch mechanic {
        case .isolation:
            pattern = nil
            direction = nil
        case .compound:
            if pattern == nil {
                pattern = .push
                direction = .horizontal
            }
        }
    }

    /// Direction is meaningful only for push and pull patterns. Selecting a
    /// push/pull pattern backfills Horizontal only when direction is absent.
    mutating func selectPattern(_ pattern: MovementPattern) {
        self.pattern = pattern
        if pattern == .push || pattern == .pull {
            if direction == nil {
                direction = .horizontal
            }
        } else {
            direction = nil
        }
    }

    /// Bodyweight coefficients belong only to the two bodyweight load modes.
    /// Entering one starts at 100%; leaving one clears the coefficient.
    mutating func selectLoadMode(_ mode: ExerciseLoadMode) {
        loadMode = mode
        switch mode {
        case .external, .nonComparable:
            bodyweightFraction = 0
        case .bodyweightAdded, .assistanceSubtracted:
            if bodyweightFraction == 0 {
                bodyweightFraction = 1
            }
        }
    }

    /// Existing editor presentation behavior repairs legacy/custom band
    /// drafts on appearance. This intentionally remains band-only; choosing
    /// another constrained fixture goes through `selectEquipment(_:)`.
    mutating func normalizeBandLoadForEditorPresentation() {
        guard equipment == .band else { return }
        loadMode = .nonComparable
        bodyweightFraction = 0
    }

    /// Split the comma-separated `aliasesInput` into a clean array.
    /// Trims whitespace per item, drops empties + duplicates (case-
    /// insensitive), preserves first-appearance order so the user's
    /// typing order isn't shuffled.
    var parsedAliases: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for piece in aliasesInput.split(separator: ",") {
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                result.append(trimmed)
            }
        }
        return result
    }
}

extension String {
    /// Whitespace-collapsed, lowercased comparison key shared by the
    /// editor's global name/alias uniqueness check and the duplicate
    /// name prefill, so a suggested "(Custom)" name is guaranteed to
    /// satisfy validation.
    var catalogSearchTermKey: String {
        split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }
}
