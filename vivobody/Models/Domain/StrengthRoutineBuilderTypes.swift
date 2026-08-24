//
//  StrengthRoutineBuilderTypes.swift
//  vivobody
//
//  Immutable inputs and outputs for the strength-only routine planner.
//  These values copy reviewed catalog facts so planning stays pure and
//  independent from SwiftData models, view state, and persistence policy.
//

import Foundation

// MARK: - Planning inputs

nonisolated enum StrengthRoutineWeekday: Int, CaseIterable, Hashable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var calendarValue: Int {
        rawValue
    }

    var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }
}

nonisolated enum StrengthRoutineSessionDuration: Int, CaseIterable, Hashable {
    case minutes30 = 30
    case minutes45 = 45
    case minutes60 = 60

    var minutes: Int {
        rawValue
    }
}

nonisolated enum StrengthRoutineGoal: String, CaseIterable, Hashable {
    case strength
    case muscle
    case balanced

    var title: String {
        switch self {
        case .strength: "Strength"
        case .muscle: "Build Muscle"
        case .balanced: "Balanced"
        }
    }
}

nonisolated struct StrengthRoutineFamiliarity: Hashable {
    static let none = StrengthRoutineFamiliarity()

    let sessionCount: Int
    let lastPerformedAt: Date?

    init(sessionCount: Int = 0, lastPerformedAt: Date? = nil) {
        self.sessionCount = max(0, sessionCount)
        self.lastPerformedAt = lastPerformedAt
    }
}

/// A reviewed catalog row copied into an immutable planner value. Favorites
/// and familiarity are user signals used only after structural fit is tied.
nonisolated struct StrengthRoutineCandidate: Hashable, Identifiable {
    var id: String {
        catalogID
    }

    let catalogID: String
    let familyID: String
    let name: String
    let group: MuscleGroup
    let equipment: Equipment
    let mechanic: Mechanic
    let trainingRole: TrainingRole
    let pattern: MovementPattern?
    let direction: PushPullDirection?
    let laterality: Laterality
    let trackingMode: TrackingMode
    let modality: ExerciseModality
    let searchPriority: Int
    let isFavorite: Bool
    let familiarity: StrengthRoutineFamiliarity

    init(
        record: CatalogRecord,
        isFavorite: Bool = false,
        familiarity: StrengthRoutineFamiliarity = .none
    ) {
        catalogID = record.catalogID
        familyID = record.familyID
        name = record.name
        group = record.group
        equipment = record.equipment
        mechanic = record.mechanic
        trainingRole = record.trainingRole
        pattern = record.pattern
        direction = record.direction
        laterality = record.laterality
        trackingMode = record.trackingMode
        modality = record.modality
        searchPriority = record.searchPriorityValue
        self.isFavorite = isFavorite
        self.familiarity = familiarity
    }

    var isStrengthExercise: Bool {
        modality == .dynamicStrength || modality == .isometricStrength
    }
}

nonisolated enum StrengthRoutineSlotKind: Hashable {
    case horizontalPush
    case horizontalPull
    case verticalPush
    case verticalPull
    case squat
    case hinge
    case unilateralLeg
    case core
    case elbowFlexion
    case elbowExtension
    case upperAccessory
    case lowerAccessory
    case emphasis(MuscleGroup)

    var title: String {
        switch self {
        case .horizontalPush: "Horizontal Push"
        case .horizontalPull: "Horizontal Pull"
        case .verticalPush: "Vertical Push"
        case .verticalPull: "Vertical Pull"
        case .squat: "Squat"
        case .hinge: "Hinge"
        case .unilateralLeg: "Single-Leg"
        case .core: "Core"
        case .elbowFlexion: "Elbow Flexion"
        case .elbowExtension: "Elbow Extension"
        case .upperAccessory: "Upper Accessory"
        case .lowerAccessory: "Lower Accessory"
        case let .emphasis(group): "\(group.displayName) Emphasis"
        }
    }
}

/// A slot remains stable while exercises are regenerated or replaced.
nonisolated struct StrengthRoutineSlotID: Hashable {
    let weekday: StrengthRoutineWeekday
    let kind: StrengthRoutineSlotKind
    let occurrence: Int

    init(
        weekday: StrengthRoutineWeekday,
        kind: StrengthRoutineSlotKind,
        occurrence: Int = 0
    ) {
        self.weekday = weekday
        self.kind = kind
        self.occurrence = max(0, occurrence)
    }
}

nonisolated struct StrengthRoutineBuilderInput: Hashable {
    /// Caller-provided locale-aware week order. The planner preserves it and
    /// removes any accidental duplicate day while keeping the first position.
    let weekdays: [StrengthRoutineWeekday]
    let sessionDuration: StrengthRoutineSessionDuration
    let goal: StrengthRoutineGoal
    /// User-selected external equipment. Bodyweight remains available through
    /// `StrengthRoutinePolicy` without requiring an explicit selection.
    let availableEquipment: Set<Equipment>
    let emphasis: MuscleGroup?
    let includedCatalogIDs: Set<String>
    let excludedCatalogIDs: Set<String>
    let preferFamiliar: Bool
    let lockedSelections: [StrengthRoutineSlotID: String]

    init(
        weekdays: [StrengthRoutineWeekday],
        sessionDuration: StrengthRoutineSessionDuration,
        goal: StrengthRoutineGoal,
        availableEquipment: Set<Equipment>,
        emphasis: MuscleGroup? = nil,
        includedCatalogIDs: Set<String> = [],
        excludedCatalogIDs: Set<String> = [],
        preferFamiliar: Bool = true,
        lockedSelections: [StrengthRoutineSlotID: String] = [:]
    ) {
        self.weekdays = weekdays
        self.sessionDuration = sessionDuration
        self.goal = goal
        self.availableEquipment = availableEquipment
        self.emphasis = emphasis
        self.includedCatalogIDs = includedCatalogIDs
        self.excludedCatalogIDs = excludedCatalogIDs
        self.preferFamiliar = preferFamiliar
        self.lockedSelections = lockedSelections
    }
}

// MARK: - Planning output

/// Conservative V1 prescription policy. It intentionally prescribes neither
/// load nor proximity to failure because the catalog cannot support those
/// decisions truthfully for every user.
nonisolated struct StrengthRoutinePrescription: Hashable {
    let sets: Int
    /// Exact editable template target, deterministically selected from the
    /// conservative policy range because persisted templates store one value.
    let targetReps: Int?
    let targetDurationSeconds: Int?

    init(sets: Int, targetReps: Int) {
        self.sets = sets
        self.targetReps = targetReps
        targetDurationSeconds = nil
    }

    init(sets: Int, targetDurationSeconds: Int) {
        self.sets = sets
        targetReps = nil
        self.targetDurationSeconds = targetDurationSeconds
    }
}

nonisolated enum StrengthRoutineSelectionReason: Hashable {
    case lockedByUser
    case includedByUser
    case movementCoverage(MovementPattern, PushPullDirection?)
    case muscleCoverage(MuscleGroup)
    case emphasis(MuscleGroup)
    case familiarExercise

    var summary: String {
        switch self {
        case .lockedByUser: "Locked by you"
        case .includedByUser: "Included by you"
        case let .movementCoverage(pattern, direction):
            if let direction {
                "\(direction.displayName.lowercased()) \(pattern.displayName.lowercased())"
            } else {
                "\(pattern.displayName.lowercased()) coverage"
            }
        case let .muscleCoverage(group): "\(group.displayName.lowercased()) coverage"
        case let .emphasis(group): "\(group.displayName.lowercased()) emphasis"
        case .familiarExercise: "Familiar exercise"
        }
    }
}

nonisolated struct StrengthRoutineExercise: Hashable, Identifiable {
    var id: String {
        candidate.catalogID
    }

    let candidate: StrengthRoutineCandidate
    let prescription: StrengthRoutinePrescription
    let selectionReasons: [StrengthRoutineSelectionReason]

    var catalogID: String {
        candidate.catalogID
    }

    var name: String {
        candidate.name
    }
}

nonisolated struct StrengthRoutineSlot: Hashable, Identifiable {
    let id: StrengthRoutineSlotID
    let kind: StrengthRoutineSlotKind
    let exercise: StrengthRoutineExercise?
}

nonisolated struct StrengthRoutineDay: Hashable, Identifiable {
    var id: StrengthRoutineWeekday {
        weekday
    }

    let weekday: StrengthRoutineWeekday
    let title: String
    let slots: [StrengthRoutineSlot]
}

nonisolated enum StrengthRoutineGapSeverity: Hashable {
    case blocking
    case advisory
}

nonisolated enum StrengthRoutineBodyRegion: CaseIterable, Hashable {
    case upperBody
    case lowerBody
    case trunk

    var title: String {
        switch self {
        case .upperBody: "upper-body"
        case .lowerBody: "lower-body"
        case .trunk: "trunk"
        }
    }

    func contains(_ group: MuscleGroup) -> Bool {
        switch self {
        case .upperBody:
            [.chest, .back, .shoulders, .arms].contains(group)
        case .lowerBody:
            group == .legs
        case .trunk:
            group == .core
        }
    }
}

nonisolated enum StrengthRoutineGapKind: Hashable {
    case invalidDayCount(Int)
    case unavailableIncludedExercise(String)
    case includedExerciseDoesNotFit(String)
    case unavailableLockedExercise(StrengthRoutineSlotID, String)
    case incompatibleLockedExercise(StrengthRoutineSlotID, String)
    case duplicateLockedExercise(StrengthRoutineSlotID, String)
    case unavailableLockedSlot(StrengthRoutineSlotID)
    case noEligibleExercise(StrengthRoutineSlotID)
    case noReplacementAvailable(StrengthRoutineSlotID)
    case repeatedExercise(String)
    case repeatedFamily(String, StrengthRoutineWeekday)
    case missingMovement(MovementPattern, PushPullDirection?)
    case missingBodyRegion(StrengthRoutineBodyRegion)
    case missingEmphasis(MuscleGroup)
}

nonisolated struct StrengthRoutineGap: Hashable {
    let severity: StrengthRoutineGapSeverity
    let kind: StrengthRoutineGapKind

    var message: String {
        switch kind {
        case let .invalidDayCount(count):
            "Choose 2 to 4 training days. Currently selected: \(count)."
        case .unavailableIncludedExercise:
            "An included exercise is unavailable with these constraints."
        case .includedExerciseDoesNotFit:
            "There is no suitable slot for an included exercise."
        case .unavailableLockedExercise:
            "A locked exercise is unavailable with these constraints."
        case .incompatibleLockedExercise:
            "A locked exercise does not match this plan position."
        case .duplicateLockedExercise:
            "A locked exercise is already used on this day."
        case .unavailableLockedSlot:
            "A locked slot is no longer part of this schedule."
        case let .noEligibleExercise(slotID):
            "No eligible exercise covers \(slotID.kind.title.lowercased())."
        case let .noReplacementAvailable(slotID):
            "No other exercise can replace \(slotID.kind.title.lowercased())."
        case .repeatedExercise:
            "No distinct exercise alternative was available."
        case .repeatedFamily:
            "This day repeats a movement family."
        case let .missingMovement(pattern, direction):
            if let direction {
                "This plan has no matching \(direction.displayName.lowercased()) \(pattern.displayName.lowercased())."
            } else {
                "This plan has no matching \(pattern.displayName.lowercased()) exercise."
            }
        case let .missingBodyRegion(region):
            "This plan has no direct \(region.title) exercise."
        case let .missingEmphasis(group):
            "This plan has no direct \(group.displayName.lowercased()) emphasis exercise."
        }
    }
}

nonisolated struct StrengthRoutinePlan: Hashable {
    let days: [StrengthRoutineDay]
    let gaps: [StrengthRoutineGap]

    var exercises: [StrengthRoutineExercise] {
        days.flatMap(\.slots).compactMap(\.exercise)
    }

    var hasBlockingGaps: Bool {
        gaps.contains { $0.severity == .blocking }
    }
}
