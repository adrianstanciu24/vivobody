//
//  ExercisePickerPurpose.swift
//  vivobody
//
//  Caller contract for ExercisePickerSheet. Each purpose keeps its title,
//  row affordance, accessibility copy, exclusions, and permission to enter
//  long-form comparison together so workout, template, and comparison flows
//  cannot accidentally inherit one another's behavior.
//

import Foundation

enum ExercisePickerPurpose: Equatable {
    /// Opens exercise detail, where the user confirms with the existing
    /// Add to Workout control.
    case explore

    /// Opens the same add-detail flow from an in-progress workout while
    /// suppressing long-form comparison and its Pro prompt.
    case addToActiveWorkout

    /// Adds a row directly to the template draft before configuration.
    case addToTemplate

    /// Selects a comparison target directly while hiding the anchor.
    case compare(anchorID: UUID, anchorName: String)

    /// Adds one bundled strength exercise to an explicit planner preference.
    case routineInclude(excludedIDs: Set<UUID>, equipment: Set<Equipment>)

    /// Adds one bundled strength exercise to the planner's avoid list.
    case routineAvoid(excludedIDs: Set<UUID>, equipment: Set<Equipment>)

    /// Replaces one generated slot with a bundled strength exercise.
    case routineSwap(
        excludedIDs: Set<UUID>,
        equipment: Set<Equipment>,
        compatibleCatalogIDs: Set<String>
    )

    var navigationTitle: String {
        switch self {
        case .explore, .addToActiveWorkout, .addToTemplate: "Add Exercise"
        case .compare: "Compare With"
        case .routineInclude: "Include Exercise"
        case .routineAvoid: "Avoid Exercise"
        case .routineSwap: "Swap Exercise"
        }
    }

    var excludedItemIDs: Set<UUID> {
        switch self {
        case let .compare(anchorID, _): [anchorID]
        case let .routineInclude(excludedIDs, _),
             let .routineAvoid(excludedIDs, _): excludedIDs
        case let .routineSwap(excludedIDs, _, _): excludedIDs
        default: []
        }
    }

    var rowAccessory: ExercisePickerRowAccessory {
        switch self {
        case .explore, .addToActiveWorkout: .disclosure
        case .addToTemplate, .routineInclude, .routineAvoid: .add
        case .compare: .compare
        case .routineSwap: .swap
        }
    }

    var directPickAccessibilityHint: String {
        switch self {
        case .explore, .addToActiveWorkout: "Shows exercise details"
        case .addToTemplate: "Adds this exercise to your template"
        case let .compare(_, anchorName): "Compares this exercise with \(anchorName)"
        case .routineInclude: "Includes this exercise in the routine"
        case .routineAvoid: "Excludes this exercise from the routine"
        case .routineSwap: "Uses this exercise in the selected routine slot"
        }
    }

    var allowsComparison: Bool {
        self != .addToActiveWorkout
    }

    var isRoutinePurpose: Bool {
        switch self {
        case .routineInclude, .routineAvoid, .routineSwap: true
        default: false
        }
    }

    var allowsCatalogEditing: Bool {
        !isRoutinePurpose
    }

    /// Comparison mirrors Library's catalog scopes so users can narrow the
    /// same exercise collection consistently. Other picker purposes retain
    /// their focused filter set.
    var includesCoreFilter: Bool {
        if case .compare = self { return true }
        return false
    }

    /// The source-level eligibility gate applied before catalog scopes and
    /// search ranking. General pickers accept every non-excluded item; routine
    /// pickers accept only reviewed bundled strength records allowed by the
    /// planner's equipment and swap-compatibility constraints.
    func includes(_ item: ExerciseCatalogItem) -> Bool {
        guard !excludedItemIDs.contains(item.id) else { return false }
        guard isRoutinePurpose else { return true }
        guard !item.isUserCreated, let catalogID = item.catalogID else { return false }
        return item.modality.supportsHardSetAnalytics
            && allowsRoutineEquipment(item.equipment)
            && allowsRoutineCatalogID(catalogID)
    }

    func allowsRoutineEquipment(_ equipment: Equipment) -> Bool {
        switch self {
        case let .routineInclude(_, available),
             let .routineAvoid(_, available):
            StrengthRoutinePolicy.allowsEquipment(
                equipment,
                selectedEquipment: available
            )
        case let .routineSwap(_, available, _):
            StrengthRoutinePolicy.allowsEquipment(
                equipment,
                selectedEquipment: available
            )
        default: true
        }
    }

    func allowsRoutineCatalogID(_ catalogID: String) -> Bool {
        switch self {
        case let .routineSwap(_, _, compatibleCatalogIDs):
            compatibleCatalogIDs.contains(catalogID)
        default: true
        }
    }
}

enum ExercisePickerRowAccessory {
    case disclosure
    case add
    case compare
    case swap

    var systemName: String {
        switch self {
        case .disclosure: "chevron.right"
        case .add: "plus"
        case .compare: "arrow.left.arrow.right"
        case .swap: "arrow.triangle.2.circlepath"
        }
    }
}
